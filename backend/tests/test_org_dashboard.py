"""Organisation dashboard: real aggregation over saved analyses, access control."""

from datetime import datetime, timedelta, timezone

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api import project_analyses as pa_module
from app.api.auth import verify_token
from app.api.org_deps import get_org_repo
from app.api.org_dashboard import router as dashboard_router
from app.api.organizations import router as org_router
from app.api.project_analyses import get_analysis_repo, router as analysis_router
from app.api.projects import get_project_repo, router as project_router
from app.models.organization import Role
from app.models.project import ProjectRecord
from app.services.analysis_repository import InMemoryAnalysisRepository
from app.services.org_dashboard import build_dashboard
from app.services.org_repository import InMemoryOrgRepository
from app.services.project_repository import InMemoryProjectRepository
from tests.test_organizations import as_user, create_org, fake_verify_token, seed_member
from tests.test_project_analyses import (  # noqa: F401  (fixture reused: fakes network only)
    REQUIREMENTS,
    fake_external_services,
    new_project,
    upload,
)

NOW = datetime(2026, 10, 21, 12, 0, tzinfo=timezone.utc)


def dist(low=0, medium=0, high=0, critical=0):
    return {"LOW": low, "MEDIUM": medium, "HIGH": high, "CRITICAL": critical}


def pointer(score, highest, d, *, analyzed=None, vulnerable=0, lic=0, unmaintained=0,
            undetermined=0, review=0, failed=0, when=NOW, aid="a1", filename="requirements.txt"):
    total = sum(d.values())
    analyzed = total if analyzed is None else analyzed
    return {
        "id": aid, "filename": filename, "created_at": when,
        "summary": {
            "compliance_score": score, "highest_risk": highest, "total_dependencies": analyzed + failed,
            "analyzed": analyzed, "failed": failed, "risk_distribution": d,
            "unmaintained": unmaintained, "maintenance_undetermined": undetermined,
            "vulnerable": vulnerable, "license_violations": lic, "needs_review": review,
        },
    }


def project(pid, name, latest=None, created=NOW):
    return ProjectRecord(pid, "org", name, "PyPI", None, "u", created, latest)


# --------------------------------------------------------------- pure aggregation
def test_empty_organisation():
    d = build_dashboard([])
    t = d.totals
    assert (t.projects, t.analysed_projects, t.not_analysed_projects) == (0, 0, 0)
    assert t.compliance_score is None and t.compliance_projects == 0
    assert t.risk_distribution == dist()
    assert d.recent_analyses == [] and d.attention_projects == [] and d.not_analysed_projects == []


def test_projects_without_analysis_are_listed_not_counted():
    d = build_dashboard([project("p1", "A"), project("p2", "B")])
    assert d.totals.projects == 2 and d.totals.analysed_projects == 0
    assert d.totals.not_analysed_projects == 2
    assert d.totals.compliance_score is None
    assert [p.id for p in d.not_analysed_projects] == ["p1", "p2"]


def test_totals_are_sums_over_latest_analyses_only():
    a = project("a", "A", pointer(80, "LOW", dist(low=2), vulnerable=0, lic=0, unmaintained=0, review=1))
    b = project("b", "B", pointer(50, "CRITICAL", dist(high=1, critical=1), vulnerable=2, lic=1,
                                  unmaintained=1, undetermined=3, review=2, failed=1, aid="b1"))
    d = build_dashboard([a, b, project("c", "C")])
    t = d.totals
    assert (t.projects, t.analysed_projects, t.not_analysed_projects) == (3, 2, 1)
    assert t.dependencies_analysed == 4 and t.dependencies_failed == 1 and t.dependencies_total == 5
    assert (t.vulnerable, t.license_violations, t.unmaintained) == (2, 1, 1)
    assert (t.maintenance_undetermined, t.needs_review) == (3, 3)
    assert t.risk_distribution == dist(low=2, high=1, critical=1)
    assert t.projects_by_highest_risk == dist(low=1, critical=1)


def test_compliance_is_risk_weighted_like_the_project_score():
    # A: score 80, 2 LOW deps  -> W = 2*1 = 2
    # B: score 50, 1 HIGH + 1 CRITICAL -> W = 1*3 + 1*4 = 7
    # org = (80*2 + 50*7) / 9 = 56.67 -> 57
    a = project("a", "A", pointer(80, "LOW", dist(low=2)))
    b = project("b", "B", pointer(50, "CRITICAL", dist(high=1, critical=1), aid="b1"))
    t = build_dashboard([a, b]).totals
    assert t.compliance_score == 57 and t.compliance_projects == 2


def test_compliance_ignores_projects_without_a_usable_score():
    a = project("a", "A", pointer(None, "LOW", dist(low=2)))
    b = project("b", "B", pointer(70, "MEDIUM", dist(medium=1), aid="b1"))
    t = build_dashboard([a, b]).totals
    assert t.compliance_score == 70 and t.compliance_projects == 1


@pytest.mark.parametrize(
    "latest",
    [
        None,
        {},
        {"id": "x"},                                           # no summary
        {"id": "x", "summary": "nope"},
        {"summary": {"analyzed": 3}},                          # no id
        {"id": "x", "summary": {"analyzed": 0, "compliance_score": 90}},  # nothing analysed
        {"id": "x", "summary": {"analyzed": "3"}},             # wrong type
    ],
)
def test_malformed_or_empty_pointers_are_treated_as_not_analysed(latest):
    d = build_dashboard([project("p", "P", latest)])
    assert d.totals.analysed_projects == 0 and d.totals.not_analysed_projects == 1
    assert d.totals.compliance_score is None


def test_garbage_values_inside_a_valid_summary_do_not_crash_or_inflate():
    latest = {"id": "x", "summary": {"analyzed": 2, "compliance_score": "high", "highest_risk": "SEVERE",
                                     "vulnerable": -5, "license_violations": None, "unmaintained": True,
                                     "risk_distribution": {"LOW": "a", "HIGH": 2.0}}}
    d = build_dashboard([project("p", "P", latest)])
    t = d.totals
    assert t.analysed_projects == 1
    assert t.compliance_score is None
    assert (t.vulnerable, t.license_violations, t.unmaintained) == (0, 0, 0)
    assert t.risk_distribution == dist(high=2)
    assert d.attention_projects == []          # unknown risk label is not ranked


def test_attention_ranking_and_exclusion_of_low_risk():
    low = project("low", "Low", pointer(95, "LOW", dist(low=3), aid="l"))
    med = project("med", "Med", pointer(70, "MEDIUM", dist(medium=2), aid="m"))
    high = project("high", "High", pointer(55, "HIGH", dist(high=1, low=1), aid="h"))
    crit_few = project("cf", "CritFew", pointer(40, "CRITICAL", dist(critical=1), aid="c1"))
    crit_many = project("cm", "CritMany", pointer(45, "CRITICAL", dist(critical=2, high=3), aid="c2"))
    d = build_dashboard([low, med, high, crit_few, crit_many])
    assert [p.id for p in d.attention_projects] == ["cm", "cf", "high", "med"]
    assert "low" not in [p.id for p in d.attention_projects]


def test_attention_tie_break_by_lower_score_then_name():
    a = project("a", "Beta", pointer(60, "HIGH", dist(high=1), aid="1"))
    b = project("b", "Alpha", pointer(60, "HIGH", dist(high=1), aid="2"))
    c = project("c", "Zeta", pointer(40, "HIGH", dist(high=1), aid="3"))
    assert [p.id for p in build_dashboard([a, b, c]).attention_projects] == ["c", "b", "a"]


def test_recent_analyses_newest_first_and_limited_to_five():
    projects = [
        project(f"p{i}", f"P{i}", pointer(80, "LOW", dist(low=1), when=NOW - timedelta(days=i), aid=f"a{i}"))
        for i in range(8)
    ]
    d = build_dashboard(list(reversed(projects)))
    assert [p.id for p in d.recent_analyses] == ["p0", "p1", "p2", "p3", "p4"]


def test_recent_analyses_handles_missing_and_naive_timestamps():
    a = project("a", "A", pointer(80, "LOW", dist(low=1), when=NOW, aid="a"))
    b = project("b", "B", pointer(80, "LOW", dist(low=1), when=None, aid="b"))
    c = project("c", "C", pointer(80, "LOW", dist(low=1), when=datetime(2020, 1, 1), aid="c"))
    assert [p.id for p in build_dashboard([b, c, a]).recent_analyses] == ["a", "c", "b"]


# --------------------------------------------------------------- endpoint
@pytest.fixture
def repos():
    return InMemoryOrgRepository(), InMemoryProjectRepository(), InMemoryAnalysisRepository()


@pytest.fixture
def client(repos):
    org, proj, ana = repos
    app = FastAPI()
    for r in (org_router, project_router, analysis_router, dashboard_router):
        app.include_router(r, prefix="/orgs")
    app.dependency_overrides[verify_token] = fake_verify_token
    app.dependency_overrides[get_org_repo] = lambda: org
    app.dependency_overrides[get_project_repo] = lambda: proj
    app.dependency_overrides[get_analysis_repo] = lambda: ana
    return TestClient(app)


def get_dash(client, org_id, uid="alice"):
    return client.get(f"/orgs/{org_id}/dashboard", headers=as_user(uid))


def test_empty_org_endpoint(client):
    org = create_org(client, "alice")
    r = get_dash(client, org["id"])
    assert r.status_code == 200
    body = r.json()
    assert body["totals"]["projects"] == 0 and body["totals"]["compliance_score"] is None
    assert body["recent_analyses"] == [] and body["attention_projects"] == []


def test_dashboard_reflects_real_stored_pipeline_results_without_rerunning(client, monkeypatch):
    org = create_org(client, "alice")
    p1 = new_project(client, org["id"])
    new_project(client, org["id"])  # second project never analysed
    first = upload(client, org["id"], p1["id"])
    assert first.status_code == 201

    # dashboard must be computed from saved data: make a re-run impossible
    def boom(*a, **k):
        raise AssertionError("dashboard must not re-run the analysis pipeline")

    monkeypatch.setattr(pa_module, "analyze_dependencies", boom)

    body = get_dash(client, org["id"]).json()
    saved = first.json()["summary"]
    t = body["totals"]
    assert (t["projects"], t["analysed_projects"], t["not_analysed_projects"]) == (2, 1, 1)
    assert t["dependencies_analysed"] == saved["analyzed"] == 4
    assert t["vulnerable"] == saved["vulnerable"] == 1
    assert t["license_violations"] == saved["license_violations"] == 1
    assert t["unmaintained"] == saved["unmaintained"] == 1
    assert t["risk_distribution"] == saved["risk_distribution"]
    assert t["compliance_score"] == saved["compliance_score"]   # single project -> identical
    assert body["recent_analyses"][0]["analysis_id"] == first.json()["id"]
    assert body["attention_projects"][0]["id"] == p1["id"]
    assert len(body["not_analysed_projects"]) == 1


def test_only_latest_analysis_per_project_counts(client):
    org = create_org(client, "alice")
    p = new_project(client, org["id"])
    upload(client, org["id"], p["id"])                               # 4 deps, vulnerable
    latest = upload(client, org["id"], p["id"], content="goodpkg==1.0.0\n").json()
    t = get_dash(client, org["id"]).json()["totals"]
    assert t["dependencies_analysed"] == 1 and t["vulnerable"] == 0
    assert get_dash(client, org["id"]).json()["recent_analyses"][0]["analysis_id"] == latest["id"]


@pytest.mark.parametrize("role", [Role.ADMIN, Role.LEAD, Role.DEVELOPER])
def test_every_member_role_can_read(client, repos, role):
    org = create_org(client, "alice")
    seed_member(repos[0], org["id"], "bob", role)
    assert get_dash(client, org["id"], "bob").status_code == 200


def test_non_member_and_anonymous_are_rejected(client):
    org = create_org(client, "alice")
    assert get_dash(client, org["id"], "mallory").status_code == 404
    assert client.get(f"/orgs/{org['id']}/dashboard").status_code == 401


def test_dashboard_is_scoped_to_the_organisation(client):
    a = create_org(client, "alice", "Org A")
    b = create_org(client, "bob", "Org B")
    pa = new_project(client, a["id"], uid="alice")
    upload(client, a["id"], pa["id"])
    new_project(client, b["id"], uid="bob")
    body = get_dash(client, b["id"], "bob").json()
    assert body["totals"]["projects"] == 1 and body["totals"]["analysed_projects"] == 0
    assert body["recent_analyses"] == []
"""Stage 2 tests: upload -> existing pipeline -> store -> history.

External network services (package registries, OSV, GitHub/ML feature fetch) are
replaced by deterministic fakes; the REAL parser, rule engine and governance
scoring run, so the stored result has the production shape.
"""

import io
import uuid

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api import project_analyses as pa_module
from app.api.auth import verify_token
from app.api.org_deps import get_org_repo
from app.api.organizations import router as org_router
from app.api.project_analyses import get_analysis_repo, router as analysis_router
from app.api.projects import get_project_repo, router as project_router
from app.models.organization import Role
from app.services import analysis_service as svc
from app.services.analysis_repository import (
    InMemoryAnalysisRepository,
    ResultTooLarge,
    prepare_result_for_storage,
)
from app.services.org_repository import InMemoryOrgRepository
from app.services.project_repository import InMemoryProjectRepository
from tests.test_organizations import as_user, create_org, fake_verify_token, seed_member

REQUIREMENTS = "goodpkg==1.0.0\nbadpkg==2.0.0\ngplpkg==3.0.0\noldpkg==4.0.0\n"
PUBSPEC = "name: app\ndependencies:\n  flutter:\n    sdk: flutter\n  http: ^1.2.0\n"


@pytest.fixture(autouse=True)
def fake_external_services(monkeypatch):
    def registry(name, ecosystem):
        return {
            "latest_version": "9.9.9",
            "license": "GPL-3.0-only" if name == "gplpkg" else "MIT",
            "repository_url": f"https://github.com/acme/{name}",
            "description": f"{name} package",
        }

    def osv(name, ecosystem, version):
        if name == "badpkg":
            return {
                "status": "ok", "queried_version": version, "scope": "exact_version",
                "vulnerability_count": 1, "highest_severity": "HIGH", "truncated": False,
                "vulnerabilities": [{
                    "id": "GHSA-test", "summary": "bad", "severity": "HIGH",
                    "aliases": [], "references": ["https://example.com/adv"],
                }],
            }
        return {
            "status": "ok", "queried_version": version, "scope": "exact_version",
            "vulnerability_count": 0, "highest_severity": "NONE", "truncated": False,
            "vulnerabilities": [],
        }

    def ml(repo_url):
        status = "Unmaintained" if repo_url and repo_url.endswith("/oldpkg") else "Maintained"
        return {
            "repository_url": repo_url,
            "repository_metadata": {"archived": False, "pushed_at": "2026-01-01T00:00:00Z"},
            "windows": [[1, 2, 3]] * 8,
            "features": {"f1": 1.0},
            "prediction": {"status": status, "probability_unmaintained": 0.9 if status == "Unmaintained" else 0.1},
        }

    monkeypatch.setattr(svc.registry_service, "get_package_metadata", registry)
    monkeypatch.setattr(svc.osv_service, "get_vulnerability_data", osv)
    monkeypatch.setattr(svc.ml_service, "predict_maintenance_status", ml)


@pytest.fixture
def repos():
    org, proj = InMemoryOrgRepository(), InMemoryProjectRepository()
    return org, proj, InMemoryAnalysisRepository()


@pytest.fixture
def client(repos):
    org, proj, ana = repos
    app = FastAPI()
    for r in (org_router, project_router, analysis_router):
        app.include_router(r, prefix="/orgs")
    app.dependency_overrides[verify_token] = fake_verify_token
    app.dependency_overrides[get_org_repo] = lambda: org
    app.dependency_overrides[get_project_repo] = lambda: proj
    app.dependency_overrides[get_analysis_repo] = lambda: ana
    return TestClient(app)


def new_project(client, org_id, ecosystem="PyPI", uid="alice"):
    r = client.post(f"/orgs/{org_id}/projects", json={"name": "Proj", "ecosystem": ecosystem}, headers=as_user(uid))
    assert r.status_code == 201, r.text
    return r.json()


def upload(client, org_id, project_id, filename="requirements.txt", content=REQUIREMENTS, uid="alice"):
    return client.post(
        f"/orgs/{org_id}/projects/{project_id}/analyses",
        files={"file": (filename, io.BytesIO(content.encode()), "text/plain")},
        headers=as_user(uid),
    )


def setup(client):
    org = create_org(client, "alice")
    return org, new_project(client, org["id"])


# ------------------------------------------------------------------ happy path
def test_run_stores_real_pipeline_result_and_history(client):
    org, proj = setup(client)
    r = upload(client, org["id"], proj["id"])
    assert r.status_code == 201, r.text
    data = r.json()

    assert data["filename"] == "requirements.txt"
    assert data["project_id"] == proj["id"]
    assert data["created_by_email"] == "alice@example.com"
    assert data["summary"]["total_dependencies"] == 4
    assert data["summary"]["vulnerable"] == 1
    assert data["summary"]["license_violations"] == 1
    assert data["summary"]["unmaintained"] == 1
    assert len(data["dependencies"]) == 4
    # real governance scoring ran: worst risk first
    assert data["dependencies"][0]["risk_rank"] == 1
    assert data["dependencies"][0]["governance"]["risk_level"] in ("HIGH", "CRITICAL")

    hist = client.get(f"/orgs/{org['id']}/projects/{proj['id']}/analyses", headers=as_user("alice")).json()["analyses"]
    assert [h["id"] for h in hist] == [data["id"]]
    assert "dependencies" not in hist[0]                 # list is light
    assert hist[0]["summary"]["compliance_score"] == data["summary"]["compliance_score"]

    full = client.get(f"/orgs/{org['id']}/projects/{proj['id']}/analyses/{data['id']}", headers=as_user("alice")).json()
    assert len(full["dependencies"]) == 4 and full["id"] == data["id"]


def test_history_is_newest_first(client):
    org, proj = setup(client)
    first = upload(client, org["id"], proj["id"]).json()["id"]
    second = upload(client, org["id"], proj["id"], content="goodpkg==1.0.0\n").json()["id"]
    hist = client.get(f"/orgs/{org['id']}/projects/{proj['id']}/analyses", headers=as_user("alice")).json()["analyses"]
    assert [h["id"] for h in hist] == [second, first]


def test_project_points_to_latest_analysis(client):
    org, proj = setup(client)
    assert client.get(f"/orgs/{org['id']}/projects/{proj['id']}", headers=as_user("alice")).json()["latest_analysis"] is None
    upload(client, org["id"], proj["id"])
    newest = upload(client, org["id"], proj["id"], content="goodpkg==1.0.0\n").json()
    p = client.get(f"/orgs/{org['id']}/projects/{proj['id']}", headers=as_user("alice")).json()
    assert p["latest_analysis"]["id"] == newest["id"]
    assert p["latest_analysis"]["summary"]["total_dependencies"] == 1
    listed = client.get(f"/orgs/{org['id']}/projects", headers=as_user("alice")).json()["projects"]
    assert listed[0]["latest_analysis"]["id"] == newest["id"]


# ------------------------------------------------------------------ permissions
@pytest.mark.parametrize("role,expected", [(Role.ADMIN, 201), (Role.LEAD, 201), (Role.DEVELOPER, 201), (None, 404)])
def test_run_permissions(client, repos, role, expected):
    org, proj = setup(client)
    if role is not None:
        seed_member(repos[0], org["id"], "bob", role)
    assert upload(client, org["id"], proj["id"], uid="bob").status_code == expected


def test_endpoints_require_authentication(client):
    org, proj = setup(client)
    base = f"/orgs/{org['id']}/projects/{proj['id']}/analyses"
    assert client.get(base).status_code == 401
    assert client.get(base + "/x").status_code == 401
    assert client.post(base, files={"file": ("requirements.txt", b"a==1", "text/plain")}).status_code == 401


def test_non_member_cannot_read_history(client):
    org, proj = setup(client)
    a = upload(client, org["id"], proj["id"]).json()
    base = f"/orgs/{org['id']}/projects/{proj['id']}/analyses"
    assert client.get(base, headers=as_user("mallory")).status_code == 404
    assert client.get(f"{base}/{a['id']}", headers=as_user("mallory")).status_code == 404


def test_analyses_are_isolated_per_project_and_organisation(client):
    org_a = create_org(client, "alice", "Org A")
    org_b = create_org(client, "alice", "Org B")  # alice admin in both
    p1, p2 = new_project(client, org_a["id"]), new_project(client, org_a["id"])
    pb = new_project(client, org_b["id"])
    a1 = upload(client, org_a["id"], p1["id"]).json()

    # other project, same org
    assert client.get(f"/orgs/{org_a['id']}/projects/{p2['id']}/analyses/{a1['id']}", headers=as_user("alice")).status_code == 404
    assert client.get(f"/orgs/{org_a['id']}/projects/{p2['id']}/analyses", headers=as_user("alice")).json()["analyses"] == []
    # other organisation
    assert client.get(f"/orgs/{org_b['id']}/projects/{pb['id']}/analyses/{a1['id']}", headers=as_user("alice")).status_code == 404
    assert client.get(f"/orgs/{org_b['id']}/projects/{p1['id']}/analyses", headers=as_user("alice")).status_code == 404
    assert upload(client, org_b["id"], p1["id"]).status_code == 404  # project id from another org


# ------------------------------------------------------------------ validation
def test_ecosystem_must_match_project(client):
    org, proj = setup(client)  # PyPI project
    r = upload(client, org["id"], proj["id"], "pubspec.yaml", PUBSPEC)
    assert r.status_code == 400 and "PyPI" in r.json()["detail"] and "pub" in r.json()["detail"]
    pub_proj = new_project(client, org["id"], "pub")
    assert upload(client, org["id"], pub_proj["id"], "pubspec.yaml", PUBSPEC).status_code == 201



@pytest.mark.parametrize(
    "filename,content,status",
    [
        ("notes.docx", "x", 400),
        ("requirements.txt", "", 400),
        ("requirements.txt", "# only a comment\n", 400),
        ("requirements.txt", "a" * (1024 * 1024 + 10), 413),
    ],
    # Short IDs prevent Windows environment-variable length errors.
    ids=["unsupported_type", "empty_file", "comments_only", "over_1mb"],
)
def test_bad_uploads(client, filename, content, status):
    org, proj = setup(client)
    assert upload(client, org["id"], proj["id"], filename, content).status_code == status


def test_non_utf8_upload_rejected(client):
    org, proj = setup(client)
    r = client.post(
        f"/orgs/{org['id']}/projects/{proj['id']}/analyses",
        files={"file": ("requirements.txt", b"\xff\xfe\x00bad", "text/plain")},
        headers=as_user("alice"),
    )
    assert r.status_code == 400


def test_path_components_in_filename_are_dropped(client):
    org, proj = setup(client)
    r = upload(client, org["id"], proj["id"], "..\\..\\evil/requirements.txt")
    assert r.status_code == 201 and r.json()["filename"] == "requirements.txt"


def test_malformed_ids_are_404(client):
    org, proj = setup(client)
    base = f"/orgs/{org['id']}/projects"
    assert client.get(f"{base}/{proj['id']}/analyses/{'a' * 200}", headers=as_user("alice")).status_code == 404
    assert client.get(f"{base}/{proj['id']}/analyses/{uuid.uuid4().hex}", headers=as_user("alice")).status_code == 404


# ------------------------------------------------------------------ failure handling
def test_nothing_is_stored_when_no_dependency_could_be_analyzed(client, monkeypatch):
    def boom(*a, **k):
        raise RuntimeError("network down")

    monkeypatch.setattr(svc.registry_service, "get_package_metadata", boom)
    org, proj = setup(client)
    r = upload(client, org["id"], proj["id"])
    assert r.status_code == 502
    assert client.get(f"/orgs/{org['id']}/projects/{proj['id']}/analyses", headers=as_user("alice")).json()["analyses"] == []
    assert client.get(f"/orgs/{org['id']}/projects/{proj['id']}", headers=as_user("alice")).json()["latest_analysis"] is None


def test_pipeline_crash_returns_502(client, monkeypatch):
    monkeypatch.setattr(pa_module, "analyze_dependencies", lambda *a, **k: (_ for _ in ()).throw(RuntimeError("x")))
    org, proj = setup(client)
    assert upload(client, org["id"], proj["id"]).status_code == 502


def test_too_large_result_returns_413(client, monkeypatch):
    def too_big(result):
        raise ResultTooLarge("big")

    monkeypatch.setattr(pa_module, "prepare_result_for_storage", too_big)
    org, proj = setup(client)
    assert upload(client, org["id"], proj["id"]).status_code == 413


# ------------------------------------------------------------------ storage trimming
def _fat_result(n=10):
    deps = [
        {
            "name": f"d{i}", "status": "analyzed",
            "maintenance": {"prediction": {"status": "Maintained"}, "windows": [[0] * 200] * 8, "features": {"a": 1}},
            "vulnerabilities": {"vulnerabilities": [{"id": "X", "references": ["https://a.b/" + "z" * 200] * 3}]},
        }
        for i in range(n)
    ]
    return {"summary": {"analyzed": n}, "dependencies": deps, "notes": []}


def test_small_results_are_stored_untouched():
    r = _fat_result(2)
    assert prepare_result_for_storage(r) is r


def test_bulky_detail_is_trimmed_to_fit_but_core_data_kept():
    r = _fat_result(10)
    slim = prepare_result_for_storage(r, limit=6000)
    d0 = slim["dependencies"][0]
    assert "windows" not in d0["maintenance"] and "features" not in d0["maintenance"]
    assert d0["maintenance"]["prediction"]["status"] == "Maintained"
    assert d0["vulnerabilities"]["vulnerabilities"][0]["id"] == "X"
    assert any("trimmed" in n for n in slim["notes"])
    assert "windows" in r["dependencies"][0]["maintenance"]  # original not mutated


def test_result_that_cannot_fit_raises():
    with pytest.raises(ResultTooLarge):
        prepare_result_for_storage(_fat_result(10), limit=100)
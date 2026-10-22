"""Stage 1 tests: project creation, listing, org isolation and role permissions."""

import uuid

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.auth import verify_token
from app.api.org_deps import get_org_repo
from app.api.organizations import router as org_router
from app.api.projects import MAX_PROJECTS_PER_ORG, get_project_repo, router as project_router
from app.models.organization import Role
from app.services.org_repository import InMemoryOrgRepository
from app.services.project_repository import InMemoryProjectRepository
from tests.test_organizations import as_user, create_org, fake_verify_token, seed_member


@pytest.fixture
def repos():
    return InMemoryOrgRepository(), InMemoryProjectRepository()


@pytest.fixture
def client(repos):
    org_repo, project_repo = repos
    app = FastAPI()
    app.include_router(org_router, prefix="/orgs")
    app.include_router(project_router, prefix="/orgs")
    app.dependency_overrides[verify_token] = fake_verify_token
    app.dependency_overrides[get_org_repo] = lambda: org_repo
    app.dependency_overrides[get_project_repo] = lambda: project_repo
    return TestClient(app)


def make_project(client, org_id, uid="alice", name="Mobile App", ecosystem="pub", **extra):
    r = client.post(
        f"/orgs/{org_id}/projects",
        json={"name": name, "ecosystem": ecosystem, **extra},
        headers=as_user(uid),
    )
    assert r.status_code == 201, r.text
    return r.json()


def test_admin_creates_project_and_it_is_listed(client):
    org = create_org(client, "alice")
    p = make_project(client, org["id"], repo_url="https://github.com/acme/app")
    assert p["name"] == "Mobile App" and p["ecosystem"] == "pub"
    assert p["org_id"] == org["id"]
    assert p["repo_url"] == "https://github.com/acme/app"

    listing = client.get(f"/orgs/{org['id']}/projects", headers=as_user("alice")).json()["projects"]
    assert [x["id"] for x in listing] == [p["id"]]
    one = client.get(f"/orgs/{org['id']}/projects/{p['id']}", headers=as_user("alice"))
    assert one.status_code == 200 and one.json()["id"] == p["id"]


@pytest.mark.parametrize(
    "role,expected",
    [(Role.ADMIN, 201), (Role.LEAD, 201), (Role.DEVELOPER, 403), (None, 404)],
)
def test_create_requires_lead_or_admin(client, repos, role, expected):
    org = create_org(client, "alice")
    if role is not None:
        seed_member(repos[0], org["id"], "bob", role)
    r = client.post(
        f"/orgs/{org['id']}/projects",
        json={"name": "Proj", "ecosystem": "npm"},
        headers=as_user("bob"),
    )
    assert r.status_code == expected


def test_all_members_can_read_non_members_cannot(client, repos):
    org = create_org(client, "alice")
    p = make_project(client, org["id"])
    seed_member(repos[0], org["id"], "dev", Role.DEVELOPER)

    assert client.get(f"/orgs/{org['id']}/projects", headers=as_user("dev")).status_code == 200
    assert client.get(f"/orgs/{org['id']}/projects/{p['id']}", headers=as_user("dev")).status_code == 200
    assert client.get(f"/orgs/{org['id']}/projects", headers=as_user("mallory")).status_code == 404
    assert client.get(f"/orgs/{org['id']}/projects/{p['id']}", headers=as_user("mallory")).status_code == 404


def test_endpoints_require_authentication(client):
    org = create_org(client, "alice")
    assert client.get(f"/orgs/{org['id']}/projects").status_code == 401
    assert client.post(f"/orgs/{org['id']}/projects", json={"name": "Ab", "ecosystem": "pub"}).status_code == 401


def test_project_cannot_be_read_through_another_organisation(client):
    a = create_org(client, "alice", "Org A")
    b = create_org(client, "alice", "Org B")  # alice is admin in BOTH
    pa = make_project(client, a["id"])
    r = client.get(f"/orgs/{b['id']}/projects/{pa['id']}", headers=as_user("alice"))
    assert r.status_code == 404
    assert client.get(f"/orgs/{b['id']}/projects", headers=as_user("alice")).json()["projects"] == []


def test_listing_only_contains_this_organisations_projects(client):
    a = create_org(client, "alice", "Org A")
    b = create_org(client, "bob", "Org B")
    make_project(client, a["id"], "alice", "A-proj")
    make_project(client, b["id"], "bob", "B-proj")
    names = [p["name"] for p in client.get(f"/orgs/{a['id']}/projects", headers=as_user("alice")).json()["projects"]]
    assert names == ["A-proj"]


@pytest.mark.parametrize(
    "body",
    [
        {"name": "", "ecosystem": "pub"},
        {"name": "a", "ecosystem": "pub"},
        {"name": "x" * 81, "ecosystem": "pub"},
        {"name": "Good", "ecosystem": "cargo"},
        {"name": "Good", "ecosystem": "PUB"},
        {"name": "Good"},
        {"name": "Good", "ecosystem": "pub", "repo_url": "ftp://x.io/r"},
        {"name": "Good", "ecosystem": "pub", "repo_url": "not a url"},
        {"name": "Good", "ecosystem": "pub", "repo_url": "https://x.io/" + "a" * 300},
        {"name": "Good", "ecosystem": "pub", "created_by": "someone"},
        {"name": "Good", "ecosystem": "pub", "org_id": "other"},
    ],
)
def test_invalid_project_bodies_rejected(client, body):
    org = create_org(client, "alice")
    r = client.post(f"/orgs/{org['id']}/projects", json=body, headers=as_user("alice"))
    assert r.status_code == 422


def test_blank_repo_url_becomes_none_and_ecosystems_accepted(client):
    org = create_org(client, "alice")
    for eco in ("pub", "PyPI", "npm"):
        p = make_project(client, org["id"], name=f"P-{eco}", ecosystem=eco, repo_url="  ")
        assert p["repo_url"] is None and p["ecosystem"] == eco


def test_malformed_ids_are_404(client):
    org = create_org(client, "alice")
    assert client.get(f"/orgs/{org['id']}/projects/{'a' * 200}", headers=as_user("alice")).status_code == 404
    assert client.get(f"/orgs/{org['id']}/projects/{uuid.uuid4().hex}", headers=as_user("alice")).status_code == 404


def test_project_limit_per_organisation(client):
    org = create_org(client, "alice")
    for i in range(MAX_PROJECTS_PER_ORG):
        make_project(client, org["id"], name=f"Proj {i:03d}")
    r = client.post(f"/orgs/{org['id']}/projects", json={"name": "Overflow", "ecosystem": "pub"}, headers=as_user("alice"))
    assert r.status_code == 409
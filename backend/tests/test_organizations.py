"""Tests for Feature 1: organisation creation, access control and role permissions.

These tests do NOT need Firebase: `verify_token` is replaced by a fake that reads
`Authorization: Bearer test-<uid>`, and Firestore by the in-memory repository.
The repository contract tests additionally run against the Firestore emulator
when FIRESTORE_EMULATOR_HOST is set.
"""

import os
import uuid

import pytest
from fastapi import FastAPI, Header, HTTPException
from fastapi.testclient import TestClient

from app.api.auth import verify_token
from app.api.org_deps import get_org_repo
from app.api.organizations import MAX_ORGS_PER_USER, router
from app.models.organization import Role
from app.services.org_repository import FirestoreOrgRepository, InMemoryOrgRepository


# --------------------------------------------------------------------------- #
# Fixtures
# --------------------------------------------------------------------------- #
def fake_verify_token(authorization: str = Header(default="")):
    if not authorization.startswith("Bearer test-"):
        raise HTTPException(status_code=401, detail="Invalid token")
    uid = authorization[len("Bearer test-"):]
    return {"uid": uid, "email": f"{uid}@example.com"}


@pytest.fixture
def repo():
    return InMemoryOrgRepository()


@pytest.fixture
def client(repo):
    app = FastAPI()
    app.include_router(router, prefix="/orgs")
    app.dependency_overrides[verify_token] = fake_verify_token
    app.dependency_overrides[get_org_repo] = lambda: repo
    return TestClient(app)


def as_user(uid):
    return {"Authorization": f"Bearer test-{uid}"}


def create_org(client, uid="alice", name="Acme Corp"):
    r = client.post("/orgs", json={"name": name}, headers=as_user(uid))
    assert r.status_code == 201, r.text
    return r.json()


def seed_member(repo, org_id, uid, role):
    repo.add_member(
        org_id=org_id, uid=uid, role=role, email=f"{uid}@example.com", added_by="seed"
    )


# --------------------------------------------------------------------------- #
# Role model
# --------------------------------------------------------------------------- #
def test_role_hierarchy():
    assert Role.ADMIN.at_least(Role.LEAD) and Role.ADMIN.at_least(Role.DEVELOPER)
    assert Role.LEAD.at_least(Role.DEVELOPER) and not Role.LEAD.at_least(Role.ADMIN)
    assert Role.DEVELOPER.at_least(Role.DEVELOPER)
    assert not Role.DEVELOPER.at_least(Role.LEAD)


@pytest.mark.parametrize("bad", [None, "", "owner", "ADMIN", 3, ["admin"]])
def test_unknown_stored_role_grants_nothing(bad):
    assert Role.parse(bad) is None


# --------------------------------------------------------------------------- #
# Organisation creation
# --------------------------------------------------------------------------- #
def test_create_makes_caller_admin_and_is_listed(client):
    org = create_org(client, "alice", "Acme Corp")
    assert org["name"] == "Acme Corp"
    assert org["role"] == "admin"
    assert org["id"]

    listing = client.get("/orgs", headers=as_user("alice")).json()["organizations"]
    assert [(o["id"], o["role"]) for o in listing] == [(org["id"], "admin")]


def test_name_is_trimmed_and_whitespace_collapsed(client):
    assert create_org(client, name="  Acme    Corp  ")["name"] == "Acme Corp"


@pytest.mark.parametrize("name", ["", " ", "a", "x" * 81, "bad\x00name", "tab\tname"])
def test_invalid_names_rejected(client, name):
    r = client.post("/orgs", json={"name": name}, headers=as_user("alice"))
    assert r.status_code == 422


def test_client_cannot_choose_role_or_owner(client):
    r = client.post(
        "/orgs",
        json={"name": "Evil Inc", "role": "admin", "created_by": "someone-else"},
        headers=as_user("mallory"),
    )
    assert r.status_code == 422
    assert client.get("/orgs", headers=as_user("mallory")).json()["organizations"] == []


def test_per_user_organization_limit(client):
    for i in range(MAX_ORGS_PER_USER):
        create_org(client, "alice", f"Org {i:02d}")
    r = client.post("/orgs", json={"name": "One too many"}, headers=as_user("alice"))
    assert r.status_code == 409
    # another user is unaffected
    create_org(client, "bob", "Bob's org")


# --------------------------------------------------------------------------- #
# Authentication
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize(
    "method,path,body",
    [
        ("post", "/orgs", {"name": "Acme"}),
        ("get", "/orgs", None),
        ("get", "/orgs/anything", None),
        ("patch", "/orgs/anything", {"name": "Acme"}),
    ],
)
def test_every_endpoint_requires_authentication(client, method, path, body):
    r = getattr(client, method)(path, **({"json": body} if body else {}))
    assert r.status_code == 401
    r = getattr(client, method)(
        path, headers={"Authorization": "Bearer garbage"}, **({"json": body} if body else {})
    )
    assert r.status_code == 401


# --------------------------------------------------------------------------- #
# Access control (membership)
# --------------------------------------------------------------------------- #
def test_non_member_gets_404_identical_to_missing_org(client):
    org = create_org(client, "alice")
    real = client.get(f"/orgs/{org['id']}", headers=as_user("mallory"))
    fake = client.get(f"/orgs/{uuid.uuid4().hex}", headers=as_user("mallory"))
    assert real.status_code == fake.status_code == 404
    assert real.json() == fake.json()  # no existence oracle


@pytest.mark.parametrize("org_id", ["..", "a" * 200, "a b", "x%2Fy", "a.b"])
def test_malformed_org_ids_are_404_not_500(client, org_id):
    r = client.get(f"/orgs/{org_id}", headers=as_user("alice"))
    assert r.status_code == 404


def test_members_see_org_with_their_own_role(client, repo):
    org = create_org(client, "alice")
    seed_member(repo, org["id"], "lena", Role.LEAD)
    seed_member(repo, org["id"], "dev", Role.DEVELOPER)

    for uid, role in [("alice", "admin"), ("lena", "lead"), ("dev", "developer")]:
        r = client.get(f"/orgs/{org['id']}", headers=as_user(uid))
        assert r.status_code == 200
        assert r.json()["role"] == role


def test_listing_is_isolated_per_user(client, repo):
    a = create_org(client, "alice", "Alice Org")
    b = create_org(client, "bob", "Bob Org")
    seed_member(repo, a["id"], "bob", Role.DEVELOPER)

    alice_ids = {o["id"] for o in client.get("/orgs", headers=as_user("alice")).json()["organizations"]}
    bob = {o["id"]: o["role"] for o in client.get("/orgs", headers=as_user("bob")).json()["organizations"]}
    assert alice_ids == {a["id"]}
    assert bob == {a["id"]: "developer", b["id"]: "admin"}


def test_client_supplied_role_hints_are_ignored(client, repo):
    org = create_org(client, "alice")
    seed_member(repo, org["id"], "dev", Role.DEVELOPER)
    spoof = {**as_user("dev"), "X-Org-Role": "admin", "X-Org-Id": org["id"], "X-Role": "admin"}

    # developer cannot rename even when claiming admin via headers/query
    r = client.patch(f"/orgs/{org['id']}?role=admin", json={"name": "Hijacked"}, headers=spoof)
    assert r.status_code == 403
    # a non-member claiming membership via headers/query still sees nothing
    spoof2 = {**as_user("mallory"), "X-Org-Role": "admin", "X-Org-Id": org["id"]}
    assert client.get(f"/orgs/{org['id']}?role=admin", headers=spoof2).status_code == 404
    assert client.get(f"/orgs/{org['id']}", headers=as_user("alice")).json()["name"] == "Acme Corp"


def test_stale_listing_entry_without_member_record_is_not_listed(client, repo):
    """Mirror/index entry exists but the authoritative membership was removed."""
    org = create_org(client, "alice")
    del repo._members[(org["id"], "alice")]
    assert client.get("/orgs", headers=as_user("alice")).json()["organizations"] == []
    assert client.get(f"/orgs/{org['id']}", headers=as_user("alice")).status_code == 404


def test_corrupt_stored_role_denies_access(client, repo):
    org = create_org(client, "alice")
    repo._members[(org["id"], "alice")] = "superuser"
    assert client.get(f"/orgs/{org['id']}", headers=as_user("alice")).status_code == 404


# --------------------------------------------------------------------------- #
# Role permissions
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize(
    "role,expected",
    [(Role.ADMIN, 200), (Role.LEAD, 403), (Role.DEVELOPER, 403), (None, 404)],
)
def test_rename_is_admin_only(client, repo, role, expected):
    org = create_org(client, "alice", "Before")
    if role is not None and role is not Role.ADMIN:
        seed_member(repo, org["id"], "bob", role)
    if role is Role.ADMIN:
        seed_member(repo, org["id"], "bob", Role.ADMIN)

    r = client.patch(f"/orgs/{org['id']}", json={"name": "After"}, headers=as_user("bob"))
    assert r.status_code == expected

    stored = repo.get_organization(org["id"]).name
    assert stored == ("After" if expected == 200 else "Before")


def test_rename_validates_and_forbids_extra_fields(client):
    org = create_org(client, "alice")
    h = as_user("alice")
    assert client.patch(f"/orgs/{org['id']}", json={"name": "x"}, headers=h).status_code == 422
    assert (
        client.patch(f"/orgs/{org['id']}", json={"name": "Valid", "created_by": "z"}, headers=h).status_code
        == 422
    )


# --------------------------------------------------------------------------- #
# Repository contract (memory always; Firestore only against the emulator)
# --------------------------------------------------------------------------- #
def _repo_factories():
    factories = [pytest.param(InMemoryOrgRepository, id="memory")]
    if os.environ.get("FIRESTORE_EMULATOR_HOST"):
        def make():
            from google.cloud import firestore

            return FirestoreOrgRepository(client=firestore.Client(project="demo-checkmydeps"))

        factories.append(pytest.param(make, id="firestore-emulator"))
    return factories


@pytest.fixture(params=_repo_factories())
def any_repo(request):
    return request.param()


def test_contract_create_get_roles_and_listing(any_repo):
    uid_a, uid_b = f"a-{uuid.uuid4().hex[:8]}", f"b-{uuid.uuid4().hex[:8]}"
    org = any_repo.create_organization(name="Contract Org", creator_uid=uid_a, creator_email="a@x.io")

    assert any_repo.get_organization(org.id).name == "Contract Org"
    assert any_repo.get_member_role(org.id, uid_a) == Role.ADMIN
    assert any_repo.get_member_role(org.id, uid_b) is None
    assert any_repo.get_organization("does-not-exist") is None

    any_repo.add_member(org_id=org.id, uid=uid_b, role=Role.LEAD, email=None, added_by=uid_a)
    assert any_repo.get_member_role(org.id, uid_b) == Role.LEAD
    assert [(o.id, r) for o, r in any_repo.list_memberships(uid_b)] == [(org.id, Role.LEAD)]

    assert any_repo.rename_organization(org.id, "Renamed").name == "Renamed"
    assert any_repo.rename_organization("does-not-exist", "x") is None
    assert any_repo.list_memberships(f"nobody-{uuid.uuid4().hex[:8]}") == []

"""Persistence for organisations.

`OrgRepository` is the interface the API depends on. Two implementations:
  * FirestoreOrgRepository  - production (Firebase Admin SDK, bypasses client rules)
  * InMemoryOrgRepository   - unit tests
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional, Protocol, Tuple

from app.models.organization import OrgRecord, Role

ORGS = "organizations"
MEMBERS = "members"
USER_MEMBERSHIPS = "user_memberships"
USER_MEMBERSHIP_ORGS = "orgs"


class OrgRepository(Protocol):
    def create_organization(
        self, *, name: str, creator_uid: str, creator_email: Optional[str]
    ) -> OrgRecord: ...

    def get_organization(self, org_id: str) -> Optional[OrgRecord]: ...

    def get_member_role(self, org_id: str, uid: str) -> Optional[Role]: ...

    def list_memberships(self, uid: str) -> List[Tuple[OrgRecord, Role]]: ...

    def rename_organization(self, org_id: str, name: str) -> Optional[OrgRecord]: ...

    def add_member(
        self,
        *,
        org_id: str,
        uid: str,
        role: Role,
        email: Optional[str],
        added_by: str,
    ) -> None: ...


def _now() -> datetime:
    return datetime.now(timezone.utc)


# --------------------------------------------------------------------------- #
# In-memory (tests)
# --------------------------------------------------------------------------- #
class InMemoryOrgRepository:
    def __init__(self) -> None:
        self._orgs: Dict[str, OrgRecord] = {}
        self._members: Dict[Tuple[str, str], str] = {}  # (org_id, uid) -> raw role
        self._index: Dict[str, List[str]] = {}  # uid -> [org_id]  (mirror)

    def create_organization(self, *, name, creator_uid, creator_email):
        org = OrgRecord(
            id=uuid.uuid4().hex,
            name=name,
            created_by=creator_uid,
            created_at=_now(),
        )
        self._orgs[org.id] = org
        self._members[(org.id, creator_uid)] = Role.ADMIN.value
        self._index.setdefault(creator_uid, []).append(org.id)
        return org

    def get_organization(self, org_id):
        return self._orgs.get(org_id)

    def get_member_role(self, org_id, uid):
        return Role.parse(self._members.get((org_id, uid)))

    def list_memberships(self, uid):
        out = []
        for org_id in self._index.get(uid, []):
            org = self._orgs.get(org_id)
            role = self.get_member_role(org_id, uid)  # authoritative check
            if org is not None and role is not None:
                out.append((org, role))
        out.sort(key=lambda pair: (pair[0].name.lower(), pair[0].id))
        return out

    def rename_organization(self, org_id, name):
        org = self._orgs.get(org_id)
        if org is None:
            return None
        updated = OrgRecord(org.id, name, org.created_by, org.created_at)
        self._orgs[org_id] = updated
        return updated

    def add_member(self, *, org_id, uid, role, email, added_by):
        self._members[(org_id, uid)] = role.value
        ids = self._index.setdefault(uid, [])
        if org_id not in ids:
            ids.append(org_id)


# --------------------------------------------------------------------------- #
# Firestore (production)
# --------------------------------------------------------------------------- #
class FirestoreOrgRepository:
    """Uses the project's existing Firestore client (`app.database.firestore.db`).

    Pass `client=` to inject a google.cloud.firestore.Client (e.g. the emulator).
    """

    def __init__(self, client=None) -> None:
        self._client = client

    @property
    def db(self):
        if self._client is None:
            # Lazy import: app.database.firestore initialises Firebase Admin at import time.
            from app.database.firestore import db

            self._client = db
        return self._client

    # -- helpers ---------------------------------------------------------- #
    def _org_ref(self, org_id: str):
        return self.db.collection(ORGS).document(org_id)

    def _member_ref(self, org_id: str, uid: str):
        return self._org_ref(org_id).collection(MEMBERS).document(uid)

    def _mirror_ref(self, uid: str, org_id: str):
        return (
            self.db.collection(USER_MEMBERSHIPS)
            .document(uid)
            .collection(USER_MEMBERSHIP_ORGS)
            .document(org_id)
        )

    @staticmethod
    def _to_record(snap) -> Optional[OrgRecord]:
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        return OrgRecord(
            id=snap.id,
            name=str(data.get("name", "")),
            created_by=str(data.get("created_by", "")),
            created_at=data.get("created_at"),
        )

    # -- interface -------------------------------------------------------- #
    def create_organization(self, *, name, creator_uid, creator_email):
        now = _now()
        org_ref = self.db.collection(ORGS).document()  # auto id
        batch = self.db.batch()  # atomic: org + admin membership + index entry
        batch.set(
            org_ref,
            {"name": name, "created_by": creator_uid, "created_at": now},
        )
        batch.set(
            org_ref.collection(MEMBERS).document(creator_uid),
            {
                "uid": creator_uid,
                "role": Role.ADMIN.value,
                "email": creator_email,
                "added_by": creator_uid,
                "added_at": now,
            },
        )
        batch.set(
            self._mirror_ref(creator_uid, org_ref.id),
            {"org_id": org_ref.id, "joined_at": now},
        )
        batch.commit()
        return OrgRecord(
            id=org_ref.id, name=name, created_by=creator_uid, created_at=now
        )

    def get_organization(self, org_id):
        return self._to_record(self._org_ref(org_id).get())

    def get_member_role(self, org_id, uid):
        snap = self._member_ref(org_id, uid).get()
        if not snap.exists:
            return None
        return Role.parse((snap.to_dict() or {}).get("role"))

    def list_memberships(self, uid):
        mirror = (
            self.db.collection(USER_MEMBERSHIPS)
            .document(uid)
            .collection(USER_MEMBERSHIP_ORGS)
            .stream()
        )
        org_ids = [d.id for d in mirror]
        if not org_ids:
            return []

        org_snaps = {
            s.id: s for s in self.db.get_all([self._org_ref(i) for i in org_ids])
        }
        member_snaps = {
            s.reference.parent.parent.id: s
            for s in self.db.get_all([self._member_ref(i, uid) for i in org_ids])
        }

        out: List[Tuple[OrgRecord, Role]] = []
        for org_id in org_ids:
            org = self._to_record(org_snaps[org_id]) if org_id in org_snaps else None
            msnap = member_snaps.get(org_id)
            role = (
                Role.parse((msnap.to_dict() or {}).get("role"))
                if msnap is not None and msnap.exists
                else None
            )
            # The authoritative member doc must exist and be valid; otherwise
            # the mirror entry is stale and the organisation is NOT listed.
            if org is not None and role is not None:
                out.append((org, role))
        out.sort(key=lambda pair: (pair[0].name.lower(), pair[0].id))
        return out

    def rename_organization(self, org_id, name):
        ref = self._org_ref(org_id)
        if not ref.get().exists:
            return None
        ref.update({"name": name})
        return self._to_record(ref.get())

    def add_member(self, *, org_id, uid, role, email, added_by):
        now = _now()
        batch = self.db.batch()
        batch.set(
            self._member_ref(org_id, uid),
            {
                "uid": uid,
                "role": role.value,
                "email": email,
                "added_by": added_by,
                "added_at": now,
            },
        )
        batch.set(self._mirror_ref(uid, org_id), {"org_id": org_id, "joined_at": now})
        batch.commit()


_default_repo: Optional[FirestoreOrgRepository] = None


def get_default_repository() -> FirestoreOrgRepository:
    global _default_repo
    if _default_repo is None:
        _default_repo = FirestoreOrgRepository()
    return _default_repo

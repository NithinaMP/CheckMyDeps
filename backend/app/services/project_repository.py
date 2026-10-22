"""Persistence for organisation projects (in-memory for tests, Firestore for prod)."""

from __future__ import annotations

import dataclasses
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from app.models.project import ProjectRecord

ORGS = "organizations"
PROJECTS = "projects"


def _now() -> datetime:
    return datetime.now(timezone.utc)


class InMemoryProjectRepository:
    def __init__(self) -> None:
        self._projects: Dict[str, Dict[str, ProjectRecord]] = {}  # org_id -> id -> rec

    def create_project(self, *, org_id, name, ecosystem, repo_url, created_by):
        rec = ProjectRecord(
            id=uuid.uuid4().hex,
            org_id=org_id,
            name=name,
            ecosystem=ecosystem,
            repo_url=repo_url,
            created_by=created_by,
            created_at=_now(),
        )
        self._projects.setdefault(org_id, {})[rec.id] = rec
        return rec

    def get_project(self, org_id, project_id):
        return self._projects.get(org_id, {}).get(project_id)

    def set_latest_analysis(self, org_id, project_id, latest: Dict[str, Any]) -> None:
        rec = self._projects.get(org_id, {}).get(project_id)
        if rec is not None:
            self._projects[org_id][project_id] = dataclasses.replace(
                rec, latest_analysis=latest
            )

    def list_projects(self, org_id) -> List[ProjectRecord]:
        items = list(self._projects.get(org_id, {}).values())
        items.sort(key=lambda p: (p.created_at, p.id), reverse=True)
        return items


class FirestoreProjectRepository:
    def __init__(self, client=None) -> None:
        self._client = client

    @property
    def db(self):
        if self._client is None:
            from app.database.firestore import db  # initialises Firebase Admin

            self._client = db
        return self._client

    def _col(self, org_id: str):
        return self.db.collection(ORGS).document(org_id).collection(PROJECTS)

    @staticmethod
    def _to_record(org_id: str, snap) -> Optional[ProjectRecord]:
        if not snap.exists:
            return None
        d = snap.to_dict() or {}
        return ProjectRecord(
            id=snap.id,
            org_id=org_id,
            name=str(d.get("name", "")),
            ecosystem=str(d.get("ecosystem", "")),
            repo_url=d.get("repo_url"),
            created_by=str(d.get("created_by", "")),
            created_at=d.get("created_at"),
            latest_analysis=d.get("latest_analysis"),
        )

    def create_project(self, *, org_id, name, ecosystem, repo_url, created_by):
        now = _now()
        ref = self._col(org_id).document()
        ref.set(
            {
                "name": name,
                "ecosystem": ecosystem,
                "repo_url": repo_url,
                "created_by": created_by,
                "created_at": now,
            }
        )
        return ProjectRecord(ref.id, org_id, name, ecosystem, repo_url, created_by, now)

    def get_project(self, org_id, project_id):
        return self._to_record(org_id, self._col(org_id).document(project_id).get())

    def set_latest_analysis(self, org_id, project_id, latest: Dict[str, Any]) -> None:
        self._col(org_id).document(project_id).update({"latest_analysis": latest})

    def list_projects(self, org_id) -> List[ProjectRecord]:
        snaps = self._col(org_id).order_by("created_at", direction="DESCENDING").stream()
        return [r for r in (self._to_record(org_id, s) for s in snaps) if r is not None]


_default_repo: Optional[FirestoreProjectRepository] = None


def get_default_project_repository() -> FirestoreProjectRepository:
    global _default_repo
    if _default_repo is None:
        _default_repo = FirestoreProjectRepository()
    return _default_repo
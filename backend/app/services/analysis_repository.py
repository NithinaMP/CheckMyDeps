"""Persistence for stored analyses (in-memory for tests, Firestore for prod)."""

from __future__ import annotations

import copy
import json
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from app.models.project_analysis import AnalysisRecord

ORGS = "organizations"
PROJECTS = "projects"
ANALYSES = "analyses"

# Firestore documents are limited to 1 MiB; stay comfortably below it.
MAX_STORED_BYTES = 900_000
LIST_LIMIT = 50


class ResultTooLarge(Exception):
    pass


def _size(obj: Any) -> int:
    return len(json.dumps(obj, separators=(",", ":"), default=str).encode("utf-8"))


def prepare_result_for_storage(result: Dict[str, Any], limit: int = MAX_STORED_BYTES) -> Dict[str, Any]:
    """Returns `result` unchanged if it fits; otherwise a copy with bulky
    diagnostic detail removed (ML commit windows/features, vulnerability
    reference links). Raises ResultTooLarge if it still does not fit."""
    if _size(result) <= limit:
        return result

    slim = copy.deepcopy(result)
    for dep in slim.get("dependencies", []):
        maintenance = dep.get("maintenance")
        if isinstance(maintenance, dict):
            maintenance.pop("windows", None)
            maintenance.pop("features", None)
        vulns = dep.get("vulnerabilities")
        if isinstance(vulns, dict):
            for item in vulns.get("vulnerabilities") or []:
                if isinstance(item, dict):
                    item["references"] = []
    slim.setdefault("notes", []).append(
        "Some bulky diagnostic detail was trimmed to fit storage."
    )
    if _size(slim) > limit:
        raise ResultTooLarge("Analysis result is too large to store")
    return slim


def _now() -> datetime:
    return datetime.now(timezone.utc)


class InMemoryAnalysisRepository:
    def __init__(self) -> None:
        self._rows: Dict[tuple, List[AnalysisRecord]] = {}  # (org, project) -> records

    def save(self, *, org_id, project_id, filename, created_by, created_by_email, result):
        rec = AnalysisRecord(
            id=uuid.uuid4().hex,
            project_id=project_id,
            filename=filename,
            created_by=created_by,
            created_by_email=created_by_email,
            created_at=_now(),
            summary=copy.deepcopy(result.get("summary") or {}),
            result=json.loads(json.dumps(result, default=str)),  # like a real store
        )
        self._rows.setdefault((org_id, project_id), []).append(rec)
        return rec

    def list(self, org_id, project_id, limit: int = LIST_LIMIT) -> List[AnalysisRecord]:
        rows = list(reversed(self._rows.get((org_id, project_id), [])))
        return rows[:limit]

    def get(self, org_id, project_id, analysis_id) -> Optional[AnalysisRecord]:
        for rec in self._rows.get((org_id, project_id), []):
            if rec.id == analysis_id:
                return rec
        return None


class FirestoreAnalysisRepository:
    def __init__(self, client=None) -> None:
        self._client = client

    @property
    def db(self):
        if self._client is None:
            from app.database.firestore import db  # initialises Firebase Admin

            self._client = db
        return self._client

    def _col(self, org_id: str, project_id: str):
        return (
            self.db.collection(ORGS)
            .document(org_id)
            .collection(PROJECTS)
            .document(project_id)
            .collection(ANALYSES)
        )

    def save(self, *, org_id, project_id, filename, created_by, created_by_email, result):
        now = _now()
        summary = result.get("summary") or {}
        ref = self._col(org_id, project_id).document()
        ref.set(
            {
                "filename": filename,
                "created_by": created_by,
                "created_by_email": created_by_email,
                "created_at": now,
                "summary": summary,
                "result_json": json.dumps(result, separators=(",", ":"), default=str),
            }
        )
        return AnalysisRecord(
            ref.id, project_id, filename, created_by, created_by_email, now, summary, result
        )

    def list(self, org_id, project_id, limit: int = LIST_LIMIT) -> List[AnalysisRecord]:
        query = (
            self._col(org_id, project_id)
            .select(["filename", "created_by_email", "created_at", "summary"])  # skip big payload
            .order_by("created_at", direction="DESCENDING")
            .limit(limit)
        )
        out = []
        for snap in query.stream():
            d = snap.to_dict() or {}
            out.append(
                AnalysisRecord(
                    id=snap.id,
                    project_id=project_id,
                    filename=str(d.get("filename", "")),
                    created_by="",
                    created_by_email=d.get("created_by_email"),
                    created_at=d.get("created_at"),
                    summary=d.get("summary") or {},
                )
            )
        return out

    def get(self, org_id, project_id, analysis_id) -> Optional[AnalysisRecord]:
        snap = self._col(org_id, project_id).document(analysis_id).get()
        if not snap.exists:
            return None
        d = snap.to_dict() or {}
        try:
            result = json.loads(d.get("result_json") or "{}")
        except ValueError:
            result = {}
        return AnalysisRecord(
            id=snap.id,
            project_id=project_id,
            filename=str(d.get("filename", "")),
            created_by=str(d.get("created_by", "")),
            created_by_email=d.get("created_by_email"),
            created_at=d.get("created_at"),
            summary=d.get("summary") or {},
            result=result,
        )


_default_repo: Optional[FirestoreAnalysisRepository] = None


def get_default_analysis_repository() -> FirestoreAnalysisRepository:
    global _default_repo
    if _default_repo is None:
        _default_repo = FirestoreAnalysisRepository()
    return _default_repo
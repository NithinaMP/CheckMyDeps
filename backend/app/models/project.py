"""Project models (Organisation portal, Stage 1).

Firestore: organizations/{orgId}/projects/{projectId}
Because projects live UNDER the organisation path, a project id can never be
resolved through a different organisation's URL.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, field_validator

from app.models.organization import OrgName, normalize_org_name

_URL_RE = re.compile(r"^https?://[^\s]+$")
REPO_URL_MAX = 300


class Ecosystem(str, Enum):
    """Same identifiers the dependency parser / registry service already use."""

    PUB = "pub"
    PYPI = "PyPI"
    NPM = "npm"


class ProjectCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: OrgName
    ecosystem: Ecosystem
    repo_url: Optional[str] = None

    @field_validator("name")
    @classmethod
    def _check_name(cls, v: str) -> str:
        return normalize_org_name(v)

    @field_validator("repo_url")
    @classmethod
    def _check_repo_url(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        v = v.strip()
        if not v:
            return None
        if len(v) > REPO_URL_MAX or not _URL_RE.match(v):
            raise ValueError("Repository link must be a valid http(s) URL")
        return v

class LatestAnalysisOut(BaseModel):
    """Pointer to a project's most recent stored analysis (summary only)."""

    id: str
    filename: str
    created_at: Optional[datetime] = None
    summary: Dict[str, Any]

class ProjectOut(BaseModel):
    id: str
    org_id: str
    name: str
    ecosystem: Ecosystem
    repo_url: Optional[str] = None
    created_at: Optional[datetime] = None
    latest_analysis: Optional[LatestAnalysisOut] = None


class ProjectListOut(BaseModel):
    projects: List[ProjectOut]


@dataclass(frozen=True)
class ProjectRecord:
    id: str
    org_id: str
    name: str
    ecosystem: str
    repo_url: Optional[str]
    created_by: str
    created_at: Optional[datetime] = None
    latest_analysis: Optional[Dict[str, Any]] = None
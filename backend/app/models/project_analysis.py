"""Models for stored project analyses (Organisation portal, Stage 2).

Firestore: organizations/{orgId}/projects/{projectId}/analyses/{analysisId}
  filename, created_by, created_by_email, created_at,
  summary   (map: same as the pipeline's `summary`)  <- cheap to list
  result_json (string: the full pipeline result)       <- read only when opened
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel


class AnalysisListItem(BaseModel):
    id: str
    filename: str
    created_at: Optional[datetime] = None
    created_by_email: Optional[str] = None
    summary: Dict[str, Any]


class AnalysisListOut(BaseModel):
    analyses: List[AnalysisListItem]


@dataclass(frozen=True)
class AnalysisRecord:
    id: str
    project_id: str
    filename: str
    created_by: str
    created_by_email: Optional[str]
    created_at: Optional[datetime]
    summary: Dict[str, Any]
    result: Dict[str, Any] = field(default_factory=dict)  # empty for list items
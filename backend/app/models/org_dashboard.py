"""Response models for the organisation dashboard (read-only aggregation)."""

from __future__ import annotations

from datetime import datetime
from typing import Dict, List, Optional

from pydantic import BaseModel


class DashboardProjectOut(BaseModel):
    id: str
    name: str
    ecosystem: str
    repo_url: Optional[str] = None
    created_at: Optional[datetime] = None
    # latest saved analysis (None when the project has not been analysed)
    analysis_id: Optional[str] = None
    filename: Optional[str] = None
    analysed_at: Optional[datetime] = None
    compliance_score: Optional[int] = None
    highest_risk: Optional[str] = None
    risk_distribution: Dict[str, int] = {}
    total_dependencies: int = 0
    analyzed: int = 0
    failed: int = 0
    vulnerable: int = 0
    license_violations: int = 0
    unmaintained: int = 0


class DashboardTotalsOut(BaseModel):
    projects: int
    analysed_projects: int
    not_analysed_projects: int
    dependencies_total: int
    dependencies_analysed: int
    dependencies_failed: int
    vulnerable: int
    license_violations: int
    unmaintained: int
    maintenance_undetermined: int
    needs_review: int
    risk_distribution: Dict[str, int]
    projects_by_highest_risk: Dict[str, int]
    compliance_score: Optional[int] = None
    compliance_projects: int = 0


class OrgDashboardOut(BaseModel):
    generated_at: datetime
    totals: DashboardTotalsOut
    recent_analyses: List[DashboardProjectOut]
    attention_projects: List[DashboardProjectOut]
    not_analysed_projects: List[DashboardProjectOut]
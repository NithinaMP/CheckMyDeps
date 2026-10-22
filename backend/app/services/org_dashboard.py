"""Organisation dashboard aggregation.

Pure function over the organisation's project records. It only reads each
project's saved `latest_analysis` pointer (written when an analysis is stored);
it never re-runs the analysis pipeline and never invents data.

Compliance score
----------------
A project's saved compliance_score is the risk-weighted average of its
dependency scores (weights per risk level: PROJECT_RISK_WEIGHTS). The same
weights are applied again here, using each project's saved risk distribution to
recover its total weight W_p:

    org_score = sum(score_p * W_p) / sum(W_p)
    W_p       = sum(count_level * PROJECT_RISK_WEIGHTS[level])

That equals the risk-weighted average over ALL analysed dependencies in the
organisation (up to <1 point of rounding, because project scores are stored
rounded). Projects without a valid analysis are not included.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from app.governance_config import PROJECT_RISK_WEIGHTS, RISK_LEVELS
from app.models.org_dashboard import (
    DashboardProjectOut,
    DashboardTotalsOut,
    OrgDashboardOut,
)

LIST_SIZE = 5
ATTENTION_LEVELS = ("MEDIUM", "HIGH", "CRITICAL")


def _int(value: Any) -> int:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return 0
    return max(0, int(value))


def _opt_int(value: Any) -> Optional[int]:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return int(value)


def _distribution(raw: Any) -> Dict[str, int]:
    raw = raw if isinstance(raw, dict) else {}
    return {level: _int(raw.get(level)) for level in RISK_LEVELS}


def _ts(value: Any) -> float:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.timestamp()
    return 0.0


def _base_row(project) -> DashboardProjectOut:
    return DashboardProjectOut(
        id=project.id,
        name=project.name,
        ecosystem=project.ecosystem,
        repo_url=project.repo_url,
        created_at=project.created_at,
    )


def _analysed_row(project) -> Optional[DashboardProjectOut]:
    """A project counts as analysed only if its saved pointer is valid and at
    least one dependency was actually analysed."""
    latest = project.latest_analysis
    if not isinstance(latest, dict) or not latest.get("id"):
        return None
    summary = latest.get("summary")
    if not isinstance(summary, dict) or _int(summary.get("analyzed")) == 0:
        return None

    highest = summary.get("highest_risk")
    row = _base_row(project)
    row.analysis_id = str(latest["id"])
    row.filename = latest.get("filename") if isinstance(latest.get("filename"), str) else None
    row.analysed_at = latest.get("created_at") if isinstance(latest.get("created_at"), datetime) else None
    row.compliance_score = _opt_int(summary.get("compliance_score"))
    row.highest_risk = highest if highest in RISK_LEVELS else None
    row.risk_distribution = _distribution(summary.get("risk_distribution"))
    row.total_dependencies = _int(summary.get("total_dependencies"))
    row.analyzed = _int(summary.get("analyzed"))
    row.failed = _int(summary.get("failed"))
    row.vulnerable = _int(summary.get("vulnerable"))
    row.license_violations = _int(summary.get("license_violations"))
    row.unmaintained = _int(summary.get("unmaintained"))
    return row


def _attention_key(row: DashboardProjectOut):
    risk_index = RISK_LEVELS.index(row.highest_risk) if row.highest_risk else -1
    dist = row.risk_distribution
    return (
        -risk_index,
        -dist.get("CRITICAL", 0),
        -dist.get("HIGH", 0),
        row.compliance_score if row.compliance_score is not None else 101,
        row.name.lower(),
    )


def build_dashboard(projects: List[Any], now: Optional[datetime] = None) -> OrgDashboardOut:
    analysed: List[DashboardProjectOut] = []
    not_analysed: List[DashboardProjectOut] = []
    summaries: List[Dict[str, Any]] = []

    for project in projects:
        row = _analysed_row(project)
        if row is None:
            not_analysed.append(_base_row(project))
        else:
            analysed.append(row)
            summaries.append(project.latest_analysis["summary"])

    risk_total = {level: 0 for level in RISK_LEVELS}
    by_highest = {level: 0 for level in RISK_LEVELS}
    weighted_sum = 0
    weight_total = 0
    compliance_projects = 0

    for row in analysed:
        for level in RISK_LEVELS:
            risk_total[level] += row.risk_distribution.get(level, 0)
        if row.highest_risk:
            by_highest[row.highest_risk] += 1
        project_weight = sum(
            row.risk_distribution.get(level, 0) * PROJECT_RISK_WEIGHTS[level]
            for level in RISK_LEVELS
        )
        if row.compliance_score is not None and project_weight > 0:
            weighted_sum += row.compliance_score * project_weight
            weight_total += project_weight
            compliance_projects += 1

    totals = DashboardTotalsOut(
        projects=len(projects),
        analysed_projects=len(analysed),
        not_analysed_projects=len(not_analysed),
        dependencies_total=sum(r.total_dependencies for r in analysed),
        dependencies_analysed=sum(r.analyzed for r in analysed),
        dependencies_failed=sum(r.failed for r in analysed),
        vulnerable=sum(r.vulnerable for r in analysed),
        license_violations=sum(r.license_violations for r in analysed),
        unmaintained=sum(r.unmaintained for r in analysed),
        maintenance_undetermined=sum(_int(s.get("maintenance_undetermined")) for s in summaries),
        needs_review=sum(_int(s.get("needs_review")) for s in summaries),
        risk_distribution=risk_total,
        projects_by_highest_risk=by_highest,
        compliance_score=round(weighted_sum / weight_total) if weight_total else None,
        compliance_projects=compliance_projects,
    )

    recent = sorted(analysed, key=lambda r: _ts(r.analysed_at), reverse=True)[:LIST_SIZE]
    attention = sorted(
        (r for r in analysed if r.highest_risk in ATTENTION_LEVELS), key=_attention_key
    )[:LIST_SIZE]

    return OrgDashboardOut(
        generated_at=now or datetime.now(timezone.utc),
        totals=totals,
        recent_analyses=recent,
        attention_projects=attention,
        not_analysed_projects=not_analysed[:LIST_SIZE],
    )
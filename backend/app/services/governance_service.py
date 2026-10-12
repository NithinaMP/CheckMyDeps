
from typing import Dict, List, Tuple

from app.governance_config import (
    COMPONENT_WEIGHTS,
    LICENSE_HEALTH,
    MAINTENANCE_HEALTH,
    PROJECT_RISK_WEIGHTS,
    RISK_LEVELS,
    RISK_SCORE_CAPS,
    SECURITY_HEALTH,
    UNCERTAIN_HEALTH,
)


def _risk_index(level: str) -> int:
    return RISK_LEVELS.index(level)


def _security_health(vuln: Dict) -> float:
    if vuln["status"] == "CLEAR":
        return 1.0

    if vuln["status"] in ("WITHIN_POLICY", "EXCEEDS_POLICY"):
        return SECURITY_HEALTH.get(
            vuln.get("highest_severity"), UNCERTAIN_HEALTH
        )

    return UNCERTAIN_HEALTH


def classify_risk(rules: Dict) -> Tuple[str, List[str]]:
    """Record triggered rules; the highest risk level wins."""
    vuln = rules["vulnerability"]
    lic = rules["license"]
    maint = rules["maintenance"]
    pol = rules["policy"]

    highest = vuln.get("highest_severity")
    triggered = []

    if highest == "CRITICAL":
        triggered.append((
            "CRITICAL",
            "Critical-severity vulnerability known (OSV.dev)"
        ))

    if highest == "HIGH":
        triggered.append((
            "HIGH",
            "High-severity vulnerability known (OSV.dev)"
        ))

    if lic["status"] == "NON_COMPLIANT":
        triggered.append(("HIGH", lic["reason"]))

    if maint["ml_status"] == "Unmaintained":
        triggered.append((
            "MEDIUM",
            "Repository predicted to be unmaintained"
        ))

    if highest == "MEDIUM":
        triggered.append((
            "MEDIUM",
            "Medium-severity vulnerability known (OSV.dev)"
        ))

    if lic["status"] == "RESTRICTED":
        triggered.append(("MEDIUM", lic["reason"]))

    if pol["policy_status"] == "VIOLATION":
        triggered.append((
            "MEDIUM",
            "Violates policy: " + "; ".join(pol["violations"])
        ))

    if pol["policy_status"] == "REVIEW":
        triggered.append((
            "MEDIUM",
            "Needs review: " + "; ".join(pol["review_items"])
        ))

    if highest == "LOW":
        triggered.append((
            "LOW",
            "Low-severity vulnerability known (OSV.dev)"
        ))

    if not triggered:
        return "LOW", []

    triggered.sort(
        key=lambda item: _risk_index(item[0]),
        reverse=True
    )

    return triggered[0][0], [
        reason for _, reason in triggered
    ]


def score_dependency(rules: Dict) -> Dict:
    health = {
        "security": _security_health(rules["vulnerability"]),
        "maintenance": MAINTENANCE_HEALTH.get(
            rules["maintenance"]["ml_status"], UNCERTAIN_HEALTH
        ),
        "license": LICENSE_HEALTH.get(
            rules["license"]["status"], UNCERTAIN_HEALTH
        ),
    }

    components = {
        name: {
            "health": value,
            "weight": COMPONENT_WEIGHTS[name],
            "points": round(
                100 * COMPONENT_WEIGHTS[name] * value, 1
            ),
        }
        for name, value in health.items()
    }

    score = round(
        sum(
            100 * COMPONENT_WEIGHTS[name] * value
            for name, value in health.items()
        )
    )

    risk_level, drivers = classify_risk(rules)

    cap = RISK_SCORE_CAPS.get(risk_level)
    cap_applied = cap is not None and score > cap

    if cap_applied:
        score = cap

    return {
        "score": int(score),
        "risk_level": risk_level,
        "risk_drivers": drivers,
        "cap_applied": cap_applied,
        "components": components,
    }


def rank_dependencies(results: List[Dict]) -> List[Dict]:
    """Rank analyzed dependencies by risk, highest first."""
    analyzed = [
        item for item in results
        if item["status"] == "analyzed"
    ]
    failed = [
        item for item in results
        if item["status"] != "analyzed"
    ]

    analyzed.sort(
        key=lambda item: (
            -_risk_index(item["governance"]["risk_level"]),
            item["governance"]["score"],
        )
    )

    for rank, item in enumerate(analyzed, start=1):
        item["risk_rank"] = rank

    return analyzed + failed



def summarize_project(results: List[Dict]) -> Dict:
    analyzed = [
        item for item in results
        if item["status"] == "analyzed"
    ]

    risk_counts = {level: 0 for level in RISK_LEVELS}

    for item in analyzed:
        risk_counts[item["governance"]["risk_level"]] += 1

    weights = [
        PROJECT_RISK_WEIGHTS[item["governance"]["risk_level"]]
        for item in analyzed
    ]

    project_score = (
        round(
            sum(
                item["governance"]["score"] * weight
                for item, weight in zip(analyzed, weights)
            ) / sum(weights)
        )
        if analyzed else None
    )

    highest = max(
        (
            item["governance"]["risk_level"]
            for item in analyzed
        ),
        key=_risk_index,
        default=None,
    )

    def get_maintenance_status(item):
        maintenance = item.get("maintenance") or {}
        prediction = maintenance.get("prediction") or {}

        return (
            prediction.get("status")
            or maintenance.get("status", "Unable to determine")
        )

    return {
        "compliance_score": project_score,
        "highest_risk": highest,
        "total_dependencies": len(results),
        "analyzed": len(analyzed),
        "failed": len(results) - len(analyzed),
        "risk_distribution": risk_counts,
        "maintained": sum(
            get_maintenance_status(item) == "Maintained"
            for item in analyzed
        ),
        "unmaintained": sum(
            get_maintenance_status(item) == "Unmaintained"
            for item in analyzed
        ),
        "maintenance_undetermined": sum(
            get_maintenance_status(item) == "Unable to determine"
            for item in analyzed
        ),
        "vulnerable": sum(
            (item["vulnerabilities"].get("vulnerability_count") or 0) > 0
            for item in analyzed
        ),
        "license_violations": sum(
            item["rules"]["license"]["status"] == "NON_COMPLIANT"
            for item in analyzed
        ),
        "needs_review": sum(
            item["rules"]["policy"]["policy_status"] == "REVIEW"
            for item in analyzed
        ),
    }

import re
from typing import Dict, Optional

from app.policy_defaults import DEFAULT_POLICY

SEVERITY_RANK = {"NONE": 0, "LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}

# Used to combine license expressions: AND takes the worst, OR takes the best.
LICENSE_ORDER = {"COMPLIANT": 0, "NOT_IN_POLICY": 1, "UNKNOWN": 2, "RESTRICTED": 3, "NON_COMPLIANT": 4}


def _merge_policy(policy: Optional[Dict]) -> Dict:
    return {**DEFAULT_POLICY, **(policy or {})}


# ----------------------------------------------------------------- licenses

def _coerce_license(raw) -> Optional[str]:
    """Registries return licenses as strings, but npm sometimes returns
    {'type': 'MIT'} or a list of those."""
    if raw is None:
        return None
    if isinstance(raw, str):
        return raw
    if isinstance(raw, dict):
        return raw.get("type")
    if isinstance(raw, list):
        parts = [_coerce_license(r) for r in raw]
        parts = [p for p in parts if p]
        return " OR ".join(parts) if parts else None
    return str(raw)


def _license_family(token: str) -> Optional[str]:
    """Map one license name/SPDX id to a family. Order matters: LGPL and AGPL
    must be checked before GPL."""
    t = token.strip().lower()
    if not t:
        return None
    if re.search(r"\bagpl|affero", t):
        return "AGPL"
    if re.search(r"\blgpl|lesser general public|library general public", t):
        return "LGPL"
    if re.search(r"\bgpl|gnu general public", t):
        return "GPL"
    if re.search(r"\bmpl|mozilla public", t):
        return "MPL"
    if "apache" in t:
        return "Apache-2.0"
    if re.search(r"\bmit\b", t):
        return "MIT"
    if re.search(r"\bbsd\b|^0bsd", t):
        return "BSD"
    if re.search(r"\bisc\b", t):
        return "ISC"
    if re.search(r"\bunlicense\b", t):        # \b so that 'UNLICENSED' (proprietary) doesn't match
        return "Unlicense"
    return None


def _token_status(token: str, policy: Dict):
    family = _license_family(token)
    if family is None:
        return "UNKNOWN", None
    f = family.lower()
    if f in [x.lower() for x in policy["prohibited_licenses"]]:
        return "NON_COMPLIANT", family
    if f in [x.lower() for x in policy["restricted_licenses"]]:
        return "RESTRICTED", family
    if f in [x.lower() for x in policy["allowed_licenses"]]:
        return "COMPLIANT", family
    return "NOT_IN_POLICY", family


def check_license(license_raw, org_policy: Optional[Dict] = None) -> Dict:
    policy = _merge_policy(org_policy)
    raw = _coerce_license(license_raw)

    if not raw or not raw.strip():
        return {"status": "UNKNOWN", "families": [], "raw": None,
                "reason": "No license information available (not assumed permissive)"}
    if len(raw) > 200:
        return {"status": "UNKNOWN", "families": [], "raw": raw[:80] + "...",
                "reason": "License field contains full license text; not auto-identified"}

    # SPDX precedence: AND binds tighter than OR. 'or later' is part of a name ('GPL-2.0 or later').
    cleaned = raw.replace("(", " ").replace(")", " ")
    alternatives = re.split(r"\s+or\s+(?!later|newer)", cleaned, flags=re.IGNORECASE)
    alt_results, families = [], []
    for alt in alternatives:
        parts = [_token_status(p, policy) for p in re.split(r"\s+and\s+", alt, flags=re.IGNORECASE)]
        families += [fam for _, fam in parts if fam]
        alt_results.append(max(parts, key=lambda r: LICENSE_ORDER[r[0]]))   # AND -> worst
    status = min((r[0] for r in alt_results), key=lambda s: LICENSE_ORDER[s])  # OR -> best

    families = list(dict.fromkeys(families))
    reasons = {
        "COMPLIANT": f"License '{raw}' is allowed by policy",
        "RESTRICTED": f"License '{raw}' is restricted by policy and needs review",
        "NON_COMPLIANT": f"License '{raw}' is prohibited by policy",
        "NOT_IN_POLICY": f"License '{raw}' is recognized but not covered by the policy",
        "UNKNOWN": f"License '{raw}' could not be identified",
    }
    return {"status": status, "families": families, "raw": raw, "reason": reasons[status]}


# ---------------------------------------------------------- vulnerabilities

def check_vulnerability(vulnerability_data: Optional[Dict], max_severity: str = None) -> Dict:
    """vulnerability_data is the dict returned by osv_service.get_vulnerability_data()."""
    max_severity = (max_severity or DEFAULT_POLICY["max_vulnerability_severity"]).upper()
    if max_severity not in SEVERITY_RANK:
        raise ValueError(f"Invalid max severity: {max_severity}")

    if not vulnerability_data or vulnerability_data.get("status") != "ok":
        return {"status": "UNVERIFIED", "highest_severity": None, "count": None,
                "reason": "Vulnerability lookup unavailable (not assumed safe)"}

    count = vulnerability_data.get("vulnerability_count", 0)
    highest = vulnerability_data.get("highest_severity", "NONE")
    scope_note = (" (no version pinned: counts every known vulnerability for the package)"
                  if vulnerability_data.get("scope") == "all_versions" else "")

    if count == 0:
        return {"status": "CLEAR", "highest_severity": "NONE", "count": 0,
                "reason": "No known vulnerabilities in OSV.dev" + scope_note}
    if highest not in SEVERITY_RANK:   # 'UNKNOWN': vulnerabilities exist but have no severity
        return {"status": "UNKNOWN_SEVERITY", "highest_severity": highest, "count": count,
                "reason": f"{count} known vulnerabilities, severity not provided by OSV" + scope_note}
    if SEVERITY_RANK[highest] > SEVERITY_RANK[max_severity]:
        return {"status": "EXCEEDS_POLICY", "highest_severity": highest, "count": count,
                "reason": f"{count} known vulnerabilities; highest severity {highest} exceeds allowed {max_severity}" + scope_note}
    return {"status": "WITHIN_POLICY", "highest_severity": highest, "count": count,
            "reason": f"{count} known vulnerabilities; highest severity {highest} is within allowed {max_severity}" + scope_note}


# -------------------------------------------------------------- maintenance


def check_maintenance(
    maintenance_result: Optional[Dict],
    require_maintained: bool = True
) -> Dict:
    """Read maintenance status from the ML prediction result."""

    result = maintenance_result or {}
    prediction = result.get("prediction") or {}

    status = (
        prediction.get("status")
        or result.get("status", "Unable to determine")
    )

    if not require_maintained:
        return {
            "status": "NOT_REQUIRED",
            "ml_status": status,
            "reason": "Policy does not require a maintained repository"
        }

    if status == "Maintained":
        return {
            "status": "MEETS",
            "ml_status": status,
            "reason": "Predicted to be maintained"
        }

    if status == "Unmaintained":
        return {
            "status": "VIOLATES",
            "ml_status": status,
            "reason": (
                "Predicted to be unmaintained; "
                "policy requires a maintained repository"
            )
        }

    return {
        "status": "UNVERIFIED",
        "ml_status": status,
        "reason": (
            "Maintenance status could not be determined "
            "(not assumed maintained)"
        )
    }


# ------------------------------------------------------------------- policy

def check_policy(license_result: Dict, vulnerability_result: Dict, maintenance_check: Dict) -> Dict:
    violations, review = [], []

    if license_result["status"] == "NON_COMPLIANT":
        violations.append(license_result["reason"])
    elif license_result["status"] in ("RESTRICTED", "UNKNOWN", "NOT_IN_POLICY"):
        review.append(license_result["reason"])

    if vulnerability_result["status"] == "EXCEEDS_POLICY":
        violations.append(vulnerability_result["reason"])
    elif vulnerability_result["status"] in ("UNKNOWN_SEVERITY", "UNVERIFIED"):
        review.append(vulnerability_result["reason"])

    if maintenance_check["status"] == "VIOLATES":
        violations.append(maintenance_check["reason"])
    elif maintenance_check["status"] == "UNVERIFIED":
        review.append(maintenance_check["reason"])

    policy_status = "VIOLATION" if violations else ("REVIEW" if review else "OK")
    return {"policy_status": policy_status, "violations": violations, "review_items": review}


def evaluate_dependency(license_raw, vulnerability_data, maintenance_result,
                        org_policy: Optional[Dict] = None) -> Dict:
    """Convenience wrapper used by the analysis pipeline (Phase 10)."""
    policy = _merge_policy(org_policy)
    lic = check_license(license_raw, policy)
    vuln = check_vulnerability(vulnerability_data, policy["max_vulnerability_severity"])
    maint = check_maintenance(maintenance_result, policy["require_maintained"])
    return {"license": lic, "vulnerability": vuln, "maintenance": maint,
            "policy": check_policy(lic, vuln, maint)}
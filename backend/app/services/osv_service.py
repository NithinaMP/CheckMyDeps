import re
import requests
from typing import Dict, List, Optional

OSV_QUERY_URL = "https://api.osv.dev/v1/query"
TIMEOUT = 10        # seconds
MAX_PAGES = 3       # OSV paginates big result sets; cap it so one package can't stall an analysis

# Our internal ecosystem names -> the names OSV expects.
# Note: Dart/Flutter is "Pub" (capital P) in OSV, but "pub" in our own parser.
OSV_ECOSYSTEMS = {
    "pub": "Pub",
    "PyPI": "PyPI",
    "npm": "npm",
}

KNOWN_SEVERITIES = {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}


def _is_concrete_version(version: Optional[str]) -> bool:
    """True only for real versions like '2.19.0'. Things like 'latest', '' or
    None mean the file didn't pin a version."""
    return bool(version) and re.match(r"^\d", version.strip()) is not None


def _normalize_severity(vuln: Dict) -> str:
    """OSV doesn't have one standard severity field. GitHub-sourced advisories
    carry LOW / MODERATE / HIGH / CRITICAL in database_specific.severity.
    If it isn't there we return UNKNOWN — we never guess a severity."""
    raw = (vuln.get("database_specific") or {}).get("severity")
    if not raw:
        for affected in vuln.get("affected", []):
            raw = (affected.get("ecosystem_specific") or {}).get("severity") \
                  or (affected.get("database_specific") or {}).get("severity")
            if raw:
                break
    if not raw:
        return "UNKNOWN"
    raw = str(raw).upper()
    if raw == "MODERATE":
        return "MEDIUM"
    return raw if raw in KNOWN_SEVERITIES else "UNKNOWN"


def _unavailable(reason: str) -> Dict:
    return {
        "status": "unavailable",      # NOT the same as "no vulnerabilities"
        "reason": reason,
        "vulnerability_count": None,
        "highest_severity": None,
        "vulnerabilities": [],
    }


def get_vulnerability_data(name: str, ecosystem: str, version: Optional[str] = None) -> Dict:
    osv_ecosystem = OSV_ECOSYSTEMS.get(ecosystem)
    if osv_ecosystem is None:
        return {
            "status": "unsupported_ecosystem",
            "reason": f"No OSV mapping for ecosystem '{ecosystem}'",
            "vulnerability_count": None,
            "highest_severity": None,
            "vulnerabilities": [],
        }

    body = {"package": {"name": name, "ecosystem": osv_ecosystem}}
    version_checked = _is_concrete_version(version)
    if version_checked:
        body["version"] = version.strip()

    raw_vulns: List[Dict] = []
    truncated = False
    try:
        for page in range(MAX_PAGES):
            resp = requests.post(OSV_QUERY_URL, json=body, timeout=TIMEOUT)
            if resp.status_code != 200:
                return _unavailable(f"OSV returned HTTP {resp.status_code}")
            data = resp.json()
            raw_vulns.extend(data.get("vulns", []))
            token = data.get("next_page_token")
            if not token:
                break
            body["page_token"] = token
            if page == MAX_PAGES - 1:
                truncated = True
    except (requests.RequestException, ValueError):
        return _unavailable("OSV request failed or timed out")

    vulnerabilities = []
    for v in raw_vulns:
        vulnerabilities.append({
            "id": v.get("id"),
            "summary": v.get("summary") or (v.get("details") or "")[:160],
            "severity": _normalize_severity(v),
            "aliases": v.get("aliases", []),
            "references": [r.get("url") for r in v.get("references", [])[:3]],
        })

    # Highest severity among the ones we actually know.
    known = [x["severity"] for x in vulnerabilities if x["severity"] in KNOWN_SEVERITIES]
    if not vulnerabilities:
        highest = "NONE"
    elif known:
        highest = max(known, key=lambda s: KNOWN_SEVERITIES[s])
    else:
        highest = "UNKNOWN"   # vulnerabilities exist but OSV gave no severity

    return {
        "status": "ok",
        "queried_version": version.strip() if version_checked else None,
        # "exact_version" = vulns affecting that version only.
        # "all_versions"  = no version pinned, so this lists every known vuln for the package ever.
        "scope": "exact_version" if version_checked else "all_versions",
        "vulnerability_count": len(vulnerabilities),
        "highest_severity": highest,
        "truncated": truncated,
        "vulnerabilities": vulnerabilities,
    }
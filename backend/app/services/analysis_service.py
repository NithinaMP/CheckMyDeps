
import re
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, List, Optional

from app.policy_defaults import DEFAULT_POLICY
from app.services import (
    governance_service,
    ml_service,
    osv_service,
    registry_service,
    rule_engine,
)

MAX_DEPENDENCIES = 50
MAX_WORKERS = 4


def _is_concrete(version: Optional[str]) -> bool:
    return bool(version) and re.match(r"^\d", version.strip()) is not None


def _analyze_one(dep: Dict, policy: Dict) -> Dict:
    base = {
        "name": dep["name"],
        "ecosystem": dep["ecosystem"],
        "declared_version": dep.get("version"),
    }

    try:
        meta = registry_service.get_package_metadata(
            dep["name"], dep["ecosystem"]
        )

        if _is_concrete(dep.get("version")):
            version_checked = dep["version"].strip()
            version_source = "declared"
        elif meta and meta.get("latest_version"):
            version_checked = meta["latest_version"]
            version_source = "registry_latest"
        else:
            version_checked = None
            version_source = "none"

        maintenance = ml_service.predict_maintenance_status(
            (meta or {}).get("repository_url")
        )
        maintenance_status = (
            maintenance.get("prediction", {}).get("status")
            or maintenance.get("status", "Unable to determine")
        )

        vulnerabilities = osv_service.get_vulnerability_data(
            dep["name"], dep["ecosystem"], version_checked
        )

        rules = rule_engine.evaluate_dependency(
            (meta or {}).get("license"),
            vulnerabilities,
            maintenance,
            policy,
        )

        governance = governance_service.score_dependency(rules)

        return {
            **base,
            "status": "analyzed",
            "version_checked": version_checked,
            "version_source": version_source,
            "registry": {
                "found": meta is not None,
                "latest_version": (meta or {}).get("latest_version"),
                "license": (meta or {}).get("license"),
                "repository_url": (meta or {}).get("repository_url"),
                "description": (meta or {}).get("description"),
            },
            "maintenance": maintenance,
            "vulnerabilities": vulnerabilities,
            "rules": rules,
            "governance": governance,
        }

    except Exception as exc:
        return {
            **base,
            "status": "failed",
            "error": f"Analysis failed ({type(exc).__name__}): {exc}"
        }


def analyze_dependencies(
    filename: str,
    dependencies: List[Dict],
    org_policy: Optional[Dict] = None,
) -> Dict:
    policy = {**DEFAULT_POLICY, **(org_policy or {})}

    selected = dependencies[:MAX_DEPENDENCIES]
    skipped = len(dependencies) - len(selected)

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        results = list(
            pool.map(lambda dep: _analyze_one(dep, policy), selected)
        )

    results = governance_service.rank_dependencies(results)

    notes = [
        "Versions are the declared versions from the uploaded file "
        "(for example the lower bound of ^1.2.3), not resolved "
        "lockfile versions."
    ]

    if skipped:
        notes.append(
            f"Only the first {MAX_DEPENDENCIES} dependencies were analyzed; "
            f"{skipped} skipped."
        )

    return {
        "filename": filename,
        "policy_used": policy,
        "summary": governance_service.summarize_project(results),
        "dependencies": results,
        "skipped": skipped,
        "notes": notes,
    }

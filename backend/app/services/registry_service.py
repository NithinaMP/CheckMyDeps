
import requests
from typing import Dict, Optional

TIMEOUT = 8  # seconds — don't let one slow registry hang the whole analysis


def _get_pub_license(package_name: str) -> Optional[str]:
    """Extract license identifiers from pub.dev score tags."""
    try:
        resp = requests.get(
            f"https://pub.dev/api/packages/{package_name}/score",
            timeout=TIMEOUT,
        )
        if resp.status_code != 200:
            return None

        tags = resp.json().get("tags", [])
    except (requests.RequestException, ValueError):
        return None

    # These are classifications, not license names.
    ignore = {"fsf-libre", "osi-approved", "unknown"}

    ids = [
        tag.split(":", 1)[1]
        for tag in tags
        if tag.startswith("license:")
        and tag.split(":", 1)[1] not in ignore
    ]

    # Multiple license tags are conservatively combined with AND.
    return " AND ".join(ids) if ids else None


def get_pub_dev_metadata(package_name: str) -> Optional[Dict]:
    url = f"https://pub.dev/api/packages/{package_name}"

    try:
        resp = requests.get(url, timeout=TIMEOUT)
        if resp.status_code != 200:
            return None

        data = resp.json()
        latest = data.get("latest", {})
        pubspec = latest.get("pubspec", {})

        return {
            "name": package_name,
            "latest_version": latest.get("version"),
            "description": pubspec.get("description"),
            "license": _get_pub_license(package_name),
            "repository_url": (
                pubspec.get("repository") or pubspec.get("homepage")
            ),
            "homepage": pubspec.get("homepage"),
        }
    except (requests.RequestException, ValueError):
        return None


def _extract_license_from_classifiers(classifiers: list) -> Optional[str]:
    """Extract license information from PyPI classifiers."""
    for classifier in classifiers:
        if classifier.startswith("License ::"):
            return classifier.split("::")[-1].strip()
    return None


def _pick_pypi_license(info: dict) -> Optional[str]:
    """Prefer an SPDX license expression over potentially long license text."""
    expression = info.get("license_expression")
    if expression:
        return expression

    text = info.get("license")
    if text and len(text) <= 100:
        return text

    return _extract_license_from_classifiers(info.get("classifiers", []))


def get_pypi_metadata(package_name: str) -> Optional[Dict]:
    url = f"https://pypi.org/pypi/{package_name}/json"

    try:
        resp = requests.get(url, timeout=TIMEOUT)
        if resp.status_code != 200:
            return None

        data = resp.json()
        info = data.get("info", {})

        return {
            "name": package_name,
            "latest_version": info.get("version"),
            "description": info.get("summary"),
            "license": _pick_pypi_license(info),
            "repository_url": (
                info.get("project_urls", {}).get("Source")
                or info.get("home_page")
            ),
            "homepage": info.get("home_page"),
        }
    except (requests.RequestException, ValueError):
        return None


def get_npm_metadata(package_name: str) -> Optional[Dict]:
    url = f"https://registry.npmjs.org/{package_name}"

    try:
        resp = requests.get(url, timeout=TIMEOUT)
        if resp.status_code != 200:
            return None

        data = resp.json()
        latest_tag = data.get("dist-tags", {}).get("latest")
        latest_data = data.get("versions", {}).get(latest_tag, {})

        repo = latest_data.get("repository")
        repo_url = repo.get("url") if isinstance(repo, dict) else repo

        return {
            "name": package_name,
            "latest_version": latest_tag,
            "description": latest_data.get("description"),
            "license": latest_data.get("license"),
            "repository_url": repo_url,
            "homepage": latest_data.get("homepage"),
        }
    except (requests.RequestException, ValueError):
        return None


def get_package_metadata(package_name: str, ecosystem: str) -> Optional[Dict]:
    """Route to the correct registry; return None if lookup fails."""
    if ecosystem == "pub":
        return get_pub_dev_metadata(package_name)
    elif ecosystem == "PyPI":
        return get_pypi_metadata(package_name)
    elif ecosystem == "npm":
        return get_npm_metadata(package_name)
    else:
        return None

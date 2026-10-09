import requests
from typing import Dict, Optional

TIMEOUT = 8  # seconds — don't let one slow registry hang the whole analysis


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
            "license": None,  # pub.dev API doesn't return license directly — see note below
            "repository_url": pubspec.get("repository") or pubspec.get("homepage"),
            "homepage": pubspec.get("homepage"),
        }
    except requests.RequestException:
        return None


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
            "license": info.get("license") or _extract_license_from_classifiers(info.get("classifiers", [])),
            "repository_url": info.get("project_urls", {}).get("Source") or info.get("home_page"),
            "homepage": info.get("home_page"),
        }
    except requests.RequestException:
        return None


def _extract_license_from_classifiers(classifiers: list) -> Optional[str]:
    """PyPI often leaves the top-level 'license' field blank and puts it in
    classifiers instead, e.g. 'License :: OSI Approved :: MIT License'."""
    for c in classifiers:
        if c.startswith("License :: OSI Approved ::"):
            return c.split("::")[-1].strip()
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
    except requests.RequestException:
        return None


def get_package_metadata(package_name: str, ecosystem: str) -> Optional[Dict]:
    """Single entry point — routes to the correct registry based on ecosystem.
    Returns None (not a fake/default value) if the lookup fails, per the
    architecture's 'do not assume' error-handling principle."""
    if ecosystem == "pub":
        return get_pub_dev_metadata(package_name)
    elif ecosystem == "PyPI":
        return get_pypi_metadata(package_name)
    elif ecosystem == "npm":
        return get_npm_metadata(package_name)
    else:
        return None
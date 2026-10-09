import json
import re
import yaml
from typing import List, Dict


def parse_pubspec(content: str) -> List[Dict]:
    """Flutter/Dart — pubspec.yaml"""
    data = yaml.safe_load(content)
    deps = []
    for section in ("dependencies", "dev_dependencies"):
        section_data = data.get(section, {}) or {}
        for name, version in section_data.items():
            if name == "flutter":
                continue
            # version can be a string ("^1.2.3") or a dict (git/path deps) — skip non-registry ones
            if isinstance(version, str):
                deps.append({
                    "name": name,
                    "version": version.lstrip("^~>=< "),
                    "ecosystem": "pub",
                })
    return deps


def parse_requirements_txt(content: str) -> List[Dict]:
    """Python — requirements.txt"""
    deps = []
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # matches: package==1.2.3 / package>=1.2.3 / package~=1.2.3 / bare "package"
        match = re.match(r"^([a-zA-Z0-9_\-\.]+)\s*([=<>~!]+)?\s*([a-zA-Z0-9_\-\.]*)", line)
        if match:
            name, _, version = match.groups()
            deps.append({
                "name": name.strip(),
                "version": version.strip() if version else "latest",
                "ecosystem": "PyPI",
            })
    return deps


def parse_package_json(content: str) -> List[Dict]:
    """Node.js/React — package.json"""
    data = json.loads(content)
    deps = []
    for section in ("dependencies", "devDependencies"):
        section_data = data.get(section, {}) or {}
        for name, version in section_data.items():
            deps.append({
                "name": name,
                "version": version.lstrip("^~>=< "),
                "ecosystem": "npm",
            })
    return deps


def parse_dependency_file(filename: str, content: str) -> List[Dict]:
    """Entry point — detects file type from filename and routes to the
    correct parser. Raises ValueError for unsupported files rather than
    guessing, per the architecture's error-handling principle."""
    lower = filename.lower()
    if lower.endswith("pubspec.yaml") or lower.endswith(".yaml"):
        return parse_pubspec(content)
    elif lower.endswith("requirements.txt"):
        return parse_requirements_txt(content)
    elif lower.endswith("package.json"):
        return parse_package_json(content)
    else:
        raise ValueError(f"Unsupported dependency file: {filename}")
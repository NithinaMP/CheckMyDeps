import os
import re
import requests
from typing import Dict, Optional
from dotenv import load_dotenv


load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
TIMEOUT = 8


def extract_owner_repo(repository_url: Optional[str]) -> Optional[tuple]:
    """Extract owner/repo from a GitHub repository URL."""
    if not repository_url:
        return None

    match = re.search(
        r"github\.com[/:]([^/]+)/([^/.\s]+)",
        repository_url
    )

    if not match:
        return None

    return match.group(1), match.group(2)


def get_repository_data(repository_url: Optional[str]) -> Optional[Dict]:
    """Fetch basic repository statistics from the GitHub API."""
    parsed = extract_owner_repo(repository_url)

    if parsed is None:
        return None

    owner, repo = parsed

    headers = (
        {"Authorization": f"token {GITHUB_TOKEN}"}
        if GITHUB_TOKEN else {}
    )

    base_url = f"https://api.github.com/repos/{owner}/{repo}"

    try:
        repo_resp = requests.get(
            base_url,
            headers=headers,
            timeout=TIMEOUT
        )

        if repo_resp.status_code == 404:
            return None

        if repo_resp.status_code == 403:
            return {"error": "rate_limited"}

        repo_resp.raise_for_status()
        repo_data = repo_resp.json()

        contributors_resp = requests.get(
            f"{base_url}/contributors?per_page=1&anon=true",
            headers=headers,
            timeout=TIMEOUT
        )

        contributor_count = _get_last_page_count(contributors_resp)

        return {
            "owner": owner,
            "repo": repo,
            "stars": repo_data.get("stargazers_count"),
            "forks": repo_data.get("forks_count"),
            "open_issues": repo_data.get("open_issues_count"),
            "watchers": repo_data.get("watchers_count"),
            "created_at": repo_data.get("created_at"),
            "updated_at": repo_data.get("updated_at"),
            "pushed_at": repo_data.get("pushed_at"),
            "default_branch": repo_data.get("default_branch"),
            "archived": repo_data.get("archived"),
            "contributor_count": contributor_count,
            "language": repo_data.get("language"),
        }

    except requests.RequestException:
        return None


def _get_last_page_count(response) -> Optional[int]:
    link_header = response.headers.get("Link")

    if not link_header:
        return 1 if response.status_code == 200 else None

    match = re.search(r'page=(\d+)>; rel="last"', link_header)

    return int(match.group(1)) if match else 1

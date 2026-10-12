
# import os
# import re
# import requests
# from typing import Dict, Optional
# from dotenv import load_dotenv
# from concurrent.futures import ThreadPoolExecutor
# from datetime import datetime, timedelta, timezone


# load_dotenv()

# GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
# TIMEOUT = 15

# def extract_owner_repo(repository_url: Optional[str]) -> Optional[tuple]:
#     if not repository_url:
#         return None

#     match = re.search(
#         r"github\.com[/:]([^/\s]+)/([^/\s#?]+)",
#         repository_url
#     )

#     if not match:
#         return None

#     owner, repo = match.group(1), match.group(2)

#     if repo.endswith(".git"):
#         repo = repo[:-4]

#     return owner, repo




# def get_repository_data(repository_url: Optional[str]) -> Optional[Dict]:
#     """Fetch basic repository statistics from the GitHub API."""
#     parsed = extract_owner_repo(repository_url)

#     if parsed is None:
#         return None

#     owner, repo = parsed

#     headers = (
#         {"Authorization": f"token {GITHUB_TOKEN}"}
#         if GITHUB_TOKEN else {}
#     )

#     base_url = f"https://api.github.com/repos/{owner}/{repo}"

#     try:
#         repo_resp = requests.get(
#             base_url,
#             headers=headers,
#             timeout=TIMEOUT
#         )

#         if repo_resp.status_code == 404:
#             return None

#         if repo_resp.status_code == 403:
#             return {"error": "rate_limited"}

#         repo_resp.raise_for_status()
#         repo_data = repo_resp.json()

#         contributors_resp = requests.get(
#             f"{base_url}/contributors?per_page=1&anon=true",
#             headers=headers,
#             timeout=TIMEOUT
#         )

#         contributor_count = _get_last_page_count(contributors_resp)

#         return {
#             "owner": owner,
#             "repo": repo,
#             "stars": repo_data.get("stargazers_count"),
#             "forks": repo_data.get("forks_count"),
#             "open_issues": repo_data.get("open_issues_count"),
#             "watchers": repo_data.get("watchers_count"),
#             "created_at": repo_data.get("created_at"),
#             "updated_at": repo_data.get("updated_at"),
#             "pushed_at": repo_data.get("pushed_at"),
#             "default_branch": repo_data.get("default_branch"),
#             "archived": repo_data.get("archived"),
#             "contributor_count": contributor_count,
#             "language": repo_data.get("language"),
#         }

#     except requests.RequestException:
#         return None


# def _get_last_page_count(response) -> Optional[int]:
#     link_header = response.headers.get("Link")

#     if not link_header:
#         return 1 if response.status_code == 200 else None

#     match = re.search(r'page=(\d+)>; rel="last"', link_header)

#     return int(match.group(1)) if match else 1



# # --- ML maintenance prediction: GitHub commit windows ---

# from concurrent.futures import ThreadPoolExecutor
# from datetime import datetime, timedelta, timezone


# def _get_commit_window(owner: str, repo: str, window: int) -> Dict:
#     """Collect commit count and longest gap for one 90-day window.
#     Window 1 = oldest; window 8 = newest.
#     """
#     end_date = datetime.now(timezone.utc) - timedelta(
#         days=(8 - window) * 90
#     )
#     start_date = end_date - timedelta(days=90)

#     headers = {"Accept": "application/vnd.github+json"}
#     if GITHUB_TOKEN:
#         headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"

#     url = f"https://api.github.com/repos/{owner}/{repo}/commits"
#     params = {
#         "since": start_date.isoformat(),
#         "until": end_date.isoformat(),
#         "per_page": 100,
#         "page": 1,
#     }

#     dates = []

#     while True:
#         response = requests.get(
#                     url,
#                     headers=headers,
#                     params=params,
#                     timeout=(5, 10),
#                 )

#         if response.status_code in (403, 429):
#             raise RuntimeError("GitHub API rate limit reached.")

#         if response.status_code == 409:
#             break
#         if response.status_code == 404:
#             raise ValueError("Repository not found.")

#         response.raise_for_status()
#         page_data = response.json()

#         if not page_data:
#             break

#         for commit in page_data:
#             commit_info = commit.get("commit", {})
#             date_text = (
#                 commit_info.get("author", {}).get("date")
#                 or commit_info.get("committer", {}).get("date")
#             )
#             if date_text:
#                 dates.append(
#                     datetime.fromisoformat(
#                         date_text.replace("Z", "+00:00")
#                     )
#                 )

#         if len(page_data) < 100:
#             break

#         params["page"] += 1

#     dates.sort()

# # Keep only commit dates that fall inside this 90-day window.
#     dates = [
#         date for date in dates
#         if start_date <= date <= end_date
#     ]

#     points = [start_date] + dates + [end_date]

#     max_gap = max(
#         (points[i + 1] - points[i]).total_seconds() / 86400
#         for i in range(len(points) - 1)
#     )

#     return {
#         "window": window,
#         "commits": len(dates),
#         "max_days_without_commits": round(max_gap, 2),
#     }



# def get_commit_windows(repository_url: Optional[str]) -> Optional[list]:
#     """Return eight chronological-window features for a GitHub repository."""
#     parsed = extract_owner_repo(repository_url)
#     if parsed is None:
#         return None

#     owner, repo = parsed

#     try:
#         with ThreadPoolExecutor(max_workers=2) as executor:
#             windows = list(executor.map(
#                 lambda number: _get_commit_window(owner, repo, number),
#                 range(1, 9),
#             ))

#         return windows

#     except (requests.RequestException, RuntimeError, ValueError) as exc:
#         return {"error": str(exc)}





import os
import re
import time
import requests

from typing import Dict, Optional
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv


load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")

# Network settings
TIMEOUT = (5, 10)  # Connection timeout, read timeout
MAX_RETRIES = 1
MAX_PAGES = 200
MAX_COLLECTION_SECONDS = 90
WINDOW_DAYS = 90
N_WINDOWS = 8
PER_PAGE = 100

API_BASE = "https://api.github.com"


def _headers() -> dict:
    """Build headers for GitHub REST API requests."""
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    if GITHUB_TOKEN:
        headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"

    return headers


def extract_owner_repo(
    repository_url: Optional[str],
) -> Optional[tuple]:
    """Extract the owner and repository name from a GitHub URL."""
    if not repository_url:
        return None

    match = re.search(
        r"github\.com[/:]([^/\s]+)/([^/\s#?]+)",
        repository_url.strip(),
        flags=re.IGNORECASE,
    )

    if not match:
        return None

    owner = match.group(1)
    repo = match.group(2)

    if repo.endswith(".git"):
        repo = repo[:-4]

    if not owner or not repo:
        return None

    return owner, repo


def _github_get(url: str, params: Optional[dict] = None):
    """Make a bounded GitHub GET request with one retry."""
    last_error = None

    for attempt in range(MAX_RETRIES + 1):
        try:
            response = requests.get(
                url,
                headers=_headers(),
                params=params,
                timeout=TIMEOUT,
            )

            if response.status_code == 404:
                raise ValueError("Repository or GitHub resource not found.")

            if response.status_code in (403, 429):
                remaining = response.headers.get(
                    "X-RateLimit-Remaining"
                )

                if (
                    response.status_code == 429
                    or remaining == "0"
                    or "rate limit" in response.text.lower()
                ):
                    raise RuntimeError(
                        "GitHub API rate limit reached. "
                        "Configure GITHUB_TOKEN and try again later."
                    )

            response.raise_for_status()
            return response

        except (requests.Timeout, requests.ConnectionError) as exc:
            last_error = exc

            if attempt >= MAX_RETRIES:
                break

            time.sleep(1)

    raise RuntimeError(
        f"GitHub API request failed after retries: {last_error}"
    ) from last_error


def _get_last_page_count(response) -> Optional[int]:
    """Read the total page count from a GitHub Link header."""
    link_header = response.headers.get("Link", "")

    if not link_header:
        return 1 if response.status_code == 200 else None

    match = re.search(
        r'<[^>]+[?&]page=(\d+)[^>]*>;\s*rel="last"',
        link_header,
    )

    return int(match.group(1)) if match else 1


def get_repository_data(
    repository_url: Optional[str],
) -> Optional[Dict]:
    """Fetch basic repository statistics from GitHub."""
    parsed = extract_owner_repo(repository_url)

    if parsed is None:
        return None

    owner, repo = parsed
    base_url = f"{API_BASE}/repos/{owner}/{repo}"

    try:
        repo_response = _github_get(base_url)
        repo_data = repo_response.json()

        contributors_response = _github_get(
            f"{base_url}/contributors",
            params={"per_page": 1, "anon": "true"},
        )

        contributor_count = _get_last_page_count(
            contributors_response
        )

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

    except ValueError:
        return None
    except (requests.RequestException, RuntimeError) as exc:
        return {"error": str(exc)}


def _empty_windows() -> list:
    """Return eight windows for a repository with no commits."""
    now = datetime.now(timezone.utc)
    windows = []

    for window in range(1, N_WINDOWS + 1):
        end_date = now - timedelta(
            days=(N_WINDOWS - window) * WINDOW_DAYS
        )
        start_date = end_date - timedelta(days=WINDOW_DAYS)

        windows.append({
            "window": window,
            "commits": 0,
            "max_days_without_commits": float(WINDOW_DAYS),
        })

    return windows



def _collect_all_commit_dates(
    owner: str,
    repo: str,
    start_date: datetime,
    end_date: datetime,
) -> list:
    """Fetch commit dates for a bounded period using one HTTP session."""
    url = f"{API_BASE}/repos/{owner}/{repo}/commits"
    dates = []
    started_at = time.monotonic()

    headers = _headers()

    with requests.Session() as session:
        session.headers.update(headers)

        for page in range(1, MAX_PAGES + 1):
            elapsed = time.monotonic() - started_at
            if elapsed >= MAX_COLLECTION_SECONDS:
                raise RuntimeError(
                    f"Commit collection timed out at page {page}."
                )

            params = {
                "since": start_date.isoformat(),
                "until": end_date.isoformat(),
                "per_page": PER_PAGE,
                "page": page,
            }

            try:
                response = session.get(
                    url,
                    params=params,
                    timeout=TIMEOUT,
                )
            except requests.RequestException as exc:
                raise RuntimeError(
                    f"GitHub request failed on page {page}: {exc}"
                ) from exc

            if response.status_code == 409:
                return dates

            if response.status_code == 404:
                raise ValueError("Repository not found.")

            if response.status_code in (403, 429):
                if (
                    response.status_code == 429
                    or response.headers.get("X-RateLimit-Remaining") == "0"
                    or "rate limit" in response.text.lower()
                ):
                    raise RuntimeError("GitHub API rate limit reached.")

            response.raise_for_status()
            page_data = response.json()

            if not page_data:
                break

            oldest_date = None

            for item in page_data:
                commit_info = item.get("commit", {})
                date_text = (
                    commit_info.get("author", {}).get("date")
                    or commit_info.get("committer", {}).get("date")
                )

                if not date_text:
                    continue

                commit_date = datetime.fromisoformat(
                    date_text.replace("Z", "+00:00")
                )

                if start_date <= commit_date <= end_date:
                    dates.append(commit_date)

                if oldest_date is None or commit_date < oldest_date:
                    oldest_date = commit_date


            # GitHub normally returns commits newest first.
            if oldest_date is not None and oldest_date < start_date:
                break

            if len(page_data) < PER_PAGE:
                break
        else:
            raise RuntimeError(
                f"Commit collection reached {MAX_PAGES} pages."
            )

    return dates




def _calculate_window(
    window: int,
    start_date: datetime,
    end_date: datetime,
    all_dates: list,
) -> Dict:
    """Calculate commit count and longest inactivity gap."""
    window_dates = sorted(
        date
        for date in all_dates
        if start_date <= date <= end_date
    )

    points = [start_date] + window_dates + [end_date]

    max_gap = max(
        (
            points[index + 1] - points[index]
        ).total_seconds() / 86400
        for index in range(len(points) - 1)
    )

    return {
        "window": window,
        "commits": len(window_dates),
        "max_days_without_commits": round(max_gap, 2),
    }



def get_commit_windows(
    repository_url: Optional[str],
) -> Optional[list]:
    """Collect eight 90-day commit windows concurrently."""
    from concurrent.futures import ThreadPoolExecutor

    parsed = extract_owner_repo(repository_url)
    if parsed is None:
        return None

    owner, repo = parsed
    now = datetime.now(timezone.utc)

    def collect_window(window: int) -> Dict:
        end_date = now - timedelta(
            days=(N_WINDOWS - window) * WINDOW_DAYS
        )
        start_date = end_date - timedelta(days=WINDOW_DAYS)

        dates = _collect_all_commit_dates(
            owner,
            repo,
            start_date,
            end_date,
        )

        return _calculate_window(
            window,
            start_date,
            end_date,
            dates,
        )

    try:
        with ThreadPoolExecutor(max_workers=8) as executor:
            results = list(
                executor.map(
                    collect_window,
                    range(1, N_WINDOWS + 1),
                )
            )

        return results

    except (requests.RequestException, RuntimeError, ValueError) as exc:
        return {"error": str(exc)}


from app.services import github_service
from app.ml import feature_mapping, predictor


def _undetermined(reason: str) -> dict:
    return {
        "status": "Unable to determine",
        "reason": reason,
    }


def predict_repository_maintenance(repository_url: str) -> dict:
    if not repository_url:
        return _undetermined("GitHub repository URL is missing.")

    # Fetch repository metadata first.
    repo_data = github_service.get_repository_data(repository_url)

    if repo_data is None:
        return _undetermined("Repository not found or unavailable.")

    if isinstance(repo_data, dict) and "error" in repo_data:
        return _undetermined(repo_data["error"])

    # Collect the eight commit windows.
    windows = github_service.get_commit_windows(repository_url)

    if windows is None:
        return _undetermined("Invalid GitHub repository URL.")

    if isinstance(windows, dict) and "error" in windows:
        return _undetermined(windows["error"])

    try:
        vector = feature_mapping.build_feature_vector(windows)
        prediction = predictor.predict(vector)
    except (ValueError, FileNotFoundError) as exc:
        return _undetermined(str(exc))

    return {
        "repository_url": repository_url,
        "repository_metadata": {
            "archived": repo_data.get("archived"),
            "pushed_at": repo_data.get("pushed_at"),
        },
        "windows": windows,
        "features": dict(zip(feature_mapping.FEATURES, vector)),
        "prediction": prediction,
    }

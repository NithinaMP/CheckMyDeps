
N_WINDOWS = 8
WINDOW_DAYS = 90   # Assumption inferred from the data; verify against GitMT documentation

# Order matters: the model is trained on exactly this column order.
FEATURES = (
    [f"commits{i}" for i in range(1, N_WINDOWS + 1)]
    + [f"Max days without commits {i}" for i in range(1, N_WINDOWS + 1)]
)


def build_feature_vector(windows):
    """Windows: window 1 = oldest, window 8 = newest."""
    by_no = {w["window"]: w for w in windows}
    commits = [by_no[i]["commits"] for i in range(1, N_WINDOWS + 1)]
    gaps = [
        by_no[i]["max_days_without_commits"]
        for i in range(1, N_WINDOWS + 1)
    ]
    return commits + gaps

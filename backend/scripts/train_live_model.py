
"""Trains the deployable maintenance model.
Run from backend/ with the venv active:
python -m scripts.train_live_model
"""
import json
from pathlib import Path

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import StratifiedKFold, cross_val_score

from app.ml.feature_mapping import FEATURES, N_WINDOWS, WINDOW_DAYS

CSV_PATH = Path("data/GitMT-Merged-1000.csv")

MODEL_PATH = Path("app/ml/maintenance_model_live_16.pkl")
META_PATH = Path("app/ml/feature_names_live_16.json")


df = pd.read_csv(CSV_PATH)

missing = [f for f in FEATURES if f not in df.columns]
if missing:
    raise SystemExit(f"CSV is missing columns: {missing}")

X = df[FEATURES].astype(float)
y = (df["Failed"] == "Yes").astype(int)

model = RandomForestClassifier(
    n_estimators=300,
    max_depth=12,
    random_state=42
)

cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
scores = cross_val_score(model, X, y, cv=cv, scoring="f1")

print(
    f"5-fold CV F1 (unmaintained class): "
    f"{scores.mean():.3f} +/- {scores.std():.3f}"
)

model.fit(X, y)

joblib.dump(model, MODEL_PATH)

META_PATH.write_text(
    json.dumps({
        "features": FEATURES,
        "n_windows": N_WINDOWS,
        "window_days": WINDOW_DAYS,
        "target": "Failed (1 = Yes = unmaintained)",
        "algorithm": (
            "RandomForestClassifier("
            "n_estimators=300, max_depth=12, random_state=42)"
        ),
        "cv_f1_mean": round(float(scores.mean()), 3),
    }, indent=2)
)

print("Saved:", MODEL_PATH, "and", META_PATH)

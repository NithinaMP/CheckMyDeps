from pathlib import Path

import joblib
import pandas as pd

from app.ml.feature_mapping import FEATURES

MODEL_PATH = Path(__file__).parent / "maintenance_model_live_16.pkl"

_model = None


def _load():
    global _model

    if _model is None:
        if not MODEL_PATH.exists():
            raise FileNotFoundError(
                f"16-feature model not found: {MODEL_PATH}"
            )

        _model = joblib.load(MODEL_PATH)

        if _model.n_features_in_ != len(FEATURES):
            raise ValueError(
                f"Model expects {_model.n_features_in_} features, "
                f"but feature mapping defines {len(FEATURES)}."
            )

    return _model


def predict(vector):
    if len(vector) != len(FEATURES):
        raise ValueError(
            f"Expected {len(FEATURES)} features, received {len(vector)}."
        )

    model = _load()
    X = pd.DataFrame([vector], columns=FEATURES)

    probabilities = model.predict_proba(X)[0]
    classes = list(model.classes_)

    if 1 not in classes:
        raise ValueError("Model does not contain class 1 (unmaintained).")

    probability = float(probabilities[classes.index(1)])

    return {
        "status": (
            "Unmaintained" if probability >= 0.5 else "Maintained"
        ),
        "probability_unmaintained": round(probability, 3),
    }
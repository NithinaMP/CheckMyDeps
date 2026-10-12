
# All scoring parameters live here so they can be documented
# and adjusted in one place.

# Component weights must sum to 1.0
COMPONENT_WEIGHTS = {
    "security": 0.40,
    "maintenance": 0.30,
    "license": 0.30,
}

# Component health values range from 0.0 (worst) to 1.0 (best)
SECURITY_HEALTH = {
    "NONE": 1.0,
    "LOW": 0.75,
    "MEDIUM": 0.5,
    "HIGH": 0.2,
    "CRITICAL": 0.0,
}

# Neutral value when information is missing or uncertain
UNCERTAIN_HEALTH = 0.5

MAINTENANCE_HEALTH = {
    "Maintained": 1.0,
    "Unable to determine": UNCERTAIN_HEALTH,
    "Unmaintained": 0.0,
}

LICENSE_HEALTH = {
    "COMPLIANT": 1.0,
    "NOT_IN_POLICY": 0.6,
    "RESTRICTED": 0.5,
    "UNKNOWN": UNCERTAIN_HEALTH,
    "NON_COMPLIANT": 0.0,
}

# Risk levels in ascending order
RISK_LEVELS = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]

# Maximum governance score allowed for higher risk levels
RISK_SCORE_CAPS = {
    "CRITICAL": 40,
    "HIGH": 60,
}

# Higher-risk dependencies have more influence on the project score
PROJECT_RISK_WEIGHTS = {
    "LOW": 1,
    "MEDIUM": 2,
    "HIGH": 3,
    "CRITICAL": 4,
}

assert abs(sum(COMPONENT_WEIGHTS.values()) - 1.0) < 1e-9, (
    "Component weights must sum to 1.0"
)

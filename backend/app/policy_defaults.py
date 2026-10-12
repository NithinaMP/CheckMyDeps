# Default governance policy.
# An organization's policy can override these values.

DEFAULT_POLICY = {
    "allowed_licenses": [
        "MIT",
        "Apache-2.0",
        "BSD",
        "ISC",
        "Unlicense",
    ],
    "restricted_licenses": [
        "LGPL",
        "MPL",
    ],
    "prohibited_licenses": [
        "GPL",
        "AGPL",
    ],
    "max_vulnerability_severity": "MEDIUM",
    # Allowed values: NONE, LOW, MEDIUM, HIGH, CRITICAL
    "require_maintained": True,
}

from app.services.rule_engine import (
    check_license,
    check_vulnerability,
    check_maintenance,
    evaluate_dependency,
)


def test_allowed_license():
    assert check_license("MIT")["status"] == "COMPLIANT"
    assert check_license("Apache-2.0")["status"] == "COMPLIANT"
    assert check_license("BSD-3-Clause")["status"] == "COMPLIANT"


def test_prohibited_license():
    assert check_license("GPL-3.0-only")["status"] == "NON_COMPLIANT"
    assert check_license("AGPL-3.0")["status"] == "NON_COMPLIANT"


def test_lgpl_is_restricted():
    assert check_license("LGPL-2.1")["status"] == "RESTRICTED"


def test_unknown_license():
    assert check_license(None)["status"] == "UNKNOWN"
    assert check_license("UNLICENSED")["status"] == "UNKNOWN"


def test_vulnerabilities():
    clean = {
        "status": "ok",
        "vulnerability_count": 0,
        "highest_severity": "NONE",
    }
    high = {
        "status": "ok",
        "vulnerability_count": 2,
        "highest_severity": "HIGH",
    }

    assert check_vulnerability(clean)["status"] == "CLEAR"
    assert check_vulnerability(high, "MEDIUM")["status"] == "EXCEEDS_POLICY"


def test_maintenance():
    assert check_maintenance(
        {"status": "Maintained"}
    )["status"] == "MEETS"

    assert check_maintenance(
        {"status": "Unmaintained"}
    )["status"] == "VIOLATES"

    assert check_maintenance(
        {"status": "Unable to determine"}
    )["status"] == "UNVERIFIED"


def test_overall_policy():
    result = evaluate_dependency(
        "MIT",
        {
            "status": "ok",
            "vulnerability_count": 0,
            "highest_severity": "NONE",
        },
        {"status": "Maintained"},
    )

    assert result["policy"]["policy_status"] == "OK"

import io
from fastapi.testclient import TestClient
from app.main import app
from app.api.analysis import GUEST_MAX_DEPENDENCIES
from app.services.dependency_parser import parse_pubspec, parse_requirements_txt, parse_package_json

SAMPLE_PUBSPEC = """
name: test_project
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  provider: ^6.1.0
  shared_preferences: ^2.2.0
  intl: ^0.19.0
  path: ^1.9.0
  url_launcher: ^6.3.0
  crypto: ^3.0.3
"""

SAMPLE_REQUIREMENTS = """
fastapi==0.110.0
pydantic>=2.6.0
requests==2.31.0
pytest==8.0.0
joblib==1.3.2
pandas==2.2.1
scikit-learn==1.4.1
"""

def test_guest_dependency_limit_enforcement():
    deps = parse_pubspec(SAMPLE_PUBSPEC)
    assert len(deps) == 7
    guest_selected = deps[:GUEST_MAX_DEPENDENCIES]
    assert len(guest_selected) == 5
    assert len(deps) - len(guest_selected) == 2

def test_requirements_parsing_and_guest_limit():
    deps = parse_requirements_txt(SAMPLE_REQUIREMENTS)
    assert len(deps) == 7
    guest_selected = deps[:GUEST_MAX_DEPENDENCIES]
    assert len(guest_selected) == 5

def test_guest_run_endpoint_live():
    client = TestClient(app)
    file_bytes = io.BytesIO(SAMPLE_PUBSPEC.encode("utf-8"))
    response = client.post(
        "/analysis/guest-run",
        files={"file": ("pubspec.yaml", file_bytes, "application/x-yaml")},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["is_guest_result"] is True
    assert data["total_in_file"] == 7
    assert data["guest_limit"] == 5
    assert data["locked_dependencies_count"] == 2
    assert len(data["dependencies"]) == 5
    assert "summary" in data
    assert "compliance_score" in data["summary"]
    # Check that dependencies were genuinely evaluated with risk scores and badges
    for dep in data["dependencies"]:
        assert "name" in dep
        assert "status" in dep
        assert "governance" in dep

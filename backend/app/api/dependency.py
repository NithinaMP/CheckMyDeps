
from typing import Optional

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from pydantic import BaseModel

from app.api.auth import verify_token
from app.services.dependency_parser import parse_dependency_file
from app.services.registry_service import get_package_metadata
from app.services.github_service import get_repository_data
from app.services.osv_service import get_vulnerability_data
from app.services.ml_service import predict_repository_maintenance
from app.services.rule_engine import evaluate_dependency


router = APIRouter()

MAX_FILE_SIZE = 1 * 1024 * 1024  # 1 MB


@router.post("/upload")
async def upload_dependency_file(
    file: UploadFile = File(...),
    user=Depends(verify_token),
):
    raw = await file.read()

    if len(raw) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large")

    try:
        content = raw.decode("utf-8")
    except UnicodeDecodeError:
        raise HTTPException(
            status_code=400,
            detail="File is not valid UTF-8 text",
        )

    try:
        dependencies = parse_dependency_file(file.filename, content)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception:
        raise HTTPException(
            status_code=400,
            detail="Could not parse dependency file — check its format",
        )

    if not dependencies:
        raise HTTPException(
            status_code=400,
            detail="No dependencies found in file",
        )

    return {
        "filename": file.filename,
        "dependencies": dependencies,
    }


@router.get("/registry-test")
def registry_test(
    name: str,
    ecosystem: str,
    user=Depends(verify_token),
):
    result = get_package_metadata(name, ecosystem)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Package not found or registry unreachable",
        )

    return result


@router.get("/github-test")
def github_test(
    repo_url: str,
    user=Depends(verify_token),
):
    result = get_repository_data(repo_url)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Repository not found or URL unparseable",
        )

    if "error" in result:
        raise HTTPException(status_code=502, detail=result["error"])

    return result


@router.get("/osv-test")
def osv_test(
    name: str,
    ecosystem: str,
    version: Optional[str] = None,
    user=Depends(verify_token),
):
    result = get_vulnerability_data(name, ecosystem, version)

    if result["status"] == "unsupported_ecosystem":
        raise HTTPException(status_code=400, detail=result["reason"])

    return result


@router.get("/ml-test")
def ml_test(
    repo_url: str,
    user=Depends(verify_token),
):
    result = predict_repository_maintenance(repo_url)

    if result.get("status") == "Unable to determine":
        raise HTTPException(
            status_code=502,
            detail=result.get("reason", "Unable to determine maintenance status"),
        )

    return result


class RulesTestInput(BaseModel):
    license: Optional[str] = None
    vulnerability_data: Optional[dict] = None
    maintenance_result: Optional[dict] = None
    policy: Optional[dict] = None


@router.post("/rules-test")
def rules_test(
    body: RulesTestInput,
    user=Depends(verify_token),
):
    return evaluate_dependency(
        body.license,
        body.vulnerability_data,
        body.maintenance_result,
        body.policy,
    )

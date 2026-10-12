
import json
from typing import Optional

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    UploadFile,
)

from app.api.auth import verify_token
from app.policy_defaults import DEFAULT_POLICY
from app.services.analysis_service import analyze_dependencies
from app.services.dependency_parser import parse_dependency_file
from app.services.rule_engine import SEVERITY_RANK

router = APIRouter()
MAX_FILE_SIZE = 1 * 1024 * 1024


@router.post("/run")
def run_analysis(
    file: UploadFile = File(...),
    policy_json: Optional[str] = Form(None),
    user=Depends(verify_token),
):
    raw = file.file.read(MAX_FILE_SIZE + 1)

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
            detail="Could not parse dependency file",
        )

    if not dependencies:
        raise HTTPException(
            status_code=400,
            detail="No dependencies found in file",
        )

    policy = None

    if policy_json:
        try:
            policy = json.loads(policy_json)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail="policy_json is not valid JSON",
            )

        if not isinstance(policy, dict) or set(policy) - set(DEFAULT_POLICY):
            raise HTTPException(
                status_code=400,
                detail=f"policy_json may only contain: {sorted(DEFAULT_POLICY)}",
            )

        if (
            str(policy.get("max_vulnerability_severity", "MEDIUM")).upper()
            not in SEVERITY_RANK
        ):
            raise HTTPException(
                status_code=400,
                detail="Invalid max_vulnerability_severity",
            )

    return analyze_dependencies(
        file.filename,
        dependencies,
        policy,
    )

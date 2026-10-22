"""Project analyses: upload a dependency file, run the EXISTING pipeline, store it.

The pipeline itself (`analyze_dependencies`: registries, OSV, ML model, rules,
scoring) is reused unchanged from app.services.analysis_service.
"""

import re
from pathlib import PurePosixPath
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from app.api.org_deps import NOT_FOUND, OrgContext, require_org_role
from app.api.projects import get_project_repo
from app.models.organization import Role
from app.models.project_analysis import AnalysisListItem, AnalysisListOut
from app.services.analysis_repository import (
    ResultTooLarge,
    get_default_analysis_repository,
    prepare_result_for_storage,
)
from app.services.analysis_service import analyze_dependencies
from app.services.dependency_parser import parse_dependency_file

router = APIRouter()

MAX_FILE_SIZE = 1 * 1024 * 1024  # same limit as /analysis/run
_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,128}$")


def get_analysis_repo():
    """Override in tests with `app.dependency_overrides[get_analysis_repo]`."""
    return get_default_analysis_repository()


def _clean_filename(raw: Optional[str]) -> str:
    name = PurePosixPath((raw or "").replace("\\", "/")).name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="The uploaded file has no name")
    return name[-200:]


def _full_payload(rec) -> dict:
    return {
        **rec.result,
        "id": rec.id,
        "project_id": rec.project_id,
        "created_at": rec.created_at,
        "created_by_email": rec.created_by_email,
    }


@router.post("/{org_id}/projects/{project_id}/analyses", status_code=201)
def run_project_analysis(
    project_id: str,
    file: UploadFile = File(...),
    ctx: OrgContext = Depends(require_org_role(Role.DEVELOPER)),
    projects=Depends(get_project_repo),
    analyses=Depends(get_analysis_repo),
):
    if not _ID_RE.fullmatch(project_id):
        raise HTTPException(status_code=404, detail=NOT_FOUND)
    project = projects.get_project(ctx.org.id, project_id)
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found")

    filename = _clean_filename(file.filename)

    raw = file.file.read(MAX_FILE_SIZE + 1)
    if len(raw) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large (limit is 1 MB)")
    try:
        content = raw.decode("utf-8")
    except UnicodeDecodeError:
        raise HTTPException(status_code=400, detail="File is not valid UTF-8 text")

    try:
        dependencies = parse_dependency_file(filename, content)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception:
        raise HTTPException(status_code=400, detail="Could not parse dependency file")
    if not dependencies:
        raise HTTPException(status_code=400, detail="No dependencies found in file")

    found = {d["ecosystem"] for d in dependencies}
    if found != {project.ecosystem}:
        raise HTTPException(
            status_code=400,
            detail=(
                f"This project tracks {project.ecosystem} dependencies, "
                f"but {filename} contains {', '.join(sorted(found))} dependencies"
            ),
        )

    try:
        # Org policy arrives in a later stage; None = the platform DEFAULT_POLICY.
        result = analyze_dependencies(filename, dependencies, None)
    except Exception:
        raise HTTPException(status_code=502, detail="The analysis pipeline failed")

    if (result.get("summary") or {}).get("analyzed", 0) == 0:
        raise HTTPException(
            status_code=502,
            detail=(
                "None of the dependencies could be analyzed (external services may be "
                "unreachable). Nothing was saved; please try again."
            ),
        )

    try:
        to_store = prepare_result_for_storage(result)
    except ResultTooLarge:
        raise HTTPException(status_code=413, detail="The analysis result is too large to store")

    rec = analyses.save(
        org_id=ctx.org.id,
        project_id=project_id,
        filename=filename,
        created_by=ctx.user.uid,
        created_by_email=ctx.user.email,
        result=to_store,
    )
    projects.set_latest_analysis(
        ctx.org.id,
        project_id,
        {
            "id": rec.id,
            "filename": rec.filename,
            "created_at": rec.created_at,
            "summary": rec.summary,
        },
    )
    return _full_payload(rec)


@router.get("/{org_id}/projects/{project_id}/analyses", response_model=AnalysisListOut)
def list_project_analyses(
    project_id: str,
    ctx: OrgContext = Depends(require_org_role(Role.DEVELOPER)),
    projects=Depends(get_project_repo),
    analyses=Depends(get_analysis_repo),
):
    if not _ID_RE.fullmatch(project_id) or projects.get_project(ctx.org.id, project_id) is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return AnalysisListOut(
        analyses=[
            AnalysisListItem(
                id=r.id,
                filename=r.filename,
                created_at=r.created_at,
                created_by_email=r.created_by_email,
                summary=r.summary,
            )
            for r in analyses.list(ctx.org.id, project_id)
        ]
    )


@router.get("/{org_id}/projects/{project_id}/analyses/{analysis_id}")
def get_project_analysis(
    project_id: str,
    analysis_id: str,
    ctx: OrgContext = Depends(require_org_role(Role.DEVELOPER)),
    projects=Depends(get_project_repo),
    analyses=Depends(get_analysis_repo),
):
    if not _ID_RE.fullmatch(project_id) or projects.get_project(ctx.org.id, project_id) is None:
        raise HTTPException(status_code=404, detail="Project not found")
    if not _ID_RE.fullmatch(analysis_id):
        raise HTTPException(status_code=404, detail="Analysis not found")
    rec = analyses.get(ctx.org.id, project_id, analysis_id)
    if rec is None:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return _full_payload(rec)
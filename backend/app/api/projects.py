import re

from fastapi import APIRouter, Depends, HTTPException

from app.api.org_deps import NOT_FOUND, OrgContext, require_org_role
from app.models.organization import Role
from app.models.project import (
    ProjectCreate,
    ProjectListOut,
    ProjectOut,
    ProjectRecord,
)
from app.services.project_repository import get_default_project_repository

router = APIRouter()

MAX_PROJECTS_PER_ORG = 100
_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,128}$")


def get_project_repo():
    """Override in tests with `app.dependency_overrides[get_project_repo]`."""
    return get_default_project_repository()


def _out(p: ProjectRecord) -> ProjectOut:
    return ProjectOut(
        id=p.id,
        org_id=p.org_id,
        name=p.name,
        ecosystem=p.ecosystem,
        repo_url=p.repo_url,
        created_at=p.created_at,
        latest_analysis=p.latest_analysis,
    )


@router.post("/{org_id}/projects", response_model=ProjectOut, status_code=201)
def create_project(
    body: ProjectCreate,
    ctx: OrgContext = Depends(require_org_role(Role.LEAD)),
    repo=Depends(get_project_repo),
):
    """Admin or lead. The organisation comes from the verified membership,
    the creator from the verified token; neither is read from the body."""
    if len(repo.list_projects(ctx.org.id)) >= MAX_PROJECTS_PER_ORG:
        raise HTTPException(
            status_code=409,
            detail=f"An organization can have at most {MAX_PROJECTS_PER_ORG} projects",
        )
    rec = repo.create_project(
        org_id=ctx.org.id,
        name=body.name,
        ecosystem=body.ecosystem.value,
        repo_url=body.repo_url,
        created_by=ctx.user.uid,
    )
    return _out(rec)


@router.get("/{org_id}/projects", response_model=ProjectListOut)
def list_projects(
    ctx: OrgContext = Depends(require_org_role(Role.DEVELOPER)),
    repo=Depends(get_project_repo),
):
    return ProjectListOut(projects=[_out(p) for p in repo.list_projects(ctx.org.id)])


@router.get("/{org_id}/projects/{project_id}", response_model=ProjectOut)
def get_project(
    project_id: str,
    ctx: OrgContext = Depends(require_org_role(Role.DEVELOPER)),
    repo=Depends(get_project_repo),
):
    if not _ID_RE.fullmatch(project_id):
        raise HTTPException(status_code=404, detail=NOT_FOUND)
    rec = repo.get_project(ctx.org.id, project_id)
    if rec is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return _out(rec)
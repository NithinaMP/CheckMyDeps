from fastapi import APIRouter, Depends, HTTPException

from app.api.org_deps import (
    AuthUser,
    OrgContext,
    current_user,
    get_org_repo,
    require_org_role,
)
from app.models.organization import (
    OrgCreate,
    OrgListOut,
    OrgOut,
    OrgUpdate,
    Role,
)
from app.services.org_repository import OrgRepository

router = APIRouter()

# Soft abuse limit: email/password sign-up is open, so cap organisations per user.
MAX_ORGS_PER_USER = 10


@router.post("", response_model=OrgOut, status_code=201)
def create_organization(
    body: OrgCreate,
    user: AuthUser = Depends(current_user),
    repo: OrgRepository = Depends(get_org_repo),
):
    """Creates an organisation. The caller becomes its first (and only) admin.
    The role is assigned by the server; it is never read from the request."""
    if len(repo.list_memberships(user.uid)) >= MAX_ORGS_PER_USER:
        raise HTTPException(
            status_code=409,
            detail=f"You can belong to at most {MAX_ORGS_PER_USER} organizations",
        )

    org = repo.create_organization(
        name=body.name, creator_uid=user.uid, creator_email=user.email
    )
    return OrgOut(id=org.id, name=org.name, role=Role.ADMIN, created_at=org.created_at)


@router.get("", response_model=OrgListOut)
def list_my_organizations(
    user: AuthUser = Depends(current_user),
    repo: OrgRepository = Depends(get_org_repo),
):
    """Organisations the caller is verified to belong to, with the caller's role."""
    return OrgListOut(
        organizations=[
            OrgOut(id=o.id, name=o.name, role=role, created_at=o.created_at)
            for o, role in repo.list_memberships(user.uid)
        ]
    )


@router.get("/{org_id}", response_model=OrgOut)
def get_organization(ctx: OrgContext = Depends(require_org_role(Role.DEVELOPER))):
    return OrgOut(
        id=ctx.org.id,
        name=ctx.org.name,
        role=ctx.role,
        created_at=ctx.org.created_at,
    )


@router.patch("/{org_id}", response_model=OrgOut)
def rename_organization(
    body: OrgUpdate,
    ctx: OrgContext = Depends(require_org_role(Role.ADMIN)),
    repo: OrgRepository = Depends(get_org_repo),
):
    """Admin-only. Also the reference example of how later features gate by role."""
    updated = repo.rename_organization(ctx.org.id, body.name)
    if updated is None:
        raise HTTPException(status_code=404, detail="Organization not found")
    return OrgOut(
        id=updated.id,
        name=updated.name,
        role=ctx.role,
        created_at=updated.created_at,
    )

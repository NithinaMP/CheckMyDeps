from fastapi import APIRouter, Depends

from app.api.org_deps import OrgContext, require_org_role
from app.api.projects import get_project_repo
from app.models.org_dashboard import OrgDashboardOut
from app.models.organization import Role
from app.services.org_dashboard import build_dashboard

router = APIRouter()


@router.get("/{org_id}/dashboard", response_model=OrgDashboardOut)
def get_org_dashboard(
    ctx: OrgContext = Depends(require_org_role(Role.DEVELOPER)),
    projects=Depends(get_project_repo),
):
    """Read-only overview built from the organisation's saved project records.
    Any member may read it. Nothing is re-analysed."""
    return build_dashboard(projects.list_projects(ctx.org.id))
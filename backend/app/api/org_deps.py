"""FastAPI dependencies that enforce authentication, membership and role.

Rules these dependencies guarantee for every route that uses them:
  1. The caller's identity comes ONLY from the verified Firebase ID token
     (via the existing `verify_token`).
  2. The organisation id comes from the URL path, and the caller's role comes
     ONLY from the authoritative Firestore membership document looked up with
     the verified uid. Headers, query params and bodies are never consulted.
  3. Non-members get 404 (not 403), so organisation ids cannot be probed.
     Members with an insufficient role get 403.
"""

from __future__ import annotations

import re
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Callable, Optional

from fastapi import Depends, HTTPException

from app.api.auth import verify_token
from app.models.organization import OrgRecord, Role
from app.services.org_repository import OrgRepository, get_default_repository

# Firestore auto-ids are 20 alphanumerics. Rejecting anything else up front also
# prevents invalid document ids ("." / "..", overly long strings) from reaching
# the SDK and turning into 500s.
_ORG_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,128}$")

NOT_FOUND = "Organization not found"


@dataclass(frozen=True)
class AuthUser:
    uid: str
    email: Optional[str] = None


@dataclass(frozen=True)
class OrgContext:
    org: OrgRecord
    role: Role
    user: AuthUser


def get_org_repo() -> OrgRepository:
    """Override in tests with `app.dependency_overrides[get_org_repo]`."""
    return get_default_repository()


def current_user(decoded=Depends(verify_token)) -> AuthUser:
    """Adapts whatever `verify_token` returns (decoded-token dict or an object
    with `.uid`) into an AuthUser. Missing uid -> 401."""
    if isinstance(decoded, Mapping):
        uid = decoded.get("uid") or decoded.get("user_id") or decoded.get("sub")
        email = decoded.get("email")
    else:
        uid = getattr(decoded, "uid", None)
        email = getattr(decoded, "email", None)

    if not isinstance(uid, str) or not uid:
        raise HTTPException(status_code=401, detail="Invalid authentication token")
    return AuthUser(uid=uid, email=email if isinstance(email, str) else None)


def require_org_role(minimum: Role = Role.DEVELOPER) -> Callable[..., OrgContext]:
    """Dependency factory: caller must be a member of `{org_id}` with at least `minimum`."""

    def dependency(
        org_id: str,
        user: AuthUser = Depends(current_user),
        repo: OrgRepository = Depends(get_org_repo),
    ) -> OrgContext:
        if not _ORG_ID_RE.fullmatch(org_id):
            raise HTTPException(status_code=404, detail=NOT_FOUND)

        role = repo.get_member_role(org_id, user.uid)
        if role is None:
            raise HTTPException(status_code=404, detail=NOT_FOUND)
        if not role.at_least(minimum):
            raise HTTPException(
                status_code=403,
                detail=f"This action requires the '{minimum.value}' role",
            )

        org = repo.get_organization(org_id)
        if org is None:  # member doc without an org doc: treat as non-existent
            raise HTTPException(status_code=404, detail=NOT_FOUND)
        return OrgContext(org=org, role=role, user=user)

    return dependency

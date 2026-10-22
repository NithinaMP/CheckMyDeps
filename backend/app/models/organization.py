"""Organisation data models (Feature 1).

Firestore layout (all access goes through the FastAPI backend / Admin SDK):

  organizations/{orgId}                      name, created_by, created_at
  organizations/{orgId}/members/{uid}        uid, role, email, added_by, added_at   <-- AUTHORITATIVE
  user_memberships/{uid}/orgs/{orgId}        org_id, joined_at                      <-- listing index only

Authorisation is ALWAYS decided from the authoritative members/{uid} document.
The user_memberships mirror only tells us *which* organisations to look up.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Annotated, List, Optional

from pydantic import BaseModel, ConfigDict, StringConstraints, field_validator

ORG_NAME_MIN = 2
ORG_NAME_MAX = 80
_CONTROL_CHARS = re.compile(r"[\x00-\x1f\x7f]")


class Role(str, Enum):
    DEVELOPER = "developer"
    LEAD = "lead"
    ADMIN = "admin"

    @property
    def rank(self) -> int:
        return _RANK[self]

    def at_least(self, minimum: "Role") -> bool:
        return self.rank >= minimum.rank

    @classmethod
    def parse(cls, value: object) -> Optional["Role"]:
        """Defensive parse: unknown / corrupt stored values grant NO access."""
        if isinstance(value, cls):
            return value
        if isinstance(value, str):
            try:
                return cls(value)
            except ValueError:
                return None
        return None


_RANK = {Role.DEVELOPER: 1, Role.LEAD: 2, Role.ADMIN: 3}


def normalize_org_name(value: str) -> str:
    if _CONTROL_CHARS.search(value):
        raise ValueError("Name must not contain control characters")
    collapsed = " ".join(value.split())
    if not (ORG_NAME_MIN <= len(collapsed) <= ORG_NAME_MAX):
        raise ValueError(
            f"Name must be {ORG_NAME_MIN}-{ORG_NAME_MAX} characters long"
        )
    return collapsed


OrgName = Annotated[str, StringConstraints(strip_whitespace=True, max_length=200)]


class OrgCreate(BaseModel):
    """Request body for POST /orgs.

    extra="forbid": a client that tries to send `role`, `created_by`, `id`, ...
    gets a 422 instead of having the field silently considered.
    """

    model_config = ConfigDict(extra="forbid")

    name: OrgName

    @field_validator("name")
    @classmethod
    def _check_name(cls, v: str) -> str:
        return normalize_org_name(v)


class OrgUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: OrgName

    @field_validator("name")
    @classmethod
    def _check_name(cls, v: str) -> str:
        return normalize_org_name(v)


class OrgOut(BaseModel):
    """An organisation as seen by ONE caller: `role` is the caller's own role."""

    id: str
    name: str
    role: Role
    created_at: Optional[datetime] = None


class OrgListOut(BaseModel):
    organizations: List[OrgOut]


@dataclass(frozen=True)
class OrgRecord:
    id: str
    name: str
    created_by: str
    created_at: Optional[datetime] = None

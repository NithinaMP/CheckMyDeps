from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import auth, dependency, analysis, organizations, projects, project_analyses, org_dashboard

app = FastAPI(title="Dependency Governance Platform")

# Allow the Flutter web dev server to call this API.
# In production, replace "*" with your actual deployed frontend URL.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # dev only — tighten this before any real deployment
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(dependency.router, prefix="/dependency", tags=["dependency"])

app.include_router(analysis.router, prefix="/analysis", tags=["analysis"])
app.include_router(organizations.router, prefix="/orgs", tags=["organizations"])
app.include_router(projects.router, prefix="/orgs", tags=["projects"])
app.include_router(project_analyses.router, prefix="/orgs", tags=["project-analyses"])
app.include_router(org_dashboard.router, prefix="/orgs", tags=["org-dashboard"])

@app.get("/")
def health_check():
    return {"status": "running"}
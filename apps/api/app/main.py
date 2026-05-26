"""FastAPI application entry point."""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db import init_db
from app.routes import search, universities, alumni, stats, health, sources, companies


@asynccontextmanager
async def lifespan(app: FastAPI):  # type: ignore[type-arg]
    init_db()
    yield


app = FastAPI(title="AlumniMap API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)

app.include_router(search.router, prefix="/api")
app.include_router(universities.router, prefix="/api")
app.include_router(alumni.router, prefix="/api")
app.include_router(stats.router, prefix="/api")
app.include_router(health.router, prefix="/api")
app.include_router(sources.router, prefix="/api")
app.include_router(companies.router, prefix="/api")

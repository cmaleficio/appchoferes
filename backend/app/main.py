"""FastAPI application entry point with CORS and router registration."""

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from .core.config import settings
from .routers import expenses, telemetry, auth, users, budgets, routes, logs, exchange_rates, deposits

app = FastAPI(title="AppChoferes Backend", version="0.2.0")

# CORS – allow all origins for development; tighten in prod.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/api/auth")
app.include_router(expenses.router, prefix="/api/expenses")
app.include_router(telemetry.router, prefix="/api/telemetry")
app.include_router(users.router, prefix="/api")
app.include_router(budgets.router, prefix="/api")
app.include_router(routes.router, prefix="/api")
app.include_router(logs.router, prefix="/api")
app.include_router(exchange_rates.router, prefix="/api")
app.include_router(deposits.router, prefix="/api")
# Serve the admin UI (frontend folder) at /admin
app.mount("/admin", StaticFiles(directory="frontend", html=True), name="admin")

# Root endpoint for health check
@app.get("/health")
async def health_check():
    return {"status": "ok"}

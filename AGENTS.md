# AGENTS.md – appchoferes (compact)

## Project snapshot
- Backend (FastAPI, async SQLAlchemy) lives under `backend/app`.
- Core packages:
  - `core/config.py` – Pydantic settings (DB URL, JWT secret).
  - `core/database.py` – async engine, `Base`, `get_db` dependency.
  - `core/security.py` – password hashing, JWT creation/validation.
  - `core/dependencies.py` – `get_current_user` extracts Bearer token, validates, returns ORM `User`.
- Models (`backend/app/models/__init__.py`):
  - `User` (role: `admin`|`driver`).
  - `Expense` with `category` ENUM (`peaje`, `hotel`, `gasolina`, `otros`) and toll fields `is_multiple_tolls`, `toll_count`.
  - `ExpenseRequest` (status ENUM `pendiente`, `aprobado`, `rechazado`).
  - `RouteTrack` (telemetry points).
  - Supporting `Route`, `Budget`, `Tag` and many‑to‑many `expense_tags`.
- Routers (`backend/app/routers`):
  - `auth.py` – `POST /api/auth/login` returns JWT.
  - `expenses.py` –
    - `POST /api/expenses/request-edit` creates `ExpenseRequest` with status *pendiente*.
    - `PUT /api/expenses/{id}` allows **admin** to edit an expense **only** if an `ExpenseRequest` with status *aprobado* exists for that `expense_id` (golden rule).
  - `telemetry.py` – `POST /api/telemetry/track` accepts a batch of `TrackPoint`s; admin can post for any user, drivers only for themselves.
- `main.py` wires FastAPI, adds CORS (allow all in dev), registers routers, provides `/health`.

## Critical business rule (easy to miss)
- **Expense edit guard:** The admin endpoint must check `ExpenseRequest.status == 'aprobado'` before applying changes; otherwise return `403 Forbidden`.

## Commands you’ll run frequently
- Create virtual env & install deps (once):
  ```bash
  python -m venv venv && .\venv\Scripts\activate && pip install fastapi[all] sqlalchemy aiosqlite passlib[bcrypt] pyjwt
  ```
- Run migrations (Alembic not added yet, placeholder): `alembic upgrade head`.
- Start dev server:
  ```bash
  uvicorn backend.app.main:app --reload
  ```
- Test a single endpoint with HTTPie or curl, e.g.:
  ```bash
  http POST http://localhost:8000/api/auth/login email=admin@example.com password=secret
  ```

## Gotchas agents may overlook
- **JWT extraction** – token is read from the `Authorization: Bearer <token>` header; missing or malformed header yields 401.
- **Async DB session** – always use `await db.commit()` and `await db.refresh(obj)` when persisting.
- **Enum values** – use the exact Spanish strings defined in `ExpenseCategory` and `ExpenseRequestStatus`; mismatched case/value causes validation errors.
- **CORS** – permissive in dev; tighten in production.
- **User role check** – `User.role` is a plain string, not an enum; ensure `'admin'` comparison is exact.

---
*Update `pr_status.md` under # CODDING after completing tasks.*
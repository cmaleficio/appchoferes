"""Create MySQL database and tables, seed admin user."""
import asyncio
import pymysql
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

# Step 1: Create database if not exists
conn = pymysql.connect(host='127.0.0.1', port=3306, user='root', password='')
cur = conn.cursor()
cur.execute("CREATE DATABASE IF NOT EXISTS appchoferes CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
print("Base de datos 'appchoferes' lista.")
conn.close()

# Step 2: Create tables using SQLAlchemy
ASYNC_DB_URL = "mysql+aiomysql://root:@127.0.0.1:3306/appchoferes"

async def setup():
    engine = create_async_engine(ASYNC_DB_URL, echo=False)
    async with engine.begin() as conn:
        from app.models import Base
        await conn.run_sync(Base.metadata.create_all)
        print("Tablas creadas exitosamente.")

        # Seed admin & drivers
        from app.core.security import get_password_hash

        existing = await conn.execute(text("SELECT email FROM users WHERE email = 'admin@example.com'"))
        if not existing.scalar_one_or_none():
            pw = get_password_hash("secret")
            await conn.execute(
                text("INSERT INTO users (email, hashed_password, role) VALUES (:e, :p, :r)"),
                {"e": "admin@example.com", "p": pw, "r": "admin"}
            )
            print("Admin seeded: admin@example.com / secret")

        for email in ["driver1@example.com", "driver2@example.com"]:
            existing = await conn.execute(text("SELECT email FROM users WHERE email = :e"), {"e": email})
            if not existing.scalar_one_or_none():
                pw = get_password_hash("secret")
                await conn.execute(
                    text("INSERT INTO users (email, hashed_password, role) VALUES (:e, :p, :r)"),
                    {"e": email, "p": pw, "r": "driver"}
                )
                print(f"Driver seeded: {email} / secret")

        # Seed routes
        existing = await conn.execute(text("SELECT COUNT(*) FROM routes"))
        if existing.scalar() == 0:
            routes = [
                ("Ruta Centro-Norte", "Centro", "Norte"),
                ("Ruta Sur-Este", "Sur", "Este"),
                ("Ruta Oeste-Periférico", "Oeste", "Periférico"),
            ]
            for name, start, end in routes:
                await conn.execute(
                    text("INSERT INTO routes (name, start_location, end_location) VALUES (:n, :s, :e)"),
                    {"n": name, "s": start, "e": end}
                )
            print("3 rutas seeded.")

        # Get driver IDs
        rows = await conn.execute(text("SELECT id FROM users WHERE role = 'driver'"))
        driver_ids = [r[0] for r in rows.fetchall()]

        for did in driver_ids:
            # Budget
            has = await conn.execute(text("SELECT id FROM budgets WHERE user_id = :uid LIMIT 1"), {"uid": did})
            if not has.scalar_one_or_none():
                await conn.execute(
                    text("INSERT INTO budgets (user_id, amount, period_start, period_end) VALUES (:uid, :amt, :ps, :pe)"),
                    {"uid": did, "amt": 5000.0, "ps": "2026-06-01 00:00:00", "pe": "2026-06-30 23:59:59"}
                )

            # Expenses
            has = await conn.execute(text("SELECT id FROM expenses WHERE user_id = :uid LIMIT 1"), {"uid": did})
            if not has.scalar_one_or_none():
                samples = [
                    (did, "GASOLINA", 1200.50, "Carga de combustible", None, None),
                    (did, "PEAGE", 350.00, "Peaje autopista", False, None),
                    (did, "HOTEL", 890.00, "Hospedaje noche", None, None),
                    (did, "OTROS", 150.00, "Refrigerios", None, None),
                ]
                for s in samples:
                    await conn.execute(
                        text("INSERT INTO expenses (user_id, category, amount, description, is_multiple_tolls, toll_count) VALUES (:uid, :cat, :amt, :desc, :mt, :tc)"),
                        {"uid": s[0], "cat": s[1], "amt": s[2], "desc": s[3], "mt": s[4], "tc": s[5]}
                    )

            # Route tracks
            route_row = await conn.execute(text("SELECT id FROM routes LIMIT 1"))
            route_id = route_row.scalar_one_or_none()
            if route_id:
                has = await conn.execute(text("SELECT id FROM route_tracks WHERE user_id = :uid LIMIT 1"), {"uid": did})
                if not has.scalar_one_or_none():
                    base_lat = 19.4326 + did * 0.01
                    base_lon = -99.1332 + did * 0.01
                    for i in range(20):
                        bat = max(0, min(100, 100 - i * 4.5 + (did * 2)))
                        await conn.execute(
                            text("INSERT INTO route_tracks (user_id, route_id, latitude, longitude, battery_level) VALUES (:uid, :rid, :lat, :lon, :bat)"),
                            {"uid": did, "rid": route_id, "lat": base_lat + i * 0.002, "lon": base_lon + i * 0.002, "bat": bat}
                        )

        print(f"Datos seeded para {len(driver_ids)} conductores.")
        await conn.commit()

    await engine.dispose()
    print("Setup completado exitosamente.")

import sys
sys.path.insert(0, "backend")
asyncio.run(setup())

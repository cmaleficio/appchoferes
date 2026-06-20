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

        # Drop all tables to ensure new columns are created
        await conn.run_sync(Base.metadata.drop_all)
        print("Tablas eliminadas.")

        await conn.run_sync(Base.metadata.create_all)
        print("Tablas creadas exitosamente.")

        # Seed admin & drivers
        from app.core.security import get_password_hash

        pw = get_password_hash("secret")
        await conn.execute(
            text("INSERT INTO users (email, hashed_password, role, name, is_active) VALUES (:e, :p, :r, :n, :a)"),
            {"e": "admin@example.com", "p": pw, "r": "admin", "n": "Admin Principal", "a": 1}
        )
        print("Admin seeded: admin@example.com / secret")

        for i, email in enumerate(["driver1@example.com", "driver2@example.com"]):
            pw = get_password_hash("secret")
            await conn.execute(
                text("INSERT INTO users (email, hashed_password, role, name, is_active) VALUES (:e, :p, :r, :n, :a)"),
                {"e": email, "p": pw, "r": "driver", "n": f"Chofer {i+1}", "a": 1}
            )
            print(f"Driver seeded: {email} / secret")

        # Seed routes
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
            # Budget (with exchange rate: Bs.60/USD)
            await conn.execute(
                text("INSERT INTO budgets (user_id, amount, amount_bs, exchange_rate, period_start, period_end) VALUES (:uid, :amt, :abs, :er, :ps, :pe)"),
                {"uid": did, "amt": 5000.0, "abs": 300000.0, "er": 60.0, "ps": "2026-06-01 00:00:00", "pe": "2026-06-30 23:59:59"}
            )

            # Expenses (with exchange rate: Bs.60/USD)
            samples = [
                (did, "GASOLINA", 1200.50, 72030.0, 60.0, "Carga de combustible", None, None),
                (did, "PEAGE", 350.00, 21000.0, 60.0, "Peaje autopista", False, None),
                (did, "HOTEL", 890.00, 53400.0, 60.0, "Hospedaje noche", None, None),
                (did, "OTROS", 150.00, 9000.0, 60.0, "Refrigerios", None, None),
            ]
            for s in samples:
                await conn.execute(
                    text("INSERT INTO expenses (user_id, category, amount, amount_bs, exchange_rate, description, is_multiple_tolls, toll_count) VALUES (:uid, :cat, :amt, :abs, :er, :desc, :mt, :tc)"),
                    {"uid": s[0], "cat": s[1], "amt": s[2], "abs": s[3], "er": s[4], "desc": s[5], "mt": s[6], "tc": s[7]}
                )

            # Route tracks
            route_row = await conn.execute(text("SELECT id FROM routes LIMIT 1"))
            route_id = route_row.scalar_one_or_none()
            base_lat = 19.4326 + did * 0.01
            base_lon = -99.1332 + did * 0.01
            for i in range(20):
                bat = max(0, min(100, 100 - i * 4.5 + (did * 2)))
                await conn.execute(
                    text("INSERT INTO route_tracks (user_id, route_id, latitude, longitude, battery_level) VALUES (:uid, :rid, :lat, :lon, :bat)"),
                    {"uid": did, "rid": route_id, "lat": base_lat + i * 0.002, "lon": base_lon + i * 0.002, "bat": bat}
                )

        # Seed exchange rates (last 5 days)
        from datetime import date, timedelta
        today = date.today()
        for i in range(5):
            d = today - timedelta(days=4-i)
            rate_val = 58.0 + i * 0.5
            await conn.execute(
                text("INSERT INTO exchange_rates (date, rate, source) VALUES (:d, :r, :s) ON DUPLICATE KEY UPDATE rate=VALUES(rate), source=VALUES(source)"),
                {"d": d, "r": rate_val, "s": "bcv" if i < 4 else "manual"}
            )
        print("5 tasas de cambio seeded.")

        # Seed deposits for each driver
        for did in driver_ids:
            dep_samples = [
                (did, 800.0, 48000.0, 60.0, "Depósito inicial"),
                (did, 350.0, 21000.0, 60.0, "Abono semana 1"),
            ]
            for d in dep_samples:
                await conn.execute(
                    text("INSERT INTO deposits (user_id, amount, amount_bs, exchange_rate, description) VALUES (:uid, :amt, :abs, :er, :desc)"),
                    {"uid": d[0], "amt": d[1], "abs": d[2], "er": d[3], "desc": d[4]}
                )
        print(f"Depósitos seeded para {len(driver_ids)} conductores.")

        print(f"Datos seeded para {len(driver_ids)} conductores.")
        await conn.commit()

    await engine.dispose()
    print("Setup completado exitosamente.")

import sys
sys.path.insert(0, "backend")
asyncio.run(setup())

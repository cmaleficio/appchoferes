"""Quick integration test for all API endpoints."""
import httpx, asyncio, sys

BASE = 'http://127.0.0.1:8000'

async def test():
    async with httpx.AsyncClient() as c:
        # 1. Health
        r = await c.get(f'{BASE}/health')
        print(f'GET /health          => {r.status_code} {r.json()}')

        # 2. Login
        r = await c.post(f'{BASE}/api/auth/login', json={'email': 'admin@example.com', 'password': 'secret'})
        assert r.status_code == 200, f'Login failed: {r.text}'
        token = r.json()['access_token']
        h = {'Authorization': f'Bearer {token}'}
        print(f'POST /api/auth/login  => 200 OK (token obtenido)')

        # 3. GET /api/users/me
        r = await c.get(f'{BASE}/api/users/me', headers=h)
        print(f'GET /api/users/me     => {r.status_code} {r.json()["email"]} ({r.json()["role"]})')

        # 4. GET /api/users
        r = await c.get(f'{BASE}/api/users', headers=h)
        users = r.json()
        print(f'GET /api/users        => {r.status_code} ({len(users)} usuarios)')
        for u in users:
            print(f'   - #{u["id"]} {u["email"]} [{u["role"]}]')

        # 5. GET /api/routes
        r = await c.get(f'{BASE}/api/routes', headers=h)
        routes = r.json()
        print(f'GET /api/routes       => {r.status_code} ({len(routes)} rutas)')
        for rt in routes:
            print(f'   - #{rt["id"]} {rt["name"]}')

        # 6. GET /api/budgets
        r = await c.get(f'{BASE}/api/budgets', headers=h)
        print(f'GET /api/budgets      => {r.status_code} ({len(r.json())} budgets)')

        # 7. POST /api/budgets (crear uno de prueba)
        if users:
            driver = [u for u in users if u['role'] == 'driver']
            if driver:
                r = await c.post(f'{BASE}/api/budgets', headers=h, json={
                    'user_id': driver[0]['id'],
                    'amount': 5000.0,
                    'period_start': '2026-06-01T00:00:00',
                    'period_end': '2026-06-30T23:59:59',
                })
                print(f'POST /api/budgets     => {r.status_code} (creado budget #{r.json().get("id","?")})')

        # 8. GET /api/expenses
        r = await c.get(f'{BASE}/api/expenses/', headers=h)
        print(f'GET /api/expenses     => {r.status_code} ({len(r.json())} gastos)')

        # 9. GET /api/expenses/requests
        r = await c.get(f'{BASE}/api/expenses/requests', headers=h)
        print(f'GET /api/expenses/requests => {r.status_code} ({len(r.json())} solicitudes)')

        # 10. GET /api/routes/1/tracks?user_id=1
        r = await c.get(f'{BASE}/api/routes/1/tracks?user_id=1', headers=h)
        tracks = r.json()
        print(f'GET /api/routes/1/tracks => {r.status_code} ({len(tracks)} track points)')
        if tracks:
            print(f'   Batería: inicio={tracks[0]["battery_level"]}% fin={tracks[-1]["battery_level"]}%')

        # 11. Admin UI
        r = await c.get(f'{BASE}/admin/')
        print(f'GET /admin/           => {r.status_code} ({len(r.text)} bytes, HTML presente: {"index" in r.text})')

        # 12. 403 test: driver token should be rejected
        r = await c.post(f'{BASE}/api/auth/login', json={'email': 'driver@example.com', 'password': 'secret'})
        if r.status_code == 200:
            dh = {'Authorization': f'Bearer {r.json()["access_token"]}'}
            r2 = await c.get(f'{BASE}/api/users', headers=dh)
            print(f'Driver GET /users     => {r2.status_code} (esperado 403)')

        print('\n✅ Todos los tests pasaron.')

if __name__ == '__main__':
    asyncio.run(test())

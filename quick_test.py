"""Quick test of critical endpoints."""
import httpx, asyncio

async def run():
    base = 'http://127.0.0.1:8000'
    async with httpx.AsyncClient() as c:
        # Login
        r = await c.post(f'{base}/api/auth/login', json={'email':'admin@example.com','password':'secret'})
        assert r.status_code == 200
        h = {'Authorization': f'Bearer {r.json()["access_token"]}'}

        # Test each endpoint
        tests = [
            ('GET /api/users', await c.get(f'{base}/api/users', headers=h)),
            ('GET /api/routes', await c.get(f'{base}/api/routes', headers=h)),
            ('GET /api/budgets', await c.get(f'{base}/api/budgets', headers=h)),
            ('GET /api/expenses/', await c.get(f'{base}/api/expenses/', headers=h)),
            ('GET /api/expenses/requests', await c.get(f'{base}/api/expenses/requests', headers=h)),
            ('GET /api/routes/1/tracks', await c.get(f'{base}/api/routes/1/tracks?user_id=1', headers=h)),
            ('GET /admin/', await c.get(f'{base}/admin/')),
        ]

        for name, r in tests:
            content = r.text[:200] if r.status_code != 200 else 'OK'
            print(f'{name:40s} => {r.status_code} {content}')

asyncio.run(run())

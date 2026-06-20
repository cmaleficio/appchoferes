"""Quick test of expense endpoint after schema fix."""
import httpx, asyncio
async def run():
    base = 'http://127.0.0.1:8000'
    async with httpx.AsyncClient() as c:
        r = await c.post(f'{base}/api/auth/login', json={'email':'admin@example.com','password':'secret'})
        assert r.status_code == 200
        h = {'Authorization': f'Bearer {r.json()["access_token"]}'}
        r2 = await c.get(f'{base}/api/expenses/', headers=h)
        print(f'Expenses: {r2.status_code}', 'OK' if r2.status_code == 200 else r2.text[:300])
        if r2.status_code == 200:
            print(f'  {len(r2.json())} expenses loaded')
asyncio.run(run())

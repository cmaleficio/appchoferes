"""Debug the 500 error on GET /api/expenses/"""
import httpx, asyncio

async def run():
    async with httpx.AsyncClient() as c:
        r = await c.post('http://127.0.0.1:8000/api/auth/login', json={'email':'admin@example.com','password':'secret'})
        token = r.json()['access_token']
        h = {'Authorization': f'Bearer {token}'}

        r = await c.get('http://127.0.0.1:8000/api/expenses/', headers=h)
        print(f'Status: {r.status_code}')
        print(f'Body length: {len(r.text)}')
        print(f'Body: {r.text[:800]}')
        print(f'Headers: {dict(r.headers)}')

asyncio.run(run())

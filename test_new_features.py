"""Test new Phase 2 features: create user, budgets with exchange rate, logs."""
import httpx, asyncio

async def run():
    base = 'http://127.0.0.1:8000'
    async with httpx.AsyncClient() as c:
        # Login fresh
        r = await c.post(f'{base}/api/auth/login', json={'email':'admin@example.com','password':'secret'})
        assert r.status_code == 200, r.text
        token = r.json()['access_token']
        h = {'Authorization': f'Bearer {token}'}
        print('Login OK')

        # Create a new user
        r2 = await c.post(f'{base}/api/users', headers=h, json={'email':'nuevo@test.com','password':'1234','role':'driver','name':'Test User'})
        print(f'Create user: {r2.status_code}', r2.json() if r2.status_code != 201 else 'Created')

        # Check logs now have entries
        r3 = await c.get(f'{base}/api/logs', headers=h)
        print(f'Logs: {r3.status_code}, {len(r3.json())} entries')

        # Check budgets with exchange_rate
        r4 = await c.get(f'{base}/api/budgets', headers=h)
        if r4.status_code == 200:
            budgets = r4.json()
            print(f'Budgets: {len(budgets)} entries')
            for b in budgets:
                print(f'  #{b["id"]} user={b["user_id"]} USD={b["amount"]} Bs={b.get("amount_bs")} tasa={b.get("exchange_rate")}')

        # Create budget with exchange rate
        r5 = await c.post(f'{base}/api/budgets', headers=h, json={
            'user_id': 2, 'amount': 200.0, 'amount_bs': 12000.0, 'exchange_rate': 60.0,
            'period_start': '2026-07-01T00:00:00', 'period_end': '2026-07-31T23:59:59'
        })
        print(f'Create budget: {r5.status_code}', r5.json() if r5.status_code != 201 else 'Created')

asyncio.run(run())

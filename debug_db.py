"""Check what's in MySQL expenses table."""
import pymysql
conn = pymysql.connect(host='127.0.0.1', port=3306, user='root', database='appchoferes')
cur = conn.cursor()
cur.execute("SELECT id, user_id, category, amount FROM expenses")
for row in cur.fetchall():
    print(f'#{row[0]} user={row[1]} cat="{row[2]}" amount={row[3]}')
print('---')
cur.execute("SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='appchoferes' AND TABLE_NAME='expenses' AND COLUMN_NAME='category'")
print('Column type:', cur.fetchone())
conn.close()

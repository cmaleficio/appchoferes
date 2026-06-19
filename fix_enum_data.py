"""Fix MySQL enum values - SQLAlchemy stores NAMES, not VALUES."""
import pymysql
conn = pymysql.connect(host='127.0.0.1', port=3306, user='root', database='appchoferes')
cur = conn.cursor()

# Fix empty string categories (inserted as 'peaje' but SQLAlchemy enum expects 'PEAGE')
cur.execute("UPDATE expenses SET category = 'PEAGE' WHERE category = '' OR category IS NULL")
print(f'Filas PEAGE corregidas: {cur.rowcount}')

# Force uppercase for any lowercase values
cur.execute("UPDATE expenses SET category = 'GASOLINA' WHERE LOWER(category) = 'gasolina'")
print(f'Filas GASOLINA: {cur.rowcount}')
cur.execute("UPDATE expenses SET category = 'HOTEL' WHERE LOWER(category) = 'hotel'")
print(f'Filas HOTEL: {cur.rowcount}')
cur.execute("UPDATE expenses SET category = 'OTROS' WHERE LOWER(category) = 'otros'")
print(f'Filas OTROS: {cur.rowcount}')

conn.commit()

# Verify
cur.execute("SELECT id, category FROM expenses")
print("\nDatos corregidos:")
for row in cur.fetchall():
    print(f'  #{row[0]}: "{row[1]}"')
conn.close()

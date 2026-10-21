#!/usr/bin/env python3
"""Export all tables from Supabase (PostgreSQL) to CSV files."""
import psycopg2
import os

# Try both password formats
passwords = ['Kenyacom23. Kenyacom_23', 'Kenyacom23', 'Kenyacom_23']

# Try with IP address directly
hosts = [
    'db.nlikgeqoocimbbqyaegq.supabase.co',
    '2a05:d01c:b72:2a02:a1bd:8232:9ea6:3448'
]

output_dir = 'supabase_export'
os.makedirs(output_dir, exist_ok=True)

for host in hosts:
    for password in passwords:
        conn_params = {
            'host': host,
            'port': 5432,
            'database': 'postgres',
            'user': 'postgres',
            'password': password,
            'sslmode': 'require',
            'connect_timeout': 10
        }
        
        try:
            print(f"Trying host={host}, password={password[:10]}...")
            conn = psycopg2.connect(**conn_params)
            cur = conn.cursor()
            
            # Get all tables
            cur.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                ORDER BY table_name
            """)
            tables = [row[0] for row in cur.fetchall()]
            
            print(f"Found {len(tables)} tables: {tables}")
            
            for table in tables:
                cur.execute(f"SELECT * FROM \"{table}\"")
                rows = cur.fetchall()
                cols = [desc[0] for desc in cur.description]
                
                filepath = os.path.join(output_dir, f"{table}.csv")
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(','.join(cols) + '\n')
                    for row in rows:
                        f.write(','.join(str(v) if v is not None else '' for v in row) + '\n')
                
                print(f"Exported {len(rows)} rows from '{table}' -> {filepath}")
            
            cur.close()
            conn.close()
            print("\nExport complete!")
            exit(0)
            
        except Exception as e:
            print(f"  Failed: {e}")
            continue

print("All connection attempts failed.")
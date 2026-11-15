"""
Database Initialization Script for Swift Route Logistics Manager.
Executes all SQL migration files in numbered sequence against MySQL 8.4 LTS.
"""
import os
import re
import sys
import pymysql

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
    "charset": "utf8mb4",
    "autocommit": True
}

SQL_FILES = [
    "00_reset_database.sql",
    "01_schema.sql",
    "02_indexes.sql",
    "03_triggers.sql",
    "04_views.sql",
    "05_procedures.sql",
    "06_sample_data.sql",
    "07_analytical_queries.sql",
    "08_transactions_and_concurrency.sql",
    "09_normalization_report.sql"
]

def split_sql_script(content: str):
    """
    Parses SQL files containing DELIMITER switches ($$) and normal semicolons.
    """
    statements = []
    current_delimiter = ";"
    buffer = []

    lines = content.splitlines()
    for line in lines:
        stripped = line.strip()
        # Check for DELIMITER change
        if stripped.upper().startswith("DELIMITER"):
            parts = stripped.split()
            if len(parts) >= 2:
                current_delimiter = parts[1]
            continue

        if stripped.startswith("--") or not stripped:
            continue

        buffer.append(line)

        # Check if the buffer ends with current delimiter
        joined = "\n".join(buffer).rstrip()
        if joined.endswith(current_delimiter):
            stmt = joined[:-len(current_delimiter)].strip()
            if stmt:
                statements.append(stmt)
            buffer = []

    if buffer:
        remaining = "\n".join(buffer).strip()
        if remaining:
            statements.append(remaining)

    return statements

def init_database():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    print(f"[*] Connecting to MySQL Server at {DB_CONFIG['host']}:{DB_CONFIG['port']} as '{DB_CONFIG['user']}'...")
    
    conn = pymysql.connect(**DB_CONFIG)
    cur = conn.cursor()

    for filename in SQL_FILES:
        filepath = os.path.join(base_dir, filename)
        if not os.path.exists(filepath):
            print(f"[!] Warning: File {filepath} not found, skipping.")
            continue

        print(f"[*] Executing {filename}...")
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        statements = split_sql_script(content)
        success_count = 0
        for i, stmt in enumerate(statements, 1):
            if not stmt.strip():
                continue
            # Skip multi-line comments that are pure documentation
            if stmt.strip().startswith("/*") and stmt.strip().endswith("*/"):
                continue
            try:
                cur.execute(stmt)
                success_count += 1
            except pymysql.MySQLError as e:
                err_code = e.args[0]
                if err_code in (1061, 1062, 1050): # Duplicate key / index / table
                    pass
                else:
                    print(f"[!] Error in {filename} statement #{i}:\n{stmt[:200]}...\nError: {e}")
                    raise

        print(f"  -> Successfully executed {success_count} statements from {filename}.")

    # Run verification queries
    print("\n[*] --- VERIFICATION SUMMARY ---")
    cur.execute("USE swiftroute;")
    cur.execute("SHOW FULL TABLES;")
    table_rows = cur.fetchall()
    tables = [row[0] for row in table_rows if row[1] == 'BASE TABLE']
    views = [row[0] for row in table_rows if row[1] == 'VIEW']
    
    print(f"[*] Base Tables Created ({len(tables)}): {', '.join(tables)}")
    print(f"[*] Relational Views Created ({len(views)}): {', '.join(views)}")

    for tbl in tables:
        cur.execute(f"SELECT COUNT(*) FROM {tbl};")
        count = cur.fetchone()[0]
        print(f"  - Table '{tbl}': {count} records")

    cur.close()
    conn.close()
    print("\n[+] Database initialization and migrations completed successfully!\n")

if __name__ == "__main__":
    init_database()

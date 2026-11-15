"""
MySQL 8.4 LTS Portable Installer & Manager for Swift Route Logistics Manager.
Downloads, extracts, initializes, and manages a portable instance of MySQL 8.4 LTS on Windows.
"""
import os
import sys
import time
import zipfile
import urllib.request
import subprocess

MYSQL_URL = "https://dev.mysql.com/get/Downloads/MySQL-8.4/mysql-8.4.4-winx64.zip"
BASE_DIR = os.path.abspath(r"D:\DBMS\mysql_server")
ZIP_PATH = os.path.join(BASE_DIR, "mysql-8.4.4-winx64.zip")
EXTRACT_DIR = os.path.join(BASE_DIR, "mysql-8.4.4-winx64")
DATA_DIR = os.path.join(BASE_DIR, "data")
INI_PATH = os.path.join(BASE_DIR, "my.ini")

def log(msg: str):
    print(f"[*] {msg}", flush=True)

def download_mysql():
    os.makedirs(BASE_DIR, exist_ok=True)
    if os.path.exists(ZIP_PATH) and os.path.getsize(ZIP_PATH) > 200 * 1024 * 1024:
        log(f"Zip already downloaded: {ZIP_PATH}")
        return

    log(f"Downloading MySQL 8.4 LTS from {MYSQL_URL} ...")
    def report(count, block_size, total_size):
        percent = int(count * block_size * 100 / total_size)
        if count % 2000 == 0:
            print(f" -> Download progress: {percent}% ({count * block_size // (1024*1024)}MB / {total_size // (1024*1024)}MB)", flush=True)

    urllib.request.urlretrieve(MYSQL_URL, ZIP_PATH, reporthook=report)
    log("Download completed successfully.")

def extract_mysql():
    if os.path.exists(os.path.join(EXTRACT_DIR, "bin", "mysqld.exe")):
        log(f"MySQL already extracted at {EXTRACT_DIR}")
        return

    log("Extracting MySQL zip archive (this may take 20-40 seconds)...")
    with zipfile.ZipFile(ZIP_PATH, 'r') as zip_ref:
        zip_ref.extractall(BASE_DIR)
    log("Extraction complete.")

def create_config():
    os.makedirs(DATA_DIR, exist_ok=True)
    base_posix = EXTRACT_DIR.replace("\\", "/")
    data_posix = DATA_DIR.replace("\\", "/")
    
    config_content = f"""[mysqld]
basedir = "{base_posix}"
datadir = "{data_posix}"
port = 3306
bind-address = 127.0.0.1
max_connections = 100
default_storage_engine = InnoDB
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Logging
log-error = "{data_posix}/mysqld.log"

[client]
port = 3306
default-character-set = utf8mb4
"""
    with open(INI_PATH, "w", encoding="utf-8") as f:
        f.write(config_content)
    log(f"Config file written at {INI_PATH}")

def initialize_database():
    bin_mysqld = os.path.join(EXTRACT_DIR, "bin", "mysqld.exe")
    if not os.path.exists(bin_mysqld):
        raise FileNotFoundError(f"Cannot find mysqld at {bin_mysqld}")

    # Check if already initialized (mysql dir exists in data dir)
    if os.path.exists(os.path.join(DATA_DIR, "mysql")):
        log("Database already initialized.")
        return

    log("Initializing MySQL data directory (insecure root mode)...")
    cmd = [
        bin_mysqld,
        f"--defaults-file={INI_PATH}",
        "--initialize-insecure",
        f"--basedir={EXTRACT_DIR}",
        f"--datadir={DATA_DIR}",
        "--console"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        log(f"Initialize output: {res.stdout}\nError: {res.stderr}")
        raise RuntimeError(f"Failed to initialize database: {res.stderr}")
    log("Database successfully initialized.")

def start_server():
    bin_mysqld = os.path.join(EXTRACT_DIR, "bin", "mysqld.exe")
    cmd = [
        bin_mysqld,
        f"--defaults-file={INI_PATH}",
        "--console"
    ]
    log("Starting MySQL 8.4 Server daemon...")
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    # Wait for server to be responsive
    time.sleep(3)
    log(f"MySQL process started with PID {proc.pid}")
    return proc

if __name__ == "__main__":
    download_mysql()
    extract_mysql()
    create_config()
    initialize_database()
    log("MySQL 8.4 LTS setup ready to launch.")

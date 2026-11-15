@echo off
title Swift Route Logistics Manager - Starter
echo =====================================================================
echo  Swift Route Logistics Manager
echo  21CSC205P Database Management Systems - SRMIST
echo  Student: Krishang Gupta (RA2411026010810) ^| Guide: Dr. Amit Kukker
echo =====================================================================
echo.

cd /d "D:\DBMS"

echo [1/3] Starting MySQL 8.4 LTS Server...
start "MySQL 8.4 Server" /min "D:\DBMS\mysql_server\mysql-8.4.4-winx64\bin\mysqld.exe" --defaults-file="D:\DBMS\mysql_server\my.ini" --console
timeout /t 3 >nul

echo [2/3] Verifying and Initializing Database Schema...
python database\init_db.py

echo [3/3] Launching FastAPI Backend on http://127.0.0.1:8000 ...
start "FastAPI Server" python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --app-dir "D:\DBMS\backend" --reload

timeout /t 2 >nul
echo.
echo =====================================================================
echo  System is running successfully!
echo   * Web Dashboard:    http://127.0.0.1:8000
echo   * Swagger UI Docs:  http://127.0.0.1:8000/docs
echo   * ReDoc API Docs:   http://127.0.0.1:8000/redoc
echo.
echo  Default Credentials:
echo   - Admin:      admin      / admin123
echo   - Dispatcher: dispatcher / dispatcher123
echo   - Viewer:     viewer     / viewer123
echo =====================================================================
pause

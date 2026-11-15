# =====================================================================
# Swift Route Logistics Manager - PowerShell Starter
# 21CSC205P Database Management Systems - SRMIST
# =====================================================================

$projectRoot = "D:\DBMS"
Set-Location $projectRoot

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host " Swift Route Logistics Manager - Starting Services" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan

# 1. Start MySQL Server
$mysqldPath = "D:\DBMS\mysql_server\mysql-8.4.4-winx64\bin\mysqld.exe"
$iniPath = "D:\DBMS\mysql_server\my.ini"

if (Test-Path $mysqldPath) {
    Write-Host "[1/3] Starting MySQL 8.4 LTS Server..." -ForegroundColor Yellow
    Start-Process -FilePath $mysqldPath -ArgumentList "--defaults-file=`"$iniPath`"", "--console" -WindowStyle Minimized
    Start-Sleep -Seconds 3
} else {
    Write-Host "[!] Note: Portable MySQL not found at $mysqldPath, relying on existing MySQL service on port 3306." -ForegroundColor Yellow
}

# 2. Run Database Initializer
Write-Host "[2/3] Initializing Database & Executing Migrations..." -ForegroundColor Yellow
python database\init_db.py

# 3. Launch FastAPI Backend
Write-Host "[3/3] Launching FastAPI Backend on http://127.0.0.1:8000 ..." -ForegroundColor Green
Start-Process -FilePath "python" -ArgumentList "-m uvicorn app.main:app --host 127.0.0.1 --port 8000 --app-dir D:\DBMS\backend --reload"

Start-Sleep -Seconds 2
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host " Services Successfully Started!" -ForegroundColor Green
Write-Host "  * Logistics Portal:  http://127.0.0.1:8000" -ForegroundColor White
Write-Host "  * Swagger UI:        http://127.0.0.1:8000/docs" -ForegroundColor White
Write-Host "  * ReDoc Docs:        http://127.0.0.1:8000/redoc" -ForegroundColor White
Write-Host ""
Write-Host " Default Logins: admin/admin123, dispatcher/dispatcher123, viewer/viewer123" -ForegroundColor Gray
Write-Host "=====================================================================" -ForegroundColor Cyan

Start-Process "http://127.0.0.1:8000"

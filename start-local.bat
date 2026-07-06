@echo off
echo ============================
echo 🚖 TOTEEL LOCAL SYSTEM START
echo ============================

cd backend
npm install
start cmd /k node server.js

cd ..

echo ============================
echo ✅ BACKEND IS RUNNING
echo ============================
pause
@echo off
cd /d %~dp0

echo =========================
echo 🚖 STARTING TOTEEL SYSTEM
echo =========================

cd backend
npm install
node server.js

pause
@echo off
cd /d "%~dp0"
start "AzerMind bridge" cmd /k node supervisor.js

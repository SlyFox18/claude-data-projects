@echo off
echo Regenerating Service Time Sheet Templates...
echo.
python "%~dp0generate_templates.py"
echo.
pause

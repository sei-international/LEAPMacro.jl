if "%~1" neq "_start_" (
  cd build
  cmd /c "%~f0" _start_ < nul
  cd ..
  exit /b
)
REM shift /1
python -m http.server 8080

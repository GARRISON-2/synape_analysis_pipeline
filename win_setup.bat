@echo off

echo ============================================
echo   Synapse Analysis Pipeline - Setup
echo ============================================
echo.

:: --------------------------------------------------
:: Check for Conda
:: --------------------------------------------------

where conda >nul 2>&1
set CONDA_FOUND=%errorlevel%

if %CONDA_FOUND% equ 0 goto CONDA_EXISTS
goto CONDA_MISSING

:CONDA_MISSING
echo Conda not found. Downloading Miniconda installer...
echo.

:: detect architecture
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" goto ARCH_64
echo ERROR: Unsupported Windows architecture: %PROCESSOR_ARCHITECTURE%
pause
exit /b 1

:ARCH_64
echo Detected 64-bit Windows
set MINICONDA_URL=https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe

:: download miniconda using PowerShell
echo Downloading Miniconda...
powershell -Command "Invoke-WebRequest -Uri '%MINICONDA_URL%' -OutFile 'Miniconda3-installer.exe'"

if not exist Miniconda3-installer.exe goto DOWNLOAD_FAILED

:: run installer silently
echo Installing Miniconda...
start /wait Miniconda3-installer.exe /S /D=%USERPROFILE%\miniconda3
del Miniconda3-installer.exe

:: add conda to path for this session
set PATH=%USERPROFILE%\miniconda3\Scripts;%USERPROFILE%\miniconda3;%PATH%

:: initialise conda for future sessions
call %USERPROFILE%\miniconda3\Scripts\conda.exe init cmd.exe
call %USERPROFILE%\miniconda3\Scripts\conda.exe init powershell

echo.
echo Miniconda installed successfully.
goto CREATE_ENV

:DOWNLOAD_FAILED
echo.
echo ERROR: Download failed. Please install Miniconda manually from:
echo https://docs.conda.io/en/latest/miniconda.html
echo Then re-run this script.
pause
exit /b 1

:CONDA_EXISTS
echo Conda found.
goto CREATE_ENV

:: --------------------------------------------------
:: Create environment from yml
:: --------------------------------------------------

:CREATE_ENV
echo.

:: extract environment name from yml file
for /f "tokens=*" %%i in ('powershell -Command "(Get-Content environment.yml | Select-String -Pattern '^name:').Line.Split(' ')[1]"') do set ENV_NAME=%%i

echo Environment name: %ENV_NAME%

:: check if environment already exists
conda env list | findstr /b "%ENV_NAME% " >nul 2>&1
set ENV_EXISTS=%errorlevel%

if %ENV_EXISTS% equ 0 goto UPDATE_ENV
goto CREATE_NEW_ENV

:UPDATE_ENV
echo Environment '%ENV_NAME%' already exists - updating...
call conda env update -f environment.yml --prune
goto ENV_DONE

:CREATE_NEW_ENV
echo Creating environment '%ENV_NAME%'...
call conda env create -f environment.yml

if %errorlevel% neq 0 goto ENV_FAILED
goto ENV_DONE

:ENV_FAILED
echo.
echo ERROR: Failed to create conda environment.
echo Please check your environment.yml file and try again.
pause
exit /b 1

:ENV_DONE
echo.

:: --------------------------------------------------
:: Done
:: --------------------------------------------------

echo ============================================
echo   Setup complete!
echo.
echo   To run the pipeline:
echo   1. Open a new Terminal window
echo   2. Run: conda activate %ENV_NAME%
echo   3. Run: python main.py
echo ============================================
echo.
pause
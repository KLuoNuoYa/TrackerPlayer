@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "REPO_ROOT=%%~fI"
set "VSWHERE=C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
set "CONFIGURATION=Release"
set "PLATFORM=both"

:parse_args
if "%~1"=="" goto after_parse
if /I "%~1"=="-Platform" (
  set "PLATFORM=%~2"
  shift
  shift
  goto parse_args
)
if /I "%~1"=="-Configuration" (
  set "CONFIGURATION=%~2"
  shift
  shift
  goto parse_args
)
if /I "%~1"=="-VsWherePath" (
  set "VSWHERE=%~2"
  shift
  shift
  goto parse_args
)
echo Unknown argument: %~1
exit /b 1

:after_parse
if /I not "%PLATFORM%"=="x86" if /I not "%PLATFORM%"=="x64" if /I not "%PLATFORM%"=="both" (
  echo Unsupported platform: %PLATFORM%
  exit /b 1
)

if not exist "%VSWHERE%" (
  echo vswhere.exe was not found at "%VSWHERE%"
  exit /b 1
)

for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.Component.MSBuild -property installationPath`) do set "VSINSTALL=%%I"
if not defined VSINSTALL (
  echo Failed to locate a Visual Studio installation.
  exit /b 1
)

set "MSBUILD=%VSINSTALL%\MSBuild\Current\Bin\MSBuild.exe"
set "DEVENV=%VSINSTALL%\Common7\IDE\devenv.com"
set "VSDEVCMD=%VSINSTALL%\Common7\Tools\VsDevCmd.bat"

if not exist "%MSBUILD%" (
  echo MSBuild.exe was not found at "%MSBUILD%"
  exit /b 1
)
if not exist "%DEVENV%" (
  echo devenv.com was not found at "%DEVENV%"
  exit /b 1
)
if not exist "%VSDEVCMD%" (
  echo VsDevCmd.bat was not found at "%VSDEVCMD%"
  exit /b 1
)

if not exist "%REPO_ROOT%\TrackerPlayback\ThirdParty\openmpt\build\vs2022win10\libopenmpt-small.sln" (
  echo OpenMPT submodule is not ready. Run:
  echo   git submodule update --init --recursive
  exit /b 1
)

if /I "%PLATFORM%"=="x86" (
  call :build_one x86
  exit /b %ERRORLEVEL%
)
if /I "%PLATFORM%"=="x64" (
  call :build_one x64
  exit /b %ERRORLEVEL%
)

call :build_one x86 || exit /b %ERRORLEVEL%
call :build_one x64 || exit /b %ERRORLEVEL%
echo Inno-ready packages are available in "%REPO_ROOT%\artifacts\inno"
exit /b 0

:build_one
set "ARCH=%~1"
if /I "%ARCH%"=="x64" (
  set "OPENMPT_PLATFORM=x64"
  set "PROJECT_PLATFORM=x64"
  set "LIB_SUBDIR=x86_64"
  set "HOST_ARCH=x64"
) else (
  set "OPENMPT_PLATFORM=Win32"
  set "PROJECT_PLATFORM=Win32"
  set "LIB_SUBDIR=x86"
  set "HOST_ARCH=x86"
)

echo == Building dependencies for %ARCH% ==
call "%VSDEVCMD%" -no_logo -arch=%HOST_ARCH% -host_arch=x64 >nul || exit /b 1

call :run_msbuild "%REPO_ROOT%\TrackerPlayback\ThirdParty\openmpt\build\vs2022win10\libopenmpt-small.sln" Build "-p:Configuration=%CONFIGURATION% -p:Platform=%OPENMPT_PLATFORM% -p:WindowsTargetPlatformVersion=10.0 -p:UseMultiToolTask=false -p:TrackFileAccess=false -p:SpectreMitigation="
if errorlevel 1 (
  echo MSBuild failed. Falling back to devenv.com...
  call :run_devenv "%REPO_ROOT%\TrackerPlayback\ThirdParty\openmpt\build\vs2022win10\libopenmpt-small.sln" "libopenmpt-small" "%OPENMPT_PLATFORM%" || exit /b 1
)

call :run_msbuild "%REPO_ROOT%\TrackerPlayback\ThirdParty\openmpt\build\vs2022win10\libopenmpt.sln" portaudio "-p:Configuration=%CONFIGURATION% -p:Platform=%OPENMPT_PLATFORM% -p:WindowsTargetPlatformVersion=10.0 -p:UseMultiToolTask=false -p:TrackFileAccess=false -p:SpectreMitigation="
if errorlevel 1 (
  echo MSBuild failed. Falling back to devenv.com...
  call :run_devenv "%REPO_ROOT%\TrackerPlayback\ThirdParty\openmpt\build\vs2022win10\libopenmpt.sln" "portaudio" "%OPENMPT_PLATFORM%" || exit /b 1
)

call :assert_libs "%ARCH%" || exit /b 1

echo == Building TrackerPlayback for %ARCH% ==
call :run_msbuild "%REPO_ROOT%\TrackerPlayback\TrackerPlayback.vcxproj" Build "-p:Configuration=%CONFIGURATION% -p:Platform=%PROJECT_PLATFORM% -p:SolutionDir=%REPO_ROOT%\ -p:WindowsTargetPlatformVersion=10.0 -p:UseMultiToolTask=false -p:TrackFileAccess=false -p:SpectreMitigation="
if errorlevel 1 (
  echo MSBuild failed. Falling back to devenv.com...
  call :run_devenv "%REPO_ROOT%\TrackerPlayback\TrackerPlayback.vcxproj" "" "%PROJECT_PLATFORM%" || exit /b 1
)

call :package_one "%ARCH%" || exit /b 1
exit /b 0

:run_msbuild
set "BUILD_FILE=%~1"
set "BUILD_TARGET=%~2"
set "BUILD_ARGS=%~3"
"%MSBUILD%" "%BUILD_FILE%" -m:1 -nr:false -t:%BUILD_TARGET% %BUILD_ARGS%
exit /b %ERRORLEVEL%

:run_devenv
set "BUILD_FILE=%~1"
set "BUILD_PROJECT=%~2"
set "BUILD_PLATFORM=%~3"
if defined BUILD_PROJECT (
  "%DEVENV%" "%BUILD_FILE%" /Build "%CONFIGURATION%|%BUILD_PLATFORM%" /Project "%BUILD_PROJECT%" /useenv
) else (
  "%DEVENV%" "%BUILD_FILE%" /Build "%CONFIGURATION%|%BUILD_PLATFORM%" /useenv
)
exit /b %ERRORLEVEL%

:assert_libs
set "CHECK_ARCH=%~1"
if /I "%CHECK_ARCH%"=="x64" (
  set "CHECK_DIR=%REPO_ROOT%\TrackerPlayback\ThirdParty\openmpt\build\lib\vs2022win10\x86_64\%CONFIGURATION%"
) else (
  set "CHECK_DIR=%REPO_ROOT%\TrackerPlayback\ThirdParty\openmpt\build\lib\vs2022win10\x86\%CONFIGURATION%"
)

set "MISSING="
for %%L in (libopenmpt-small.lib openmpt-minimp3.lib openmpt-miniz.lib openmpt-stb_vorbis.lib openmpt-portaudio.lib) do (
  if not exist "%CHECK_DIR%\%%L" set "MISSING=!MISSING! %%L"
)
if defined MISSING (
  echo OpenMPT dependency build for %CHECK_ARCH% did not produce:%MISSING%
  echo Checked directory: "%CHECK_DIR%"
  exit /b 1
)
exit /b 0

:package_one
set "PKG_ARCH=%~1"
set "OUTPUT_DIR=%REPO_ROOT%\%PKG_ARCH%\%CONFIGURATION%"
set "ARTIFACT_ROOT=%REPO_ROOT%\artifacts\inno"
set "ARTIFACT_DIR=%ARTIFACT_ROOT%\%PKG_ARCH%"
set "ZIP_PATH=%ARTIFACT_ROOT%\TrackerPlayback-Inno-%PKG_ARCH%.zip"

if not exist "%OUTPUT_DIR%\TrackerPlayback.dll" (
  echo Expected build output was not found: "%OUTPUT_DIR%\TrackerPlayback.dll"
  exit /b 1
)
if not exist "%OUTPUT_DIR%\TrackerPlayback.lib" (
  echo Expected build output was not found: "%OUTPUT_DIR%\TrackerPlayback.lib"
  exit /b 1
)

if not exist "%ARTIFACT_ROOT%" mkdir "%ARTIFACT_ROOT%"
if exist "%ARTIFACT_DIR%" rmdir /s /q "%ARTIFACT_DIR%"
mkdir "%ARTIFACT_DIR%" || exit /b 1

copy /y "%OUTPUT_DIR%\TrackerPlayback.dll" "%ARTIFACT_DIR%\" >nul || exit /b 1
copy /y "%OUTPUT_DIR%\TrackerPlayback.lib" "%ARTIFACT_DIR%\" >nul || exit /b 1
if exist "%OUTPUT_DIR%\TrackerPlayback.exp" copy /y "%OUTPUT_DIR%\TrackerPlayback.exp" "%ARTIFACT_DIR%\" >nul
if exist "%OUTPUT_DIR%\TrackerPlayback.pdb" copy /y "%OUTPUT_DIR%\TrackerPlayback.pdb" "%ARTIFACT_DIR%\" >nul
copy /y "%REPO_ROOT%\InnoSetupTrackerPlayback.iss.inc" "%ARTIFACT_DIR%\" >nul || exit /b 1
copy /y "%REPO_ROOT%\InnoSetupExample.iss" "%ARTIFACT_DIR%\" >nul || exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "if (Test-Path '%ZIP_PATH%') { Remove-Item '%ZIP_PATH%' -Force }; Compress-Archive -Path '%ARTIFACT_DIR%\*' -DestinationPath '%ZIP_PATH%' -Force" >nul

echo Packaged %PKG_ARCH% artifacts to "%ZIP_PATH%"
exit /b 0

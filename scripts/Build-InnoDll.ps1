param(
    [ValidateSet('x86', 'x64', 'both')]
    [string]$Platform = 'both',
    [ValidateSet('Release', 'Debug')]
    [string]$Configuration = 'Release',
    [string]$VsWherePath = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe',
    [ValidateSet('auto', 'msbuild', 'devenv')]
    [string]$BuildEngine = 'auto',
    [switch]$SkipSubmoduleCheck
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$openMptRoot = Join-Path $repoRoot 'TrackerPlayback\ThirdParty\openmpt'
$openMptBuildRoot = Join-Path $openMptRoot 'build\vs2022win10'
$artifactsRoot = Join-Path $repoRoot 'artifacts\inno'
$declarationsFile = Join-Path $repoRoot 'InnoSetupTrackerPlayback.iss.inc'
$exampleScriptFile = Join-Path $repoRoot 'InnoSetupExample.iss'

function Get-RequestedPlatforms {
    param([string]$RequestedPlatform)

    switch ($RequestedPlatform) {
        'x86' { return @('x86') }
        'x64' { return @('x64') }
        default { return @('x86', 'x64') }
    }
}

function Get-PlatformSpec {
    param([string]$PlatformName)

    switch ($PlatformName) {
        'x86' {
            return @{
                Name = 'x86'
                OpenMptPlatform = 'Win32'
                ProjectPlatform = 'Win32'
                OutputDir = Join-Path $repoRoot 'x86\Release'
                ArtifactDir = Join-Path $artifactsRoot 'x86'
            }
        }
        'x64' {
            return @{
                Name = 'x64'
                OpenMptPlatform = 'x64'
                ProjectPlatform = 'x64'
                OutputDir = Join-Path $repoRoot 'x64\Release'
                ArtifactDir = Join-Path $artifactsRoot 'x64'
            }
        }
        default {
            throw "Unsupported platform: $PlatformName"
        }
    }
}

function Get-VisualStudioInstallation {
    param([string]$VsWhereExe)

    if (-not (Test-Path -LiteralPath $VsWhereExe)) {
        throw "vswhere.exe was not found at '$VsWhereExe'."
    }

    $json = & $VsWhereExe -latest -products * -requires Microsoft.Component.MSBuild -format json
    if (-not $json) {
        throw 'vswhere.exe did not return a Visual Studio installation.'
    }

    $instances = $json | ConvertFrom-Json
    if (-not $instances -or $instances.Count -eq 0) {
        throw 'No Visual Studio installation with MSBuild was found.'
    }

    $installation = $instances[0]
    $msbuildPath = Join-Path $installation.installationPath 'MSBuild\Current\Bin\MSBuild.exe'
    $devenvPath = Join-Path $installation.installationPath 'Common7\IDE\devenv.com'
    $vsDevCmdPath = Join-Path $installation.installationPath 'Common7\Tools\VsDevCmd.bat'
    if (-not (Test-Path -LiteralPath $msbuildPath)) {
        throw "MSBuild.exe was not found at '$msbuildPath'."
    }
    if (-not (Test-Path -LiteralPath $devenvPath)) {
        throw "devenv.com was not found at '$devenvPath'."
    }
    if (-not (Test-Path -LiteralPath $vsDevCmdPath)) {
        throw "VsDevCmd.bat was not found at '$vsDevCmdPath'."
    }

    return @{
        InstallationPath = $installation.installationPath
        MsBuildPath = $msbuildPath
        DevenvPath = $devenvPath
        VsDevCmdPath = $vsDevCmdPath
    }
}

function Test-OpenMptReady {
    $requiredPaths = @(
        (Join-Path $openMptRoot 'libopenmpt'),
        (Join-Path $openMptRoot 'include\portaudio\include'),
        (Join-Path $openMptBuildRoot 'libopenmpt-small.sln'),
        (Join-Path $openMptBuildRoot 'libopenmpt.sln')
    )

    foreach ($path in $requiredPaths) {
        if (-not (Test-Path -LiteralPath $path)) {
            return $false
        }
    }

    return $true
}

function Invoke-ExternalProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$Arguments,
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $null = $psi.EnvironmentVariables
    $psi.EnvironmentVariables.Clear()

    foreach ($entry in [System.Environment]::GetEnvironmentVariables('Machine').GetEnumerator()) {
        $psi.EnvironmentVariables[[string]$entry.Key] = [string]$entry.Value
    }
    foreach ($entry in [System.Environment]::GetEnvironmentVariables('User').GetEnumerator()) {
        $psi.EnvironmentVariables[[string]$entry.Key] = [string]$entry.Value
    }

    if ($env:PATH) {
        $psi.EnvironmentVariables['Path'] = $env:PATH
    } elseif ($env:Path) {
        $psi.EnvironmentVariables['Path'] = $env:Path
    }

    if (-not $psi.EnvironmentVariables['TEMP']) {
        $psi.EnvironmentVariables['TEMP'] = [System.IO.Path]::GetTempPath()
    }
    if (-not $psi.EnvironmentVariables['TMP']) {
        $psi.EnvironmentVariables['TMP'] = $psi.EnvironmentVariables['TEMP']
    }

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($stdout) {
        Write-Host $stdout.TrimEnd()
    }
    if ($stderr) {
        Write-Host $stderr.TrimEnd()
    }

    if ($process.ExitCode -ne 0) {
        throw "Command failed with exit code $($process.ExitCode): `"$FilePath`" $Arguments"
    }
}

function Invoke-MsBuildStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MsBuildPath,
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $true)]
        [string[]]$Properties,
        [string]$Targets = 'Build'
    )

    $propertyArgs = @()
    foreach ($property in $Properties) {
        $propertyArgs += "-p:$property"
    }

    $arguments = @(
        ('"{0}"' -f $ProjectPath),
        '-m:1',
        ('-t:{0}' -f $Targets),
        '-nr:false',
        '-p:UseMultiToolTask=false',
        '-p:TrackFileAccess=false',
        '-p:SpectreMitigation='
    ) + $propertyArgs

    Invoke-ExternalProcess -FilePath $MsBuildPath -Arguments ($arguments -join ' ') -WorkingDirectory $repoRoot
}

function Should-FallbackToDevenv {
    param([System.Exception]$Exception)

    if (-not $Exception) {
        return $false
    }

    $message = $Exception.ToString()
    return (
        $message -match 'FileLoadException' -or
        $message -match '0xe0434352' -or
        $message -match 'exit code -532462766' -or
        $message -match 'MSBuild\.exe'
    )
}

function Invoke-DevenvStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DevenvPath,
        [Parameter(Mandatory = $true)]
        [string]$VsDevCmdPath,
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $true)]
        [hashtable]$PlatformSpec,
        [string]$ProjectName
    )

    $arch = if ($PlatformSpec.Name -eq 'x64') { 'x64' } else { 'x86' }
    $args = @(
        "/Build `"$Configuration|$($PlatformSpec.ProjectPlatform)`""
    )
    if ($ProjectName) {
        $args += "/Project `"$ProjectName`""
    }

    $command = @(
        "call `"$VsDevCmdPath`" -no_logo -arch=$arch -host_arch=x64 >nul",
        "`"$DevenvPath`" `"$ProjectPath`" $($args -join ' ')"
    ) -join ' && '

    Invoke-ExternalProcess -FilePath 'cmd.exe' -Arguments ("/d /c `"$command`"") -WorkingDirectory $repoRoot
}

function Invoke-BuildStep {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$VisualStudio,
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $true)]
        [hashtable]$PlatformSpec,
        [string[]]$Properties = @(),
        [string]$Targets = 'Build',
        [string]$DevenvProjectName
    )

    if ($BuildEngine -eq 'devenv') {
        Invoke-DevenvStep -DevenvPath $VisualStudio.DevenvPath `
            -VsDevCmdPath $VisualStudio.VsDevCmdPath `
            -ProjectPath $ProjectPath `
            -PlatformSpec $PlatformSpec `
            -ProjectName $DevenvProjectName
        return
    }

    if ($BuildEngine -eq 'msbuild') {
        Invoke-MsBuildStep -MsBuildPath $VisualStudio.MsBuildPath `
            -ProjectPath $ProjectPath `
            -Properties $Properties `
            -Targets $Targets
        return
    }

    try {
        Invoke-MsBuildStep -MsBuildPath $VisualStudio.MsBuildPath `
            -ProjectPath $ProjectPath `
            -Properties $Properties `
            -Targets $Targets
    } catch {
        if (-not (Should-FallbackToDevenv -Exception $_.Exception)) {
            throw
        }

        Write-Host 'MSBuild failed with a host/runtime error. Falling back to devenv.com...'
        Invoke-DevenvStep -DevenvPath $VisualStudio.DevenvPath `
            -VsDevCmdPath $VisualStudio.VsDevCmdPath `
            -ProjectPath $ProjectPath `
            -PlatformSpec $PlatformSpec `
            -ProjectName $DevenvProjectName
    }
}

function New-ArtifactPackage {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$PlatformSpec
    )

    $artifactDir = $PlatformSpec.ArtifactDir
    $outputDir = $PlatformSpec.OutputDir
    $zipPath = Join-Path $artifactsRoot ("TrackerPlayback-Inno-{0}.zip" -f $PlatformSpec.Name)

    if (Test-Path -LiteralPath $artifactDir) {
        Remove-Item -LiteralPath $artifactDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $artifactDir | Out-Null

    $filesToCopy = @(
        'TrackerPlayback.dll',
        'TrackerPlayback.lib'
    )

    foreach ($name in $filesToCopy) {
        $sourcePath = Join-Path $outputDir $name
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            throw "Expected build output was not found: $sourcePath"
        }
        Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $artifactDir $name) -Force
    }

    $optionalFiles = @(
        'TrackerPlayback.exp',
        'TrackerPlayback.pdb'
    )
    foreach ($name in $optionalFiles) {
        $sourcePath = Join-Path $outputDir $name
        if (Test-Path -LiteralPath $sourcePath) {
            Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $artifactDir $name) -Force
        }
    }

    Copy-Item -LiteralPath $declarationsFile -Destination (Join-Path $artifactDir (Split-Path -Leaf $declarationsFile)) -Force
    Copy-Item -LiteralPath $exampleScriptFile -Destination (Join-Path $artifactDir (Split-Path -Leaf $exampleScriptFile)) -Force

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $artifactDir '*') -DestinationPath $zipPath -Force

    Write-Host ("Packaged {0} artifacts to {1}" -f $PlatformSpec.Name, $zipPath)
}

function Assert-OpenMptLibrariesPresent {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$PlatformSpec
    )

    $libraryDir = Join-Path $openMptRoot ("build\lib\vs2022win10\{0}\{1}" -f `
        ($(if ($PlatformSpec.Name -eq 'x64') { 'x86_64' } else { 'x86' })), `
        $Configuration)

    $requiredLibraries = @(
        'libopenmpt-small.lib',
        'openmpt-minimp3.lib',
        'openmpt-miniz.lib',
        'openmpt-stb_vorbis.lib',
        'openmpt-portaudio.lib'
    )

    $missing = @()
    foreach ($name in $requiredLibraries) {
        if (-not (Test-Path -LiteralPath (Join-Path $libraryDir $name))) {
            $missing += $name
        }
    }

    if ($missing.Count -gt 0) {
        throw ("OpenMPT dependency build for {0} did not produce: {1}. Checked: {2}" -f `
            $PlatformSpec.Name,
            ($missing -join ', '),
            $libraryDir)
    }
}

if (-not $SkipSubmoduleCheck -and -not (Test-OpenMptReady)) {
    throw "OpenMPT is not ready. Run 'git submodule update --init --recursive' first."
}

$vs = Get-VisualStudioInstallation -VsWhereExe $VsWherePath
$platforms = Get-RequestedPlatforms -RequestedPlatform $Platform

foreach ($platformName in $platforms) {
    $spec = Get-PlatformSpec -PlatformName $platformName

    Write-Host ("== Building dependencies for {0} ==" -f $spec.Name)
    Invoke-BuildStep -VisualStudio $vs `
        -ProjectPath (Join-Path $openMptBuildRoot 'libopenmpt-small.sln') `
        -PlatformSpec $spec `
        -DevenvProjectName 'libopenmpt-small' `
        -Targets 'Build' `
        -Properties @(
            "Configuration=$Configuration",
            "Platform=$($spec.OpenMptPlatform)",
            'WindowsTargetPlatformVersion=10.0'
        )

    Invoke-BuildStep -VisualStudio $vs `
        -ProjectPath (Join-Path $openMptBuildRoot 'libopenmpt.sln') `
        -PlatformSpec $spec `
        -DevenvProjectName 'portaudio' `
        -Targets 'portaudio' `
        -Properties @(
            "Configuration=$Configuration",
            "Platform=$($spec.OpenMptPlatform)",
            'WindowsTargetPlatformVersion=10.0'
        )

    Assert-OpenMptLibrariesPresent -PlatformSpec $spec

    Write-Host ("== Building TrackerPlayback for {0} ==" -f $spec.Name)
    Invoke-BuildStep -VisualStudio $vs `
        -ProjectPath (Join-Path $repoRoot 'TrackerPlayback\TrackerPlayback.vcxproj') `
        -PlatformSpec $spec `
        -Targets 'Build' `
        -Properties @(
            "Configuration=$Configuration",
            "Platform=$($spec.ProjectPlatform)",
            ("SolutionDir={0}\" -f $repoRoot),
            'WindowsTargetPlatformVersion=10.0'
        )

    New-ArtifactPackage -PlatformSpec $spec
}

Write-Host ("Inno-ready packages are available in {0}" -f $artifactsRoot)

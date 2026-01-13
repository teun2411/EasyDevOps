<#
install-easydevops.ps1
Doel (Week 3 tooling):
1) Installeert .NET SDK 8
2) Installeert Git
3) Clonet jouw EasyDevOps repo
4) Start de .NET frontend

Gebruik:
- Open PowerShell als Administrator
- Run:
  Set-ExecutionPolicy Bypass -Scope Process -Force
  .\install-easydevops.ps1 -RepoUrl "https://github.com/<jouw-username>/EasyDevOps.git"

Optioneel:
  -InstallDir "C:\EasyDevOps" -AppPort 5000
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$RepoUrl,

  [string]$InstallDir = "C:\EasyDevOps",

  [int]$AppPort = 5000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step($msg) {
  Write-Host ""
  Write-Host "==> $msg" -ForegroundColor Cyan
}

function Assert-IsAdmin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

  if (-not $isAdmin) {
    throw "Run PowerShell als Administrator."
  }
}

function Test-CommandExists($cmd) {
  return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Ensure-Winget {
  if (-not (Test-CommandExists "winget")) {
    throw "winget is niet beschikbaar. Installeer 'App Installer' via Microsoft Store of gebruik Windows 10/11 met winget."
  }
}

function Install-DotNet8 {
  Write-Step ".NET SDK 8 installeren (via winget) - indien nodig"

  if (Test-CommandExists "dotnet") {
    $v = (& dotnet --version) 2>$null
    if ($v -match '^8\.') {
      Write-Host ".NET SDK 8 is al geïnstalleerd: $v" -ForegroundColor Green
      return
    }
    Write-Host "dotnet is aanwezig maar niet versie 8 (gevonden: $v). We installeren SDK 8 erbij." -ForegroundColor Yellow
  }

  # Microsoft .NET SDK 8
  # --accept-package-agreements/--accept-source-agreements voorkomt prompts
  winget install --id Microsoft.DotNet.SDK.8 --source winget --accept-package-agreements --accept-source-agreements -e

  if (-not (Test-CommandExists "dotnet")) { throw ".NET installatie lijkt mislukt: dotnet commando niet gevonden." }

  $v2 = (& dotnet --version) 2>$null
  if ($v2 -notmatch '^8\.') {
    Write-Host "Let op: dotnet versie is $v2 (verwacht 8.x). Controleer of SDK 8 correct is geïnstalleerd." -ForegroundColor Yellow
  } else {
    Write-Host ".NET SDK OK: $v2" -ForegroundColor Green
  }
}

function Install-Git {
  Write-Step "Git installeren (via winget) - indien nodig"

  if (Test-CommandExists "git") {
    $gv = (& git --version) 2>$null
    Write-Host "Git is al geïnstalleerd: $gv" -ForegroundColor Green
    return
  }

  # Git for Windows
  winget install --id Git.Git --source winget --accept-package-agreements --accept-source-agreements -e

  # PATH kan in dezelfde sessie nog niet direct bijgewerkt zijn; probeer opnieuw laden
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

  if (-not (Test-CommandExists "git")) { throw "Git installatie lijkt mislukt: git commando niet gevonden." }

  $gv2 = (& git --version) 2>$null
  Write-Host "Git OK: $gv2" -ForegroundColor Green
}

function Prepare-InstallDir {
  Write-Step "Installatiemap voorbereiden: $InstallDir"

  if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
    Write-Host "Map aangemaakt: $InstallDir" -ForegroundColor Green
  } else {
    Write-Host "Map bestaat al: $InstallDir" -ForegroundColor Yellow
  }
}

function Get-RepoFolderName {
  # Haal naam uit URL, bv. https://github.com/user/EasyDevOps.git -> EasyDevOps
  $name = ($RepoUrl.TrimEnd("/") -split "/")[-1]
  $name = $name -replace '\.git$',''
  if ([string]::IsNullOrWhiteSpace($name)) { throw "Kan repo naam niet bepalen uit RepoUrl: $RepoUrl" }
  return $name
}

function Clone-Repo {
  Write-Step "Repository clonen"

  $repoName = Get-RepoFolderName
  $targetPath = Join-Path $InstallDir $repoName

  if (Test-Path $targetPath) {
    Write-Host "Repo map bestaat al: $targetPath" -ForegroundColor Yellow
    Write-Host "We doen: git pull (main) in plaats van opnieuw clonen." -ForegroundColor Yellow

    Push-Location $targetPath
    try {
      # Zorg dat we op main zitten
      & git fetch --all
      & git checkout main
      & git pull
    } finally {
      Pop-Location
    }
  } else {
    Push-Location $InstallDir
    try {
      & git clone $RepoUrl
    } finally {
      Pop-Location
    }
  }

  if (-not (Test-Path $targetPath)) { throw "Clone/pull mislukt. Repo map niet gevonden: $targetPath" }
  Write-Host "Repo klaar: $targetPath" -ForegroundColor Green
  return $targetPath
}

function Find-FrontendProject {
  param([Parameter(Mandatory=$true)][string]$RepoPath)

  # Verwacht: repo\frontend\EasyDevOps.Frontend\EasyDevOps.Frontend.csproj
  $frontendRoot = Join-Path $RepoPath "frontend"

  if (-not (Test-Path $frontendRoot)) {
    throw "Frontend map niet gevonden: $frontendRoot. Controleer je repo structuur."
  }

  $csproj = Get-ChildItem -Path $frontendRoot -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1

  if (-not $csproj) {
    throw "Geen .csproj gevonden onder: $frontendRoot. Heb je de .NET frontend al gecommit?"
  }

  return $csproj.FullName
}

function Start-Frontend {
  param(
    [Parameter(Mandatory=$true)][string]$CsprojPath
  )

  Write-Step "Frontend bouwen en starten"

  $projDir = Split-Path -Parent $CsprojPath

  Push-Location $projDir
  try {
    Write-Host "Project: $CsprojPath"
    Write-Host "Restore..." -ForegroundColor DarkGray
    & dotnet restore

    Write-Host "Build..." -ForegroundColor DarkGray
    & dotnet build -c Release

    # Stel poort in via ASPNETCORE_URLS
    $env:ASPNETCORE_URLS = "http://localhost:$AppPort"

    Write-Host ""
    Write-Host "✅ Frontend starten op http://localhost:$AppPort" -ForegroundColor Green
    Write-Host "Stoppen: druk in dit venster op CTRL+C" -ForegroundColor Yellow
    Write-Host ""

    & dotnet run
  } finally {
    Pop-Location
  }
}

# =========================
# Main
# =========================
Assert-IsAdmin
Ensure-Winget

Write-Step "Installatie EasyDevOps (Week 3) starten"
Write-Host "RepoUrl     : $RepoUrl"
Write-Host "InstallDir  : $InstallDir"
Write-Host "AppPort     : $AppPort"

Install-DotNet8
Install-Git
Prepare-InstallDir

$repoPath = Clone-Repo
$csprojPath = Find-FrontendProject -RepoPath $repoPath

Start-Frontend -CsprojPath $csprojPath

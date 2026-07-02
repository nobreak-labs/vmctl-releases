#Requires -Version 5.1
<#
vmctl Windows installer.

Usage:
  irm https://raw.githubusercontent.com/nobreak-labs/vmctl-releases/main/install.ps1 | iex

Pin a specific version, or override the source repo / install location:
  $script = irm https://raw.githubusercontent.com/nobreak-labs/vmctl-releases/main/install.ps1
  & ([scriptblock]::Create($script)) -Version 0.2.0
  & ([scriptblock]::Create($script)) -Repo "myorg/myrepo" -InstallDir "C:\tools\vmctl"
#>

param(
    # 바이너리를 받아올 GitHub 저장소 (release asset 보유)
    [string]$Repo = "nobreak-labs/vmctl-releases",
    # vmctl.exe를 설치할 디렉토리
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "vmctl"),
    # 설치할 버전 (release 태그) 또는 "latest"
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

$BinName  = "vmctl.exe"
$DestPath = Join-Path $InstallDir $BinName

function Get-Release {
    param([string]$Tag)
    $uri = if ($Tag -eq "latest") {
        "https://api.github.com/repos/$Repo/releases/latest"
    } else {
        "https://api.github.com/repos/$Repo/releases/tags/$Tag"
    }
    Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = "vmctl-installer" }
}

Write-Host "vmctl installer" -ForegroundColor Cyan

$release = Get-Release -Tag $Version
$tag = $release.tag_name
$asset = $release.assets | Where-Object { $_.name -like "vmctl-*-windows-amd64.exe" } | Select-Object -First 1

if (-not $asset) {
    Write-Error "No Windows asset found in release '$tag' of $Repo"
    exit 1
}

Write-Host "Version: $tag"
Write-Host "Downloading $($asset.name)..."

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$tmpPath = "$DestPath.download"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpPath -UseBasicParsing
Move-Item -Force $tmpPath $DestPath

# 웹에서 받은 파일은 Zone.Identifier(차단 표시)가 붙을 수 있으므로 해제
Unblock-File -Path $DestPath -ErrorAction SilentlyContinue

# 사용자 PATH에 설치 경로 추가 (관리자 권한 불필요)
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathEntries = @()
if ($userPath) { $pathEntries = $userPath -split ";" }
if ($pathEntries -notcontains $InstallDir) {
    $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added $InstallDir to your user PATH."
}

# 현재 세션 PATH도 갱신해 설치 직후 바로 사용 가능하게 함
if (($env:Path -split ";") -notcontains $InstallDir) {
    $env:Path = "$env:Path;$InstallDir"
}

Write-Host ""
Write-Host "vmctl $tag installed to $DestPath" -ForegroundColor Green
Write-Host "Run 'vmctl version' to verify. Open a new terminal if the command is not found yet."

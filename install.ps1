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

function Get-ReleaseTag {
    param([string]$Version)
    if ($Version -eq "latest") {
        # .NET WebRequest를 사용하여 리다이렉트된 최종 URL에서 태그명을 추출합니다.
        # 이 방법은 GitHub API Rate Limit를 발생시키지 않습니다.
        $url = "https://github.com/$Repo/releases/latest"
        $request = [System.Net.WebRequest]::Create($url)
        $request.Method = "HEAD"
        $request.AllowAutoRedirect = $true
        try {
            $response = $request.GetResponse()
            $tag = ($response.ResponseUri.OriginalString -split '/')[-1]
            $response.Close()
            return $tag
        } catch {
            Write-Error "Failed to fetch latest release version from $url"
            exit 1
        }
    } else {
        return $Version
    }
}

Write-Host "vmctl installer" -ForegroundColor Cyan

$tag = Get-ReleaseTag -Version $Version
$assetName = "vmctl-$tag-windows-amd64.exe"
$downloadUrl = "https://github.com/$Repo/releases/download/$tag/$assetName"

Write-Host "Version: $tag"
Write-Host "Downloading $assetName..."

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$tmpPath = "$DestPath.download"
Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpPath -UseBasicParsing
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

# `$PROFILE`에 `vmctl completion powershell`을 추가해 자동완성을 켜려면
# 실행 정책이 최소 RemoteSigned 이상이어야 스크립트가 로드된다.
# Restricted(기본값)면 새 셸을 열 때마다 `$PROFILE` 실행이 조용히 막히거나 오류가 난다.
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "Undefined") {
    Write-Host ""
    Write-Host "Note: PowerShell execution policy for CurrentUser is '$currentPolicy'." -ForegroundColor Yellow
    Write-Host "To enable shell completion via `$PROFILE (see README), run this once first:" -ForegroundColor Yellow
    Write-Host "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
}

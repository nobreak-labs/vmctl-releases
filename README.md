# vmctl-releases

`vmctl` 바이너리 배포 전용 저장소입니다. 소스코드는 비공개 저장소(`nobreak-labs/vmctl`)에
있고, 이 저장소에는 빌드된 바이너리(Releases)와 설치 스크립트만 미러링됩니다.

## 설치

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/nobreak-labs/vmctl-releases/main/install.ps1 | iex
```

**macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/nobreak-labs/vmctl-releases/main/install.sh | bash
```

버전/설치 경로를 바꾸려면 각 스크립트 상단의 사용법 주석을 참고하세요.

## Releases

빌드 산출물은 [Releases](https://github.com/nobreak-labs/vmctl-releases/releases) 탭에서
직접 받을 수도 있습니다:

- `vmctl-<version>-windows-amd64.exe`
- `vmctl-<version>-macos-amd64`
- `vmctl-<version>-macos-arm64`

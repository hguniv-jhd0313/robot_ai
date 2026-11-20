# 노트북 평가 환경 설치 (과제 4 실로봇 평가용, 임시 파일)
# 사용법: 저장소 폴더(robot_ai)에서 PowerShell을 열고
#   powershell -ExecutionPolicy Bypass -File laptop\setup.ps1
# GPU 드라이버가 오래되어 CPU로만 설치하려면 끝에 -Cpu 를 붙인다.
param([switch]$Cpu)
$ErrorActionPreference = "Continue"   # pip 경고(stderr) 때문에 멈추지 않도록, 실패는 종료 코드로 확인
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
function Step($m) { Write-Host "`n=== $m" -ForegroundColor Cyan }
function Check($what) { if ($LASTEXITCODE -ne 0) { Write-Host "실패: $what (위 메시지를 확인)" -ForegroundColor Red; exit 1 } }

# 1. Python 3.12
Step "Python 3.12 확인"
$hasPy = $false
try { py -3.12 --version; $hasPy = $? } catch {}
if (-not $hasPy) {
    winget install --id Python.Python.3.12 -e --silent --accept-source-agreements --accept-package-agreements
}

# 2. 가상환경
Step "가상환경 .venv 만들기"
if (-not (Test-Path ".venv\Scripts\python.exe")) { py -3.12 -m venv .venv; Check "가상환경 생성 (Python 3.12 설치 직후라면 새 PowerShell 창에서 다시 실행)" }
$py = Join-Path $repo ".venv\Scripts\python.exe"
& $py -m pip install -q --upgrade pip

# 3. PyTorch (GPU 드라이버 버전에 따라 선택)
Step "PyTorch 설치"
$driver = 0
try { $driver = [double]((nvidia-smi --query-gpu=driver_version --format=csv,noheader | Select-Object -First 1).Split(".")[0]) } catch {}
Write-Host "NVIDIA 드라이버 주 버전: $driver"
if (-not $Cpu -and $driver -ge 570) {
    & $py -m pip install "torch<2.12" "torchvision<0.27" --index-url https://download.pytorch.org/whl/cu128; Check "PyTorch 설치"
} elseif (-not $Cpu) {
    Write-Host "NVIDIA 드라이버가 570 미만이라 GPU(CUDA 12.8)를 쓸 수 없습니다." -ForegroundColor Yellow
    Write-Host "  -> NVIDIA 앱 또는 https://www.nvidia.com/Download/index.aspx 에서 드라이버를 업데이트한 뒤 다시 실행하세요." -ForegroundColor Yellow
    Write-Host "  -> GPU 없이 진행하려면: powershell -ExecutionPolicy Bypass -File laptop\setup.ps1 -Cpu" -ForegroundColor Yellow
    Write-Host "     (CPU에서는 Diffusion Policy DDPM 추론이 매우 느려 평가가 사실상 어렵습니다)" -ForegroundColor Yellow
    exit 1
} else {
    & $py -m pip install "torch<2.12" "torchvision<0.27" --index-url https://download.pytorch.org/whl/cpu; Check "PyTorch 설치"
}

# 4. LeRobot (평가에 필요한 부분만: 데이터셋 녹화, SO-101 모터, 키보드, Diffusion)
Step "LeRobot 0.6.0 설치"
& $py -m pip install "lerobot[dataset,hardware,feetech,diffusion]==0.6.0"; Check "LeRobot 설치"

# 5. FFmpeg 8 (torchcodec이 Windows에서 영상 읽을 때 필요)
Step "FFmpeg 8.1.2 설치"
$ff = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "avcodec-*.dll" -ErrorAction SilentlyContinue |
      Where-Object FullName -like "*ffmpeg-8*" | Select-Object -First 1
if (-not $ff) {
    winget install --id Gyan.FFmpeg.Shared -e --version 8.1.2 --silent --accept-source-agreements --accept-package-agreements
    $ff = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "avcodec-*.dll" | Where-Object FullName -like "*ffmpeg-8*" | Select-Object -First 1
}
$ffbin = $ff.DirectoryName
$u = [Environment]::GetEnvironmentVariable("Path", "User")
if ($u -notlike "*$ffbin*") { [Environment]::SetEnvironmentVariable("Path", "$u;$ffbin", "User") }

# 6. 확인
Step "설치 확인"
& $py -c "import torch; from importlib.metadata import version as v; print('lerobot', v('lerobot'), '| torch', torch.__version__, '| CUDA', torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else '')"

Step "Hugging Face 로그인 확인 (jhd0313 이어야 평가 데이터셋이 올라감)"
try { & "$repo\.venv\Scripts\hf.exe" auth whoami } catch {}
Write-Host "로그인이 안 되어 있으면: .venv\Scripts\hf.exe auth login" -ForegroundColor Yellow

Step "캘리브레이션 파일 확인"
$cal = Join-Path $env:USERPROFILE ".cache\huggingface\lerobot\calibration"
foreach ($f in @("robots\so101_follower\follower1.json", "teleoperators\so101_leader\leader1.json")) {
    $p = Join-Path $cal $f
    if (Test-Path $p) { Write-Host "있음: $p" -ForegroundColor Green }
    else { Write-Host "없음: $p" -ForegroundColor Yellow }
}
Write-Host "없으면 과제 1을 녹화한 PC의 같은 경로에서 복사해 오거나, laptop\README.md의 '캘리브레이션' 절차를 따른다."

Step "연결된 시리얼 포트 (로봇 USB를 꽂은 상태에서)"
& $py -m serial.tools.list_ports -v

Write-Host "`n설치 완료. 다음: laptop\README.md 의 2단계(포트·카메라 확인)" -ForegroundColor Green

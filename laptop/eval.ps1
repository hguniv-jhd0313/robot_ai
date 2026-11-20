# 과제 4 실로봇 평가 실행 (임시 파일)
# 사용 예 (저장소 폴더 robot_ai에서):
#   powershell -ExecutionPolicy Bypass -File laptop\eval.ps1 -Condition dp -Follower COM4 -Leader COM3 -Overhead 1 -Wrist 0
# Condition:
#   dp            DP (DDPM)      10회 녹화 -> rollout_diffusion_move-box_<시각>
#   ddim10        DP (DDIM 10)   10회 녹화 -> rollout_diffusion_move-box_ddim10_<시각>
#   act           ACT (chunk50)  10회 녹화 -> rollout_act_move-box_chunk50_<시각>
#   react-dp      반응성 테스트 DP (DDPM)   녹화 없음, 20초 1회 (3번 실행)
#   react-ddim10  반응성 테스트 DP (DDIM 10) 녹화 없음, 20초 1회 (3번 실행)
param(
    [Parameter(Mandatory = $true)][ValidateSet("dp", "ddim10", "act", "react-dp", "react-ddim10")][string]$Condition,
    [Parameter(Mandatory = $true)][string]$Follower,   # 예: COM4
    [string]$Leader = "",                               # 예: COM3 (리셋 때 리더 암으로 되돌리려면)
    [int]$Overhead = 2,
    [int]$Wrist = 0,
    [int]$CamFps = 30,                                  # 카메라 오류가 나면 25로
    [string]$Device = "cuda"                            # GPU가 없으면 cpu
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
$ffbin = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "avcodec-*.dll" -ErrorAction SilentlyContinue |
         Where-Object FullName -like "*ffmpeg-8*" | Select-Object -First 1
if ($ffbin) { $env:PATH = "$($ffbin.DirectoryName);$env:PATH" }
$env:PYTHONIOENCODING = "utf-8"

$cams = "{ overhead: {type: opencv, index_or_path: $Overhead, width: 640, height: 480, fps: $CamFps}, wrist: {type: opencv, index_or_path: $Wrist, width: 640, height: 480, fps: $CamFps}}"
$robot = @("--robot.type=so101_follower", "--robot.port=$Follower", "--robot.id=follower1", "--robot.cameras=$cams")
$teleop = @()
if ($Leader) { $teleop = @("--teleop.type=so101_leader", "--teleop.port=$Leader", "--teleop.id=leader1") }
$ddim = @("--policy.noise_scheduler_type=DDIM", "--policy.num_inference_steps=10")

switch ($Condition) {
    "dp"     { $policy = @("--policy.path=jhd0313/diffusion_move-box");                 $name = "rollout_diffusion_move-box" }
    "ddim10" { $policy = @("--policy.path=jhd0313/diffusion_move-box") + $ddim;         $name = "rollout_diffusion_move-box_ddim10" }
    "act"    { $policy = @("--policy.path=jhd0313/act_move-box_chunk50");               $name = "rollout_act_move-box_chunk50" }
    "react-dp"     { $policy = @("--policy.path=jhd0313/diffusion_move-box") }
    "react-ddim10" { $policy = @("--policy.path=jhd0313/diffusion_move-box") + $ddim }
}

if ($Condition -like "react-*") {
    $cmdArgs = @("--strategy.type=base") + $policy + @("--device=$Device") + $robot + @("--task=Move the box", "--duration=20")
} else {
    $cmdArgs = @("--strategy.type=episodic") + $policy + @("--device=$Device") + $robot + $teleop + @(
        "--dataset.repo_id=jhd0313/$name",
        "--dataset.single_task=Move the box",
        "--dataset.num_episodes=10",
        "--dataset.episode_time_s=20",
        "--dataset.reset_time_s=15")
}

New-Item -ItemType Directory -Force outputs\logs | Out-Null
$log = "outputs\logs\eval_$Condition`_$(Get-Date -Format yyyyMMdd_HHmmss).log"
Write-Host "실행: lerobot-rollout $($cmdArgs -join ' ')`n로그: $log" -ForegroundColor Cyan
# LeRobot은 일반 로그를 stderr로 내보내므로, 오류로 취급해 멈추지 않게 Continue로 바꾸고 문자열로 변환한다
$ErrorActionPreference = "Continue"
& "$repo\.venv\Scripts\lerobot-rollout.exe" @cmdArgs 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log
if ($Condition -notlike "react-*") {
    Write-Host "`n녹화가 끝났으면 Hub의 실제 데이터셋 이름을 확인: https://huggingface.co/jhd0313 (이름이 $name`_YYYYMMDD_HHMMSS 형태)" -ForegroundColor Green
}

# 노트북에서 과제 4 실로봇 평가하기 (임시 폴더, 평가 후 삭제)

모든 명령은 **저장소 폴더(`robot_ai`)에서 PowerShell로** 실행한다.

## 1. 설치 (처음 한 번, 약 10~15분)
```powershell
git pull
powershell -ExecutionPolicy Bypass -File laptop\setup.ps1
```
- NVIDIA 드라이버가 570 미만이면 스크립트가 멈추고 업데이트를 안내한다. 드라이버를 업데이트하고 다시 실행한다.
  (MX450도 최신 드라이버를 지원한다. CPU로만 하려면 `-Cpu`를 붙이지만, DP(DDPM) 추론이 너무 느려 평가가 어렵다.)
- Hugging Face 로그인이 안 되어 있으면 `.venv\Scripts\hf.exe auth login`을 실행한다. 녹화한 데이터셋을 Hub에 올리려면 필요하다.

## 2. 포트·카메라 확인
1. 로봇(follower)과 리더 암 USB를 꽂고 포트를 확인한다.
   ```powershell
   .venv\Scripts\python.exe -m serial.tools.list_ports -v
   ```
   하나씩 뽑았다 꽂아 보면 어느 COM이 follower인지, leader인지 알 수 있다. (예: follower COM4, leader COM3)
2. 카메라 번호를 확인한다.
   ```powershell
   .venv\Scripts\lerobot-find-cameras.exe opencv
   ```
   저장된 사진(`outputs\captured_images`)을 보고 **위에서 내려다보는 카메라 = overhead**, **손목 카메라 = wrist**의 번호를 확인한다.
   노트북 내장 웹캠도 번호를 하나 차지하니 주의한다.

## 3. 캘리브레이션 (setup.ps1에서 "없음"이 나온 경우만)
과제 1을 녹화한 PC의 `C:\Users\<이름>\.cache\huggingface\lerobot\calibration\` 폴더(리눅스는 `~/.cache/huggingface/lerobot/calibration/`)를
이 노트북의 같은 경로로 복사하는 것이 가장 좋다. 학습 데이터와 관절 값 기준이 같아진다.
복사할 수 없으면 새로 캘리브레이션한다. (기준이 조금 달라질 수 있어 성공률에 영향이 있을 수 있다)
```powershell
.venv\Scripts\lerobot-calibrate.exe --robot.type=so101_follower --robot.port=COM4 --robot.id=follower1
.venv\Scripts\lerobot-calibrate.exe --teleop.type=so101_leader --teleop.port=COM3 --teleop.id=leader1
```

## 4. 평가 녹화 (조건별 10회, 각 약 6분)
박스 시작 위치 10곳(1~10번)을 테이프로 표시하고, 세 조건 모두 같은 순서로 쓴다. (에피소드 0 = 위치 1)
아래 COM 번호와 카메라 번호는 2단계에서 확인한 값으로 바꾼다.
```powershell
powershell -ExecutionPolicy Bypass -File laptop\eval.ps1 -Condition dp     -Follower COM4 -Leader COM3 -Overhead 1 -Wrist 0
powershell -ExecutionPolicy Bypass -File laptop\eval.ps1 -Condition ddim10 -Follower COM4 -Leader COM3 -Overhead 1 -Wrist 0
powershell -ExecutionPolicy Bypass -File laptop\eval.ps1 -Condition act    -Follower COM4 -Leader COM3 -Overhead 1 -Wrist 0
```
- 키보드: `→` 에피소드 조기 종료, `←` 그 회차 버리고 다시 녹화(이유 기록), `ESC` 종료
- 리셋 시간 15초 동안 박스를 다음 번호 위치에 놓는다.
- 카메라 오류가 나면 `-CamFps 25`를 붙인다.

## 5. 반응성 테스트 (녹화 없음, 각 3번 실행)
로봇이 박스 쪽으로 움직이기 시작하면 박스를 약 5 cm 옮기고, 따라가는지 본다.
```powershell
powershell -ExecutionPolicy Bypass -File laptop\eval.ps1 -Condition react-dp     -Follower COM4 -Overhead 1 -Wrist 0
powershell -ExecutionPolicy Bypass -File laptop\eval.ps1 -Condition react-ddim10 -Follower COM4 -Overhead 1 -Wrist 0
```

## 6. 결과 기록해서 보내기
```
[DP DDPM]   1: 성공, 부드러움 3, 다시 추론할 때 1초쯤 멈춤
            2: 실패, 부드러움 2, 박스를 놓침   ... 10까지
[DP DDIM10] 1: ...
[ACT 50]    1: ...
[반응성 DDPM]   1: 따라감 / 2: 못 따라감, 원래 위치로 감 / 3: ...
[반응성 DDIM10] 1: ...
Hub 데이터셋 이름 3개: rollout_..._20261120_HHMMSS
```
부드러움은 1(덜컥거림·떨림 심함) ~ 5(매우 부드러움). 실패 회차는 원인을 꼭 적는다.

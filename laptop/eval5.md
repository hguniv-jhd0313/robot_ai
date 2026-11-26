# 과제 5 로봇 평가 (임시 파일, 평가 후 삭제)

노트북(Ubuntu)의 lerobot 0.6.0 환경에서 실행한다. 포트와 카메라 번호는 본인 환경에 맞게 바꾼다.
**카메라 2대를 모두 정상 연결**하고, 실행 전에 영상이 제대로 나오는지 확인한다 (과제 4는 검은 화면, 초록 화면만 들어가 전부 실패).

```bash
lerobot-find-cameras opencv      # 저장된 사진으로 overhead, wrist 번호 확인
```

아래 명령에서 공통으로 쓰는 부분:
```bash
ROBOT='--robot.type=so101_follower --robot.port=/dev/ttyACM0 --robot.id=follower1'
CAMS='{ overhead: {type: opencv, index_or_path: 2, width: 640, height: 480, fps: 30}, wrist: {type: opencv, index_or_path: 0, width: 640, height: 480, fps: 30}}'
REN='{"observation.images.overhead": "observation.images.camera1", "observation.images.wrist": "observation.images.camera2"}'
```
- SmolVLA는 카메라 이름을 camera1, camera2로 바꿔 학습했으므로 `--rename_map`을 꼭 같이 준다.
- 팔이 너무 급하게 움직이면 `--robot.max_relative_target=5`를 붙인다 (붙였다면 결과에 적어 준다).
- 키보드: `→` 조기 종료, `←` 그 회차 버리고 다시 녹화(이유 기록), `ESC` 종료

## 1. 정책 비교: SmolVLA 10회 (약 6분)
과제 3·4와 같은 박스 위치 1~10번, 같은 순서. 장면에는 박스만 놓는다.
```bash
lerobot-rollout --strategy.type=episodic \
  --policy.path=jhd0313/smolvla_move-box --device=cuda \
  $ROBOT --robot.cameras="$CAMS" --rename_map="$REN" \
  --dataset.repo_id=jhd0313/rollout_smolvla_move-box \
  --dataset.single_task="Move the box" \
  --dataset.num_episodes=10 --dataset.episode_time_s=20 --dataset.reset_time_s=15
```

## 2. 언어 지시 평가 (세트 3개 × 10회, 약 20분)
매번 **박스와 검은 큐브를 둘 다** 놓는다. 위치 쌍 1~5번을 테이프로 표시하고 아래 배치표대로 둔다.
"지시 대상"이 정책에 시킨 물체다. 정책이 실제로 어느 물체로 갔는지(박스 / 큐브 / 없음)를 기록한다.

| 에피소드 | 위치 쌍 | 왼쪽 | 오른쪽 |
|---|---|---|---|
| 0 | 1 | 지시 대상 | 다른 물체 |
| 1 | 1 | 다른 물체 | 지시 대상 |
| 2 | 2 | 지시 대상 | 다른 물체 |
| 3 | 2 | 다른 물체 | 지시 대상 |
| ... | ... | (짝수 = 지시 대상 왼쪽, 홀수 = 오른쪽) | |
| 9 | 5 | 다른 물체 | 지시 대상 |

세트 A (지시 대상 = 박스):
```bash
lerobot-rollout --strategy.type=episodic \
  --policy.path=jhd0313/smolvla_move-box-grab-cube --device=cuda \
  $ROBOT --robot.cameras="$CAMS" --rename_map="$REN" \
  --dataset.repo_id=jhd0313/rollout_smolvla_lang_a \
  --dataset.single_task="Move the box" \
  --dataset.num_episodes=10 --dataset.episode_time_s=20 --dataset.reset_time_s=15
```
세트 B (지시 대상 = 검은 큐브): 위 명령에서 아래 두 줄만 바꾼다.
```bash
  --dataset.repo_id=jhd0313/rollout_smolvla_lang_b \
  --dataset.single_task="Grab the black cube" \
```
바꿔 말하기 (에피소드 0~4 = 박스, 5~9 = 검은 큐브):
```bash
# 앞 5회: 박스
lerobot-rollout --strategy.type=episodic \
  --policy.path=jhd0313/smolvla_move-box-grab-cube --device=cuda \
  $ROBOT --robot.cameras="$CAMS" --rename_map="$REN" \
  --dataset.repo_id=jhd0313/rollout_smolvla_lang_para \
  --dataset.single_task="Push the box to the right." \
  --dataset.num_episodes=5 --dataset.episode_time_s=20 --dataset.reset_time_s=15

# 뒤 5회: 검은 큐브 (repo_id에는 위에서 생성된, 녹화 시각이 붙은 실제 이름을 넣는다)
lerobot-rollout --strategy.type=episodic \
  --policy.path=jhd0313/smolvla_move-box-grab-cube --device=cuda \
  $ROBOT --robot.cameras="$CAMS" --rename_map="$REN" \
  --dataset.repo_id=jhd0313/rollout_smolvla_lang_para_YYYYMMDD_HHMMSS \
  --dataset.single_task="Pick up the black block." \
  --dataset.num_episodes=5 --dataset.episode_time_s=20 --dataset.reset_time_s=15 \
  --resume=true
```
바꿔 말하기 세트의 배치도 위 표와 같다 (에피소드 i → 위치 쌍 i//2+1, 짝수면 지시 대상이 왼쪽, 홀수면 오른쪽).
예: 에피소드 4 = 쌍 3·박스 왼쪽, 에피소드 5 = 쌍 3·큐브 오른쪽.

## 3. 결과 보내기
```
[SmolVLA 비교] 1: 성공/실패, 부드러움 1~5, 메모 ... 10까지
[언어 A]  0: 간 물체(박스/큐브/없음), 성공/실패, 메모 ... 9까지
[언어 B]  ...
[바꿔 말하기] ...
Hub 데이터셋 이름 4개, 카메라/안전 제한 등 바뀐 설정
```

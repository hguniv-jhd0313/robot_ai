# 과제 3 인수인계 (Claude Code 세션 이어가기용)

> 집 컴퓨터에서 이 저장소를 clone/pull한 뒤 Claude Code에 "HANDOFF.md 읽고 이어서 해줘"라고 하면 된다.
> 작성일: 2026-11-12 (노트북 PC에서 작성)

## 과제 요약
`assignment_3.ipynb` — 같은 데이터셋으로 ACT `chunk_size` 10 / 50 / 100 정책 3개를 학습 → 실로봇 평가 조건별 10회
→ 반응성 테스트 조건별 3회 → chunk100에 temporal ensemble 적용해 10회 평가 → 노트북에 결과·분석 작성.
환경: **LeRobot 0.6.0**, Python 3.12+, PyTorch 2.7+ (`pip install "lerobot[all]==0.6.0"`)

## 작업 규칙 (사용자 요청)
- **노트북의 기존 형식(안내 문구, 예시 코드 블록, 체크 셀)은 수정하지 않는다. `[작성]` 칸만 채운다.**
- 5절의 temporal ensemble 예시 명령어 블록도 원본 그대로 둔다. (실행할 때만 아래 값으로 바꿔서 사용)

## 확인된 사실 (Hub에서 직접 확인함)
| 항목 | 값 |
|---|---|
| HF 사용자 | `jhd0313` |
| 학습 데이터셋 | `jhd0313/move-box_20261008_100955` — 30 fps, 50 에피소드, 평균 7.1 s |
| 데이터셋 task 문장 | **`Move the box`** (노트북 템플릿 예시의 "Pick up the cube…" 아님) |
| 카메라 이름 | **`overhead`, `wrist`** (템플릿 예시의 `top` 아님) |
| 과제 1 녹화 설정 | follower `/dev/ttyACM1` id `follower1`, leader `/dev/ttyACM0` id `leader1`, overhead index 2, wrist index 0 |
| 과제 2 정책 | `jhd0313/act_move_box` — chunk_size=100, n_action_steps=100, **steps=1000**, batch_size=8, seed=1000 |
| Hub에 아직 없는 것 | `act_move-box_chunk10/50/100` 정책, 평가 데이터셋 전부 |

- 과제 1 명령어에는 카메라 `fps: 25`라고 적혀 있으나 데이터셋 info.json은 fps 30. 노트북 명령어에는 30으로 넣었다. 시작 시 오류가 나면 25로 시도.
- 포트·카메라 index는 PC마다 다를 수 있으니 실습 PC에서 확인.

## 지금까지 노트북에서 채운 곳
- 0절: `NAME`, `TASK = "Move the box"`, `EVAL_DATASETS`는 `..._YYYYMMDD_HHMMSS` 자리표시 → **녹화 후 Hub의 실제 이름으로 교체**
- 2-1: `lerobot-train` 명령어 3개 (steps=100000, batch_size=8, seed=1000, wandb 사용)
- 3-2: `lerobot-rollout` 명령어 3개 (episode_time_s=20)
- `.gitignore` 생성 (`outputs/` 포함 — 가중치는 GitHub에 올리지 않음)

## 미결정 사항
- **steps**: 과제 2 정책을 chunk100으로 재사용하면 세 조건 모두 steps=1000으로 맞춰야 하는데, 1000 step은 학습이 거의 안 된 수준이라 비추천.
  → 권장: 세 개 모두 새로 학습 (명령어에는 100000으로 들어가 있음. 시간이 부족하면 세 개를 같은 값으로 줄이고 2-1 명령어도 실제 값으로 수정)

## 남은 작업 순서
1. 집 PC 환경 준비: Python 3.12, `pip install "lerobot[all]==0.6.0"`, CUDA PyTorch 확인, `huggingface-cli login`, `wandb login`
2. **학습 전에** 노트북 1-2 가설, 3-1 성공 기준 작성
3. 2-1 명령어로 학습 3개 실행 → `--policy.repo_id`로 Hub 자동 업로드 (public 확인)
   - 학습 로그 마지막의 `l1_loss`, `kld_loss` → 2-3 `final_loss`, GPU·소요 시간 → 2-2
   - wandb loss 곡선 3개를 겹친 이미지 → `images/loss_curve_hw3.png`
4. 실로봇 평가 (로봇이 있는 곳에서): 3-2 명령어로 조건별 10회 → Hub 실제 이름을 0절 `EVAL_DATASETS`에 기록, `results` 입력 (실패 시 note 필수)
5. 반응성 테스트 (`--strategy.type=base`) 조건별 3회 → `reactivity` 입력
6. temporal ensemble 10회: 5절 예시 블록에서 `pick-cube`→`move-box`, `top`→`overhead`, task→`"Move the box"`, 포트/id를 위 설정으로 바꿔 실행 → `TE_EVAL_DATASET`, `te_results` 입력
7. GIF 3개 → `images/hw3_chunk10.gif` 등, 4절 고찰, 5절 비교 작성
8. lerobot 0.6.0 환경에서 노트북을 **처음부터 끝까지 실행** → 출력이 남은 상태로 커밋 (마감 이후 커밋은 반영 안 됨)

## 참고: 템플릿 체크 셀의 허점
- 1-3 "통제 변수 일치"는 정책을 못 불러와 값이 모두 None이어도 [일치]로 나온다.
- "실패 회차에 원인 기재"는 결과를 입력하지 않아도 [통과]로 나온다.
→ 체크리스트 통과만 믿지 말고 실제 값이 들어갔는지 확인할 것.

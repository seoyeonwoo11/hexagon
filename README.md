99.9% 바이브코딩

# Hexagon

검은 배경 위 네온 육각형 타일로 하는 2D 디펜스 게임입니다. Godot 4.7로 만듭니다.

목표: 30웨이브의 최종 보스 OVERLORD를 잡으면 클리어. 클리어 뒤에는 원하면 무한 모드로 이어서 할 수 있습니다.

## 실행

Godot 4.7 에디터에서 이 폴더의 `project.godot`를 열고 F5로 실행합니다.

## 웹(태블릿)에서 하기

- 주소: https://seoyeonwoo11.github.io/hexagon/ (태블릿은 가로로 두는 걸 추천)
- main에 올라가면 GitHub Actions(`.github/workflows/web.yml`)가 웹 빌드를 만들어 `gh-pages` 브랜치에 올림
- 저장(SHARD, 영구 강화)은 그 브라우저에 남음. 다른 기기나 PC 버전과는 따로
- 직접 내보내기: Godot 에디터의 Project > Export에서 "Web" 프리셋 (스레드 끔, 그래서 특별한 서버 설정 없이 동작)
- 터치: 탭이 왼쪽 클릭. 오른쪽 클릭 대신 정보 창의 CLOSE 버튼이나 빈 곳 탭, 옮기기 취소는 MOVE 버튼, 스킬은 왼쪽 아래 버튼, FULL 버튼으로 전체 화면

## 테스트

```
godot --headless --path . -s res://tests/test_hex_grid.gd
godot --headless --fixed-fps 60 --path . -s res://tests/test_combat.gd
godot --headless --fixed-fps 60 --path . -s res://tests/test_progression.gd
godot --headless --fixed-fps 60 --path . -s res://tests/test_enemies.gd
godot --headless --fixed-fps 60 --path . -s res://tests/test_meta.gd
godot --headless --fixed-fps 60 --path . -s res://tests/test_actions.gd
godot --headless --fixed-fps 60 --path . -s res://tests/test_final.gd
```

## 조작

- Space 또는 PAUSE/PLAY 버튼: 일시정지 / 계속. 일시정지 중에는 화면 아무 데나 눌러도(탭) 이어서 한다. 일시정지 화면에 타일별 최근 7웨이브 피해 표 (총 피해 많은 순, 부서진 타일은 흐리게 X)
- F: 1배속 / 2배속
- R: 게임 오버 후 재시작
- Q: 코어 스킬 (왼쪽 아래 버튼, 막대가 차면 다시 쓸 수 있음)
- M: 타일 옮기기. 웨이브마다 1번 (쌓이지 않음). 옮길 타일을 클릭한 뒤 갈 칸을 클릭. 다른 타일을 클릭하면 자리 바꾸기. 빈 칸은 다른 타일과 맞닿아 있어야 함. 코어는 제자리. 오른쪽 클릭으로 취소
- F11: 전체 화면 (웹/터치 화면에서는 오른쪽 위 FULL 버튼)
- 타일 왼쪽 클릭: 정보 창 (돈으로 UPGRADE), 오른쪽 클릭: 창 닫기
- 웨이브 클리어: 카드 3장 중 하나 선택 (타일, 강화, 장비가 무작위로 섞여 나옴). 타일 카드는 표시된 맞닿은 칸을 클릭해 배치, 장비 카드는 깜빡이는 타일을 클릭해 장착

## 장비 (타일마다 1개, 새로 달면 교체)

- SCOPE: 사거리 +40%
- SPLITTER: 공격마다 대상 1명 추가, ORBIT은 구체 +1, DRONE HIVE는 드론 +1 (FROST에는 못 닮)
- IGNITER: 맞은 적에게 3초 화상
- CRIT LENS: 25% 확률로 3.5배 피해
- DETONATOR: 맞힐 때마다 그 자리에서 폭발해 반경 90 안 다른 적에게 맞힌 피해의 45%
- BANK에는 장비를 달 수 없음

## 적 종류

- GRUNT (빨간 삼각형): 기본
- RUNNER (노란 작은 사각형, 웨이브 2~): 체력 낮고 매우 빠름
- TANK (주황 큰 사각형, 웨이브 4~): 체력 많고 느림, 부딪히면 큰 피해, 보상 3배
- SPLITTER (연두 오각형, 웨이브 6~): 처치하면 RUNNER 2마리로 갈라짐
- ARMORED (회색 이중 육각형, 웨이브 8~): 받는 피해 30% 감소
- BOSS (분홍 별, 10웨이브마다 1마리): 체력 매우 많음, 피해 20% 감소, 보상 큼. 타일에 닿아도 사라지지 않고 1초마다 때리며, 타일을 부수면 다음 타일로 이동
- OVERLORD (금색 왕관 별, 30웨이브 마지막): 최종 보스. BOSS의 2.5배 체력, 피해 30% 감소. 5초마다 RUNNER 3마리를 부름. 체력이 절반 아래로 떨어지면 붉게 맥동하며 1.6배 빨라지고 2.5초마다 부름. 화면 위에 체력 막대. 잡으면 클리어

## 클리어와 무한 모드

- 왼쪽 위 웨이브 표시는 "WAVE 12 / 30"
- OVERLORD를 포함해 30웨이브 적을 다 잡으면 VICTORY 화면. 그 자리에서 SHARD 75개 (30웨이브 몫 45 + 클리어 보너스 30)를 바로 받음
- CONTINUE ENDLESS: 같은 판을 카드 3장부터 이어서 진행 ("WAVE 31 ENDLESS"). 끝나면 31웨이브부터 버틴 만큼 SHARD를 더 받음
- END RUN: 시작 화면으로. 시작 화면에 클리어 횟수(Clears) 표시

## 타일 종류

- CORE: 시작 타일. 부서지면 게임 오버
- LASER: 가장 가까운 적에게 사거리 끝까지 뻗는 관통 광선. 줄 위의 다른 적도 40% 피해. 같은 적을 계속 맞히면 집중이 쌓여 1번마다 +12% (최대 6번, 강화마다 +3%p). 타일 둘레의 호가 집중 게이지
- SPARK: 가까운 적들 사이를 튕기는 번개 투사체. 피해 8, 1초마다, 사거리 300, 3번 튕김 (레벨마다 튕김 +1)
- FROST: 사거리 안 적을 느리게 하고 약한 피해. 감속 범위는 옅은 원과 테두리로 늘 보이고, 공격마다 냉기 파동이 퍼짐
- ORBIT: 빛나는 구체 3개가 타일 주위 원 궤도(반지름 145)를 돌며 닿은 적에게 피해 17 (레벨마다 구체 +1, 최대 6개)
- DRONE HIVE: 드론 2기가 벌집 주위를 돌다가 사거리(330) 안 적을 쫓아가 들이받음. 드론마다 다른 적을 노림
- ARCHER: 긴 사거리(360) 화살. 면이 맞닿은 ARCHER 1개당 공격력 +35% (가운데 끼면 최대 +210%). 연결된 변에 밝은 막대
- PRISM: 공격하지 않는 대신 면이 맞닿은 LASER/ARCHER가 쏠 때마다 쏜 타일 → PRISM 방향으로 세 갈래(가운데 ±24°)를 쏨. 갈래마다 원래 공격력의 60% (강화마다 +10%p). LASER는 관통 광선(빨강/초록/파랑), ARCHER는 곧게 나는 화살. 놓는 위치가 화력 방향을 정함
- BOOSTER: 공격하지 않는 대신 면이 맞닿은 타일들의 공격 속도 +25% (강화마다 +10%p, 여러 개면 더해짐). 장비 불가
- BANK: 웨이브를 넘길 때마다 돈 $12 (강화마다 +$6), 그리고 가진 돈의 4% 이자 (강화마다 +1%p, 최대 수입 × 3)

## 판 사이 성장 (SHARD)

- 게임을 켜면 시작 화면(상점)이 뜨고, START 또는 Enter로 판을 시작
- 게임 오버 때 다 처리한 웨이브 수만큼 SHARD를 받음 (10웨이브마다 +5). 결과는 시작 화면에 표시되고, R을 누르면 상점 없이 바로 새 판
- 코어 종류 (시작 화면 왼쪽 아래에서 고름, 판마다 1개):
  - CORE (기본): OVERDRIVE, 6초 동안 모든 타일 공격력 +60%, 쿨다운 35초
  - CRYO CORE (15): FREEZE, 모든 적 3.5초 정지 (움직이지도 때리지도 않음), 쿨다운 30초
  - AEGIS CORE (20): REPAIR, 모든 타일 최대 체력의 50% 회복, 쿨다운 40초
  - NOVA CORE (25): NOVA, 반경 560 안 적에게 최대 체력 30% 피해 (보스 10%, 장갑 무시), 쿨다운 40초
- 영구 강화 (각 5레벨): CORE PLATING 코어 체력 +25, POWER GRID 공격력 +8%, FAST CYCLE 공격 속도 +5%, HARD SHELL 타일 체력 +10%, SEED FUND 시작 돈 +$10
- 타일 구매: 처음엔 LASER, FROST, BOOSTER, BANK만 쓸 수 있고 SPARK(12), ARCHER(15), ORBIT(20), PRISM(20), DRONE HIVE(25)는 SHARD로 사야 함
- 출정 타일: 시작 화면에서 풀린 타일을 클릭해 최대 6종을 고름. 판에서는 고른 타일만 카드로 나옴. 새로 산 타일은 자리가 있으면 바로 들어감
- 저장 위치: `user://meta.cfg` (Windows는 `%APPDATA%\Godot\app_userdata\Hexagon\`). 지우면 처음부터

## 강화 (타일 정보 창의 UPGRADE)

- 1번마다 공격력 ×1.5, 공격 속도 +11%, 사거리 +20, 체력 +20. 비용은 $25에서 레벨마다 1.8배
- 타일별 추가 효과: CORE는 3, 5레벨에 광선 +1, LASER는 집중 +3%p, DRONE HIVE는 3, 5, 7레벨에 드론 +1, ARCHER는 연결 보너스 +10%p, SPARK는 튕김 +1, FROST는 감속 강화, ORBIT은 구체 +1, BANK는 수입 +$6
- 정보 창의 NEXT LEVEL에 다음 강화로 바뀌는 수치가 나옴. 레벨이 오르면 타일이 더 밝고 두꺼워짐

## 후반 밸런스

- 적 체력: 15웨이브까지는 웨이브마다 ×1.23, 그 뒤로는 ×1.17로 성장이 느려짐
- 처치 보상: 0.3 × 적 체력^0.38. 적이 강해질수록 조금씩 늘어남
- 강화 카드는 웨이브가 높을수록 수치가 커짐. 공격력/속도 카드는 곱하지 않고 더해서 쌓임 (몰아 먹어도 끝없이 불어나지 않음)
  - OVERCHARGE: 모든 타일 공격력 +(10 + 0.3 × 웨이브)%p
  - OVERCLOCK: 모든 타일 공격 속도 +(10 + 0.3 × 웨이브)%p
  - REINFORCE: 코어 최대 체력 +(25 + 4 × 웨이브), 다른 타일 최대 체력 +15%, 모든 타일 완전 수리
  - RESONANCE: 고른 뒤로 웨이브를 넘길 때마다 모든 타일 공격력 +1%p (여러 번 고르면 더해짐)
- 카드 밸런스는 카드마다 "나오면 무조건 고르는" 봇을 40판씩 돌려 도달 웨이브를 비교해서 맞춤
- 자동 플레이 봇 기준으로 메타 강화 없이 10~80웨이브(고른 타일에 따라 차이 큼), 메타 최대로 55~60웨이브에서 끝남

## 성능

- 타일과 적은 모양이 바뀔 때만 다시 그림 (밝기 맥동은 투명도, 회전은 노드 rotation)
- ORBIT 구체, FROST 눈금, 적 몸체는 자식 노드를 돌려서 표현
- 배경 격자는 선분 묶음 하나로 그림. 네온 번짐 층은 2겹
- 37타일, 35웨이브 부하 측정에서 프레임당 그리기 호출 약 9,900 → 2,600

## 구조

- `scripts/hex_grid.gd`: 육각형 좌표 계산 (pointy-top, axial 좌표)
- `scripts/neon_draw.gd`: 네온 선 그리기
- `scripts/gear_defs.gd`: 장비 종류와 효과 수치
- `scripts/tile_defs.gd`: 타일 종류별 능력치 (새 타일은 여기에 추가)
- `scripts/hex_tile.gd`: 타일 하나 (공격, 강화)
- `scripts/board.gd`: 보드, 배경 그리드, 배치 규칙 (맞닿은 면에만 배치)
- `scripts/explosion.gd`: DETONATOR 폭발 효과
- `scripts/chain_bolt.gd`: SPARK 타일의 튕기는 번개 투사체
- `scripts/orbit_ring.gd`: ORBIT 타일의 도는 구체 그리기
- `scripts/level_up_fx.gd`: 강화 순간 연출 (퍼지는 고리와 LV 글자)
- `scripts/frost_field.gd`: FROST 감속 범위와 냉기 파동
- `scripts/drone.gd`, `scripts/arrow.gd`: DRONE HIVE의 드론, ARCHER의 화살
- `scripts/damage_stats.gd`, `scripts/stats_panel.gd`: 타일별 웨이브 피해 기록과 일시정지 화면 표
- `scripts/enemy_defs.gd`: 적 종류별 배율과 등장 웨이브
- `scripts/enemy.gd`: 적 (화면 밖에서 등장해 가장 가까운 타일로 이동)
- `scripts/game.gd`: 돈, 웨이브, 적 생성, 웨이브 클리어 카드, 강화, 일시정지/배속, 게임 오버 (밸런스 숫자는 wave_enemy_* 함수)
- `scripts/meta.gd`: SHARD, 영구 강화, 타일 구매, 저장/불러오기
- `scripts/shop.gd`: 시작 화면 겸 상점
- `scripts/hud.gd`: 화면 위 정보와 버튼
- `scenes/main.tscn`: 메인 화면 (글로우, 카메라, 보드, HUD)

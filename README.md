99.9% 바이브코딩

# Hexagon

검은 배경 위 네온 육각형 타일로 하는 2D 디펜스 게임입니다. Godot 4.7로 만듭니다.

## 실행

Godot 4.7 에디터에서 이 폴더의 `project.godot`를 열고 F5로 실행합니다.

## 테스트

```
godot --headless --path . -s res://tests/test_hex_grid.gd
godot --headless --fixed-fps 60 --path . -s res://tests/test_combat.gd
godot --headless --fixed-fps 60 --path . -s res://tests/test_progression.gd
```

## 조작

- Space: 일시정지 / 계속
- F: 1배속 / 2배속
- R: 게임 오버 후 재시작
- F11: 전체 화면
- 타일 왼쪽 클릭: 정보 창 (돈으로 UPGRADE), 오른쪽 클릭: 창 닫기
- 웨이브 클리어: 카드 3장 중 하나 선택 (타일, 강화, 장비가 무작위로 섞여 나옴). 타일 카드는 표시된 맞닿은 칸을 클릭해 배치, 장비 카드는 깜빡이는 타일을 클릭해 장착

## 장비 (타일마다 1개, 새로 달면 교체)

- SCOPE: 사거리 +40%
- SPLITTER: 공격마다 대상 1명 추가 (LASER, SPARK, CORE)
- IGNITER: 맞은 적에게 3초 화상
- CRYO COIL: 맞은 적 35% 감속 (LASER, SPARK, CORE)
- CRIT LENS: 20% 확률로 3배 피해
- DETONATOR: 이 타일이 처치한 적이 폭발해 주변 적에게 피해
- BANK에는 장비를 달 수 없음
- COLLECTOR: 이 타일이 처치한 적 보상 +$1

## 타일 종류

- CORE: 시작 타일. 부서지면 게임 오버
- LASER: 가장 가까운 적 하나를 공격
- SPARK: 가까운 적들 사이를 튕기는 번개 투사체 (레벨마다 튕김 +1)
- FROST: 사거리 안 적을 느리게 하고 약한 피해
- BANK: 웨이브를 넘길 때마다 돈

## 구조

- `scripts/hex_grid.gd`: 육각형 좌표 계산 (pointy-top, axial 좌표)
- `scripts/neon_draw.gd`: 네온 선 그리기
- `scripts/gear_defs.gd`: 장비 종류와 효과 수치
- `scripts/tile_defs.gd`: 타일 종류별 능력치 (새 타일은 여기에 추가)
- `scripts/hex_tile.gd`: 타일 하나 (공격, 강화)
- `scripts/board.gd`: 보드, 배경 그리드, 배치 규칙 (맞닿은 면에만 배치)
- `scripts/explosion.gd`: DETONATOR 폭발 효과
- `scripts/chain_bolt.gd`: SPARK 타일의 튕기는 번개 투사체
- `scripts/enemy.gd`: 적 (화면 밖에서 등장해 가장 가까운 타일로 이동)
- `scripts/game.gd`: 돈, 웨이브, 적 생성, 웨이브 클리어 카드, 강화, 일시정지/배속, 게임 오버 (밸런스 숫자는 wave_enemy_* 함수)
- `scripts/hud.gd`: 화면 위 정보와 버튼
- `scenes/main.tscn`: 메인 화면 (글로우, 카메라, 보드, HUD)

99.9% 바이브코딩

# Hexagon

검은 배경 위 네온 육각형 타일로 하는 2D 디펜스 게임입니다. Godot 4.7로 만듭니다.

## 실행

Godot 4.7 에디터에서 이 폴더의 `project.godot`를 열고 F5로 실행합니다.

## 테스트

```
godot --headless --path . -s res://tests/test_hex_grid.gd
godot --headless --fixed-fps 60 --path . -s res://tests/test_combat.gd
```

## 조작

- Space: 일시정지 / 계속
- F: 1배속 / 2배속
- R: 게임 오버 후 재시작

## 구조

- `scripts/hex_grid.gd`: 육각형 좌표 계산 (pointy-top, axial 좌표)
- `scripts/neon_draw.gd`: 네온 선 그리기
- `scripts/hex_tile.gd`: 타일 하나
- `scripts/board.gd`: 보드, 배경 그리드, 배치 규칙 (맞닿은 면에만 배치)
- `scripts/enemy.gd`: 적 (화면 밖에서 등장해 가장 가까운 타일로 이동)
- `scripts/game.gd`: 돈, 웨이브, 적 생성, 일시정지/배속, 게임 오버
- `scripts/hud.gd`: 화면 위 정보와 버튼
- `scenes/main.tscn`: 메인 화면 (글로우, 카메라, 보드, HUD)

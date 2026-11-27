import test from 'node:test';
import assert from 'node:assert/strict';
import {
  BOARD_SIZE,
  createBoard,
  rotateMatrix90,
  rotateTrayPiece,
  canPlacePiece,
  placePieceOnBoard,
  getBoosterCoinCost,
  applyHammerBooster,
  applyBombBlastBooster,
  applyLaserBooster,
  convertPieceToSingleStar,
  getCampaignStageConfig,
  getProjectedClearLines,
  hasAnyValidMove,
  TrayPiece,
} from './rules';

test('variable grid architectures mark void coordinates accurately', () => {
  const standard = createBoard('standard');
  assert.equal(standard[3][3].kind, 'empty');

  const holed = createBoard('holed');
  assert.equal(holed[3][3].kind, 'void');
  assert.equal(holed[4][4].kind, 'void');
  assert.equal(holed[0][0].kind, 'empty');

  const lShaped = createBoard('l_shaped');
  assert.equal(lShaped[0][6].kind, 'void');
  assert.equal(lShaped[2][5].kind, 'void');
  assert.equal(lShaped[5][5].kind, 'empty');
});

test('rotateMatrix90 and rotateTrayPiece rotate 90 degrees clockwise', () => {
  const lMatrix = [
    [1, 0],
    [1, 0],
    [1, 1],
  ];
  const rotated = rotateMatrix90(lMatrix);
  assert.deepEqual(rotated, [
    [1, 1, 1],
    [1, 0, 0],
  ]);

  const piece: TrayPiece = {
    id: 'p1',
    name: 'L',
    matrix: lMatrix,
    color: 'ruby',
    modifiers: [{ dr: 2, dc: 1, kind: 'wildcard' }],
    used: false,
  };
  const rotatedPiece = rotateTrayPiece(piece);
  assert.equal(rotatedPiece.matrix.length, 2);
  assert.equal(rotatedPiece.matrix[0].length, 3);
  assert.deepEqual(rotatedPiece.modifiers[0], { dr: 1, dc: 0, kind: 'wildcard' });
});

test('frozen blocks require multiple line clears to shatter completely', () => {
  const board = createBoard('standard');
  // Fill row 0 cols 0..6 with normal blocks, leave col 7 empty
  for (let c = 0; c < 7; c++) {
    board[0][c] = {
      row: 0,
      col: c,
      kind: 'normal',
      color: 'ruby',
      frozenLayers: 0,
      bombTimer: 0,
    };
  }
  // Make (0, 3) a 2-layer Frozen block
  board[0][3] = {
    row: 0,
    col: 3,
    kind: 'frozen',
    color: 'sapphire',
    frozenLayers: 2,
    bombTimer: 0,
  };

  const singlePiece: TrayPiece = {
    id: 'single',
    name: 'Monolith',
    matrix: [[1]],
    color: 'ruby',
    modifiers: [],
    used: false,
  };

  assert.equal(canPlacePiece(board, singlePiece, 0, 7), true);
  const res1 = placePieceOnBoard(board, singlePiece, 0, 7);
  assert.equal(res1.valid, true);
  assert.equal(res1.linesCleared, 1);
  // Normal cells cleared, but (0, 3) cracked from 2 layers down to 1 layer!
  assert.equal(res1.board[0][0].kind, 'empty');
  assert.equal(res1.board[0][3].kind, 'frozen');
  assert.equal(res1.board[0][3].frozenLayers, 1);
  assert.equal(res1.iceShattered, 0);

  // Now fill row 0 again except col 7 and clear it a second time
  for (let c = 0; c < 7; c++) {
    if (c !== 3) {
      res1.board[0][c] = {
        row: 0,
        col: c,
        kind: 'normal',
        color: 'ruby',
        frozenLayers: 0,
        bombTimer: 0,
      };
    }
  }
  const res2 = placePieceOnBoard(res1.board, singlePiece, 0, 7);
  assert.equal(res2.linesCleared, 1);
  assert.equal(res2.board[0][3].kind, 'empty');
  assert.equal(res2.iceShattered, 1);
});

test('bomb blocks defuse on line clear and detonate when countdown reaches 0', () => {
  const board = createBoard('standard');
  // Place a bomb with timer = 1 at (4, 4)
  board[4][4] = {
    row: 4,
    col: 4,
    kind: 'bomb',
    color: 'ruby',
    frozenLayers: 0,
    bombTimer: 1,
  };

  const singlePiece: TrayPiece = {
    id: 'single',
    name: 'Monolith',
    matrix: [[1]],
    color: 'emerald',
    modifiers: [],
    used: false,
  };

  // Place piece at (0, 0) without clearing row 4 -> bomb at (4,4) should detonate!
  const res = placePieceOnBoard(board, singlePiece, 0, 0);
  assert.equal(res.bombsDetonated, 1);
  assert.equal(res.board[4][4].kind, 'frozen');
  assert.equal(res.board[3][4].kind, 'frozen');
});

test('anti-pay-to-win booster cost compounds exponentially and enforces 3-use session cap', () => {
  assert.equal(getBoosterCoinCost('hammer', 0), 50);
  assert.equal(getBoosterCoinCost('hammer', 1), 100);
  assert.equal(getBoosterCoinCost('hammer', 2), 200);
  assert.equal(getBoosterCoinCost('hammer', 3), null);
});

test('hammer and bomb blast boosters clear occupied obstacles', () => {
  const board = createBoard('standard', { initialFrozenCount: 4, seed: 42 });
  const occupied = board.flat().find((c) => c.kind === 'frozen');
  assert.ok(occupied);

  const hammered = applyHammerBooster(board, occupied.row, occupied.col);
  assert.equal(hammered.success, true);
  assert.equal(hammered.board[occupied.row][occupied.col].kind, 'empty');

  const bombed = applyBombBlastBooster(board, occupied.row, occupied.col);
  assert.equal(bombed.success, true);
  assert.ok(bombed.clearedCount >= 1);
});

test('500-stage campaign generator produces valid configurations up to stage 500', () => {
  const s1 = getCampaignStageConfig(1);
  const s250 = getCampaignStageConfig(250);
  const s500 = getCampaignStageConfig(500);

  assert.equal(s1.stageNumber, 1);
  assert.equal(s250.stageNumber, 250);
  assert.equal(s500.stageNumber, 500);
  assert.ok(s500.objectives[0].target > s1.objectives[0].target);
  assert.equal(hasAnyValidMove(createBoard(s1.architecture), []), true);
});

test('getProjectedClearLines accurately predicts row and column clears on hover', () => {
  const board = createBoard('standard');
  for (let c = 0; c < 6; c++) {
    board[2][c] = {
      row: 2,
      col: c,
      kind: 'normal',
      color: 'emerald',
      frozenLayers: 0,
      bombTimer: 0,
    };
  }
  const duoH: TrayPiece = {
    id: 'duo',
    name: 'Duo H',
    matrix: [[1, 1]],
    color: 'emerald',
    modifiers: [],
    used: false,
  };
  const proj = getProjectedClearLines(board, duoH, 2, 6);
  assert.deepEqual(proj.rows, [2]);
  assert.deepEqual(proj.cols, []);
});

test('buildGodotProjectZipBytes builds a valid PKZIP archive with all Godot 4 project files', async () => {
  const { GODOT_PROJECT_FILES, buildGodotProjectZipBytes } = await import('./godotExporter');
  assert.ok(GODOT_PROJECT_FILES.length >= 6);
  assert.ok(GODOT_PROJECT_FILES.some((f) => f.path === 'project.godot'));
  assert.ok(GODOT_PROJECT_FILES.some((f) => f.path === 'scripts/RelicBoardCanvas.gd'));
  assert.ok(GODOT_PROJECT_FILES.some((f) => f.path === 'scenes/Main.tscn'));

  const zipBytes = buildGodotProjectZipBytes(GODOT_PROJECT_FILES);
  assert.ok(zipBytes.byteLength > 2000);
  const view = new DataView(zipBytes.buffer);
  // Check PK\x03\x04 local file header signature
  assert.equal(view.getUint32(0, true), 0x04034b50);
  // Check PK\x05\x06 End of Central Directory signature at the end of the archive
  assert.equal(view.getUint32(zipBytes.byteLength - 22, true), 0x06054b50);
});

test('Pastel Blast merged mechanics: Cross-Laser booster, 1x1 Star converter, and Gem Star collection', () => {
  const board = createBoard('standard');
  board[3][2] = {
    row: 3,
    col: 2,
    kind: 'normal',
    color: 'ruby',
    frozenLayers: 0,
    bombTimer: 0,
    hasGem: true,
  };
  board[5][4] = {
    row: 5,
    col: 4,
    kind: 'normal',
    color: 'sapphire',
    frozenLayers: 0,
    bombTimer: 0,
    hasGem: true,
  };

  // Cross-Laser at (3, 4) clears row 3 and col 4 and collects both gems
  const laserRes = applyLaserBooster(board, 3, 4);
  assert.equal(laserRes.success, true);
  assert.equal(laserRes.clearedCount, 2);
  assert.equal(laserRes.gemsCollected, 2);
  assert.equal(laserRes.board[3][2].kind, 'empty');
  assert.equal(laserRes.board[5][4].kind, 'empty');

  // 1x1 Star converter turns a multi-tile piece into a 1x1 gem star block
  const bigPiece: TrayPiece = {
    id: 'big1',
    name: '3x3 Square',
    matrix: [
      [1, 1, 1],
      [1, 1, 1],
      [1, 1, 1],
    ],
    color: 'emerald',
    modifiers: [],
    used: false,
  };
  const starPiece = convertPieceToSingleStar(bigPiece);
  assert.deepEqual(starPiece.matrix, [[1]]);
  assert.equal(starPiece.modifiers[0]?.hasGem, true);
});



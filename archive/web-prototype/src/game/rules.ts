export type BlockColor = 'ruby' | 'amber' | 'emerald' | 'sapphire' | 'amethyst';

export type CellKind = 'empty' | 'void' | 'normal' | 'frozen' | 'bomb' | 'wildcard';

export type GridArchitecture = 'standard' | 'holed' | 'shifting' | 'l_shaped';

export type GameMode = 'classic' | 'daily' | 'blitz' | 'campaign';

export type BoosterType =
  | 'rotate'
  | 'hammer'
  | 'reroll'
  | 'bomb_blast'
  | 'laser'
  | 'single_star';

export type ThemeSkinId =
  | 'pastel_blast'
  | 'classic_video'
  | 'sugar_cream'
  | 'night_neon'
  | 'mystic_forest'
  | 'artisan_wood'
  | 'crystal_prism'
  | 'autumn_leaf'
  | 'retro_pixel';

export interface GridCell {
  row: number;
  col: number;
  kind: CellKind;
  color: BlockColor;
  frozenLayers: number; // 0 for normal, 2 or 3 for frozen blocks
  bombTimer: number; // 0 for normal, 1..5 for bomb blocks
  hasGem?: boolean; // Collectible Adventure Star / Gem embedded in tile
  highlightFlash?: number; // transient visual flash timestamp/intensity
}

export interface PieceCellModifier {
  dr: number;
  dc: number;
  kind: 'normal' | 'frozen' | 'bomb' | 'wildcard';
  frozenLayers?: number;
  bombTimer?: number;
  hasGem?: boolean;
}

export interface TrayPiece {
  id: string;
  name: string;
  matrix: number[][]; // 2D array of 0 or 1
  color: BlockColor;
  modifiers: PieceCellModifier[];
  used: boolean;
}

export interface StageObjective {
  type:
    | 'score'
    | 'clear_ruby'
    | 'shatter_ice'
    | 'defuse_bomb'
    | 'clear_lines'
    | 'collect_gems';
  label: string;
  target: number;
  current: number;
}

export interface CampaignStageConfig {
  stageNumber: number;
  title: string;
  biome: string;
  architecture: GridArchitecture;
  moveLimit: number;
  objectives: StageObjective[];
  initialFrozenCount: number;
  initialBombCount: number;
  initialGemCount?: number;
  rewardCoins: number;
  rewardStars: number;
}

export interface PlacementEvent {
  type:
    | 'line_clear'
    | 'combo_clear'
    | 'frost_crack'
    | 'ice_shatter'
    | 'bomb_defused'
    | 'bomb_detonated'
    | 'wildcard_surge'
    | 'row_shifted';
  row?: number;
  col?: number;
  count?: number;
  message: string;
}

export interface PlacementResult {
  valid: boolean;
  board: GridCell[][];
  scoreDelta: number;
  linesCleared: number;
  comboCount: number;
  timeBonusSec: number;
  coinsEarned: number;
  rubyCleared: number;
  iceShattered: number;
  bombsDefused: number;
  bombsDetonated: number;
  wildcardsTriggered: number;
  gemsCollected: number;
  fullRows: number[];
  fullCols: number[];
  clearedCells: Array<{ row: number; col: number; color: BlockColor; hasGem?: boolean }>;
  events: PlacementEvent[];
}

export const BOARD_SIZE = 8;

export const BLOCK_COLORS: BlockColor[] = ['ruby', 'amber', 'emerald', 'sapphire', 'amethyst'];

export const MAX_BOOSTER_USES_PER_SESSION = 3;

export const BASE_BOOSTER_COSTS: Record<BoosterType, number> = {
  rotate: 30,
  reroll: 40,
  hammer: 50,
  single_star: 50,
  bomb_blast: 60,
  laser: 75,
};

export interface ShapeTemplate {
  name: string;
  matrix: number[][];
}

export const SHAPE_TEMPLATES: ShapeTemplate[] = [
  { name: 'Monolith', matrix: [[1]] },
  { name: 'Duo H', matrix: [[1, 1]] },
  { name: 'Duo V', matrix: [[1], [1]] },
  { name: 'Trio Bar H', matrix: [[1, 1, 1]] },
  { name: 'Trio Bar V', matrix: [[1], [1], [1]] },
  { name: 'Quad Bar H', matrix: [[1, 1, 1, 1]] },
  { name: 'Quad Bar V', matrix: [[1], [1], [1], [1]] },
  {
    name: 'Square 2x2',
    matrix: [
      [1, 1],
      [1, 1],
    ],
  },
  {
    name: 'Corner L3',
    matrix: [
      [1, 0],
      [1, 1],
    ],
  },
  {
    name: 'Corner R3',
    matrix: [
      [0, 1],
      [1, 1],
    ],
  },
  {
    name: 'Relic L4',
    matrix: [
      [1, 0],
      [1, 0],
      [1, 1],
    ],
  },
  {
    name: 'Relic J4',
    matrix: [
      [0, 1],
      [0, 1],
      [1, 1],
    ],
  },
  {
    name: 'Altar T4',
    matrix: [
      [1, 1, 1],
      [0, 1, 0],
    ],
  },
  {
    name: 'Serpent Z4',
    matrix: [
      [1, 1, 0],
      [0, 1, 1],
    ],
  },
  {
    name: 'Serpent S4',
    matrix: [
      [0, 1, 1],
      [1, 1, 0],
    ],
  },
  {
    name: 'Sanctum 3x3 L',
    matrix: [
      [1, 0, 0],
      [1, 0, 0],
      [1, 1, 1],
    ],
  },
  {
    name: 'Cross 5',
    matrix: [
      [0, 1, 0],
      [1, 1, 1],
      [0, 1, 0],
    ],
  },
  {
    name: 'Diagonal Step',
    matrix: [
      [1, 0],
      [0, 1],
    ],
  },
  {
    name: 'Diagonal Step R',
    matrix: [
      [0, 1],
      [1, 0],
    ],
  },
  {
    name: 'Diagonal 3',
    matrix: [
      [1, 0, 0],
      [0, 1, 0],
      [0, 0, 1],
    ],
  },
  {
    name: 'Rect 2x3',
    matrix: [
      [1, 1],
      [1, 1],
      [1, 1],
    ],
  },
  {
    name: 'Rect 3x2',
    matrix: [
      [1, 1, 1],
      [1, 1, 1],
    ],
  },
  {
    name: 'Arch U5',
    matrix: [
      [1, 0, 1],
      [1, 1, 1],
    ],
  },
  {
    name: 'Grand T5',
    matrix: [
      [1, 1, 1],
      [0, 1, 0],
      [0, 1, 0],
    ],
  },
  {
    name: 'Staircase W5',
    matrix: [
      [1, 0, 0],
      [1, 1, 0],
      [0, 1, 1],
    ],
  },
  {
    name: 'Square 3x3',
    matrix: [
      [1, 1, 1],
      [1, 1, 1],
      [1, 1, 1],
    ],
  },
  {
    name: 'Penta Bar H',
    matrix: [[1, 1, 1, 1, 1]],
  },
  {
    name: 'Penta Bar V',
    matrix: [[1], [1], [1], [1], [1]],
  },
];

/**
 * Checks if a coordinate is a void hole for a given GridArchitecture.
 */
export function isVoidCoordinate(architecture: GridArchitecture, row: number, col: number): boolean {
  if (architecture === 'holed') {
    // 2x2 sanctuary hole in the center (rows 3..4, cols 3..4)
    return (row === 3 || row === 4) && (col === 3 || col === 4);
  }
  if (architecture === 'l_shaped') {
    // Top-right 3x3 corner carved out (rows 0..2, cols 5..7)
    return row <= 2 && col >= 5;
  }
  return false;
}

/**
 * Creates a fresh 8x8 board for the given architecture and optional pre-seeded obstacles.
 */
export function createBoard(
  architecture: GridArchitecture = 'standard',
  options?: {
    initialFrozenCount?: number;
    initialBombCount?: number;
    initialGemCount?: number;
    seed?: number;
  }
): GridCell[][] {
  const board: GridCell[][] = [];
  for (let r = 0; r < BOARD_SIZE; r++) {
    const rowCells: GridCell[] = [];
    for (let c = 0; c < BOARD_SIZE; c++) {
      const isVoid = isVoidCoordinate(architecture, r, c);
      rowCells.push({
        row: r,
        col: c,
        kind: isVoid ? 'void' : 'empty',
        color: 'emerald',
        frozenLayers: 0,
        bombTimer: 0,
      });
    }
    board.push(rowCells);
  }

  const frozenCount = options?.initialFrozenCount ?? 0;
  const bombCount = options?.initialBombCount ?? 0;
  let s = options?.seed ?? 1337;
  const nextRand = () => {
    s = (s * 1664525 + 1013904223) % 4294967296;
    return s / 4294967296;
  };

  // Place deterministic initial frozen blocks
  let placedFrozen = 0;
  let attempts = 0;
  while (placedFrozen < frozenCount && attempts < 200) {
    attempts++;
    const r = Math.floor(nextRand() * BOARD_SIZE);
    const c = Math.floor(nextRand() * BOARD_SIZE);
    if (board[r][c].kind === 'empty') {
      board[r][c] = {
        row: r,
        col: c,
        kind: 'frozen',
        color: BLOCK_COLORS[(r + c) % BLOCK_COLORS.length],
        frozenLayers: (placedFrozen % 2 === 0 ? 2 : 3),
        bombTimer: 0,
      };
      placedFrozen++;
    }
  }

  // Place deterministic initial bomb blocks
  let placedBombs = 0;
  attempts = 0;
  while (placedBombs < bombCount && attempts < 200) {
    attempts++;
    const r = Math.floor(nextRand() * BOARD_SIZE);
    const c = Math.floor(nextRand() * BOARD_SIZE);
    if (board[r][c].kind === 'empty') {
      board[r][c] = {
        row: r,
        col: c,
        kind: 'bomb',
        color: 'ruby',
        frozenLayers: 0,
        bombTimer: 5,
      };
      placedBombs++;
    }
  }

  // Place deterministic initial collectible Gem Star blocks
  const gemCount = options?.initialGemCount ?? 0;
  let placedGems = 0;
  attempts = 0;
  while (placedGems < gemCount && attempts < 200) {
    attempts++;
    const r = Math.floor(nextRand() * BOARD_SIZE);
    const c = Math.floor(nextRand() * BOARD_SIZE);
    if (board[r][c].kind === 'empty') {
      board[r][c] = {
        row: r,
        col: c,
        kind: 'normal',
        color: BLOCK_COLORS[(r * 3 + c) % BLOCK_COLORS.length],
        frozenLayers: 0,
        bombTimer: 0,
        hasGem: true,
      };
      placedGems++;
    } else if (board[r][c].kind === 'frozen' && !board[r][c].hasGem) {
      board[r][c].hasGem = true;
      placedGems++;
    }
  }

  return board;
}

/**
 * Deep clones a board state.
 */
export function cloneBoard(board: GridCell[][]): GridCell[][] {
  return board.map((row) => row.map((cell) => ({ ...cell })));
}

/**
 * Rotates a 2D shape matrix 90 degrees clockwise.
 */
export function rotateMatrix90(matrix: number[][]): number[][] {
  const rows = matrix.length;
  const cols = matrix[0].length;
  const rotated: number[][] = Array.from({ length: cols }, () => Array(rows).fill(0));
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      rotated[c][rows - 1 - r] = matrix[r][c];
    }
  }
  return rotated;
}

/**
 * Rotates a TrayPiece 90 degrees clockwise, including its cell modifiers.
 */
export function rotateTrayPiece(piece: TrayPiece): TrayPiece {
  const rows = piece.matrix.length;
  const newMatrix = rotateMatrix90(piece.matrix);
  const newModifiers: PieceCellModifier[] = piece.modifiers.map((mod) => ({
    ...mod,
    dr: mod.dc,
    dc: rows - 1 - mod.dr,
  }));
  return {
    ...piece,
    matrix: newMatrix,
    modifiers: newModifiers,
  };
}

/**
 * Checks whether a piece can be legally placed with its top-left at (anchorRow, anchorCol).
 */
export function canPlacePiece(
  board: GridCell[][],
  piece: TrayPiece,
  anchorRow: number,
  anchorCol: number
): boolean {
  if (piece.used) return false;
  const rows = piece.matrix.length;
  const cols = piece.matrix[0].length;

  for (let dr = 0; dr < rows; dr++) {
    for (let dc = 0; dc < cols; dc++) {
      if (piece.matrix[dr][dc] === 1) {
        const r = anchorRow + dr;
        const c = anchorCol + dc;
        if (r < 0 || r >= BOARD_SIZE || c < 0 || c >= BOARD_SIZE) {
          return false;
        }
        if (board[r][c].kind !== 'empty') {
          return false;
        }
      }
    }
  }
  return true;
}

/**
 * Checks if ANY of the remaining unused tray pieces can fit anywhere on the board.
 */
export function hasAnyValidMove(board: GridCell[][], tray: TrayPiece[]): boolean {
  const available = tray.filter((p) => !p.used);
  if (available.length === 0) return true; // New tray will be dealt

  for (const piece of available) {
    for (let r = 0; r < BOARD_SIZE; r++) {
      for (let c = 0; c < BOARD_SIZE; c++) {
        if (canPlacePiece(board, piece, r, c)) {
          return true;
        }
      }
    }
  }
  return false;
}

/**
 * Finds the first valid (row, col) placement for a piece on the board, preferring center cells.
 */
export function findBestValidPlacement(
  board: GridCell[][],
  piece: TrayPiece
): { row: number; col: number } | null {
  let best: { row: number; col: number; dist: number } | null = null;
  for (let r = 0; r < BOARD_SIZE; r++) {
    for (let c = 0; c < BOARD_SIZE; c++) {
      if (canPlacePiece(board, piece, r, c)) {
        const dist = Math.hypot(r - 3.5, c - 3.5);
        if (!best || dist < best.dist) {
          best = { row: r, col: c, dist };
        }
      }
    }
  }
  return best ? { row: best.row, col: best.col } : null;
}

/**
 * Shifts a playable row horizontally by 1 step to the right (wrapping around non-void cells).
 */
export function shiftBoardRowRight(board: GridCell[][], rowIndex: number): GridCell[][] {
  const next = cloneBoard(board);
  const playableCols: number[] = [];
  for (let c = 0; c < BOARD_SIZE; c++) {
    if (next[rowIndex][c].kind !== 'void') {
      playableCols.push(c);
    }
  }
  if (playableCols.length <= 1) return next;

  const snapshot = playableCols.map((c) => ({ ...next[rowIndex][c] }));
  for (let i = 0; i < playableCols.length; i++) {
    const targetCol = playableCols[(i + 1) % playableCols.length];
    const sourceCell = snapshot[i];
    next[rowIndex][targetCol] = {
      ...sourceCell,
      row: rowIndex,
      col: targetCol,
    };
  }
  return next;
}

/**
 * Computes which rows and columns would complete and clear if `piece` is placed at `(anchorRow, anchorCol)`.
 */
export function getProjectedClearLines(
  board: GridCell[][],
  piece: TrayPiece,
  anchorRow: number,
  anchorCol: number
): { rows: number[]; cols: number[] } {
  if (!canPlacePiece(board, piece, anchorRow, anchorCol)) {
    return { rows: [], cols: [] };
  }

  const occupied = new Set<string>();
  for (let dr = 0; dr < piece.matrix.length; dr++) {
    for (let dc = 0; dc < piece.matrix[0].length; dc++) {
      if (piece.matrix[dr][dc] === 1) {
        occupied.add(`${anchorRow + dr},${anchorCol + dc}`);
      }
    }
  }

  const rows: number[] = [];
  const cols: number[] = [];

  for (let r = 0; r < BOARD_SIZE; r++) {
    let playableCount = 0;
    let filledCount = 0;
    for (let c = 0; c < BOARD_SIZE; c++) {
      const kind = board[r][c].kind;
      if (kind !== 'void') {
        playableCount++;
        if (kind !== 'empty' || occupied.has(`${r},${c}`)) {
          filledCount++;
        }
      }
    }
    if (playableCount > 0 && filledCount === playableCount) {
      rows.push(r);
    }
  }

  for (let c = 0; c < BOARD_SIZE; c++) {
    let playableCount = 0;
    let filledCount = 0;
    for (let r = 0; r < BOARD_SIZE; r++) {
      const kind = board[r][c].kind;
      if (kind !== 'void') {
        playableCount++;
        if (kind !== 'empty' || occupied.has(`${r},${c}`)) {
          filledCount++;
        }
      }
    }
    if (playableCount > 0 && filledCount === playableCount) {
      cols.push(c);
    }
  }

  return { rows, cols };
}

/**
 * Places a piece onto the board and resolves Wildcard conversions, Line Clears,
 * Frozen block layer cracking/shattering, Bomb countdowns/detonations, and Shifting rows.
 */
export function placePieceOnBoard(
  board: GridCell[][],
  piece: TrayPiece,
  anchorRow: number,
  anchorCol: number,
  options?: {
    architecture?: GridArchitecture;
    moveCountAfterPlacement?: number;
    currentComboStreak?: number;
  }
): PlacementResult {
  if (!canPlacePiece(board, piece, anchorRow, anchorCol)) {
    return {
      valid: false,
      board,
      scoreDelta: 0,
      linesCleared: 0,
      comboCount: 0,
      timeBonusSec: 0,
      coinsEarned: 0,
      rubyCleared: 0,
      iceShattered: 0,
      bombsDefused: 0,
      bombsDetonated: 0,
      wildcardsTriggered: 0,
      gemsCollected: 0,
      fullRows: [],
      fullCols: [],
      clearedCells: [],
      events: [],
    };
  }

  const nextBoard = cloneBoard(board);
  const events: PlacementEvent[] = [];
  const newlyPlacedCoords = new Set<string>();
  const placedWildcardCoords: Array<{ r: number; c: number }> = [];
  let blocksPlacedCount = 0;
  let rubyCleared = 0;
  let iceShattered = 0;
  let bombsDefused = 0;
  let bombsDetonated = 0;
  let wildcardsTriggered = 0;
  let gemsCollected = 0;
  const clearedCells: Array<{ row: number; col: number; color: BlockColor; hasGem?: boolean }> = [];

  // 1. Place piece cells onto nextBoard
  for (let dr = 0; dr < piece.matrix.length; dr++) {
    for (let dc = 0; dc < piece.matrix[0].length; dc++) {
      if (piece.matrix[dr][dc] === 1) {
        const r = anchorRow + dr;
        const c = anchorCol + dc;
        const mod = piece.modifiers.find((m) => m.dr === dr && m.dc === dc);
        const kind: CellKind = mod ? mod.kind : 'normal';
        nextBoard[r][c] = {
          row: r,
          col: c,
          kind,
          color: piece.color,
          frozenLayers: kind === 'frozen' ? (mod?.frozenLayers ?? 2) : 0,
          bombTimer: kind === 'bomb' ? (mod?.bombTimer ?? 5) : 0,
          hasGem: Boolean(mod?.hasGem),
        };
        newlyPlacedCoords.add(`${r},${c}`);
        blocksPlacedCount++;
        if (kind === 'wildcard') {
          placedWildcardCoords.push({ r, c });
        }
      }
    }
  }

  // 2. Trigger Wildcard color-shift & 3x3 conversion upon placement
  for (const wc of placedWildcardCoords) {
    wildcardsTriggered++;
    let converted = 0;
    for (let nr = Math.max(0, wc.r - 1); nr <= Math.min(BOARD_SIZE - 1, wc.r + 1); nr++) {
      for (let nc = Math.max(0, wc.c - 1); nc <= Math.min(BOARD_SIZE - 1, wc.c + 1); nc++) {
        const cell = nextBoard[nr][nc];
        if (cell.kind !== 'empty' && cell.kind !== 'void') {
          cell.color = piece.color;
          if (cell.kind === 'frozen' && cell.frozenLayers > 1) {
            cell.frozenLayers = 1; // Wildcard weakens adjacent ice!
          }
          converted++;
        }
      }
    }
    events.push({
      type: 'wildcard_surge',
      row: wc.r,
      col: wc.c,
      count: converted,
      message: `Wildcard Surge harmonized ${converted} relics!`,
    });
  }

  // 3. Identify full rows and columns (where every non-void cell is occupied)
  const fullRows: number[] = [];
  const fullCols: number[] = [];

  for (let r = 0; r < BOARD_SIZE; r++) {
    const playable = nextBoard[r].filter((cell) => cell.kind !== 'void');
    if (playable.length > 0 && playable.every((cell) => cell.kind !== 'empty')) {
      fullRows.push(r);
    }
  }

  for (let c = 0; c < BOARD_SIZE; c++) {
    const playable: GridCell[] = [];
    for (let r = 0; r < BOARD_SIZE; r++) {
      if (nextBoard[r][c].kind !== 'void') {
        playable.push(nextBoard[r][c]);
      }
    }
    if (playable.length > 0 && playable.every((cell) => cell.kind !== 'empty')) {
      fullCols.push(c);
    }
  }

  const linesCleared = fullRows.length + fullCols.length;

  // Collect unique target cells in cleared lines
  const targetCoords = new Set<string>();
  for (const r of fullRows) {
    for (let c = 0; c < BOARD_SIZE; c++) {
      if (nextBoard[r][c].kind !== 'void') {
        targetCoords.add(`${r},${c}`);
      }
    }
  }
  for (const c of fullCols) {
    for (let r = 0; r < BOARD_SIZE; r++) {
      if (nextBoard[r][c].kind !== 'void') {
        targetCoords.add(`${r},${c}`);
      }
    }
  }

  // If any cleared cell is a wildcard, also add its 3x3 neighborhood to targetCoords!
  for (const key of Array.from(targetCoords)) {
    const [r, c] = key.split(',').map(Number);
    if (nextBoard[r][c].kind === 'wildcard') {
      for (let nr = Math.max(0, r - 1); nr <= Math.min(BOARD_SIZE - 1, r + 1); nr++) {
        for (let nc = Math.max(0, c - 1); nc <= Math.min(BOARD_SIZE - 1, c + 1); nc++) {
          if (nextBoard[nr][nc].kind !== 'void' && nextBoard[nr][nc].kind !== 'empty') {
            targetCoords.add(`${nr},${nc}`);
          }
        }
      }
    }
  }

  // 4. Resolve each cell in targetCoords
  for (const key of targetCoords) {
    const [r, c] = key.split(',').map(Number);
    const cell = nextBoard[r][c];
    if (cell.kind === 'empty' || cell.kind === 'void') continue;

    if (cell.kind === 'frozen' && cell.frozenLayers > 1) {
      cell.frozenLayers -= 1;
      events.push({
        type: 'frost_crack',
        row: r,
        col: c,
        count: cell.frozenLayers,
        message: `Frost Relic cracked (${cell.frozenLayers} layer left)`,
      });
    } else {
      if (cell.kind === 'frozen') {
        iceShattered++;
        events.push({
          type: 'ice_shatter',
          row: r,
          col: c,
          message: 'Frozen Relic shattered!',
        });
      } else if (cell.kind === 'bomb') {
        bombsDefused++;
        events.push({
          type: 'bomb_defused',
          row: r,
          col: c,
          message: 'Bomb Relic defused! +250 pts',
        });
      }
      if (cell.color === 'ruby') {
        rubyCleared++;
      }
      if (cell.hasGem) {
        gemsCollected++;
      }
      clearedCells.push({ row: r, col: c, color: cell.color, hasGem: cell.hasGem });
      nextBoard[r][c] = {
        row: r,
        col: c,
        kind: 'empty',
        color: 'emerald',
        frozenLayers: 0,
        bombTimer: 0,
        hasGem: false,
      };
    }
  }

  // 5. Tick down remaining active Bomb blocks that were NOT just placed on this turn
  for (let r = 0; r < BOARD_SIZE; r++) {
    for (let c = 0; c < BOARD_SIZE; c++) {
      const cell = nextBoard[r][c];
      if (cell.kind === 'bomb' && !newlyPlacedCoords.has(`${r},${c}`)) {
        cell.bombTimer -= 1;
        if (cell.bombTimer <= 0) {
          // Detonate! Convert bomb and up to 4 orthogonal neighbor cells into 2-layer Frozen Stone obstacles
          bombsDetonated++;
          cell.kind = 'frozen';
          cell.frozenLayers = 2;
          cell.bombTimer = 0;
          cell.color = 'amethyst';
          const dirs = [
            [-1, 0],
            [1, 0],
            [0, -1],
            [0, 1],
          ];
          for (const [dr, dc] of dirs) {
            const nr = r + dr;
            const nc = c + dc;
            if (nr >= 0 && nr < BOARD_SIZE && nc >= 0 && nc < BOARD_SIZE) {
              if (nextBoard[nr][nc].kind === 'empty' || nextBoard[nr][nc].kind === 'normal') {
                nextBoard[nr][nc] = {
                  row: nr,
                  col: nc,
                  kind: 'frozen',
                  color: 'amethyst',
                  frozenLayers: 2,
                  bombTimer: 0,
                };
              }
            }
          }
          events.push({
            type: 'bomb_detonated',
            row: r,
            col: c,
            message: 'Bomb Detonated! 3x3 sector petrified in Frost!',
          });
        }
      }
    }
  }

  // 6. Shifting Row Architecture mechanic: every 3 moves, shift a middle row right by 1
  const arch = options?.architecture ?? 'standard';
  const moveNum = options?.moveCountAfterPlacement ?? 1;
  let finalBoard = nextBoard;
  if (arch === 'shifting' && moveNum > 0 && moveNum % 3 === 0) {
    const shiftRow = 2 + ((moveNum / 3) % 4); // rows 2, 3, 4, 5
    finalBoard = shiftBoardRowRight(nextBoard, shiftRow);
    events.push({
      type: 'row_shifted',
      row: shiftRow,
      message: `Tectonic Shift slid Row ${shiftRow + 1} right!`,
    });
  }

  // 7. Compute Score, Combo, Coins & Time Bonus
  const prevCombo = options?.currentComboStreak ?? 0;
  const comboCount = linesCleared > 0 ? prevCombo + linesCleared : 0;
  const basePlacementScore = blocksPlacedCount * 10;
  const lineClearScore =
    linesCleared > 0 ? linesCleared * 120 * Math.max(1, linesCleared) + comboCount * 45 : 0;
  const specialBonus =
    iceShattered * 90 + bombsDefused * 250 + wildcardsTriggered * 150;
  const scoreDelta = basePlacementScore + lineClearScore + specialBonus;

  const coinsEarned =
    linesCleared * 6 +
    (linesCleared >= 2 ? linesCleared * 5 : 0) +
    bombsDefused * 15 +
    iceShattered * 8;

  const timeBonusSec = linesCleared > 0 ? linesCleared * 4 + (linesCleared >= 2 ? 4 : 0) : 0;

  if (linesCleared === 1) {
    events.unshift({
      type: 'line_clear',
      count: 1,
      message: 'Line Cleared! +120',
    });
  } else if (linesCleared >= 2) {
    events.unshift({
      type: 'combo_clear',
      count: linesCleared,
      message: `${linesCleared}x Mystic Combo! +${lineClearScore}`,
    });
  }

  return {
    valid: true,
    board: finalBoard,
    scoreDelta,
    linesCleared,
    comboCount,
    timeBonusSec,
    coinsEarned,
    rubyCleared,
    iceShattered,
    bombsDefused,
    bombsDetonated,
    wildcardsTriggered,
    gemsCollected,
    fullRows,
    fullCols,
    clearedCells,
    events,
  };
}

/**
 * Computes the exponential anti-pay-to-win coin cost for deploying a booster in the current session.
 * Returns null if the session cap (MAX_BOOSTER_USES_PER_SESSION) has been reached.
 */
export function getBoosterCoinCost(type: BoosterType, usesThisSession: number): number | null {
  if (usesThisSession >= MAX_BOOSTER_USES_PER_SESSION) {
    return null;
  }
  const base = BASE_BOOSTER_COSTS[type];
  return base * Math.pow(2, usesThisSession);
}

/**
 * Applies the Hammer booster to destroy a single occupied cell at (row, col).
 */
export function applyHammerBooster(
  board: GridCell[][],
  row: number,
  col: number
): {
  success: boolean;
  board: GridCell[][];
  shatteredCell?: GridCell;
} {
  if (row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE) {
    return { success: false, board };
  }
  const target = board[row][col];
  if (target.kind === 'empty' || target.kind === 'void') {
    return { success: false, board };
  }
  const next = cloneBoard(board);
  next[row][col] = {
    row,
    col,
    kind: 'empty',
    color: 'emerald',
    frozenLayers: 0,
    bombTimer: 0,
  };
  return {
    success: true,
    board: next,
    shatteredCell: { ...target },
  };
}

/**
 * Applies the 3x3 Bomb Blast booster centered at (centerRow, centerCol).
 */
export function applyBombBlastBooster(
  board: GridCell[][],
  centerRow: number,
  centerCol: number
): {
  success: boolean;
  board: GridCell[][];
  clearedCount: number;
  gemsCollected: number;
  clearedCells: Array<{ row: number; col: number; color: BlockColor; hasGem?: boolean }>;
} {
  if (centerRow < 0 || centerRow >= BOARD_SIZE || centerCol < 0 || centerCol >= BOARD_SIZE) {
    return { success: false, board, clearedCount: 0, gemsCollected: 0, clearedCells: [] };
  }
  const next = cloneBoard(board);
  let gemsCollected = 0;
  const clearedCells: Array<{ row: number; col: number; color: BlockColor; hasGem?: boolean }> = [];
  for (let r = Math.max(0, centerRow - 1); r <= Math.min(BOARD_SIZE - 1, centerRow + 1); r++) {
    for (let c = Math.max(0, centerCol - 1); c <= Math.min(BOARD_SIZE - 1, centerCol + 1); c++) {
      const cell = next[r][c];
      if (cell.kind !== 'empty' && cell.kind !== 'void') {
        if (cell.hasGem) gemsCollected++;
        clearedCells.push({ row: r, col: c, color: cell.color, hasGem: cell.hasGem });
        next[r][c] = {
          row: r,
          col: c,
          kind: 'empty',
          color: 'emerald',
          frozenLayers: 0,
          bombTimer: 0,
          hasGem: false,
        };
      }
    }
  }
  return {
    success: clearedCells.length > 0,
    board: next,
    clearedCount: clearedCells.length,
    gemsCollected,
    clearedCells,
  };
}

/**
 * Applies the Row & Column Cross Laser Joker centered at (targetRow, targetCol).
 * Clears all occupied cells along both targetRow and targetCol.
 */
export function applyLaserBooster(
  board: GridCell[][],
  targetRow: number,
  targetCol: number
): {
  success: boolean;
  board: GridCell[][];
  clearedCount: number;
  gemsCollected: number;
  clearedCells: Array<{ row: number; col: number; color: BlockColor; hasGem?: boolean }>;
} {
  if (targetRow < 0 || targetRow >= BOARD_SIZE || targetCol < 0 || targetCol >= BOARD_SIZE) {
    return { success: false, board, clearedCount: 0, gemsCollected: 0, clearedCells: [] };
  }
  const next = cloneBoard(board);
  const clearedCells: Array<{ row: number; col: number; color: BlockColor; hasGem?: boolean }> = [];
  let gemsCollected = 0;

  for (let i = 0; i < BOARD_SIZE; i++) {
    // Row sweep
    const rowCell = next[targetRow][i];
    if (rowCell.kind !== 'empty' && rowCell.kind !== 'void') {
      if (rowCell.hasGem) gemsCollected++;
      clearedCells.push({ row: targetRow, col: i, color: rowCell.color, hasGem: rowCell.hasGem });
      next[targetRow][i] = {
        row: targetRow,
        col: i,
        kind: 'empty',
        color: 'emerald',
        frozenLayers: 0,
        bombTimer: 0,
        hasGem: false,
      };
    }
    // Column sweep
    if (i !== targetRow) {
      const colCell = next[i][targetCol];
      if (colCell.kind !== 'empty' && colCell.kind !== 'void') {
        if (colCell.hasGem) gemsCollected++;
        clearedCells.push({ row: i, col: targetCol, color: colCell.color, hasGem: colCell.hasGem });
        next[i][targetCol] = {
          row: i,
          col: targetCol,
          kind: 'empty',
          color: 'emerald',
          frozenLayers: 0,
          bombTimer: 0,
          hasGem: false,
        };
      }
    }
  }

  return {
    success: clearedCells.length > 0,
    board: next,
    clearedCount: clearedCells.length,
    gemsCollected,
    clearedCells,
  };
}

/**
 * Converts a TrayPiece into a 1x1 Pastel Star Block that fits any empty cell.
 */
export function convertPieceToSingleStar(piece: TrayPiece): TrayPiece {
  return {
    ...piece,
    name: '1×1 Pastel Yıldız',
    matrix: [[1]],
    modifiers: [{ dr: 0, dc: 0, kind: 'wildcard', hasGem: true }],
    used: false,
  };
}

/**
 * Generates a set of 3 TrayPieces with optional special blocks (frozen, bomb, wildcard).
 */
export function generateTrayPieces(
  seed: number,
  mode: GameMode = 'classic',
  turnIndex: number = 0
): TrayPiece[] {
  let s = Math.max(1, seed + turnIndex * 7919);
  const nextRand = () => {
    s = (s * 1664525 + 1013904223) % 4294967296;
    return s / 4294967296;
  };

  const tray: TrayPiece[] = [];
  for (let i = 0; i < 3; i++) {
    // Ensure at least 1 compact piece in the tray so players have tactical options
    const pool =
      i === 0
        ? SHAPE_TEMPLATES.slice(0, 10)
        : SHAPE_TEMPLATES;
    const tpl = pool[Math.floor(nextRand() * pool.length)];
    const color = BLOCK_COLORS[Math.floor(nextRand() * BLOCK_COLORS.length)];
    const modifiers: PieceCellModifier[] = [];

    // Find all occupied (dr, dc) in tpl.matrix
    const coords: Array<{ dr: number; dc: number }> = [];
    for (let r = 0; r < tpl.matrix.length; r++) {
      for (let c = 0; c < tpl.matrix[0].length; c++) {
        if (tpl.matrix[r][c] === 1) {
          coords.push({ dr: r, dc: c });
        }
      }
    }

    // Add special block modifiers based on turn and slot
    const roll = nextRand();
    if (coords.length > 0) {
      const pick = coords[Math.floor(nextRand() * coords.length)];
      if (i === 2 && roll < 0.28) {
        modifiers.push({ dr: pick.dr, dc: pick.dc, kind: 'wildcard', hasGem: roll < 0.14 });
      } else if (i === 1 && turnIndex >= 1 && roll < 0.22) {
        modifiers.push({ dr: pick.dr, dc: pick.dc, kind: 'frozen', frozenLayers: 2 });
      } else if (mode !== 'daily' && i === 1 && turnIndex >= 2 && roll > 0.86) {
        modifiers.push({ dr: pick.dr, dc: pick.dc, kind: 'bomb', bombTimer: 5 });
      } else if (roll > 0.45 && roll < 0.72) {
        modifiers.push({ dr: pick.dr, dc: pick.dc, kind: 'normal', hasGem: true });
      }
    }

    tray.push({
      id: `piece-${turnIndex}-${i}-${Math.floor(nextRand() * 100000)}`,
      name: tpl.name,
      matrix: tpl.matrix.map((row) => [...row]),
      color,
      modifiers,
      used: false,
    });
  }

  return tray;
}

const BIOME_NAMES = [
  'Whispering Canopy',
  'Sunken Runestones',
  'Frostfire Sanctum',
  'Obsidian Vault',
  'Amber Rootway',
  'Celestial Observatory',
  'Crystal Cavern',
  'Tectonic Forge',
  'Lunar Reliquary',
  'Aether Citadel',
];

const PASTEL_STAGE_TITLES: Record<number, string> = {
  1: 'Pastel Bahçe',
  2: 'Buzul Şekeri',
  3: 'Lavanta Mozaik',
  4: 'Şeker Kristali',
  5: 'Gökkuşağı Zirvesi',
};

/**
 * Deterministically builds any of the 500 Campaign Stages (including Pastel Blast Adventure stages 1-5)!
 */
export function getCampaignStageConfig(stageNumber: number): CampaignStageConfig {
  const clamped = Math.max(1, Math.min(500, Math.floor(stageNumber)));
  const biomeIndex = Math.min(BIOME_NAMES.length - 1, Math.floor((clamped - 1) / 50));
  const biome = PASTEL_STAGE_TITLES[clamped] || BIOME_NAMES[biomeIndex];

  let architecture: GridArchitecture = 'standard';
  if (clamped > 5) {
    if (clamped % 4 === 2) architecture = 'holed';
    else if (clamped % 4 === 3) architecture = 'shifting';
    else if (clamped % 4 === 0) architecture = 'l_shaped';
  }

  const moveLimit = Math.max(14, 22 - Math.floor(clamped / 120));
  const initialFrozenCount = clamped >= 2 ? Math.min(8, 2 + Math.floor(clamped / 35)) : 2;
  const initialBombCount = clamped >= 3 ? Math.min(3, 1 + Math.floor(clamped / 90)) : 0;
  const initialGemCount = clamped % 2 === 1 ? 6 : 4;

  const objectives: StageObjective[] = [
    {
      type: 'score',
      label: 'Relic Score',
      target: 450 + clamped * 85,
      current: 0,
    },
    {
      type: 'collect_gems',
      label: 'Collect Gem Stars',
      target: Math.min(8, 3 + Math.floor(clamped / 30)),
      current: 0,
    },
    {
      type: 'shatter_ice',
      label: 'Shatter Ice Blocks',
      target: Math.min(10, 2 + Math.floor(clamped / 40)),
      current: 0,
    },
  ];

  if (clamped >= 3) {
    objectives.push({
      type: 'clear_ruby',
      label: 'Clear Ruby Blocks',
      target: Math.min(24, 6 + (clamped % 10)),
      current: 0,
    });
  }

  return {
    stageNumber: clamped,
    title: `Stage ${clamped}: ${biome}`,
    biome,
    architecture,
    moveLimit,
    objectives,
    initialFrozenCount,
    initialBombCount,
    initialGemCount,
    rewardCoins: 60 + clamped * 5,
    rewardStars: 3,
  };
}

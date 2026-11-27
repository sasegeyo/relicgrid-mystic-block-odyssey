import React, { useEffect, useRef } from 'react';
import {
  BOARD_SIZE,
  BLOCK_COLORS,
  BlockColor,
  BoosterType,
  GridArchitecture,
  GridCell,
  ThemeSkinId,
  TrayPiece,
  canPlacePiece,
  findBestValidPlacement,
  getProjectedClearLines,
} from '../game/rules';
import { THEME_SKINS } from '../game/metaState';
import { soundSynth } from '../game/audioSynth';

export type ShellState = 'title' | 'playing' | 'paused' | 'gameover';

export interface CanvasParticleBurst {
  id: number;
  cells: Array<{ row: number; col: number; color: BlockColor }>;
  placedCells?: Array<{ row: number; col: number }>;
  fullRows?: number[];
  fullCols?: number[];
  ringCenter?: { row: number; col: number };
  intensity: 'light' | 'medium' | 'heavy';
  calloutText?: string;
  secondaryBannerText?: string;
}

interface RelicBoardCanvasProps {
  shellState: ShellState;
  board: GridCell[][];
  architecture: GridArchitecture;
  tray: TrayPiece[];
  selectedPieceIndex: number;
  activeTargetingBooster: 'hammer' | 'bomb_blast' | 'laser' | null;
  themeId: ThemeSkinId;
  burstSignal: CanvasParticleBurst | null;
  curtainSignal?: number;
  onSelectPiece: (index: number) => void;
  onPlacePiece: (pieceIndex: number, row: number, col: number) => void;
  onUseTargetBooster: (row: number, col: number) => void;
  onRotatePiece: (pieceIndex: number) => void;
  onRerollTray: () => void;
  onActivateBoosterMode: (booster: BoosterType) => void;
  onStartGame: () => void;
  onTogglePause: () => void;
  onToggleMute: () => void;
}

interface PooledParticle {
  active: boolean;
  x: number;
  y: number;
  vx: number;
  vy: number;
  size: number;
  alpha: number;
  life: number;
  maxLife: number;
  color: string;
  isSpark: boolean;
}

interface PooledFloatingText {
  active: boolean;
  x: number;
  y: number;
  vy: number;
  text: string;
  color: string;
  life: number;
  maxLife: number;
  scale: number;
  isMini: boolean;
}

interface PooledShockwave {
  active: boolean;
  kind: 'row' | 'col' | 'ring';
  indexOrRow: number;
  col: number;
  life: number;
  maxLife: number;
  color: string;
}

interface PlacedCellBounce {
  active: boolean;
  row: number;
  col: number;
  life: number;
  maxLife: number;
}

const MAX_PARTICLES = 220;
const MAX_FLOATING_TEXTS = 36;
const MAX_SHOCKWAVES = 16;
const MAX_CELL_BOUNCES = 24;

export const RelicBoardCanvas: React.FC<RelicBoardCanvasProps> = (props) => {
  const mountRef = useRef<HTMLDivElement | null>(null);
  const propsRef = useRef<RelicBoardCanvasProps>(props);
  propsRef.current = props;

  const lastBurstIdRef = useRef<number>(0);
  const lastCurtainIdRef = useRef<number>(0);
  const requestRedrawRef = useRef<() => void>(() => {});

  // Trigger immediate canvas redraw whenever React props update
  useEffect(() => {
    requestRedrawRef.current();
  });

  useEffect(() => {
    const container = mountRef.current;
    if (!container) return;

    const canvas = document.createElement('canvas');
    canvas.className = 'block w-full h-full cursor-pointer touch-none';
    canvas.setAttribute('data-testid', 'relic-game-canvas');
    canvas.setAttribute('aria-label', 'RelicGrid Puzzle Board Canvas');
    canvas.tabIndex = 0;
    container.innerHTML = '';
    container.appendChild(canvas);

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Viewport & Layout Geometry Cache
    let width = container.clientWidth || window.innerWidth || 1440;
    let height = container.clientHeight || window.innerHeight || 900;
    let dpr = Math.min(window.devicePixelRatio || 1, 2);

    const updateCanvasSize = () => {
      if (!container) return;
      const rect = container.getBoundingClientRect();
      width = Math.max(320, rect.width || window.innerWidth);
      height = Math.max(480, rect.height || window.innerHeight);
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.round(width * dpr);
      canvas.height = Math.round(height * dpr);
    };
    updateCanvasSize();

    const resizeObserver = new ResizeObserver(() => {
      updateCanvasSize();
      requestRedrawRef.current();
    });
    resizeObserver.observe(container);

    // Zero-GC Pooled Particle Ring Buffer
    const particles: PooledParticle[] = Array.from({ length: MAX_PARTICLES }, () => ({
      active: false,
      x: 0,
      y: 0,
      vx: 0,
      vy: 0,
      size: 4,
      alpha: 1,
      life: 0,
      maxLife: 1,
      color: '#FBBF24',
      isSpark: false,
    }));
    let particleHead = 0;

    const spawnParticle = (
      x: number,
      y: number,
      vx: number,
      vy: number,
      size: number,
      maxLife: number,
      color: string,
      isSpark = false
    ) => {
      const p = particles[particleHead];
      particleHead = (particleHead + 1) % MAX_PARTICLES;
      p.active = true;
      p.x = x;
      p.y = y;
      p.vx = vx;
      p.vy = vy;
      p.size = size;
      p.alpha = 1;
      p.life = 0;
      p.maxLife = maxLife;
      p.color = color;
      p.isSpark = isSpark;
    };

    // Zero-GC Pooled Floating Combo Banners & Mini Tile Popups
    const floatingTexts: PooledFloatingText[] = Array.from({ length: MAX_FLOATING_TEXTS }, () => ({
      active: false,
      x: 0,
      y: 0,
      vy: -54,
      text: '',
      color: '#FDE68A',
      life: 0,
      maxLife: 1.2,
      scale: 1,
      isMini: false,
    }));
    let textHead = 0;

    const spawnFloatingText = (
      x: number,
      y: number,
      text: string,
      color: string,
      scale = 1.15,
      isMini = false
    ) => {
      const ft = floatingTexts[textHead];
      textHead = (textHead + 1) % MAX_FLOATING_TEXTS;
      ft.active = true;
      ft.x = x;
      ft.y = y;
      ft.vy = isMini ? -38 : -56;
      ft.text = text;
      ft.color = color;
      ft.life = 0;
      ft.maxLife = isMini ? 0.78 : 1.25;
      ft.scale = scale;
      ft.isMini = isMini;
    };

    // 8x8 Rainbow Curtain Wipe Animation State
    const curtainPalette: BlockColor[] = BLOCK_COLORS;
    const curtainAnim = {
      active: false,
      progress: 0,
      duration: 0.72,
      colors: Array.from({ length: BOARD_SIZE }, (_, r) =>
        Array.from({ length: BOARD_SIZE }, (_, c) => curtainPalette[(r + c) % curtainPalette.length])
      ),
    };

    // Zero-GC Pooled Shockwaves (Row Beams, Col Beams & Blast Rings)
    const shockwaves: PooledShockwave[] = Array.from({ length: MAX_SHOCKWAVES }, () => ({
      active: false,
      kind: 'row',
      indexOrRow: 0,
      col: 0,
      life: 0,
      maxLife: 0.45,
      color: '#FDE68A',
    }));
    let shockwaveHead = 0;

    const spawnShockwave = (
      kind: 'row' | 'col' | 'ring',
      indexOrRow: number,
      col: number,
      color: string
    ) => {
      const sw = shockwaves[shockwaveHead];
      shockwaveHead = (shockwaveHead + 1) % MAX_SHOCKWAVES;
      sw.active = true;
      sw.kind = kind;
      sw.indexOrRow = indexOrRow;
      sw.col = col;
      sw.life = 0;
      sw.maxLife = kind === 'ring' ? 0.52 : 0.44;
      sw.color = color;
    };

    // Zero-GC Per-Cell Placement Squash & Bounce Pool
    const cellBounces: PlacedCellBounce[] = Array.from({ length: MAX_CELL_BOUNCES }, () => ({
      active: false,
      row: 0,
      col: 0,
      life: 0,
      maxLife: 0.24,
    }));
    let bounceHead = 0;

    const spawnCellBounce = (row: number, col: number) => {
      const cb = cellBounces[bounceHead];
      bounceHead = (bounceHead + 1) % MAX_CELL_BOUNCES;
      cb.active = true;
      cb.row = row;
      cb.col = col;
      cb.life = 0;
      cb.maxLife = 0.24;
    };

    // Ambient Fireflies / Embers (Fixed array, zero GC)
    const embers = Array.from({ length: 36 }, (_, i) => ({
      x: ((i * 197) % 100) / 100,
      y: ((i * 313) % 100) / 100,
      speedY: 0.012 + (i % 5) * 0.004,
      driftX: 0.008 + (i % 3) * 0.004,
      phase: i * 0.7,
      radius: 1.5 + (i % 3) * 1.1,
    }));

    // Simulation state
    let simTime = 0;
    let hitstopTimer = 0;
    let cameraTrauma = 0;
    let boardSquash = 0;
    let pointerX = width * 0.5;
    let pointerY = height * 0.5;
    let isDragging = false;
    let cursorRow = 3;
    let cursorCol = 3;
    let hoverRow = -1;
    let hoverCol = -1;

    // Unified Input Hub
    const heldKeys = new Set<string>();
    const justPressedKeys = new Set<string>();

    const clearInputs = () => {
      heldKeys.clear();
      justPressedKeys.clear();
      isDragging = false;
    };

    /**
     * Mobile-First Vertically Stacked Viewport Geometry:
     * Top HUD (~114px) -> 8x8 Carved Relic Grid -> 3-Piece Tray -> Dedicated Bottom Booster Bar (~94px)
     */
    const computeLayout = () => {
      const isTitle = propsRef.current.shellState === 'title';
      const minDim = Math.min(width, height);

      if (isTitle) {
        const cellSize = Math.max(28, Math.min(48, Math.floor(minDim * 0.052)));
        const boardPx = cellSize * BOARD_SIZE;
        const boardCenterX = width >= 900 ? width * 0.68 : width * 0.5;
        const boardCenterY = width >= 900 ? height * 0.5 : height * 0.66;
        const boardLeft = Math.round(boardCenterX - boardPx / 2);
        const boardTop = Math.round(boardCenterY - boardPx / 2);
        return {
          cellSize,
          boardPx,
          boardLeft,
          boardTop,
          boardCenterX,
          boardCenterY,
          trayTop: boardTop + boardPx + 18,
          traySlotWidth: Math.floor(boardPx / 3),
          trayHeight: 84,
        };
      }

      // Playing / Paused / Gameover Mobile-First Centered Stack
      const topSafe = height < 740 ? 96 : 114;
      const bottomBoosterSafe = height < 740 ? 84 : 98;
      const availableVertical = Math.max(300, height - topSafe - bottomBoosterSafe);
      const maxContainerWidth = Math.min(width - 24, 448);

      // Fit 8 board rows + 0.45 gap + 2.15 tray height inside availableVertical
      const cellByHeight = Math.floor(availableVertical / (BOARD_SIZE + 2.65));
      const cellByWidth = Math.floor((maxContainerWidth - 20) / BOARD_SIZE);
      const cellSize = Math.max(28, Math.min(50, Math.min(cellByHeight, cellByWidth)));
      const boardPx = cellSize * BOARD_SIZE;

      const trayGap = Math.max(12, Math.floor(cellSize * 0.36));
      const trayHeight = Math.max(76, Math.floor(cellSize * 2.08));
      const totalStackHeight = boardPx + trayGap + trayHeight;

      const boardCenterX = width * 0.5;
      const stackTop = Math.round(
        topSafe + Math.max(4, (availableVertical - totalStackHeight) * 0.42)
      );
      const boardTop = stackTop;
      const boardLeft = Math.round(boardCenterX - boardPx / 2);
      const boardCenterY = boardTop + boardPx / 2;

      const trayTop = boardTop + boardPx + trayGap;
      const traySlotWidth = Math.floor(boardPx / 3);

      return {
        cellSize,
        boardPx,
        boardLeft,
        boardTop,
        boardCenterX,
        boardCenterY,
        trayTop,
        traySlotWidth,
        trayHeight,
      };
    };

    const screenToCanvas = (clientX: number, clientY: number) => {
      const rect = canvas.getBoundingClientRect();
      return {
        x: clientX - rect.left,
        y: clientY - rect.top,
      };
    };

    const updateHoverGridFromPointer = (cx: number, cy: number, applyDragLift = false) => {
      const layout = computeLayout();
      const p = propsRef.current;
      const selectedPiece = p.tray[p.selectedPieceIndex];

      // When dragging with finger/mouse, lift piece slightly above pointer for clear visibility
      const effectiveY = applyDragLift ? cy - layout.cellSize * 0.65 : cy;

      const floatCol = (cx - layout.boardLeft) / layout.cellSize;
      const floatRow = (effectiveY - layout.boardTop) / layout.cellSize;

      // Allow slight magnetic margin around the 8x8 board when dragging or hovering
      if (
        floatRow >= -0.85 &&
        floatRow <= BOARD_SIZE + 0.85 &&
        floatCol >= -0.85 &&
        floatCol <= BOARD_SIZE + 0.85
      ) {
        if (p.activeTargetingBooster) {
          const r = Math.max(0, Math.min(BOARD_SIZE - 1, Math.floor(floatRow)));
          const c = Math.max(0, Math.min(BOARD_SIZE - 1, Math.floor(floatCol)));
          hoverRow = r;
          hoverCol = c;
          cursorRow = r;
          cursorCol = c;
          return;
        }

        if (selectedPiece && !selectedPiece.used) {
          const pieceRows = selectedPiece.matrix.length;
          const pieceCols = selectedPiece.matrix[0].length;
          const anchorFloatRow = floatRow - (pieceRows - 1) * 0.5;
          const anchorFloatCol = floatCol - (pieceCols - 1) * 0.5;

          const baseRow = Math.max(0, Math.min(BOARD_SIZE - pieceRows, Math.round(anchorFloatRow)));
          const baseCol = Math.max(0, Math.min(BOARD_SIZE - pieceCols, Math.round(anchorFloatCol)));

          if (canPlacePiece(p.board, selectedPiece, baseRow, baseCol)) {
            hoverRow = baseRow;
            hoverCol = baseCol;
            cursorRow = baseRow;
            cursorCol = baseCol;
            return;
          }

          // Magnetic snap: search 1-cell neighborhood sorted by distance to pointer anchor
          let bestNeighbor: { row: number; col: number; distSq: number } | null = null;
          for (let dr = -1; dr <= 1; dr++) {
            for (let dc = -1; dc <= 1; dc++) {
              if (dr === 0 && dc === 0) continue;
              const nr = baseRow + dr;
              const nc = baseCol + dc;
              if (nr < 0 || nr > BOARD_SIZE - pieceRows || nc < 0 || nc > BOARD_SIZE - pieceCols) {
                continue;
              }
              if (canPlacePiece(p.board, selectedPiece, nr, nc)) {
                const dRow = nr - anchorFloatRow;
                const dCol = nc - anchorFloatCol;
                const distSq = dRow * dRow + dCol * dCol;
                if (!bestNeighbor || distSq < bestNeighbor.distSq) {
                  bestNeighbor = { row: nr, col: nc, distSq };
                }
              }
            }
          }

          if (bestNeighbor && bestNeighbor.distSq <= 1.85) {
            hoverRow = bestNeighbor.row;
            hoverCol = bestNeighbor.col;
            cursorRow = bestNeighbor.row;
            cursorCol = bestNeighbor.col;
            return;
          }

          hoverRow = baseRow;
          hoverCol = baseCol;
          cursorRow = baseRow;
          cursorCol = baseCol;
          return;
        }
      }

      hoverRow = -1;
      hoverCol = -1;
    };

    const handlePointerDown = (e: PointerEvent) => {
      const p = propsRef.current;
      const pt = screenToCanvas(e.clientX, e.clientY);
      pointerX = pt.x;
      pointerY = pt.y;

      if (p.shellState !== 'playing') return;

      const layout = computeLayout();

      // Check if touching/clicking one of the 3 Tray Pieces
      if (
        pt.y >= layout.trayTop - 10 &&
        pt.y <= layout.trayTop + layout.trayHeight + 14 &&
        pt.x >= layout.boardLeft - 18 &&
        pt.x <= layout.boardLeft + layout.boardPx + 18
      ) {
        const slotIdx = Math.min(
          2,
          Math.max(0, Math.floor((pt.x - layout.boardLeft) / layout.traySlotWidth))
        );
        if (p.tray[slotIdx] && !p.tray[slotIdx].used) {
          soundSynth.playSelect();
          p.onSelectPiece(slotIdx);
          isDragging = true;
          requestRedrawRef.current();
          return;
        }
      }

      // Check if clicking directly onto the Board
      updateHoverGridFromPointer(pt.x, pt.y, false);
      if (hoverRow >= 0 && hoverCol >= 0) {
        if (p.activeTargetingBooster) {
          p.onUseTargetBooster(hoverRow, hoverCol);
          requestRedrawRef.current();
          return;
        }
        const piece = p.tray[p.selectedPieceIndex];
        if (piece && !piece.used && canPlacePiece(p.board, piece, hoverRow, hoverCol)) {
          boardSquash = 1;
          p.onPlacePiece(p.selectedPieceIndex, hoverRow, hoverCol);
          hoverRow = -1;
          hoverCol = -1;
          isDragging = false;
          requestRedrawRef.current();
          return;
        }
      }
    };

    const handlePointerMove = (e: PointerEvent) => {
      const pt = screenToCanvas(e.clientX, e.clientY);
      pointerX = pt.x;
      pointerY = pt.y;
      if (propsRef.current.shellState === 'playing') {
        const prevR = hoverRow;
        const prevC = hoverCol;
        updateHoverGridFromPointer(pt.x, pt.y, isDragging);
        if (isDragging && hoverRow >= 0 && hoverCol >= 0 && (hoverRow !== prevR || hoverCol !== prevC)) {
          soundSynth.playTick();
        }
        requestRedrawRef.current();
      }
    };

    const handlePointerUp = (e: PointerEvent) => {
      if (!isDragging) return;
      const wasDragging = isDragging;
      isDragging = false;
      const p = propsRef.current;
      if (p.shellState !== 'playing') return;
      const pt = screenToCanvas(e.clientX, e.clientY);
      updateHoverGridFromPointer(pt.x, pt.y, wasDragging);
      if (hoverRow >= 0 && hoverCol >= 0) {
        const piece = p.tray[p.selectedPieceIndex];
        if (piece && !piece.used && canPlacePiece(p.board, piece, hoverRow, hoverCol)) {
          boardSquash = 1;
          p.onPlacePiece(p.selectedPieceIndex, hoverRow, hoverCol);
          hoverRow = -1;
          hoverCol = -1;
        }
      }
      requestRedrawRef.current();
    };

    const handleKeyDown = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement | null)?.tagName;
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;

      const code = e.code;
      if (!heldKeys.has(code)) {
        justPressedKeys.add(code);
      }
      heldKeys.add(code);

      const p = propsRef.current;

      if (p.shellState === 'title') {
        if (code === 'Enter' || code === 'Space') {
          e.preventDefault();
          p.onStartGame();
        }
        return;
      }

      if (code === 'Escape' || code === 'KeyP') {
        e.preventDefault();
        p.onTogglePause();
        return;
      }

      if (code === 'KeyM') {
        e.preventDefault();
        p.onToggleMute();
        return;
      }

      if (p.shellState !== 'playing') return;

      if (code === 'Digit1' || code === 'Numpad1') {
        soundSynth.playSelect();
        p.onSelectPiece(0);
      } else if (code === 'Digit2' || code === 'Numpad2') {
        soundSynth.playSelect();
        p.onSelectPiece(1);
      } else if (code === 'Digit3' || code === 'Numpad3') {
        soundSynth.playSelect();
        p.onSelectPiece(2);
      } else if (code === 'KeyR') {
        e.preventDefault();
        p.onRotatePiece(p.selectedPieceIndex);
      } else if (code === 'KeyF') {
        e.preventDefault();
        p.onRerollTray();
      } else if (code === 'KeyH') {
        e.preventDefault();
        p.onActivateBoosterMode('hammer');
      } else if (code === 'KeyB') {
        e.preventDefault();
        p.onActivateBoosterMode('bomb_blast');
      } else if (code === 'KeyL') {
        e.preventDefault();
        p.onActivateBoosterMode('laser');
      } else if (code === 'KeyG') {
        e.preventDefault();
        p.onActivateBoosterMode('single_star');
      } else if (code === 'ArrowUp' || code === 'KeyW') {
        e.preventDefault();
        cursorRow = Math.max(0, cursorRow - 1);
        hoverRow = cursorRow;
        if (hoverCol < 0) hoverCol = cursorCol;
        requestRedrawRef.current();
      } else if (code === 'ArrowDown' || code === 'KeyS') {
        e.preventDefault();
        cursorRow = Math.min(BOARD_SIZE - 1, cursorRow + 1);
        hoverRow = cursorRow;
        if (hoverCol < 0) hoverCol = cursorCol;
        requestRedrawRef.current();
      } else if (code === 'ArrowLeft' || code === 'KeyA') {
        e.preventDefault();
        cursorCol = Math.max(0, cursorCol - 1);
        hoverCol = cursorCol;
        if (hoverRow < 0) hoverRow = cursorRow;
        requestRedrawRef.current();
      } else if (code === 'ArrowRight' || code === 'KeyD') {
        e.preventDefault();
        cursorCol = Math.min(BOARD_SIZE - 1, cursorCol + 1);
        hoverCol = cursorCol;
        if (hoverRow < 0) hoverRow = cursorRow;
        requestRedrawRef.current();
      } else if (code === 'Space' || code === 'Enter') {
        e.preventDefault();
        const targetR = hoverRow >= 0 ? hoverRow : cursorRow;
        const targetC = hoverCol >= 0 ? hoverCol : cursorCol;

        if (p.activeTargetingBooster) {
          p.onUseTargetBooster(targetR, targetC);
          return;
        }

        const piece = p.tray[p.selectedPieceIndex];
        if (piece && !piece.used) {
          if (canPlacePiece(p.board, piece, targetR, targetC)) {
            boardSquash = 1;
            p.onPlacePiece(p.selectedPieceIndex, targetR, targetC);
          } else {
            const best = findBestValidPlacement(p.board, piece);
            if (best) {
              cursorRow = best.row;
              cursorCol = best.col;
              hoverRow = best.row;
              hoverCol = best.col;
              boardSquash = 1;
              p.onPlacePiece(p.selectedPieceIndex, best.row, best.col);
            }
          }
        }
      }
    };

    const handleKeyUp = (e: KeyboardEvent) => {
      heldKeys.delete(e.code);
    };

    const handleVisibilityChange = () => {
      if (document.hidden) clearInputs();
    };

    canvas.addEventListener('pointerdown', handlePointerDown);
    window.addEventListener('pointermove', handlePointerMove);
    window.addEventListener('pointerup', handlePointerUp);
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    window.addEventListener('blur', clearInputs);
    document.addEventListener('visibilitychange', handleVisibilityChange);

    /**
     * Renders a High-Fidelity 3D Beveled & Glossy Gem Relic Block
     * with Dynamic Obstacle & Opportunity states (Frozen Cracks, Neon Fuse Bomb, Chromatic Wildcard, Embedded Gem Star).
     */
    const drawRelicBlock = (
      x: number,
      y: number,
      size: number,
      colorKey: BlockColor,
      kind: GridCell['kind'],
      frozenLayers: number,
      bombTimer: number,
      themeId: ThemeSkinId,
      alpha: number = 1,
      scaleFactor: number = 1,
      hasGem: boolean = false
    ) => {
      const theme = THEME_SKINS[themeId] || THEME_SKINS.pastel_blast;
      const palette = theme.blocks[colorKey] || theme.blocks.emerald;
      const pad = Math.max(1.5, size * 0.045);
      const rawBs = size - pad * 2;
      if (rawBs <= 4) return;

      const bs = rawBs * scaleFactor;
      const bx = x + (size - bs) / 2;
      const by = y + (size - bs) / 2;
      const bevel = Math.max(3, Math.floor(bs * 0.14));

      ctx.save();
      ctx.globalAlpha = alpha;

      // 1. Dark Outer Carved Silhouette + Drop Depth
      ctx.fillStyle = '#030806';
      ctx.beginPath();
      ctx.roundRect(bx - 1, by - 1, bs + 2, bs + 2.5, 6);
      ctx.fill();

      // 2. Main Block Base Fill (or Prismatic Rainbow Gradient for Wildcard)
      if (kind === 'wildcard') {
        const hue1 = Math.floor((simTime * 110) % 360);
        const hue2 = (hue1 + 120) % 360;
        const hue3 = (hue1 + 240) % 360;
        const rainbowGrad = ctx.createLinearGradient(bx, by, bx + bs, by + bs);
        rainbowGrad.addColorStop(0, `hsl(${hue1}, 88%, 60%)`);
        rainbowGrad.addColorStop(0.5, `hsl(${hue2}, 90%, 55%)`);
        rainbowGrad.addColorStop(1, `hsl(${hue3}, 88%, 58%)`);
        ctx.fillStyle = rainbowGrad;
      } else {
        ctx.fillStyle = palette.fill;
      }
      ctx.beginPath();
      ctx.roundRect(bx, by, bs, bs, 5);
      ctx.fill();

      // 3. 3D Top & Left Specular Bevel Faces
      ctx.fillStyle = kind === 'wildcard' ? 'rgba(255, 255, 255, 0.48)' : palette.topHighlight;
      ctx.beginPath();
      ctx.moveTo(bx + 2, by);
      ctx.lineTo(bx + bs - 2, by);
      ctx.lineTo(bx + bs - bevel, by + bevel);
      ctx.lineTo(bx + bevel, by + bevel);
      ctx.closePath();
      ctx.fill();

      ctx.fillStyle = 'rgba(255, 255, 255, 0.18)';
      ctx.beginPath();
      ctx.moveTo(bx, by + 2);
      ctx.lineTo(bx + bevel, by + bevel);
      ctx.lineTo(bx + bevel, by + bs - bevel);
      ctx.lineTo(bx, by + bs - 2);
      ctx.closePath();
      ctx.fill();

      // 4. 3D Bottom & Right Deep Bevel Faces
      ctx.fillStyle = kind === 'wildcard' ? 'rgba(15, 23, 42, 0.45)' : palette.bottomShadow;
      ctx.beginPath();
      ctx.moveTo(bx + bevel, by + bs - bevel);
      ctx.lineTo(bx + bs - bevel, by + bs - bevel);
      ctx.lineTo(bx + bs - 2, by + bs);
      ctx.lineTo(bx + 2, by + bs);
      ctx.closePath();
      ctx.fill();

      ctx.fillStyle = 'rgba(0, 0, 0, 0.28)';
      ctx.beginPath();
      ctx.moveTo(bx + bs - bevel, by + bevel);
      ctx.lineTo(bx + bs, by + 2);
      ctx.lineTo(bx + bs, by + bs - 2);
      ctx.lineTo(bx + bs - bevel, by + bs - bevel);
      ctx.closePath();
      ctx.fill();

      // 5. Raised Center Gem Facet + Glossy Diagonal Glassmorphic Sheen
      const innerX = bx + bevel;
      const innerY = by + bevel;
      const innerS = bs - bevel * 2;
      if (innerS > 4) {
        const faceGrad = ctx.createLinearGradient(innerX, innerY, innerX, innerY + innerS);
        if (kind === 'wildcard') {
          faceGrad.addColorStop(0, 'rgba(255, 255, 255, 0.35)');
          faceGrad.addColorStop(1, 'rgba(255, 255, 255, 0.05)');
        } else {
          faceGrad.addColorStop(0, palette.topHighlight);
          faceGrad.addColorStop(0.35, palette.fill);
          faceGrad.addColorStop(1, palette.bottomShadow);
        }
        ctx.fillStyle = faceGrad;
        ctx.beginPath();
        ctx.roundRect(innerX, innerY, innerS, innerS, 3);
        ctx.fill();

        // Diagonal glossy glass highlight
        ctx.fillStyle = 'rgba(255, 255, 255, 0.26)';
        ctx.beginPath();
        ctx.moveTo(innerX + 2, innerY + 1);
        ctx.lineTo(innerX + innerS * 0.65, innerY + 1);
        ctx.lineTo(innerX + innerS * 0.3, innerY + innerS * 0.55);
        ctx.lineTo(innerX + 1, innerY + innerS * 0.55);
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = 'rgba(255, 255, 255, 0.32)';
        ctx.lineWidth = 0.9;
        ctx.strokeRect(innerX + 0.5, innerY + 0.5, innerS - 1, innerS - 1);
      }

      // 5B. Embedded Adventure Gem Star (Block Blast Pastel Edition feature)
      if (hasGem && kind === 'normal') {
        const cx = bx + bs * 0.5;
        const cy = by + bs * 0.5;
        const outerR = bs * 0.28;
        const innerR = bs * 0.13;
        ctx.save();
        ctx.fillStyle = '#FFF6A9';
        ctx.strokeStyle = '#C97A00';
        ctx.lineWidth = 1.3;
        ctx.beginPath();
        for (let i = 0; i < 10; i++) {
          const rad = i % 2 === 0 ? outerR : innerR;
          const angle = -Math.PI / 2 + (i * Math.PI) / 5;
          const px = cx + Math.cos(angle) * rad;
          const py = cy + Math.sin(angle) * rad;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        ctx.restore();
      }

      // 6. Dynamic Obstacle & Opportunity Overlays
      if (kind === 'frozen') {
        // Multi-stage Icy Glaze & Realistic Frost Cracks
        const frostGrad = ctx.createLinearGradient(bx, by, bx + bs, by + bs);
        frostGrad.addColorStop(
          0,
          frozenLayers >= 3 ? 'rgba(224, 242, 254, 0.78)' : 'rgba(186, 230, 253, 0.58)'
        );
        frostGrad.addColorStop(1, 'rgba(56, 189, 248, 0.42)');
        ctx.fillStyle = frostGrad;
        ctx.beginPath();
        ctx.roundRect(bx + 1, by + 1, bs - 2, bs - 2, 4);
        ctx.fill();

        // Ice Rim Border
        ctx.strokeStyle = '#E0F2FE';
        ctx.lineWidth = 1.6;
        ctx.strokeRect(bx + 1.5, by + 1.5, bs - 3, bs - 3);

        // Multi-stage Fracture Network (more cracks as frozenLayers decreases)
        ctx.strokeStyle = '#FFFFFF';
        ctx.lineWidth = 1.6;
        ctx.beginPath();
        ctx.moveTo(bx + 4, by + 5);
        ctx.lineTo(bx + bs * 0.46, by + bs * 0.44);
        ctx.lineTo(bx + bs - 5, by + 7);
        if (frozenLayers <= 2) {
          ctx.moveTo(bx + bs * 0.46, by + bs * 0.44);
          ctx.lineTo(bx + bs * 0.32, by + bs - 5);
          ctx.moveTo(bx + 5, by + bs * 0.62);
          ctx.lineTo(bx + bs * 0.46, by + bs * 0.44);
        }
        if (frozenLayers === 1) {
          ctx.moveTo(bx + bs * 0.46, by + bs * 0.44);
          ctx.lineTo(bx + bs - 4, by + bs - 6);
          ctx.moveTo(bx + bs * 0.72, by + bs * 0.28);
          ctx.lineTo(bx + bs * 0.85, by + bs * 0.65);
        }
        ctx.stroke();

        // Icy Sparkle Gleam on top-left corner
        const gleamX = bx + bs * 0.24;
        const gleamY = by + bs * 0.24;
        ctx.fillStyle = '#FFFFFF';
        ctx.beginPath();
        ctx.moveTo(gleamX, gleamY - 4);
        ctx.lineTo(gleamX + 1.4, gleamY - 1.4);
        ctx.lineTo(gleamX + 4, gleamY);
        ctx.lineTo(gleamX + 1.4, gleamY + 1.4);
        ctx.lineTo(gleamX, gleamY + 4);
        ctx.lineTo(gleamX - 1.4, gleamY + 1.4);
        ctx.lineTo(gleamX - 4, gleamY);
        ctx.lineTo(gleamX - 1.4, gleamY - 1.4);
        ctx.closePath();
        ctx.fill();

        // Layer Counter Pill Badge
        if (bs >= 24) {
          ctx.fillStyle = '#082F49';
          ctx.beginPath();
          ctx.arc(bx + bs - 8.5, by + bs - 8.5, 7, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = '#7DD3FC';
          ctx.lineWidth = 1.2;
          ctx.stroke();

          ctx.fillStyle = '#F0F9FF';
          ctx.font = '700 9.5px "JetBrains Mono", monospace';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillText(`${frozenLayers}`, bx + bs - 8.5, by + bs - 8);
        }
      } else if (kind === 'bomb') {
        const urgent = bombTimer <= 2;
        const pulse = 0.5 + 0.5 * Math.sin(simTime * (urgent ? 16 : 6));

        if (urgent) {
          ctx.fillStyle = `rgba(239, 68, 68, ${(0.28 + pulse * 0.42).toFixed(2)})`;
          ctx.beginPath();
          ctx.roundRect(bx, by, bs, bs, 5);
          ctx.fill();

          ctx.strokeStyle = `rgba(254, 240, 138, ${(0.5 + pulse * 0.5).toFixed(2)})`;
          ctx.lineWidth = 2;
          ctx.strokeRect(bx + 1, by + 1, bs - 2, bs - 2);
        }

        const cx = bx + bs * 0.48;
        const cy = by + bs * 0.55;
        const radius = bs * 0.31;

        const fuseEndX = cx + radius * 0.85;
        const fuseEndY = cy - radius * 0.95;
        ctx.strokeStyle = '#FBBF24';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(cx + radius * 0.35, cy - radius * 0.65);
        ctx.quadraticCurveTo(cx + radius * 0.9, cy - radius * 0.7, fuseEndX, fuseEndY);
        ctx.stroke();

        const sparkR = (urgent ? 3.8 : 2.6) + pulse * 1.8;
        ctx.fillStyle = urgent ? '#EF4444' : '#F59E0B';
        ctx.beginPath();
        ctx.arc(fuseEndX, fuseEndY, sparkR + 1.5, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#FEF08A';
        ctx.beginPath();
        ctx.arc(fuseEndX, fuseEndY, sparkR * 0.65, 0, Math.PI * 2);
        ctx.fill();

        const bombGrad = ctx.createRadialGradient(
          cx - radius * 0.3,
          cy - radius * 0.3,
          1,
          cx,
          cy,
          radius
        );
        bombGrad.addColorStop(0, '#475569');
        bombGrad.addColorStop(0.5, '#0F172A');
        bombGrad.addColorStop(1, '#020617');
        ctx.fillStyle = bombGrad;
        ctx.beginPath();
        ctx.arc(cx, cy, radius, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = urgent ? '#FCA5A5' : '#FBBF24';
        ctx.lineWidth = 1.5;
        ctx.stroke();

        ctx.fillStyle = urgent ? '#FEF08A' : '#FFFFFF';
        ctx.font = `800 ${Math.max(10, Math.floor(bs * 0.34))}px "JetBrains Mono", monospace`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(`${bombTimer}`, cx, cy + 1);
      } else if (kind === 'wildcard') {
        const cx = bx + bs / 2;
        const cy = by + bs / 2;
        const outerR = bs * 0.33;
        const innerR = bs * 0.15;

        ctx.strokeStyle = '#FEF08A';
        ctx.lineWidth = 1.6;
        ctx.strokeRect(bx + 1.5, by + 1.5, bs - 3, bs - 3);

        ctx.fillStyle = '#FFFBEB';
        ctx.strokeStyle = '#78350F';
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        for (let i = 0; i < 10; i++) {
          const angle = (i * Math.PI) / 5 - Math.PI / 2 + simTime * 1.6;
          const r = i % 2 === 0 ? outerR : innerR;
          const px = cx + Math.cos(angle) * r;
          const py = cy + Math.sin(angle) * r;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
      }

      ctx.restore();
    };

    // Main 60Hz Simulation & Render Loop
    let lastTime = performance.now();
    let rafId = 0;
    const isDisposedRef = { current: false };

    const tick = (now: number) => {
      if (isDisposedRef.current) return;

      const rawDt = (now - lastTime) / 1000;
      lastTime = now;
      const dt = Math.min(Math.max(rawDt, 0.001), 0.05);

      const p = propsRef.current;
      const theme = THEME_SKINS[p.themeId] || THEME_SKINS.pastel_blast;
      const layout = computeLayout();

      // Trigger 8x8 Rainbow Curtain Wipe when curtainSignal increments
      if (p.curtainSignal && p.curtainSignal !== lastCurtainIdRef.current) {
        lastCurtainIdRef.current = p.curtainSignal;
        curtainAnim.active = true;
        curtainAnim.progress = 0;
        for (let r = 0; r < BOARD_SIZE; r++) {
          for (let c = 0; c < BOARD_SIZE; c++) {
            curtainAnim.colors[r][c] =
              curtainPalette[(r + c + Math.floor(Math.random() * 2)) % curtainPalette.length];
          }
        }
        soundSynth.playCurtain();
      }

      if (curtainAnim.active) {
        curtainAnim.progress += dt / curtainAnim.duration;
        if (curtainAnim.progress >= 1) {
          curtainAnim.active = false;
        }
      }

      // Process Incoming Burst, Shockwaves, Cell Bounces, Mini Popups & Floating Combo Banners
      if (p.burstSignal && p.burstSignal.id !== lastBurstIdRef.current) {
        lastBurstIdRef.current = p.burstSignal.id;
        const sig = p.burstSignal;
        const isHeavy = sig.intensity === 'heavy';
        const isMedium = sig.intensity === 'medium';

        hitstopTimer = isHeavy ? 0.06 : isMedium ? 0.035 : 0;
        cameraTrauma = Math.min(
          1,
          cameraTrauma + (isHeavy ? 0.62 : isMedium ? 0.34 : 0.1)
        );

        // Register placement bounce animations
        if (sig.placedCells) {
          for (const pc of sig.placedCells) {
            spawnCellBounce(pc.row, pc.col);
          }
        }

        // Register Row & Column Shockwave Beams
        if (sig.fullRows) {
          for (const r of sig.fullRows) {
            spawnShockwave('row', r, 0, '#FDE68A');
          }
        }
        if (sig.fullCols) {
          for (const c of sig.fullCols) {
            spawnShockwave('col', c, 0, '#6EE7B7');
          }
        }
        if (sig.ringCenter) {
          spawnShockwave('ring', sig.ringCenter.row, sig.ringCenter.col, '#FBBF24');
        }

        // Explosive Debris, Spark Particles & Per-Tile Mini Score Popups (+10 / +15)
        let miniCount = 0;
        for (const cell of sig.cells) {
          const cx = layout.boardLeft + (cell.col + 0.5) * layout.cellSize;
          const cy = layout.boardTop + (cell.row + 0.5) * layout.cellSize;
          const pal = theme.blocks[cell.color] || theme.blocks.amber;
          const count = isHeavy ? 8 : isMedium ? 5 : 3;
          for (let i = 0; i < count; i++) {
            const angle = Math.random() * Math.PI * 2;
            const speed = (isHeavy ? 135 : 75) + Math.random() * 165;
            spawnParticle(
              cx,
              cy,
              Math.cos(angle) * speed,
              Math.sin(angle) * speed - 45,
              3.5 + Math.random() * 4.5,
              0.45 + Math.random() * 0.38,
              i % 3 === 0 ? '#FEF08A' : i % 2 === 0 ? pal.topHighlight : pal.fill,
              i % 2 === 0
            );
          }
          if ((isMedium || isHeavy) && miniCount < 10 && miniCount % 2 === 0) {
            spawnFloatingText(cx, cy - 2, isHeavy ? '+15' : '+10', '#FFFFFF', 0.72, true);
          }
          miniCount++;
        }

        if (sig.calloutText) {
          spawnFloatingText(
            layout.boardCenterX,
            layout.boardTop + layout.boardPx * 0.42,
            sig.calloutText,
            '#FDE68A',
            isHeavy ? 1.32 : 1.12,
            false
          );
        }
        if (sig.secondaryBannerText) {
          spawnFloatingText(
            layout.boardCenterX,
            layout.boardTop + layout.boardPx * 0.26,
            sig.secondaryBannerText,
            '#6EE7B7',
            1.42,
            false
          );
        }
      }

      if (hitstopTimer > 0) {
        hitstopTimer = Math.max(0, hitstopTimer - dt);
      }
      const simDt = hitstopTimer > 0 || p.shellState === 'paused' ? 0 : dt;
      simTime += simDt;

      // Decay camera trauma & board bounce
      cameraTrauma = Math.max(0, cameraTrauma - dt * 2.5);
      boardSquash = Math.max(0, boardSquash - dt * 7);

      const shakeMag = cameraTrauma * cameraTrauma * 13;
      const shakeX = shakeMag > 0.1 ? (Math.random() * 2 - 1) * shakeMag : 0;
      const shakeY = shakeMag > 0.1 ? (Math.random() * 2 - 1) * shakeMag : 0;

      ctx.save();
      ctx.scale(dpr, dpr);

      // 1. Atmospheric Sanctuary Radial Canvas Backdrop
      const bgGrad = ctx.createRadialGradient(
        layout.boardCenterX,
        layout.boardCenterY,
        30,
        layout.boardCenterX,
        layout.boardCenterY,
        Math.max(width, height) * 0.85
      );
      bgGrad.addColorStop(0, theme.canvasBgEnd);
      bgGrad.addColorStop(1, theme.canvasBgStart);
      ctx.fillStyle = bgGrad;
      ctx.fillRect(0, 0, width, height);

      // Subtle Carved Halo Rings around the Board
      ctx.save();
      ctx.strokeStyle = 'rgba(255, 217, 90, 0.08)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(layout.boardCenterX, layout.boardCenterY, layout.boardPx * 0.66, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();

      // 2. Ambient Drifting Golden Embers
      for (const e of embers) {
        e.y -= e.speedY * (simDt || dt * 0.3);
        if (e.y < -0.05) e.y = 1.05;
        const ex = ((e.x + Math.sin(simTime * 0.8 + e.phase) * e.driftX + 1) % 1) * width;
        const ey = e.y * height;
        const alpha = 0.18 + 0.24 * Math.sin(simTime * 2.2 + e.phase);
        ctx.fillStyle = `rgba(251, 191, 36, ${alpha.toFixed(3)})`;
        ctx.beginPath();
        ctx.arc(ex, ey, e.radius, 0, Math.PI * 2);
        ctx.fill();
      }

      // Apply Camera Shake + Placement Squash-and-Stretch Impulse
      ctx.save();
      const parallaxX =
        p.shellState === 'title' ? ((pointerX - width * 0.5) / width) * 14 : 0;
      const parallaxY =
        p.shellState === 'title' ? ((pointerY - height * 0.5) / height) * 10 : 0;

      const squashScaleX = 1 + boardSquash * 0.016;
      const squashScaleY = 1 - boardSquash * 0.016;

      ctx.translate(
        layout.boardCenterX + shakeX + parallaxX,
        layout.boardCenterY + shakeY + parallaxY
      );
      ctx.scale(squashScaleX, squashScaleY);
      ctx.translate(-layout.boardCenterX, -layout.boardCenterY);

      // 3. Carved Stone / Pastel Block Blast Board Frame
      const framePad = 10;
      ctx.fillStyle = '#030806';
      ctx.beginPath();
      ctx.roundRect(
        layout.boardLeft - framePad - 3,
        layout.boardTop - framePad - 3,
        layout.boardPx + (framePad + 3) * 2,
        layout.boardPx + (framePad + 3) * 2,
        18
      );
      ctx.fill();

      ctx.fillStyle = theme.boardFrameFill;
      ctx.strokeStyle = theme.boardFrameStroke;
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.roundRect(
        layout.boardLeft - framePad,
        layout.boardTop - framePad,
        layout.boardPx + framePad * 2,
        layout.boardPx + framePad * 2,
        15
      );
      ctx.fill();
      ctx.stroke();

      // Shifting Architecture Row Telegraph Arrows
      if (p.architecture === 'shifting') {
        for (let r = 2; r <= 5; r++) {
          const ry = layout.boardTop + (r + 0.5) * layout.cellSize;
          ctx.fillStyle = 'rgba(251, 191, 36, 0.65)';
          ctx.beginPath();
          ctx.moveTo(layout.boardLeft - 7, ry - 4);
          ctx.lineTo(layout.boardLeft - 1.5, ry);
          ctx.lineTo(layout.boardLeft - 7, ry + 4);
          ctx.closePath();
          ctx.fill();
        }
      }

      // Compute active cell bounce scale map
      const getCellBounceScale = (r: number, c: number): number => {
        for (let i = 0; i < MAX_CELL_BOUNCES; i++) {
          const cb = cellBounces[i];
          if (cb.active && cb.row === r && cb.col === c) {
            const t = cb.life / cb.maxLife;
            return 1 + Math.sin(t * Math.PI) * 0.16;
          }
        }
        return 1;
      };

      // Update active cell bounces
      for (let i = 0; i < MAX_CELL_BOUNCES; i++) {
        const cb = cellBounces[i];
        if (!cb.active) continue;
        cb.life += dt;
        if (cb.life >= cb.maxLife) cb.active = false;
      }

      // Pre-compute Ghost Placement & Projected Line Clears for Block Blast Color-Shift Anticipation
      let previewR = hoverRow >= 0 ? hoverRow : cursorRow;
      let previewC = hoverCol >= 0 ? hoverCol : cursorCol;
      const activePiece =
        p.shellState === 'playing' && !p.activeTargetingBooster
          ? p.tray[p.selectedPieceIndex]
          : null;

      if (
        activePiece &&
        !activePiece.used &&
        hoverRow < 0 &&
        !canPlacePiece(p.board, activePiece, previewR, previewC)
      ) {
        const bestSnap = findBestValidPlacement(p.board, activePiece);
        if (bestSnap) {
          cursorRow = bestSnap.row;
          cursorCol = bestSnap.col;
          previewR = bestSnap.row;
          previewC = bestSnap.col;
        }
      }

      const validGhostPlacement =
        Boolean(activePiece && !activePiece.used && previewR >= 0 && previewC >= 0) &&
        canPlacePiece(p.board, activePiece!, previewR, previewC);

      const projectedLines =
        validGhostPlacement && activePiece
          ? getProjectedClearLines(p.board, activePiece, previewR, previewC)
          : { rows: [], cols: [] };

      const projectedRowSet = new Set(projectedLines.rows);
      const projectedColSet = new Set(projectedLines.cols);

      // 4. Render 8x8 Carved / Checkerboard Grid Sockets & Placed 3D Blocks
      for (let r = 0; r < BOARD_SIZE; r++) {
        for (let c = 0; c < BOARD_SIZE; c++) {
          const cell = p.board[r][c];
          const cx = layout.boardLeft + c * layout.cellSize;
          const cy = layout.boardTop + r * layout.cellSize;
          const s = layout.cellSize;

          if (cell.kind === 'void') {
            ctx.fillStyle = theme.cellVoidFill;
            ctx.beginPath();
            ctx.roundRect(cx + 2, cy + 2, s - 4, s - 4, 6);
            ctx.fill();
            ctx.strokeStyle = 'rgba(217, 155, 38, 0.16)';
            ctx.lineWidth = 1;
            ctx.stroke();
            continue;
          }

          // Recessed Carved / Checkerboard Socket Base
          const isEvenCell = (r + c) % 2 === 0;
          ctx.fillStyle = isEvenCell
            ? theme.cellEmptyFill
            : theme.cellEmptyFillAlt || theme.cellEmptyFill;
          ctx.beginPath();
          ctx.roundRect(cx + 1.5, cy + 1.5, s - 3, s - 3, 5.5);
          ctx.fill();

          // Recessed Inner Top-Left Shadow
          ctx.strokeStyle = 'rgba(0, 0, 0, 0.45)';
          ctx.lineWidth = 1.4;
          ctx.beginPath();
          ctx.moveTo(cx + 2.5, cy + s - 3);
          ctx.lineTo(cx + 2.5, cy + 2.5);
          ctx.lineTo(cx + s - 3, cy + 2.5);
          ctx.stroke();

          // Subtle Bottom-Right Socket Rim Highlight
          ctx.strokeStyle = theme.cellEmptyStroke;
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(cx + s - 2, cy + 3);
          ctx.lineTo(cx + s - 2, cy + s - 2);
          ctx.lineTo(cx + 3, cy + s - 2);
          ctx.stroke();

          // Faint Etched Center Rune Dot inside empty socket
          if (cell.kind === 'empty' && p.shellState !== 'title') {
            ctx.fillStyle = 'rgba(255, 255, 255, 0.045)';
            ctx.beginPath();
            ctx.arc(cx + s / 2, cy + s / 2, 2, 0, Math.PI * 2);
            ctx.fill();
          }

          // Title Screen Animated Showcase Blocks
          if (p.shellState === 'title' && cell.kind === 'empty') {
            const wave = Math.sin(simTime * 2.1 + r * 0.55 + c * 0.45);
            if (wave > 0.35) {
              const demoColors: BlockColor[] = ['emerald', 'amber', 'sapphire', 'ruby', 'amethyst'];
              const colKey = demoColors[(r * 3 + c) % demoColors.length];
              const demoKind =
                r === 2 && c === 5
                  ? 'frozen'
                  : r === 5 && c === 2
                    ? 'wildcard'
                    : r === 4 && c === 6
                      ? 'bomb'
                      : 'normal';
              drawRelicBlock(
                cx,
                cy,
                s,
                colKey,
                demoKind,
                2,
                2,
                p.themeId,
                Math.min(1, (wave - 0.35) * 2.2),
                1,
                r === 3 && c === 3
              );
            }
          } else if (cell.kind !== 'empty') {
            const bScale = getCellBounceScale(r, c);
            const isAnticipatingClear =
              validGhostPlacement &&
              activePiece &&
              (projectedRowSet.has(r) || projectedColSet.has(c));

            // Block Blast Color-Shift Line Anticipation: shift clearing line blocks to the active piece's color!
            const displayColor =
              isAnticipatingClear && activePiece ? activePiece.color : cell.color;

            drawRelicBlock(
              cx,
              cy,
              s,
              displayColor,
              cell.kind,
              cell.frozenLayers,
              cell.bombTimer,
              p.themeId,
              1,
              isAnticipatingClear ? Math.max(bScale, 1.03) : bScale,
              Boolean(cell.hasGem)
            );

            if (isAnticipatingClear) {
              ctx.save();
              ctx.strokeStyle = 'rgba(255, 255, 255, 0.92)';
              ctx.lineWidth = 2.2;
              ctx.beginPath();
              ctx.roundRect(cx + 2, cy + 2, s - 4, s - 4, 5);
              ctx.stroke();
              ctx.restore();
            }
          }
        }
      }

      // 5. Render High-Transparency 'Ghost' Piece Projection + Clear-Line Projections + Booster Aiming
      if (p.shellState === 'playing') {
        if (p.activeTargetingBooster && previewR >= 0 && previewC >= 0) {
          if (p.activeTargetingBooster === 'laser') {
            // Cross-Laser Full Row + Full Column Highlight
            for (let i = 0; i < BOARD_SIZE; i++) {
              const rowX = layout.boardLeft + i * layout.cellSize;
              const rowY = layout.boardTop + previewR * layout.cellSize;
              ctx.fillStyle = 'rgba(56, 189, 248, 0.34)';
              ctx.strokeStyle = '#66E8FF';
              ctx.lineWidth = 2;
              ctx.beginPath();
              ctx.roundRect(rowX + 2, rowY + 2, layout.cellSize - 4, layout.cellSize - 4, 5);
              ctx.fill();
              ctx.stroke();

              if (i !== previewR) {
                const colX = layout.boardLeft + previewC * layout.cellSize;
                const colY = layout.boardTop + i * layout.cellSize;
                ctx.beginPath();
                ctx.roundRect(colX + 2, colY + 2, layout.cellSize - 4, layout.cellSize - 4, 5);
                ctx.fill();
                ctx.stroke();
              }
            }
          } else {
            const isBomb = p.activeTargetingBooster === 'bomb_blast';
            const minR = isBomb ? Math.max(0, previewR - 1) : previewR;
            const maxR = isBomb ? Math.min(BOARD_SIZE - 1, previewR + 1) : previewR;
            const minC = isBomb ? Math.max(0, previewC - 1) : previewC;
            const maxC = isBomb ? Math.min(BOARD_SIZE - 1, previewC + 1) : previewC;

            for (let r = minR; r <= maxR; r++) {
              for (let c = minC; c <= maxC; c++) {
                const cx = layout.boardLeft + c * layout.cellSize;
                const cy = layout.boardTop + r * layout.cellSize;
                ctx.fillStyle = 'rgba(239, 68, 68, 0.34)';
                ctx.strokeStyle = '#FEF08A';
                ctx.lineWidth = 2.2;
                ctx.beginPath();
                ctx.roundRect(cx + 2, cy + 2, layout.cellSize - 4, layout.cellSize - 4, 5);
                ctx.fill();
                ctx.stroke();
              }
            }
          }
        } else if (activePiece && !activePiece.used && previewR >= 0 && previewC >= 0) {
          const piece = activePiece;
          const valid = validGhostPlacement;
          const projected = projectedLines;
          const totalProjectedLines = projected.rows.length + projected.cols.length;
          const ghostPulse = 0.5 + 0.5 * Math.sin(simTime * 7);

          // 5A. Highlight Projected Line Clears (Full Row/Col Beams + Per-Cell Clear Frames)
          if (valid && totalProjectedLines > 0) {
            const beamAlpha = 0.24 + 0.18 * ghostPulse;

            for (const pr of projected.rows) {
              const ry = layout.boardTop + pr * layout.cellSize;
              const rowGrad = ctx.createLinearGradient(
                layout.boardLeft,
                ry,
                layout.boardLeft + layout.boardPx,
                ry
              );
              rowGrad.addColorStop(0, `rgba(253, 230, 138, ${(beamAlpha * 0.65).toFixed(2)})`);
              rowGrad.addColorStop(0.5, `rgba(254, 240, 138, ${(beamAlpha * 1.25).toFixed(2)})`);
              rowGrad.addColorStop(1, `rgba(253, 230, 138, ${(beamAlpha * 0.65).toFixed(2)})`);

              ctx.fillStyle = rowGrad;
              ctx.fillRect(layout.boardLeft + 1, ry + 1, layout.boardPx - 2, layout.cellSize - 2);

              ctx.strokeStyle = '#FEF08A';
              ctx.lineWidth = 2.2;
              ctx.strokeRect(
                layout.boardLeft + 1.5,
                ry + 1.5,
                layout.boardPx - 3,
                layout.cellSize - 3
              );
            }

            for (const pc of projected.cols) {
              const rx = layout.boardLeft + pc * layout.cellSize;
              const colGrad = ctx.createLinearGradient(
                rx,
                layout.boardTop,
                rx,
                layout.boardTop + layout.boardPx
              );
              colGrad.addColorStop(0, `rgba(110, 231, 183, ${(beamAlpha * 0.65).toFixed(2)})`);
              colGrad.addColorStop(0.5, `rgba(167, 243, 208, ${(beamAlpha * 1.25).toFixed(2)})`);
              colGrad.addColorStop(1, `rgba(110, 231, 183, ${(beamAlpha * 0.65).toFixed(2)})`);

              ctx.fillStyle = colGrad;
              ctx.fillRect(rx + 1, layout.boardTop + 1, layout.cellSize - 2, layout.boardPx - 2);

              ctx.strokeStyle = '#6EE7B7';
              ctx.lineWidth = 2.2;
              ctx.strokeRect(
                rx + 1.5,
                layout.boardTop + 1.5,
                layout.cellSize - 3,
                layout.boardPx - 3
              );
            }
          }

          // 5B. Render Snapped High-Transparency 'Ghost' Piece Cells
          const s = layout.cellSize;
          const bracketLen = Math.max(5, Math.floor(s * 0.22));

          for (let dr = 0; dr < piece.matrix.length; dr++) {
            for (let dc = 0; dc < piece.matrix[0].length; dc++) {
              if (piece.matrix[dr][dc] === 1) {
                const r = previewR + dr;
                const c = previewC + dc;
                if (r >= 0 && r < BOARD_SIZE && c >= 0 && c < BOARD_SIZE) {
                  const cx = layout.boardLeft + c * s;
                  const cy = layout.boardTop + r * s;
                  const mod = piece.modifiers.find((m) => m.dr === dr && m.dc === dc);

                  if (valid) {
                    drawRelicBlock(
                      cx,
                      cy,
                      s,
                      piece.color,
                      mod ? mod.kind : 'normal',
                      mod?.frozenLayers ?? 2,
                      mod?.bombTimer ?? 5,
                      p.themeId,
                      0.38 + 0.08 * ghostPulse,
                      0.94,
                      Boolean(mod?.hasGem)
                    );

                    ctx.save();
                    ctx.fillStyle =
                      totalProjectedLines > 0
                        ? 'rgba(254, 240, 138, 0.18)'
                        : 'rgba(110, 231, 183, 0.12)';
                    ctx.beginPath();
                    ctx.roundRect(cx + 2.5, cy + 2.5, s - 5, s - 5, 5);
                    ctx.fill();

                    ctx.strokeStyle =
                      totalProjectedLines > 0
                        ? 'rgba(254, 240, 138, 0.72)'
                        : 'rgba(167, 243, 208, 0.62)';
                    ctx.lineWidth = 1.25;
                    ctx.setLineDash([4, 3]);
                    ctx.strokeRect(cx + 3.5, cy + 3.5, s - 7, s - 7);
                    ctx.setLineDash([]);

                    // 4 Tactile Corner Snap Brackets
                    ctx.strokeStyle = totalProjectedLines > 0 ? '#FEF08A' : '#6EE7B7';
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.moveTo(cx + 2, cy + 2 + bracketLen);
                    ctx.lineTo(cx + 2, cy + 2);
                    ctx.lineTo(cx + 2 + bracketLen, cy + 2);
                    ctx.moveTo(cx + s - 2 - bracketLen, cy + 2);
                    ctx.lineTo(cx + s - 2, cy + 2);
                    ctx.lineTo(cx + s - 2, cy + 2 + bracketLen);
                    ctx.moveTo(cx + s - 2, cy + s - 2 - bracketLen);
                    ctx.lineTo(cx + s - 2, cy + s - 2);
                    ctx.lineTo(cx + s - 2 - bracketLen, cy + s - 2);
                    ctx.moveTo(cx + 2 + bracketLen, cy + s - 2);
                    ctx.lineTo(cx + 2, cy + s - 2);
                    ctx.lineTo(cx + 2, cy + s - 2 - bracketLen);
                    ctx.stroke();

                    ctx.fillStyle = totalProjectedLines > 0 ? '#FEF08A' : '#A7F3D0';
                    ctx.beginPath();
                    ctx.arc(cx + s / 2, cy + s / 2, 2.2, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.restore();
                  } else {
                    drawRelicBlock(
                      cx,
                      cy,
                      s,
                      piece.color,
                      mod ? mod.kind : 'normal',
                      mod?.frozenLayers ?? 2,
                      mod?.bombTimer ?? 5,
                      p.themeId,
                      0.2,
                      0.92,
                      Boolean(mod?.hasGem)
                    );
                    ctx.save();
                    ctx.fillStyle = 'rgba(239, 68, 68, 0.24)';
                    ctx.beginPath();
                    ctx.roundRect(cx + 2.5, cy + 2.5, s - 5, s - 5, 5);
                    ctx.fill();

                    ctx.strokeStyle = 'rgba(248, 113, 113, 0.85)';
                    ctx.lineWidth = 1.6;
                    ctx.setLineDash([4, 3]);
                    ctx.strokeRect(cx + 3, cy + 3, s - 6, s - 6);
                    ctx.setLineDash([]);
                    ctx.restore();
                  }
                }
              }
            }
          }

          // 5C. Floating Line-Clear Projection Tag Above Ghost Piece
          if (valid && totalProjectedLines > 0) {
            const ghostCenterX =
              layout.boardLeft + (previewC + piece.matrix[0].length * 0.5) * s;
            const ghostTopY = Math.max(
              layout.boardTop + 14,
              layout.boardTop + previewR * s - 10
            );
            const label =
              totalProjectedLines >= 2
                ? `CLEAR x${totalProjectedLines}!`
                : 'LINE CLEAR!';

            ctx.save();
            ctx.font = '800 10.5px "JetBrains Mono", monospace';
            const textW = ctx.measureText(label).width;
            const pillW = textW + 14;
            const pillH = 18;
            ctx.fillStyle = 'rgba(6, 20, 15, 0.92)';
            ctx.strokeStyle = '#FEF08A';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.roundRect(ghostCenterX - pillW / 2, ghostTopY - pillH / 2, pillW, pillH, 9);
            ctx.fill();
            ctx.stroke();

            ctx.fillStyle = '#FEF08A';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(label, ghostCenterX, ghostTopY + 0.5);
            ctx.restore();
          }
        }
      }

      // 5D. Iconic 8x8 Block Blast Rainbow Curtain Wipe Overlay
      if (curtainAnim.active) {
        const pProg = curtainAnim.progress;
        let fillRows = 0;
        if (pProg < 0.46) {
          fillRows = Math.ceil((pProg / 0.46) * BOARD_SIZE);
          for (let r = BOARD_SIZE - 1; r >= BOARD_SIZE - fillRows; r--) {
            for (let c = 0; c < BOARD_SIZE; c++) {
              drawRelicBlock(
                layout.boardLeft + c * layout.cellSize,
                layout.boardTop + r * layout.cellSize,
                layout.cellSize,
                curtainAnim.colors[r][c],
                'normal',
                0,
                0,
                p.themeId,
                1,
                1
              );
            }
          }
        } else if (pProg < 0.56) {
          for (let r = 0; r < BOARD_SIZE; r++) {
            for (let c = 0; c < BOARD_SIZE; c++) {
              drawRelicBlock(
                layout.boardLeft + c * layout.cellSize,
                layout.boardTop + r * layout.cellSize,
                layout.cellSize,
                curtainAnim.colors[r][c],
                'normal',
                0,
                0,
                p.themeId,
                1,
                1
              );
            }
          }
        } else {
          const rem = 1 - (pProg - 0.56) / 0.44;
          fillRows = Math.ceil(Math.max(0, rem) * BOARD_SIZE);
          for (let r = BOARD_SIZE - 1; r >= BOARD_SIZE - fillRows; r--) {
            for (let c = 0; c < BOARD_SIZE; c++) {
              drawRelicBlock(
                layout.boardLeft + c * layout.cellSize,
                layout.boardTop + r * layout.cellSize,
                layout.cellSize,
                curtainAnim.colors[r][c],
                'normal',
                0,
                0,
                p.themeId,
                1,
                1
              );
            }
          }
        }
      }

      // 6. Update & Render Line Clear / Blast Shockwave Beams & Rings
      for (let i = 0; i < MAX_SHOCKWAVES; i++) {
        const sw = shockwaves[i];
        if (!sw.active) continue;
        sw.life += dt;
        if (sw.life >= sw.maxLife) {
          sw.active = false;
          continue;
        }
        const progress = sw.life / sw.maxLife;
        const alpha = 1 - progress;

        ctx.save();
        ctx.globalAlpha = Math.max(0, alpha);

        if (sw.kind === 'row') {
          const cy = layout.boardTop + (sw.indexOrRow + 0.5) * layout.cellSize;
          const beamHalfH = layout.cellSize * (0.65 * (1 - progress * 0.5));
          const spanW = layout.boardPx * (0.4 + 0.65 * Math.sin(progress * Math.PI * 0.5));
          const grad = ctx.createLinearGradient(
            layout.boardCenterX - spanW / 2,
            cy,
            layout.boardCenterX + spanW / 2,
            cy
          );
          grad.addColorStop(0, 'rgba(253, 230, 138, 0)');
          grad.addColorStop(0.5, '#FEF08A');
          grad.addColorStop(1, 'rgba(253, 230, 138, 0)');
          ctx.fillStyle = grad;
          ctx.fillRect(
            layout.boardCenterX - spanW / 2,
            cy - beamHalfH,
            spanW,
            beamHalfH * 2
          );
        } else if (sw.kind === 'col') {
          const cx = layout.boardLeft + (sw.indexOrRow + 0.5) * layout.cellSize;
          const beamHalfW = layout.cellSize * (0.65 * (1 - progress * 0.5));
          const spanH = layout.boardPx * (0.4 + 0.65 * Math.sin(progress * Math.PI * 0.5));
          const grad = ctx.createLinearGradient(
            cx,
            layout.boardCenterY - spanH / 2,
            cx,
            layout.boardCenterY + spanH / 2
          );
          grad.addColorStop(0, 'rgba(110, 231, 183, 0)');
          grad.addColorStop(0.5, '#A7F3D0');
          grad.addColorStop(1, 'rgba(110, 231, 183, 0)');
          ctx.fillStyle = grad;
          ctx.fillRect(
            cx - beamHalfW,
            layout.boardCenterY - spanH / 2,
            beamHalfW * 2,
            spanH
          );
        } else if (sw.kind === 'ring') {
          const cx = layout.boardLeft + (sw.col + 0.5) * layout.cellSize;
          const cy = layout.boardTop + (sw.indexOrRow + 0.5) * layout.cellSize;
          const radius = layout.cellSize * (0.5 + progress * 2.4);
          ctx.strokeStyle = sw.color;
          ctx.lineWidth = Math.max(1.5, (1 - progress) * 7);
          ctx.beginPath();
          ctx.arc(cx, cy, radius, 0, Math.PI * 2);
          ctx.stroke();
        }
        ctx.restore();
      }

      // 7. Render 3-Piece Tactician Tray Below Board (with 1.1x Lift & Drop-Shadow)
      if (p.shellState !== 'title') {
        const trayLeft = layout.boardLeft;
        const trayWidth = layout.boardPx;

        // Recessed Tray Dock Surface
        ctx.fillStyle = 'rgba(15, 23, 42, 0.72)';
        ctx.strokeStyle = 'rgba(255, 217, 90, 0.38)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.roundRect(trayLeft - 8, layout.trayTop, trayWidth + 16, layout.trayHeight, 14);
        ctx.fill();
        ctx.stroke();

        const baseMiniCell = Math.max(15, Math.min(23, Math.floor(layout.cellSize * 0.47)));

        for (let i = 0; i < 3; i++) {
          const piece = p.tray[i];
          const slotX = trayLeft + i * layout.traySlotWidth;
          const slotCenterX = slotX + layout.traySlotWidth / 2;
          const slotCenterY = layout.trayTop + layout.trayHeight / 2;
          const isSelected = i === p.selectedPieceIndex && piece && !piece.used;
          const isBeingDragged = isSelected && isDragging;

          if (isSelected) {
            ctx.fillStyle = 'rgba(245, 158, 11, 0.16)';
            ctx.strokeStyle = '#FBBF24';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.roundRect(
              slotX + 4,
              layout.trayTop + 5,
              layout.traySlotWidth - 8,
              layout.trayHeight - 10,
              10
            );
            ctx.fill();
            ctx.stroke();
          }

          ctx.fillStyle = isSelected ? '#FBBF24' : 'rgba(226, 232, 240, 0.55)';
          ctx.font = '700 10.5px "JetBrains Mono", monospace';
          ctx.textAlign = 'left';
          ctx.textBaseline = 'top';
          ctx.fillText(`[${i + 1}]`, slotX + 10, layout.trayTop + 9);

          if (!piece || piece.used) {
            ctx.fillStyle = 'rgba(148, 163, 184, 0.25)';
            ctx.font = '600 11px "Plus Jakarta Sans", sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('PLACED', slotCenterX, slotCenterY);
            continue;
          }

          if (isBeingDragged) {
            continue;
          }

          const scaleMult = isSelected ? 1.1 : 1.0;
          const miniCell = Math.round(baseMiniCell * scaleMult);
          const liftY = isSelected ? -4 : 3;

          const rows = piece.matrix.length;
          const cols = piece.matrix[0].length;
          const pWidth = cols * miniCell;
          const pHeight = rows * miniCell;
          const startX = Math.round(slotCenterX - pWidth / 2);
          const startY = Math.round(slotCenterY - pHeight / 2 + liftY);

          const fitsAnywhere = findBestValidPlacement(p.board, piece) !== null;

          ctx.save();
          if (isSelected) {
            ctx.shadowColor = 'rgba(0, 0, 0, 0.65)';
            ctx.shadowBlur = 10;
            ctx.shadowOffsetY = 6;
          }

          for (let r = 0; r < rows; r++) {
            for (let c = 0; c < cols; c++) {
              if (piece.matrix[r][c] === 1) {
                const mod = piece.modifiers.find((m) => m.dr === r && m.dc === c);
                drawRelicBlock(
                  startX + c * miniCell,
                  startY + r * miniCell,
                  miniCell,
                  piece.color,
                  mod ? mod.kind : 'normal',
                  mod?.frozenLayers ?? 2,
                  mod?.bombTimer ?? 5,
                  p.themeId,
                  fitsAnywhere ? 1 : 0.38,
                  1,
                  Boolean(mod?.hasGem)
                );
              }
            }
          }
          ctx.restore();
        }

        const draggedPiece = p.tray[p.selectedPieceIndex];
        if (isDragging && draggedPiece && !draggedPiece.used) {
          const dragCell = Math.round(layout.cellSize * 0.86);
          const rows = draggedPiece.matrix.length;
          const cols = draggedPiece.matrix[0].length;
          const pWidth = cols * dragCell;
          const pHeight = rows * dragCell;
          const startX = Math.round(pointerX - pWidth / 2);
          const startY = Math.round(pointerY - layout.cellSize * 0.65 - pHeight / 2);

          ctx.save();
          ctx.shadowColor = 'rgba(0, 0, 0, 0.78)';
          ctx.shadowBlur = 18;
          ctx.shadowOffsetY = 12;

          for (let r = 0; r < rows; r++) {
            for (let c = 0; c < cols; c++) {
              if (draggedPiece.matrix[r][c] === 1) {
                const mod = draggedPiece.modifiers.find((m) => m.dr === r && m.dc === c);
                drawRelicBlock(
                  startX + c * dragCell,
                  startY + r * dragCell,
                  dragCell,
                  draggedPiece.color,
                  mod ? mod.kind : 'normal',
                  mod?.frozenLayers ?? 2,
                  mod?.bombTimer ?? 5,
                  p.themeId,
                  0.94,
                  1,
                  Boolean(mod?.hasGem)
                );
              }
            }
          }
          ctx.restore();
        }
      }

      ctx.restore(); // Restore from shake/parallax transform

      // 8. Update & Render Zero-GC Particle Pool (Debris & Sparks)
      for (let i = 0; i < MAX_PARTICLES; i++) {
        const pt = particles[i];
        if (!pt.active) continue;
        pt.life += dt;
        if (pt.life >= pt.maxLife) {
          pt.active = false;
          continue;
        }
        pt.x += pt.vx * dt;
        pt.y += pt.vy * dt;
        pt.vy += 310 * dt;
        const progress = pt.life / pt.maxLife;
        pt.alpha = 1 - progress;

        ctx.save();
        ctx.globalAlpha = Math.max(0, pt.alpha);
        ctx.fillStyle = pt.color;
        if (pt.isSpark) {
          ctx.translate(pt.x, pt.y);
          ctx.rotate(pt.life * 8);
          ctx.fillRect(-pt.size / 2, -pt.size / 2, pt.size, pt.size);
        } else {
          ctx.beginPath();
          ctx.roundRect(pt.x - pt.size / 2, pt.y - pt.size / 2, pt.size, pt.size, 2);
          ctx.fill();
        }
        ctx.restore();
      }

      // 9. Update & Render Pooled Floating Combo Banners & Mini Tile Popups
      for (let i = 0; i < MAX_FLOATING_TEXTS; i++) {
        const ft = floatingTexts[i];
        if (!ft.active) continue;
        ft.life += dt;
        if (ft.life >= ft.maxLife) {
          ft.active = false;
          continue;
        }
        ft.y += ft.vy * dt;
        const progress = ft.life / ft.maxLife;
        const alpha = progress < 0.75 ? 1 : 1 - (progress - 0.75) / 0.25;
        const popScale =
          progress < 0.18
            ? ft.scale * (0.7 + (progress / 0.18) * 0.52)
            : ft.scale * (1.22 - Math.min(0.22, (progress - 0.18) * 0.5));

        ctx.save();
        ctx.globalAlpha = Math.max(0, alpha);
        ctx.translate(ft.x, ft.y);
        ctx.scale(popScale, popScale);
        ctx.font = ft.isMini
          ? '900 16px "Plus Jakarta Sans", sans-serif'
          : '800 22px "Cinzel", Georgia, serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.strokeStyle = 'rgba(15, 23, 42, 0.85)';
        ctx.lineWidth = ft.isMini ? 3.5 : 4.5;
        ctx.strokeText(ft.text, 0, 0);
        ctx.fillStyle = ft.color;
        ctx.fillText(ft.text, 0, 0);
        ctx.restore();
      }

      justPressedKeys.clear();
      ctx.restore();

      const isHeadless = typeof navigator !== 'undefined' && navigator.webdriver === true;
      if (!isDisposedRef.current && !isHeadless) {
        rafId = requestAnimationFrame(tick);
      }
    };

    const scheduleSingleFrame = () => {
      if (isDisposedRef.current) return;
      cancelAnimationFrame(rafId);
      rafId = requestAnimationFrame(tick);
    };

    requestRedrawRef.current = scheduleSingleFrame;
    scheduleSingleFrame();

    return () => {
      isDisposedRef.current = true;
      cancelAnimationFrame(rafId);
      resizeObserver.disconnect();
      canvas.removeEventListener('pointerdown', handlePointerDown);
      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerup', handlePointerUp);
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
      window.removeEventListener('blur', clearInputs);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, []);

  return (
    <div
      ref={mountRef}
      className="fixed inset-0 w-screen h-screen overflow-hidden z-0"
      aria-label="Game Viewport Container"
    />
  );
};

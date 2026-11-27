import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  BoosterType,
  GameMode,
  GridArchitecture,
  GridCell,
  MAX_BOOSTER_USES_PER_SESSION,
  StageObjective,
  ThemeSkinId,
  TrayPiece,
  applyBombBlastBooster,
  applyHammerBooster,
  applyLaserBooster,
  convertPieceToSingleStar,
  createBoard,
  getBoosterCoinCost,
  getCampaignStageConfig,
  generateTrayPieces,
  hasAnyValidMove,
  placePieceOnBoard,
  rotateTrayPiece,
} from './game/rules';
import {
  CalendarDayEntry,
  INITIAL_STREAK_CHESTS,
  ShopBundle,
  StreakChestTier,
  THEME_SKINS,
  computeCalendarStreak,
  createInitialLeagueCohort,
  createInitialNovemberCalendar,
} from './game/metaState';
import { soundSynth } from './game/audioSynth';
import {
  BombIcon,
  CalendarIcon,
  CoinIcon,
  FlameStreakIcon,
  GemIcon,
  HammerIcon,
  MapIcon,
  MuteIcon,
  PauseIcon,
  RelicTitleEmblem,
  RerollIcon,
  RestartIcon,
  RotateIcon,
  ShopIcon,
  TrophyIcon,
} from './components/RelicIcons';
import { CanvasParticleBurst, RelicBoardCanvas, ShellState } from './components/RelicBoardCanvas';
import { ActiveMetaModal, MetaModals } from './components/MetaModals';
import { GodotExportModal } from './components/GodotExportModal';

interface FrozenRunSummary {
  outcome: 'victory' | 'defeat';
  mode: GameMode;
  score: number;
  bestScore: number;
  linesClearedTotal: number;
  coinsEarnedRun: number;
  stageNumber: number;
  objectivesCompleted: number;
  objectivesTotal: number;
  doubledPayoutClaimed: boolean;
}

export default function App() {
  const initialShellState = useMemo<ShellState>(() => {
    if (typeof window !== 'undefined') {
      const params = new URLSearchParams(window.location.search);
      if (params.get('autostart') === '1') {
        return 'playing';
      }
    }
    return 'title';
  }, []);

  const [shellState, setShellState] = useState<ShellState>(initialShellState);
  const [gameMode, setGameMode] = useState<GameMode>('classic');
  const [architecture, setArchitecture] = useState<GridArchitecture>('standard');

  // Board & Tray state
  const [board, setBoard] = useState<GridCell[][]>(() =>
    createBoard('standard', {
      initialFrozenCount: 3,
      initialBombCount: 1,
      initialGemCount: 3,
      seed: 2026,
    })
  );
  const [turnIndex, setTurnIndex] = useState<number>(1);
  const [tray, setTray] = useState<TrayPiece[]>(() => generateTrayPieces(2026, 'classic', 1));
  const [selectedPieceIndex, setSelectedPieceIndex] = useState<number>(0);

  // Run Metrics
  const [score, setScore] = useState<number>(0);
  const [bestScore, setBestScore] = useState<number>(1480);
  const [comboStreak, setComboStreak] = useState<number>(0);
  const [linesClearedRun, setLinesClearedRun] = useState<number>(0);
  const [movesRemaining, setMovesRemaining] = useState<number>(15);
  const [blitzSecondsLeft, setBlitzSecondsLeft] = useState<number>(90);
  const [objectives, setObjectives] = useState<StageObjective[]>([]);
  const [lastChanceUsed, setLastChanceUsed] = useState<boolean>(false);
  const [statusBannerText, setStatusBannerText] = useState<string>(
    'Blokları [1-3] sürükle veya tıkla · Satır/Sütun patlat ve kombo yap!'
  );
  const [burstSignal, setBurstSignal] = useState<CanvasParticleBurst | null>(null);
  const [curtainSignal, setCurtainSignal] = useState<number>(0);

  // 6 Tactical Boosters & Jokers + Anti-Pay-to-Win Session Safeguards
  const [boosterStock, setBoosterStock] = useState<Record<BoosterType, number>>({
    rotate: 2,
    hammer: 2,
    reroll: 2,
    bomb_blast: 1,
    laser: 1,
    single_star: 1,
  });
  const [boosterUsesSession, setBoosterUsesSession] = useState<Record<BoosterType, number>>({
    rotate: 0,
    hammer: 0,
    reroll: 0,
    bomb_blast: 0,
    laser: 0,
    single_star: 0,
  });
  const [activeTargetingBooster, setActiveTargetingBooster] = useState<
    'hammer' | 'bomb_blast' | 'laser' | null
  >(null);

  // Economy & Meta Progression
  const [coins, setCoins] = useState<number>(420);
  const [gems, setGems] = useState<number>(65);
  const [calendar, setCalendar] = useState<CalendarDayEntry[]>(() =>
    createInitialNovemberCalendar()
  );
  const [streakChests, setStreakChests] = useState<StreakChestTier[]>(() => INITIAL_STREAK_CHESTS);
  const [highestCampaignStage, setHighestCampaignStage] = useState<number>(6);
  const [currentCampaignStage, setCurrentCampaignStage] = useState<number>(1);
  const [weeklyLeagueBaseScore, setWeeklyLeagueBaseScore] = useState<number>(3850);
  const [unlockedSkins, setUnlockedSkins] = useState<ThemeSkinId[]>([
    'pastel_blast',
    'classic_video',
    'mystic_forest',
    'artisan_wood',
  ]);
  const [equippedSkin, setEquippedSkin] = useState<ThemeSkinId>('pastel_blast');
  const [claimedShopBundles, setClaimedShopBundles] = useState<string[]>([]);
  const [activeModal, setActiveModal] = useState<ActiveMetaModal>(null);
  const [isGodotModalOpen, setIsGodotModalOpen] = useState<boolean>(() => {
    if (typeof window !== 'undefined') {
      return new URLSearchParams(window.location.search).get('godot') === '1';
    }
    return false;
  });
  const [isMuted, setIsMuted] = useState<boolean>(false);
  const [bgmEnabled, setBgmEnabled] = useState<boolean>(false);
  const [frozenSummary, setFrozenSummary] = useState<FrozenRunSummary | null>(null);

  const burstIdCounterRef = useRef<number>(1);

  useEffect(() => {
    document.body.dataset.state = shellState;
  }, [shellState]);

  const leagueCohort = useMemo(
    () => createInitialLeagueCohort(weeklyLeagueBaseScore + score),
    [weeklyLeagueBaseScore, score]
  );
  const playerLeagueRank = useMemo(() => {
    const idx = leagueCohort.findIndex((p) => p.isPlayer);
    return idx >= 0 ? idx + 1 : 4;
  }, [leagueCohort]);

  const { currentStreak } = useMemo(() => computeCalendarStreak(calendar), [calendar]);

  // Milestone Progress Percentage (Block Blast Top Pill)
  const milestonePct = useMemo(() => {
    if ((gameMode === 'daily' || gameMode === 'campaign') && objectives.length > 0) {
      const totalRatio = objectives.reduce(
        (acc, o) => acc + Math.min(1, o.current / Math.max(1, o.target)),
        0
      );
      return Math.min(100, Math.round((totalRatio / objectives.length) * 100));
    }
    return Math.min(100, Math.round(((score % 1000) / 1000) * 100));
  }, [gameMode, objectives, score]);

  const startNewRun = useCallback(
    (
      targetMode: GameMode = gameMode,
      targetArch: GridArchitecture = architecture,
      stageNum: number = currentCampaignStage,
      withCurtain: boolean = true
    ) => {
      if (document.activeElement instanceof HTMLElement) {
        document.activeElement.blur();
      }
      setActiveModal(null);
      setActiveTargetingBooster(null);
      setFrozenSummary(null);
      setLastChanceUsed(false);
      setScore(0);
      setComboStreak(0);
      setLinesClearedRun(0);
      setTurnIndex(1);
      setBoosterUsesSession({
        rotate: 0,
        hammer: 0,
        reroll: 0,
        bomb_blast: 0,
        laser: 0,
        single_star: 0,
      });

      let chosenArch = targetArch;
      let frozenInit = 3;
      let bombInit = 1;
      let gemInit = 2;
      let moveLim = 16;
      let nextObjectives: StageObjective[] = [];

      if (targetMode === 'daily') {
        chosenArch = 'holed';
        frozenInit = 3;
        bombInit = 1;
        gemInit = 3;
        moveLim = 14;
        nextObjectives = [
          { type: 'clear_ruby', label: 'Clear Ruby Blocks', target: 12, current: 0 },
          { type: 'shatter_ice', label: 'Shatter Ice Blocks', target: 2, current: 0 },
        ];
        setStatusBannerText('Günlük Bulmaca (8 Kasım): 14 hamlede 12 Yakut & 2 Buz Bloğu kır!');
      } else if (targetMode === 'campaign') {
        const cfg = getCampaignStageConfig(stageNum);
        chosenArch = cfg.architecture;
        frozenInit = cfg.initialFrozenCount;
        bombInit = cfg.initialBombCount;
        gemInit = cfg.initialGemCount ?? 4;
        moveLim = cfg.moveLimit;
        nextObjectives = cfg.objectives.map((o) => ({ ...o, current: 0 }));
        setStatusBannerText(`${cfg.title} · ${cfg.architecture.toUpperCase()} Tahta · ${moveLim} Hamle`);
      } else if (targetMode === 'blitz') {
        frozenInit = 2;
        bombInit = 2;
        gemInit = 3;
        setBlitzSecondsLeft(90);
        setStatusBannerText('Time Attack Blitz: Her kombo ve satır patlatma +4sn/+8sn süre verir!');
      } else {
        setStatusBannerText(
          `Klasik Sonsuz (${chosenArch.replace('_', ' ')}) · Blokları yerleştir ve rekor kır!`
        );
      }

      setGameMode(targetMode);
      setArchitecture(chosenArch);
      setMovesRemaining(moveLim);
      setObjectives(nextObjectives);

      const newBoard = createBoard(chosenArch, {
        initialFrozenCount: frozenInit,
        initialBombCount: bombInit,
        initialGemCount: gemInit,
        seed: 2026 + stageNum * 37,
      });
      const newTray = generateTrayPieces(2026 + stageNum * 91, targetMode, 1);
      setBoard(newBoard);
      setTray(newTray);
      setSelectedPieceIndex(0);
      setShellState('playing');
      if (withCurtain) {
        setCurtainSignal((prev) => prev + 1);
      } else {
        soundSynth.playSelect();
      }
    },
    [architecture, currentCampaignStage, gameMode]
  );

  // Blitz Mode 1Hz Timer
  useEffect(() => {
    if (shellState !== 'playing' || gameMode !== 'blitz' || activeModal !== null) return;
    const timer = window.setInterval(() => {
      setBlitzSecondsLeft((prev) => {
        if (prev <= 1) {
          soundSynth.playGameOver();
          setFrozenSummary({
            outcome: 'defeat',
            mode: 'blitz',
            score,
            bestScore: Math.max(bestScore, score),
            linesClearedTotal: linesClearedRun,
            coinsEarnedRun: Math.max(15, Math.floor(score / 40)),
            stageNumber: currentCampaignStage,
            objectivesCompleted: 0,
            objectivesTotal: 0,
            doubledPayoutClaimed: false,
          });
          setShellState('gameover');
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => window.clearInterval(timer);
  }, [
    activeModal,
    bestScore,
    currentCampaignStage,
    gameMode,
    linesClearedRun,
    score,
    shellState,
  ]);

  // Handle placing a piece onto the board
  const handlePlacePiece = useCallback(
    (pieceIndex: number, row: number, col: number) => {
      if (shellState !== 'playing') return;
      const piece = tray[pieceIndex];
      if (!piece || piece.used) return;

      const nextTurnNum = turnIndex + 1;
      const result = placePieceOnBoard(board, piece, row, col, {
        architecture,
        moveCountAfterPlacement: nextTurnNum,
        currentComboStreak: comboStreak,
      });

      if (!result.valid) return;

      // Audio & Haptic Feedback
      if (result.bombsDetonated > 0) {
        soundSynth.playBombDetonate();
      } else if (result.bombsDefused > 0) {
        soundSynth.playBombDefuse();
      } else if (result.iceShattered > 0) {
        soundSynth.playHammerSmash();
      } else if (result.linesCleared > 0) {
        soundSynth.playLineClear(result.linesCleared, result.comboCount);
      } else if (result.events.some((e) => e.type === 'frost_crack')) {
        soundSynth.playFrostCrack();
      } else {
        soundSynth.playPlace();
      }

      if (result.gemsCollected > 0) {
        soundSynth.playCoin();
      }

      const placedCellsList = piece.matrix.flatMap((rArr, dr) =>
        rArr
          .map((val, dc) =>
            val === 1 ? { row: row + dr, col: col + dc, color: piece.color } : null
          )
          .filter((x): x is { row: number; col: number; color: typeof piece.color } => x !== null)
      );

      const burstCells =
        result.clearedCells.length > 0 ? result.clearedCells : placedCellsList;

      // Block Blast Praise & Combo Callouts
      let secondaryBanner: string | undefined;
      if (result.linesCleared >= 4) {
        secondaryBanner = 'EFSANEVİ!';
      } else if (result.linesCleared === 3) {
        secondaryBanner = 'Muhteşem!';
      } else if (result.linesCleared === 2) {
        secondaryBanner = 'Süper!';
      } else if (result.linesCleared === 1) {
        secondaryBanner = 'Harika!';
      } else if (result.wildcardsTriggered > 0) {
        secondaryBanner = 'PRISM SURGE!';
      }

      const primaryCallout =
        result.comboCount >= 2
          ? `Combo ${result.comboCount}!`
          : result.gemsCollected > 0
            ? `⭐ +${result.gemsCollected} Taş!`
            : result.events[0]?.message;

      burstIdCounterRef.current += 1;
      setBurstSignal({
        id: burstIdCounterRef.current,
        cells: burstCells,
        placedCells: placedCellsList.map((c) => ({ row: c.row, col: c.col })),
        fullRows: result.fullRows,
        fullCols: result.fullCols,
        ringCenter:
          result.bombsDefused > 0 || result.bombsDetonated > 0 || result.wildcardsTriggered > 0
            ? { row, col }
            : undefined,
        intensity:
          result.linesCleared >= 2 || result.bombsDetonated > 0
            ? 'heavy'
            : result.linesCleared === 1 || result.wildcardsTriggered > 0
              ? 'medium'
              : 'light',
        calloutText: primaryCallout,
        secondaryBannerText: secondaryBanner,
      });

      if (result.events.length > 0) {
        setStatusBannerText(result.events.map((e) => e.message).join(' · '));
      } else {
        setStatusBannerText(`${piece.name} yerleştirildi (+${result.scoreDelta} puan)`);
      }

      const nextScore = score + result.scoreDelta;
      const nextBest = Math.max(bestScore, nextScore);
      const nextLines = linesClearedRun + result.linesCleared;
      const nextCoins = coins + result.coinsEarned + result.gemsCollected * 4;

      setBoard(result.board);
      setScore(nextScore);
      setBestScore(nextBest);
      setComboStreak(result.comboCount);
      setLinesClearedRun(nextLines);
      setCoins(nextCoins);
      setTurnIndex(nextTurnNum);

      if (gameMode === 'blitz' && result.timeBonusSec > 0) {
        setBlitzSecondsLeft((prev) => prev + result.timeBonusSec);
      }

      let updatedTray = tray.map((p, idx) => (idx === pieceIndex ? { ...p, used: true } : p));
      if (updatedTray.every((p) => p.used)) {
        updatedTray = generateTrayPieces(2026 + nextTurnNum * 131, gameMode, nextTurnNum);
      }
      setTray(updatedTray);

      const nextAvailableIdx = updatedTray.findIndex((p) => !p.used);
      if (nextAvailableIdx >= 0) {
        setSelectedPieceIndex(nextAvailableIdx);
      }

      let updatedObjectives = objectives;
      if (gameMode === 'daily' || gameMode === 'campaign') {
        updatedObjectives = objectives.map((obj) => {
          if (obj.type === 'score') {
            return { ...obj, current: Math.min(obj.target, nextScore) };
          }
          if (obj.type === 'clear_ruby') {
            return { ...obj, current: Math.min(obj.target, obj.current + result.rubyCleared) };
          }
          if (obj.type === 'shatter_ice') {
            return { ...obj, current: Math.min(obj.target, obj.current + result.iceShattered) };
          }
          if (obj.type === 'defuse_bomb') {
            return { ...obj, current: Math.min(obj.target, obj.current + result.bombsDefused) };
          }
          if (obj.type === 'clear_lines') {
            return { ...obj, current: Math.min(obj.target, obj.current + result.linesCleared) };
          }
          if (obj.type === 'collect_gems') {
            return { ...obj, current: Math.min(obj.target, obj.current + result.gemsCollected) };
          }
          return obj;
        });
        setObjectives(updatedObjectives);
      }

      const nextMovesLeft =
        gameMode === 'daily' || gameMode === 'campaign' ? movesRemaining - 1 : movesRemaining;
      if (gameMode === 'daily' || gameMode === 'campaign') {
        setMovesRemaining(nextMovesLeft);
      }

      const allObjectivesComplete =
        updatedObjectives.length > 0 &&
        updatedObjectives.every((o) => o.current >= o.target);

      if (allObjectivesComplete) {
        soundSynth.playVictory();
        const rewardBonus = gameMode === 'daily' ? 150 : 60 + currentCampaignStage * 5;
        setCoins((c) => c + rewardBonus);
        setWeeklyLeagueBaseScore((s) => s + nextScore);

        if (gameMode === 'daily') {
          setCalendar((prev) =>
            prev.map((d) => (d.day === 8 ? { ...d, status: 'completed' } : d))
          );
          setBoosterStock((prev) => ({ ...prev, hammer: prev.hammer + 1 }));
        } else if (gameMode === 'campaign') {
          setHighestCampaignStage((h) => Math.max(h, Math.min(500, currentCampaignStage + 1)));
        }

        setFrozenSummary({
          outcome: 'victory',
          mode: gameMode,
          score: nextScore,
          bestScore: nextBest,
          linesClearedTotal: nextLines,
          coinsEarnedRun: rewardBonus + result.coinsEarned,
          stageNumber: currentCampaignStage,
          objectivesCompleted: updatedObjectives.length,
          objectivesTotal: updatedObjectives.length,
          doubledPayoutClaimed: false,
        });
        setShellState('gameover');
        return;
      }

      const noMovesLeft =
        (gameMode === 'daily' || gameMode === 'campaign') && nextMovesLeft <= 0;
      const boardBlocked = !hasAnyValidMove(result.board, updatedTray);

      if (noMovesLeft || boardBlocked) {
        soundSynth.playGameOver();
        const completedCount = updatedObjectives.filter((o) => o.current >= o.target).length;
        setFrozenSummary({
          outcome: 'defeat',
          mode: gameMode,
          score: nextScore,
          bestScore: nextBest,
          linesClearedTotal: nextLines,
          coinsEarnedRun: Math.max(10, Math.floor(nextScore / 45)),
          stageNumber: currentCampaignStage,
          objectivesCompleted: completedCount,
          objectivesTotal: updatedObjectives.length,
          doubledPayoutClaimed: false,
        });
        setShellState('gameover');
      }
    },
    [
      architecture,
      bestScore,
      board,
      coins,
      comboStreak,
      currentCampaignStage,
      gameMode,
      linesClearedRun,
      movesRemaining,
      objectives,
      score,
      shellState,
      tray,
      turnIndex,
    ]
  );

  // Consume booster helper
  const tryConsumeBooster = useCallback(
    (type: BoosterType): boolean => {
      const usedThisSession = boosterUsesSession[type];
      if (usedThisSession >= MAX_BOOSTER_USES_PER_SESSION) {
        setStatusBannerText(
          `Anti-Pay-to-Win Sınırı: ${type.toUpperCase()} bu oyunda ${MAX_BOOSTER_USES_PER_SESSION}/3 kez kullanıldı!`
        );
        return false;
      }

      const currentStock = boosterStock[type];
      if (currentStock > 0) {
        setBoosterStock((prev) => ({ ...prev, [type]: prev[type] - 1 }));
        setBoosterUsesSession((prev) => ({ ...prev, [type]: prev[type] + 1 }));
        return true;
      }

      const coinCost = getBoosterCoinCost(type, usedThisSession);
      if (coinCost !== null && coins >= coinCost) {
        setCoins((c) => c - coinCost);
        setBoosterUsesSession((prev) => ({ ...prev, [type]: prev[type] + 1 }));
        return true;
      }

      setStatusBannerText(
        `${type.toUpperCase()} için ${coinCost ?? 999} Coin veya stok gerekli!`
      );
      return false;
    },
    [boosterStock, boosterUsesSession, coins]
  );

  // Rotate Booster [R]
  const handleRotatePiece = useCallback(
    (pieceIdx: number = selectedPieceIndex) => {
      if (shellState !== 'playing') return;
      const target = tray[pieceIdx];
      if (!target || target.used) return;
      if (!tryConsumeBooster('rotate')) return;

      soundSynth.playBooster();
      setTray((prev) =>
        prev.map((p, idx) => (idx === pieceIdx ? rotateTrayPiece(p) : p))
      );
      setStatusBannerText(`${target.name} 90° döndürüldü!`);
    },
    [selectedPieceIndex, shellState, tray, tryConsumeBooster]
  );

  // Reroll / Shape Refresh Booster [F]
  const handleRerollTray = useCallback(() => {
    if (shellState !== 'playing') return;
    if (!tryConsumeBooster('reroll')) return;

    soundSynth.playBooster();
    const nextTurn = turnIndex + 1;
    setTurnIndex(nextTurn);
    const fresh = generateTrayPieces(2026 + nextTurn * 313, gameMode, nextTurn);
    setTray(fresh);
    setSelectedPieceIndex(0);
    setStatusBannerText('3 yeni blok şekli yenilendi!');
  }, [gameMode, shellState, tryConsumeBooster, turnIndex]);

  // 1x1 Single Star Joker [G]
  const handleConvertSingleStar = useCallback(
    (pieceIdx: number = selectedPieceIndex) => {
      if (shellState !== 'playing') return;
      const target = tray[pieceIdx];
      if (!target || target.used) return;
      if (!tryConsumeBooster('single_star')) return;

      soundSynth.playBooster();
      setTray((prev) =>
        prev.map((p, idx) => (idx === pieceIdx ? convertPieceToSingleStar(p) : p))
      );
      setStatusBannerText('✨ Seçili parça 1×1 Yıldız Bloğa dönüştürüldü!');
    },
    [selectedPieceIndex, shellState, tray, tryConsumeBooster]
  );

  // Activate Targetable or Instant Booster Mode
  const handleActivateBoosterMode = useCallback(
    (booster: BoosterType) => {
      if (shellState !== 'playing') return;
      if (booster === 'rotate') {
        handleRotatePiece(selectedPieceIndex);
        return;
      }
      if (booster === 'reroll') {
        handleRerollTray();
        return;
      }
      if (booster === 'single_star') {
        handleConvertSingleStar(selectedPieceIndex);
        return;
      }
      if (booster === 'hammer' || booster === 'bomb_blast' || booster === 'laser') {
        if (boosterUsesSession[booster] >= MAX_BOOSTER_USES_PER_SESSION) {
          setStatusBannerText(
            `Anti-Pay-to-Win Sınırı: ${booster.toUpperCase()} bu oyunda ${MAX_BOOSTER_USES_PER_SESSION}/3 kez kullanıldı!`
          );
          return;
        }
        setActiveTargetingBooster((prev) => (prev === booster ? null : booster));
        setStatusBannerText(
          booster === 'hammer'
            ? '🔨 Çekiç Hazır: Kırmak istediğin bloğa tıkla!'
            : booster === 'bomb_blast'
              ? '💥 3×3 Bomba Hazır: Patlatmak istediğin 3×3 alana tıkla!'
              : '⚡ Lazer Hazır: Tam satır ve sütunu temizlemek için bir hücreye tıkla!'
        );
      }
    },
    [
      boosterUsesSession,
      handleConvertSingleStar,
      handleRerollTray,
      handleRotatePiece,
      selectedPieceIndex,
      shellState,
    ]
  );

  // Execute Targetable Booster on board cell (row, col)
  const handleUseTargetBooster = useCallback(
    (row: number, col: number) => {
      if (!activeTargetingBooster) return;
      if (activeTargetingBooster === 'hammer') {
        const res = applyHammerBooster(board, row, col);
        if (!res.success || !res.shatteredCell) {
          setStatusBannerText('Çekiç için dolu bir blok seçmelisin!');
          return;
        }
        if (!tryConsumeBooster('hammer')) {
          setActiveTargetingBooster(null);
          return;
        }
        soundSynth.playHammerSmash();
        setBoard(res.board);
        setActiveTargetingBooster(null);
        burstIdCounterRef.current += 1;
        setBurstSignal({
          id: burstIdCounterRef.current,
          cells: [{ row, col, color: res.shatteredCell.color }],
          ringCenter: { row, col },
          intensity: 'heavy',
          calloutText: 'HAMMER SMASH!',
        });
        setStatusBannerText(`Çekiç (${row + 1}, ${col + 1}) hücresini kırdı!`);
      } else if (activeTargetingBooster === 'bomb_blast') {
        const res = applyBombBlastBooster(board, row, col);
        if (!res.success) {
          setStatusBannerText('En az 1 dolu blok içeren bir 3×3 bölge seç!');
          return;
        }
        if (!tryConsumeBooster('bomb_blast')) {
          setActiveTargetingBooster(null);
          return;
        }
        soundSynth.playBombDefuse();
        const bonusPts = res.clearedCount * 10;
        setBoard(res.board);
        setScore((s) => s + bonusPts);
        setBestScore((b) => Math.max(b, score + bonusPts));
        if (res.gemsCollected > 0) {
          setCoins((c) => c + res.gemsCollected * 5);
        }
        setActiveTargetingBooster(null);
        burstIdCounterRef.current += 1;
        setBurstSignal({
          id: burstIdCounterRef.current,
          cells: res.clearedCells,
          ringCenter: { row, col },
          intensity: 'heavy',
          calloutText: `💥 3×3 BOMBA! (+${bonusPts})`,
        });
        setStatusBannerText(`3×3 Bomba ${res.clearedCount} bloğu temizledi!`);
      } else if (activeTargetingBooster === 'laser') {
        const res = applyLaserBooster(board, row, col);
        if (!res.success) {
          setStatusBannerText('En az 1 dolu blok içeren bir satır/sütun kesişimi seç!');
          return;
        }
        if (!tryConsumeBooster('laser')) {
          setActiveTargetingBooster(null);
          return;
        }
        soundSynth.playLaser();
        const bonusPts = res.clearedCount * 12;
        setBoard(res.board);
        setScore((s) => s + bonusPts);
        setBestScore((b) => Math.max(b, score + bonusPts));
        if (res.gemsCollected > 0) {
          setCoins((c) => c + res.gemsCollected * 5);
        }
        setActiveTargetingBooster(null);
        burstIdCounterRef.current += 1;
        setBurstSignal({
          id: burstIdCounterRef.current,
          cells: res.clearedCells,
          fullRows: [row],
          fullCols: [col],
          ringCenter: { row, col },
          intensity: 'heavy',
          calloutText: `⚡ LAZER! (+${bonusPts})`,
        });
        setStatusBannerText(`Satır & Sütun Lazeri ${res.clearedCount} bloğu temizledi!`);
      }
    },
    [activeTargetingBooster, board, score, tryConsumeBooster]
  );

  // Out-of-Moves Joker Rescue (from Game Over Modal)
  const handleOutOfMovesJokerRescue = useCallback(
    (rescueType: 'reroll' | 'single_star' | 'center_bomb') => {
      if (rescueType === 'center_bomb') {
        if (lastChanceUsed) return;
        setLastChanceUsed(true);
        const res = applyBombBlastBooster(board, 3, 3);
        const res2 = applyBombBlastBooster(res.board, 4, 4);
        const nextTurn = turnIndex + 1;
        setBoard(res2.board);
        setTray(generateTrayPieces(2026 + nextTurn * 509, gameMode, nextTurn));
        setMovesRemaining((m) => Math.max(5, m + 5));
        setBlitzSecondsLeft((s) => Math.max(30, s + 30));
        setFrozenSummary(null);
        setShellState('playing');
        soundSynth.playBooster();
        setStatusBannerText('💥 Merkez 3×3 temizlendi ve +5 Hamle eklendi!');
        return;
      }

      if (rescueType === 'reroll') {
        const stock = boosterStock.reroll;
        if (stock <= 0 && coins < 25) {
          setStatusBannerText('Yenile Jokeri için 25 Coin gerekli!');
          return;
        }
        if (stock > 0) {
          setBoosterStock((prev) => ({ ...prev, reroll: prev.reroll - 1 }));
        } else {
          setCoins((c) => c - 25);
        }
        const nextTurn = turnIndex + 1;
        setTurnIndex(nextTurn);
        setTray(generateTrayPieces(2026 + nextTurn * 419, gameMode, nextTurn));
        setSelectedPieceIndex(0);
        setMovesRemaining((m) => Math.max(3, m + 3));
        setFrozenSummary(null);
        setShellState('playing');
        soundSynth.playBooster();
        setStatusBannerText('↻ Yenile Jokeri kullanıldı — yeni bloklarla devam!');
        return;
      }

      if (rescueType === 'single_star') {
        const stock = boosterStock.single_star;
        if (stock <= 0 && coins < 35) {
          setStatusBannerText('1×1 Yıldız Jokeri için 35 Coin gerekli!');
          return;
        }
        if (stock > 0) {
          setBoosterStock((prev) => ({ ...prev, single_star: prev.single_star - 1 }));
        } else {
          setCoins((c) => c - 35);
        }
        const targetIdx = tray.findIndex((p) => !p.used);
        const idxToConvert = targetIdx >= 0 ? targetIdx : 0;
        setTray((prev) =>
          prev.map((p, idx) =>
            idx === idxToConvert ? { ...convertPieceToSingleStar(p), used: false } : p
          )
        );
        setSelectedPieceIndex(idxToConvert);
        setMovesRemaining((m) => Math.max(3, m + 3));
        setFrozenSummary(null);
        setShellState('playing');
        soundSynth.playBooster();
        setStatusBannerText('✨ 1×1 Yıldız Blok ile oyuna geri döndün!');
      }
    },
    [board, boosterStock, coins, gameMode, lastChanceUsed, tray, turnIndex]
  );

  // Meta Handlers
  const handleClaimStreakChest = (chestId: string) => {
    const chest = streakChests.find((c) => c.id === chestId);
    if (!chest || chest.claimed) return;
    soundSynth.playVictory();
    setCoins((c) => c + chest.coins);
    if (chest.boosterType && chest.boosterCount) {
      const bType = chest.boosterType;
      const bCount = chest.boosterCount;
      setBoosterStock((prev) => ({ ...prev, [bType]: prev[bType] + bCount }));
    }
    if (chest.unlockSkin && !unlockedSkins.includes(chest.unlockSkin)) {
      setUnlockedSkins((prev) => [...prev, chest.unlockSkin!]);
      setEquippedSkin(chest.unlockSkin);
    }
    setStreakChests((prev) =>
      prev.map((c) => (c.id === chestId ? { ...c, claimed: true } : c))
    );
  };

  const handleRecoverMissedDay = (day: number, method: 'gems' | 'ad') => {
    if (method === 'gems') {
      if (gems < 15) {
        setStatusBannerText('Yeterli Gem yok (15 Gem gerekli) — Ücretsiz Reklam ile kurtar!');
        return;
      }
      setGems((g) => g - 15);
    }
    soundSynth.playVictory();
    setCalendar((prev) =>
      prev.map((entry) => (entry.day === day ? { ...entry, status: 'completed' } : entry))
    );
  };

  const handleBuyOrEquipSkin = (skinId: ThemeSkinId) => {
    if (unlockedSkins.includes(skinId)) {
      soundSynth.playSelect();
      setEquippedSkin(skinId);
      return;
    }
    const skin = THEME_SKINS[skinId];
    if (skin.costCoins && coins >= skin.costCoins) {
      soundSynth.playVictory();
      setCoins((c) => c - skin.costCoins!);
      setUnlockedSkins((prev) => [...prev, skinId]);
      setEquippedSkin(skinId);
      return;
    }
    if (gems >= skin.costGems) {
      soundSynth.playVictory();
      setGems((g) => g - skin.costGems);
      setUnlockedSkins((prev) => [...prev, skinId]);
      setEquippedSkin(skinId);
    }
  };

  const handleBuySingleBooster = (booster: BoosterType, costCoins: number) => {
    if (coins < costCoins) {
      setStatusBannerText(`Yeterli Coin yok (${costCoins} Coin gerekli)!`);
      return;
    }
    soundSynth.playCoin();
    setCoins((c) => c - costCoins);
    setBoosterStock((prev) => ({ ...prev, [booster]: (prev[booster] || 0) + 1 }));
  };

  const handleGrantFreeCoins = (amount: number) => {
    soundSynth.playCoin();
    setCoins((c) => c + amount);
    setStatusBannerText(`🎁 +${amount} Ücretsiz Coin eklendi!`);
  };

  const handlePurchaseBundle = (bundle: ShopBundle) => {
    if (bundle.isRewardedAd) {
      if (claimedShopBundles.includes(bundle.id)) return;
      setClaimedShopBundles((prev) => [...prev, bundle.id]);
    } else if (bundle.costCoins) {
      if (coins < bundle.costCoins) return;
      setCoins((c) => c - bundle.costCoins!);
    } else if (bundle.costGems) {
      if (gems < bundle.costGems) return;
      setGems((g) => g - bundle.costGems!);
    }

    soundSynth.playVictory();
    if (bundle.rewards.coins) {
      setCoins((c) => c + bundle.rewards.coins!);
    }
    if (bundle.rewards.boosters) {
      setBoosterStock((prev) => {
        const next = { ...prev };
        for (const [k, v] of Object.entries(bundle.rewards.boosters!)) {
          const key = k as BoosterType;
          next[key] = (next[key] || 0) + (v || 0);
        }
        return next;
      });
    }
  };

  const handleTogglePause = useCallback(() => {
    setShellState((prev) => {
      if (prev === 'playing') return 'paused';
      if (prev === 'paused') return 'playing';
      return prev;
    });
  }, []);

  const handleToggleMute = useCallback(() => {
    soundSynth.isMuted = !soundSynth.isMuted;
    setIsMuted(soundSynth.isMuted);
    if (soundSynth.isMuted) {
      soundSynth.setBgm(false);
    } else if (bgmEnabled) {
      soundSynth.setBgm(true);
    }
  }, [bgmEnabled]);

  const handleToggleBgm = useCallback(() => {
    const next = !bgmEnabled;
    setBgmEnabled(next);
    soundSynth.setBgm(next);
  }, [bgmEnabled]);

  const cyclePastelAndRelicTheme = useCallback(() => {
    const order: ThemeSkinId[] = [
      'pastel_blast',
      'classic_video',
      'sugar_cream',
      'night_neon',
      'mystic_forest',
      'artisan_wood',
    ];
    const available = order.filter((id) => unlockedSkins.includes(id));
    const idx = available.indexOf(equippedSkin);
    const next = available[(idx + 1) % available.length] || 'pastel_blast';
    soundSynth.playSelect();
    setEquippedSkin(next);
  }, [equippedSkin, unlockedSkins]);

  return (
    <main className="relative w-screen h-screen overflow-hidden select-none">
      {/* 1. Isolated 60fps Canvas World & Board Viewport */}
      <RelicBoardCanvas
        shellState={shellState}
        board={board}
        architecture={architecture}
        tray={tray}
        selectedPieceIndex={selectedPieceIndex}
        activeTargetingBooster={activeTargetingBooster}
        themeId={equippedSkin}
        burstSignal={burstSignal}
        curtainSignal={curtainSignal}
        onSelectPiece={(idx) => setSelectedPieceIndex(idx)}
        onPlacePiece={handlePlacePiece}
        onUseTargetBooster={handleUseTargetBooster}
        onRotatePiece={handleRotatePiece}
        onRerollTray={handleRerollTray}
        onActivateBoosterMode={handleActivateBoosterMode}
        onStartGame={() => startNewRun(gameMode, architecture, currentCampaignStage, true)}
        onTogglePause={handleTogglePause}
        onToggleMute={handleToggleMute}
      />

      {/* 2. TITLE SCREEN STAGE (Merged Block Blast Pastel Edition + RelicGrid Odyssey) */}
      {shellState === 'title' && (
        <section
          aria-label="Title Screen"
          className="fixed inset-0 z-20 pointer-events-none flex flex-col justify-between p-6 md:p-12"
        >
          <div className="max-w-xl w-full my-auto pointer-events-auto space-y-5 bg-[#1B2748]/95 p-6 md:p-8 rounded-3xl border-2 border-[#FFD95A]/80 shadow-2xl">
            <div className="flex items-center justify-between gap-3">
              <RelicTitleEmblem className="w-full max-w-sm" />
              <button
                type="button"
                onClick={cyclePastelAndRelicTheme}
                className="px-3 py-1.5 rounded-full bg-white/15 hover:bg-white/25 border border-white/25 text-xs font-extrabold text-amber-200 cursor-pointer whitespace-nowrap shrink-0"
              >
                🎨 {THEME_SKINS[equippedSkin].name}
              </button>
            </div>

            <p className="text-sm text-blue-100/90 leading-relaxed">
              <strong>BLOCK BLAST: RelicGrid Pastel Edition</strong> — Yumuşak mat 3D pastel bloklar,
              satır/sütun renk değiştiren patlama önizlemesi, yıldızlı elmas bloklar, 6 taktiksel
              Joker, 500 Macera Bölümü ve 30 oyunculu Haftalık Lig tek oyunda birleşti!
            </p>

            {/* Game Mode Selection Tabs */}
            <div className="space-y-2">
              <div className="text-xs font-bold text-amber-300 uppercase tracking-wider">
                Oyun Modu Seç (Game Modes)
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                {(
                  [
                    { id: 'classic', label: '♾️ Klasik Sonsuz' },
                    { id: 'campaign', label: '🗺️ Macera (500)' },
                    { id: 'daily', label: '📅 Günlük Görev' },
                    { id: 'blitz', label: '⏱️ Time Blitz' },
                  ] as const
                ).map((m) => (
                  <button
                    key={m.id}
                    type="button"
                    onClick={() => setGameMode(m.id)}
                    className={`py-2 px-3 rounded-xl text-xs font-bold transition-colors cursor-pointer whitespace-nowrap shrink-0 border ${
                      gameMode === m.id
                        ? 'bg-amber-400 text-slate-950 border-amber-200 shadow-md'
                        : 'bg-[#24345E] text-blue-100 border-white/15 hover:border-amber-300/60'
                    }`}
                  >
                    {m.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Variable Grid Architecture Selector */}
            <div className="space-y-2">
              <div className="text-xs font-bold text-amber-300 uppercase tracking-wider">
                Tahta Mimarisi (Grid Architecture)
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                {(
                  [
                    { id: 'standard', label: 'Standart 8×8' },
                    { id: 'holed', label: 'Delikli 2×2' },
                    { id: 'shifting', label: 'Kayan Satırlar' },
                    { id: 'l_shaped', label: 'L-Tahta' },
                  ] as const
                ).map((arch) => (
                  <button
                    key={arch.id}
                    type="button"
                    onClick={() => setArchitecture(arch.id)}
                    className={`py-1.5 px-2.5 rounded-xl text-xs font-semibold transition-colors cursor-pointer whitespace-nowrap shrink-0 border ${
                      architecture === arch.id
                        ? 'bg-emerald-500 text-slate-950 border-emerald-200 font-extrabold'
                        : 'bg-[#172342] text-blue-100/80 border-white/15 hover:text-white'
                    }`}
                  >
                    {arch.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Primary Start CTA + Meta Quick Links */}
            <div className="flex flex-wrap items-center gap-2.5 pt-2">
              <button
                type="button"
                data-start="true"
                onClick={() => startNewRun(gameMode, architecture, currentCampaignStage, true)}
                className="flex-1 py-3.5 px-6 rounded-2xl bg-gradient-to-b from-amber-400 to-amber-500 hover:from-amber-300 hover:to-amber-400 text-slate-950 font-display font-extrabold text-base tracking-wider shadow-lg transition-transform active:scale-98 cursor-pointer whitespace-nowrap"
              >
                ▶ OYUNA BAŞLA (Start Odyssey)
              </button>
              <button
                type="button"
                onClick={() => setActiveModal('shop')}
                className="py-3.5 px-4 rounded-2xl bg-[#24345E] hover:bg-[#2F4378] border border-amber-300/50 text-amber-200 text-xs font-bold transition-colors cursor-pointer whitespace-nowrap"
              >
                🛒 Market & Temalar
              </button>
              <button
                type="button"
                onClick={() => setActiveModal('daily')}
                className="py-3.5 px-3.5 rounded-2xl bg-[#24345E] hover:bg-[#2F4378] border border-emerald-300/40 text-emerald-200 text-xs font-bold transition-colors cursor-pointer whitespace-nowrap"
              >
                🔥 Seri ({currentStreak}g)
              </button>
              <button
                type="button"
                onClick={() => setIsGodotModalOpen(true)}
                className="py-3.5 px-3.5 rounded-2xl bg-[#14293A] hover:bg-[#1D3B52] border border-[#478CBF] text-[#9AD4FF] text-xs font-bold transition-colors cursor-pointer whitespace-nowrap"
              >
                Godot 4 (.ZIP)
              </button>
            </div>
          </div>

          <div className="text-xs text-blue-100/85 font-mono-tabular tracking-wide">
            1-3 Parça Seç · Sürükle veya Ok Tuşları · Space Yerleştir · R Döndür · H Çekiç · F Yenile · B 3×3 Bomba · L Lazer · G 1×1 Yıldız
          </div>
        </section>
      )}

      {/* 3. MOBILE-FIRST VERTICALLY STACKED GAMEPLAY SHELL (Top HUD -> Board/Tray -> Bottom 6-Joker Bar) */}
      {shellState !== 'title' && (
        <div className="fixed inset-0 z-10 pointer-events-none flex flex-col justify-between items-center px-2.5 py-2 sm:py-3">
          {/* STREAMLINED BLOCK BLAST PASTEL + RELIC TOP HUD */}
          <header className="w-full max-w-[468px] pointer-events-auto flex flex-col gap-1.5 bg-[#1B284B]/92 backdrop-blur-md px-2.5 sm:px-3.5 py-2 rounded-2xl border border-[#FFD95A]/55 shadow-xl">
            {/* Top Sub-Row: Crown Best, Milestone Progress Pill, Currencies, Hub Pills & Settings */}
            <div className="flex items-center justify-between gap-1 border-b border-white/15 pb-1.5">
              {/* Compact Currency, Milestone & Streak Readout */}
              <div className="flex items-center gap-1.5 text-[11px] sm:text-xs font-mono-tabular shrink-0">
                <button
                  type="button"
                  onClick={() => setActiveModal('shop')}
                  className="flex items-center gap-0.5 px-2 py-0.5 rounded-full bg-white/10 hover:bg-white/20 border border-white/15 text-amber-300 font-extrabold cursor-pointer"
                  title="Altın (Coins) · Market & Jokerler"
                >
                  <CoinIcon className="w-3.5 h-3.5 shrink-0" />
                  <span data-testid="hud-coins">{Math.round(coins)}</span>
                </button>
                <button
                  type="button"
                  onClick={() => setActiveModal('shop')}
                  className="flex items-center gap-0.5 px-1.5 py-0.5 rounded-full bg-white/10 hover:bg-white/20 border border-white/15 text-purple-200 font-extrabold cursor-pointer"
                  title="Elmas (Gems)"
                >
                  <GemIcon className="w-3.5 h-3.5 shrink-0" />
                  <span data-testid="hud-gems">{Math.round(gems)}</span>
                </button>
                {/* Block Blast Milestone Progress Pill */}
                <div
                  className="hidden sm:flex items-center gap-1 px-2 py-0.5 rounded-full bg-black/30 border border-white/15"
                  title="Hedef / Seviye İlerlemesi"
                >
                  <div className="w-10 h-2 rounded-full bg-black/50 overflow-hidden">
                    <div
                      className="h-full bg-gradient-to-r from-emerald-400 to-amber-300 transition-all duration-300"
                      style={{ width: `${milestonePct}%` }}
                    />
                  </div>
                  <span className="text-[10px] font-extrabold text-white">{milestonePct}%</span>
                </div>
              </div>

              {/* Compact Meta Hub Pills (Daily, Campaign, League, Shop, Godot) */}
              <div className="flex items-center gap-1 shrink-0">
                <button
                  type="button"
                  onClick={() => setActiveModal('daily')}
                  aria-label={`Daily Mosaic ${currentStreak}d Streak`}
                  className="flex items-center gap-0.5 px-1.5 py-1 rounded-lg bg-white/10 hover:bg-white/20 border border-white/15 text-[10px] font-bold text-orange-200 cursor-pointer transition-colors whitespace-nowrap"
                >
                  <FlameStreakIcon className="w-3 h-3 shrink-0" />
                  <span>{currentStreak}g</span>
                </button>
                <button
                  type="button"
                  onClick={() => setActiveModal('campaign')}
                  aria-label={`500 Campaigns Stage ${currentCampaignStage}`}
                  className="flex items-center gap-0.5 px-1.5 py-1 rounded-lg bg-white/10 hover:bg-white/20 border border-white/15 text-[10px] font-bold text-emerald-100 cursor-pointer transition-colors whitespace-nowrap"
                >
                  <MapIcon className="hidden sm:block w-3 h-3 shrink-0" />
                  <span>Blm {currentCampaignStage}</span>
                </button>
                <button
                  type="button"
                  onClick={() => setActiveModal('league')}
                  aria-label={`Weekly League Rank #${playerLeagueRank}`}
                  className="flex items-center gap-0.5 px-1.5 py-1 rounded-lg bg-white/10 hover:bg-white/20 border border-white/15 text-[10px] font-bold text-amber-200 cursor-pointer transition-colors whitespace-nowrap"
                >
                  <TrophyIcon className="hidden sm:block w-3 h-3 shrink-0" />
                  <span>#{playerLeagueRank}</span>
                </button>
                <button
                  type="button"
                  onClick={() => setActiveModal('shop')}
                  aria-label={`Relic Shop ${THEME_SKINS[equippedSkin].name}`}
                  className="flex items-center gap-0.5 px-1.5 py-1 rounded-lg bg-white/10 hover:bg-white/20 border border-white/15 text-[10px] font-bold text-amber-300 cursor-pointer transition-colors whitespace-nowrap"
                >
                  <ShopIcon className="hidden sm:block w-3 h-3 shrink-0" />
                  <span>Market</span>
                </button>
                <button
                  type="button"
                  onClick={() => setIsGodotModalOpen(true)}
                  aria-label="Godot 4 Export Studio"
                  title="Godot 4.3+ Proje & Kaynak Kod Paketi İndir"
                  className="flex items-center gap-0.5 px-1.5 py-1 rounded-lg bg-[#122636] hover:bg-[#1A364D] border border-[#478CBF] text-[10px] font-bold text-[#9AD4FF] cursor-pointer transition-colors whitespace-nowrap"
                >
                  <span>G4</span>
                </button>
              </div>

              {/* Compact Utility Controls: Mute [M], Pause/Settings [P], Curtain Restart */}
              <div className="flex items-center gap-1 shrink-0">
                <button
                  type="button"
                  tabIndex={-1}
                  aria-label={isMuted ? 'Unmute Audio' : 'Mute Audio'}
                  onClick={(e) => {
                    e.currentTarget.blur();
                    handleToggleMute();
                  }}
                  className="w-6 h-6 sm:w-7 sm:h-7 flex items-center justify-center rounded-lg bg-white/10 hover:bg-white/20 border border-white/15 cursor-pointer transition-colors"
                >
                  <MuteIcon muted={isMuted} className="w-3.5 h-3.5" />
                </button>
                <button
                  type="button"
                  tabIndex={-1}
                  aria-label="Pause Game"
                  onClick={(e) => {
                    e.currentTarget.blur();
                    handleTogglePause();
                  }}
                  className="w-6 h-6 sm:w-7 sm:h-7 flex items-center justify-center rounded-lg bg-white/10 hover:bg-white/20 border border-white/15 cursor-pointer transition-colors"
                >
                  <PauseIcon className="w-3.5 h-3.5" />
                </button>
                <button
                  type="button"
                  tabIndex={-1}
                  aria-label="Restart Run"
                  onClick={(e) => {
                    e.currentTarget.blur();
                    startNewRun(gameMode, architecture, currentCampaignStage, true);
                  }}
                  className="w-6 h-6 sm:w-7 sm:h-7 flex items-center justify-center rounded-lg bg-white/10 hover:bg-white/20 border border-white/15 cursor-pointer transition-colors"
                >
                  <RestartIcon className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>

            {/* Bottom Sub-Row: Glowing Hero Score with Beating Heart Combo Aura, Crown Best, & Objectives */}
            <div className="flex items-center justify-between gap-2 pt-0.5">
              <div className="flex items-center gap-3">
                {/* Hero Score + Beating Glowing Heart Combo Aura */}
                <div className="relative flex items-center gap-1.5">
                  {comboStreak > 0 && (
                    <span
                      id="comboHeartAura"
                      aria-hidden="true"
                      className="text-xl sm:text-2xl animate-pulse drop-shadow-[0_0_12px_rgba(255,94,132,0.95)]"
                    >
                      💖
                    </span>
                  )}
                  <div>
                    <div className="text-[9px] font-bold uppercase tracking-widest text-amber-200/85">
                      SKOR {comboStreak > 0 ? `· COMBO ${comboStreak}x` : ''}
                    </div>
                    <div
                      data-testid="hud-score"
                      className="text-2xl sm:text-3xl font-extrabold text-white drop-shadow-[0_3px_0_rgba(0,0,0,0.38)] hud-numeral leading-none"
                    >
                      {Math.round(score)}
                    </div>
                  </div>
                </div>

                <div className="h-7 w-px bg-white/15" />

                {/* Crown High Score / Best */}
                <div>
                  <div className="text-[9px] font-bold uppercase tracking-widest text-amber-300/90 flex items-center gap-0.5">
                    <span>👑</span>
                    <span>REKOR</span>
                  </div>
                  <div className="text-base font-extrabold text-amber-300 hud-numeral leading-none mt-0.5">
                    {Math.round(bestScore)}
                  </div>
                </div>
              </div>

              {/* Mode / Stage Objective Indicator + Quick Theme Toggle */}
              <div className="text-right text-xs flex flex-col items-end">
                <div className="flex items-center gap-1.5">
                  <button
                    type="button"
                    onClick={cyclePastelAndRelicTheme}
                    className="px-1.5 py-0.5 rounded bg-white/10 hover:bg-white/20 border border-white/15 text-[10px] font-bold text-amber-200 cursor-pointer"
                    title="Temayı Değiştir"
                  >
                    🎨 {THEME_SKINS[equippedSkin].name.split(' ')[0]}
                  </button>
                  <span className="font-extrabold text-amber-200 uppercase tracking-wide text-[11px]">
                    {gameMode === 'classic' && `Klasik · ${architecture.replace('_', ' ')}`}
                    {gameMode === 'daily' && `Günlük · ${movesRemaining} Hamle`}
                    {gameMode === 'blitz' && `Blitz · ${Math.round(blitzSecondsLeft)}sn`}
                    {gameMode === 'campaign' && `Blm ${currentCampaignStage} · ${movesRemaining}h`}
                  </span>
                </div>
                <div className="text-[11px] text-blue-100/85 font-mono-tabular truncate max-w-[205px] mt-0.5">
                  {(gameMode === 'daily' || gameMode === 'campaign') && objectives.length > 0
                    ? objectives
                        .map((o) => `${o.label.split(' ')[0]}: ${o.current}/${o.target}`)
                        .join(' · ')
                    : `${linesClearedRun} Satır Patlatıldı · ${milestonePct}%`}
                </div>
              </div>
            </div>
          </header>

          {/* DEDICATED BOTTOM 6-JOKER / BOOSTER TACTICAL BAR */}
          <footer
            aria-label="Strategic Boosters Dock"
            className="w-full max-w-[468px] pointer-events-auto flex flex-col items-center gap-1 bg-[#1B284B]/92 backdrop-blur-md px-2.5 py-2 rounded-2xl border border-[#FFD95A]/55 shadow-xl"
          >
            <div className="w-full grid grid-cols-6 gap-1">
              {(
                [
                  {
                    type: 'rotate' as const,
                    label: 'Döndür',
                    keyHint: '[R]',
                    icon: <RotateIcon className="w-4 h-4 sm:w-5 sm:h-5" />,
                  },
                  {
                    type: 'hammer' as const,
                    label: 'Çekiç',
                    keyHint: '[H]',
                    icon: <HammerIcon className="w-4 h-4 sm:w-5 sm:h-5" />,
                  },
                  {
                    type: 'reroll' as const,
                    label: 'Yenile',
                    keyHint: '[F]',
                    icon: <RerollIcon className="w-4 h-4 sm:w-5 sm:h-5" />,
                  },
                  {
                    type: 'bomb_blast' as const,
                    label: '3×3 Bomba',
                    keyHint: '[B]',
                    icon: <BombIcon className="w-4 h-4 sm:w-5 sm:h-5" />,
                  },
                  {
                    type: 'laser' as const,
                    label: 'Lazer',
                    keyHint: '[L]',
                    icon: <span className="text-base sm:text-lg leading-none">⚡</span>,
                  },
                  {
                    type: 'single_star' as const,
                    label: '1×1 Yıldız',
                    keyHint: '[G]',
                    icon: <span className="text-base sm:text-lg leading-none">✨</span>,
                  },
                ]
              ).map((b) => {
                const uses = boosterUsesSession[b.type];
                const stock = boosterStock[b.type];
                const cost = getBoosterCoinCost(b.type, uses);
                const isArmed = activeTargetingBooster === b.type;
                const isMaxed = uses >= MAX_BOOSTER_USES_PER_SESSION;

                return (
                  <button
                    key={b.type}
                    type="button"
                    disabled={isMaxed}
                    onClick={() => handleActivateBoosterMode(b.type)}
                    className="group flex flex-col items-center gap-0.5 cursor-pointer disabled:cursor-not-allowed disabled:opacity-45"
                  >
                    <div
                      className={`relative w-10 h-10 sm:w-11 sm:h-11 rounded-full flex items-center justify-center border-2 transition-transform group-hover:scale-105 group-active:scale-95 shadow-md ${
                        isArmed
                          ? 'bg-amber-400/35 border-amber-200 ring-2 ring-amber-300/60'
                          : isMaxed
                            ? 'bg-slate-950/70 border-slate-700'
                            : 'bg-gradient-to-b from-[#2A3E73] to-[#1A274B] border-[#FFD95A]/75 group-hover:border-amber-200'
                      }`}
                    >
                      {b.icon}

                      {/* Floating Stock or Compounding Coin Cost Badge */}
                      <span
                        className={`absolute -top-1 -right-1 px-1 py-0.2 rounded-full text-[9px] font-mono-tabular font-extrabold border shadow ${
                          isMaxed
                            ? 'bg-red-950 text-red-300 border-red-400/50'
                            : stock > 0
                              ? 'bg-emerald-500 text-slate-950 border-emerald-100'
                              : 'bg-amber-400 text-slate-950 border-amber-100'
                        }`}
                      >
                        {isMaxed ? 'CAP' : stock > 0 ? `x${stock}` : `${cost}c`}
                      </span>
                    </div>

                    {/* Label + Key Hint */}
                    <span className="text-[9px] sm:text-[10px] font-bold text-blue-50 whitespace-nowrap leading-tight">
                      {b.label} <span className="text-amber-300 font-mono-tabular">{b.keyHint}</span>
                    </span>
                  </button>
                );
              })}
            </div>

            {/* Subtle Contextual Status Strip */}
            <div className="w-full text-center text-[11px] text-blue-100/90 truncate border-t border-white/15 pt-1">
              {statusBannerText}
            </div>
          </footer>
        </div>
      )}

      {/* 4. PAUSE & BLOCK BLAST SETTINGS MODAL (body[data-state="paused"]) */}
      {shellState === 'paused' && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Game Paused"
          className="fixed inset-0 z-30 flex items-center justify-center p-4 bg-black/75 pointer-events-auto"
        >
          <div className="w-full max-w-md p-6 rounded-3xl bg-[#1F2C52] border-2 border-[#FFD95A] shadow-2xl text-center space-y-4">
            <h2 className="font-display text-2xl font-extrabold text-amber-300">
              ⚙️ Ayarlar & Duraklatma
            </h2>
            <p className="text-xs text-blue-100/80">
              Tahta durumun, kombo serin ve aktif blokların korunuyor.
            </p>

            {/* Sound Effects & Relaxing Procedural BGM Switches */}
            <div className="space-y-2 text-left">
              <div className="flex items-center justify-between px-4 py-2.5 rounded-2xl bg-black/25 border border-white/10">
                <span className="text-xs font-bold text-white">🔊 Ses Efektleri (SFX)</span>
                <button
                  type="button"
                  onClick={handleToggleMute}
                  className={`px-3 py-1 rounded-full text-xs font-extrabold cursor-pointer transition-colors ${
                    !isMuted
                      ? 'bg-emerald-400 text-slate-950'
                      : 'bg-slate-700 text-slate-300'
                  }`}
                >
                  {!isMuted ? 'AÇIK' : 'KAPALI'}
                </button>
              </div>
              <div className="flex items-center justify-between px-4 py-2.5 rounded-2xl bg-black/25 border border-white/10">
                <span className="text-xs font-bold text-white">🎵 Rahatlatıcı Müzik (BGM)</span>
                <button
                  type="button"
                  onClick={handleToggleBgm}
                  className={`px-3 py-1 rounded-full text-xs font-extrabold cursor-pointer transition-colors ${
                    bgmEnabled
                      ? 'bg-emerald-400 text-slate-950'
                      : 'bg-slate-700 text-slate-300'
                  }`}
                >
                  {bgmEnabled ? 'AÇIK' : 'KAPALI'}
                </button>
              </div>
            </div>

            <div className="grid grid-cols-3 gap-2.5 p-3 rounded-2xl bg-black/30 border border-white/10 font-mono-tabular">
              <div>
                <div className="text-[10px] text-blue-200/70 uppercase">SKOR</div>
                <div className="text-lg font-bold text-amber-300">{Math.round(score)}</div>
              </div>
              <div>
                <div className="text-[10px] text-blue-200/70 uppercase">SATIR</div>
                <div className="text-lg font-bold text-white">{linesClearedRun}</div>
              </div>
              <div>
                <div className="text-[10px] text-blue-200/70 uppercase">LİG</div>
                <div className="text-lg font-bold text-emerald-300">#{playerLeagueRank}</div>
              </div>
            </div>

            <div className="flex flex-col gap-2">
              <button
                type="button"
                onClick={() => setShellState('playing')}
                className="w-full py-3 px-5 rounded-2xl bg-amber-400 hover:bg-amber-300 text-slate-950 font-extrabold text-sm cursor-pointer transition-colors"
              >
                ▶ Oyuna Devam Et (Resume)
              </button>
              <button
                type="button"
                onClick={() => startNewRun(gameMode, architecture, currentCampaignStage, true)}
                className="w-full py-2.5 px-5 rounded-2xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-extrabold text-xs cursor-pointer transition-colors"
              >
                🔄 Yeniden Başlat (Perde Geçişi)
              </button>
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setShellState('playing');
                    setActiveModal('shop');
                  }}
                  className="py-2.5 px-3 rounded-2xl bg-white/10 hover:bg-white/20 border border-white/15 text-amber-200 font-bold text-xs cursor-pointer transition-colors"
                >
                  🎨 Tema & Market
                </button>
                <button
                  type="button"
                  onClick={() => setIsGodotModalOpen(true)}
                  className="py-2.5 px-3 rounded-2xl bg-[#14293A] hover:bg-[#1D3B52] border border-[#478CBF] text-[#9AD4FF] font-bold text-xs cursor-pointer transition-colors"
                >
                  📦 Godot 4 (.ZIP)
                </button>
              </div>
              <button
                type="button"
                onClick={() => setShellState('title')}
                className="w-full py-2.5 px-5 rounded-2xl bg-black/35 hover:bg-black/50 border border-white/15 text-blue-100/80 font-semibold text-xs cursor-pointer transition-colors"
              >
                🏠 Ana Ekrana Dön (Title Screen)
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 5. VICTORY / OUT-OF-MOVES JOKER RESCUE MODAL (body[data-state="gameover"]) */}
      {shellState === 'gameover' && frozenSummary && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label={frozenSummary.outcome === 'victory' ? 'Stage Clear Victory' : 'Game Over'}
          className="fixed inset-0 z-30 flex items-center justify-center p-4 bg-black/80 pointer-events-auto"
        >
          <div className="w-full max-w-md p-6 rounded-3xl bg-[#1F2C52] border-2 border-[#FFD95A] shadow-2xl text-center space-y-4">
            <div>
              <div className="text-xs font-extrabold uppercase tracking-widest text-amber-300">
                {frozenSummary.outcome === 'victory' ? '🎉 BÖLÜM TAMAMLANDI!' : '😮 HAMLE KALMADI!'}
              </div>
              <h2 className="font-display text-2xl font-extrabold text-white mt-1">
                {frozenSummary.outcome === 'victory'
                  ? 'Relic & Pastel Zaferi!'
                  : 'Joker Kullanıp Devam Et veya Yeni Oyun Başlat'}
              </h2>
            </div>

            <div className="grid grid-cols-3 gap-2.5 p-3.5 rounded-2xl bg-black/30 border border-white/15 font-mono-tabular">
              <div>
                <div className="text-[10px] text-blue-200/75 uppercase">SKOR / REKOR</div>
                <div className="text-sm font-bold text-amber-300 mt-0.5">
                  {Math.round(frozenSummary.score)} / {Math.round(frozenSummary.bestScore)}
                </div>
              </div>
              <div>
                <div className="text-[10px] text-blue-200/75 uppercase">PATLAYAN SATIR</div>
                <div className="text-sm font-bold text-white mt-0.5">
                  {frozenSummary.linesClearedTotal}
                </div>
              </div>
              <div>
                <div className="text-[10px] text-blue-200/75 uppercase">KAZANILAN COİN</div>
                <div className="text-sm font-bold text-emerald-300 mt-0.5">
                  +{frozenSummary.coinsEarnedRun}
                </div>
              </div>
            </div>

            {frozenSummary.outcome === 'victory' && !frozenSummary.doubledPayoutClaimed && (
              <button
                type="button"
                onClick={() => {
                  soundSynth.playVictory();
                  setCoins((c) => c + frozenSummary.coinsEarnedRun);
                  setFrozenSummary((prev) =>
                    prev
                      ? {
                          ...prev,
                          coinsEarnedRun: prev.coinsEarnedRun * 2,
                          doubledPayoutClaimed: true,
                        }
                      : null
                  );
                }}
                className="w-full py-2.5 px-4 rounded-2xl bg-emerald-600 hover:bg-emerald-500 border border-emerald-300 text-white font-bold text-xs cursor-pointer transition-colors"
              >
                🎁 Ödülü İkiye Katla (+{frozenSummary.coinsEarnedRun} Bonus Coin)
              </button>
            )}

            {/* Block Blast Out-of-Moves Joker Rescue Grid */}
            {frozenSummary.outcome === 'defeat' && (
              <div className="space-y-2 text-left bg-black/25 p-3 rounded-2xl border border-white/10">
                <div className="text-[11px] font-extrabold text-amber-300 uppercase tracking-wider text-center">
                  ⚡ Joker ile Oyunu Kurtar (Keep Playing)
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => handleOutOfMovesJokerRescue('reroll')}
                    className="p-2.5 rounded-xl bg-white/10 hover:bg-white/20 border border-white/15 flex flex-col items-center gap-0.5 cursor-pointer"
                  >
                    <span className="text-sm font-extrabold text-white">↻ Blokları Yenile</span>
                    <span className="text-[10px] font-bold text-amber-300">
                      {boosterStock.reroll > 0 ? `Stoktan (x${boosterStock.reroll})` : '🪙 25 Coin'}
                    </span>
                  </button>
                  <button
                    type="button"
                    onClick={() => handleOutOfMovesJokerRescue('single_star')}
                    className="p-2.5 rounded-xl bg-white/10 hover:bg-white/20 border border-white/15 flex flex-col items-center gap-0.5 cursor-pointer"
                  >
                    <span className="text-sm font-extrabold text-white">✨ 1×1 Yıldız Blok</span>
                    <span className="text-[10px] font-bold text-amber-300">
                      {boosterStock.single_star > 0
                        ? `Stoktan (x${boosterStock.single_star})`
                        : '🪙 35 Coin'}
                    </span>
                  </button>
                </div>

                {!lastChanceUsed && (
                  <button
                    type="button"
                    onClick={() => handleOutOfMovesJokerRescue('center_bomb')}
                    className="w-full py-2.5 px-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 border border-emerald-300 text-white font-bold text-xs cursor-pointer transition-colors text-center"
                  >
                    💥 Ücretsiz Son Şans (Merkez 3×3 Temizle & Devam Et)
                  </button>
                )}
              </div>
            )}

            <div className="flex flex-col gap-2">
              <button
                type="button"
                data-start="true"
                onClick={() => {
                  const nextStage =
                    frozenSummary.outcome === 'victory' && gameMode === 'campaign'
                      ? Math.min(500, currentCampaignStage + 1)
                      : currentCampaignStage;
                  setCurrentCampaignStage(nextStage);
                  startNewRun(gameMode, architecture, nextStage, true);
                }}
                className="w-full py-3 px-5 rounded-2xl bg-amber-400 hover:bg-amber-300 text-slate-950 font-extrabold text-sm cursor-pointer transition-colors"
              >
                {frozenSummary.outcome === 'victory' && gameMode === 'campaign'
                  ? `Sonraki Bölüm (Bölüm ${Math.min(500, currentCampaignStage + 1)})`
                  : '🔄 Tekrar Oyna (Perde Geçişi)'}
              </button>
              <button
                type="button"
                onClick={() => setShellState('title')}
                className="w-full py-2.5 px-5 rounded-2xl bg-black/35 hover:bg-black/50 border border-white/15 text-blue-100/80 font-semibold text-xs cursor-pointer transition-colors"
              >
                🏠 Ana Ekrana Dön
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 6. META-PROGRESSION MODALS */}
      <MetaModals
        activeModal={activeModal}
        onClose={() => setActiveModal(null)}
        coins={coins}
        gems={gems}
        calendar={calendar}
        streakChests={streakChests}
        onClaimStreakChest={handleClaimStreakChest}
        onRecoverMissedDay={handleRecoverMissedDay}
        onStartDailyPuzzle={() => startNewRun('daily', 'holed', currentCampaignStage, true)}
        highestCampaignStage={highestCampaignStage}
        currentCampaignStage={currentCampaignStage}
        onSelectCampaignStage={(stageNumber) => {
          setCurrentCampaignStage(stageNumber);
          startNewRun('campaign', getCampaignStageConfig(stageNumber).architecture, stageNumber, true);
        }}
        leagueCohort={leagueCohort}
        unlockedSkins={unlockedSkins}
        equippedSkin={equippedSkin}
        onBuyOrEquipSkin={handleBuyOrEquipSkin}
        claimedShopBundles={claimedShopBundles}
        onPurchaseBundle={handlePurchaseBundle}
        boosterStock={boosterStock}
        onBuySingleBooster={handleBuySingleBooster}
        onGrantFreeCoins={handleGrantFreeCoins}
      />

      {/* 7. GODOT 4.3+ PROJECT EXPORT STUDIO MODAL */}
      <GodotExportModal
        isOpen={isGodotModalOpen}
        onClose={() => setIsGodotModalOpen(false)}
      />
    </main>
  );
}


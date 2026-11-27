import React, { useState } from 'react';
import {
  CalendarDayEntry,
  LeagueParticipant,
  SHOP_BUNDLES,
  ShopBundle,
  StreakChestTier,
  THEME_SKINS,
   computeCalendarStreak,
} from '../game/metaState';
import { BoosterType, ThemeSkinId, getCampaignStageConfig } from '../game/rules';
import {
  CalendarIcon,
  CoinIcon,
  FlameStreakIcon,
  GemIcon,
  MapIcon,
  ShopIcon,
  TrophyIcon,
} from './RelicIcons';

export type ActiveMetaModal = 'daily' | 'campaign' | 'league' | 'shop' | null;

interface MetaModalsProps {
  activeModal: ActiveMetaModal;
  onClose: () => void;
  coins: number;
  gems: number;
  calendar: CalendarDayEntry[];
  streakChests: StreakChestTier[];
  onClaimStreakChest: (chestId: string) => void;
  onRecoverMissedDay: (day: number, method: 'gems' | 'ad') => void;
  onStartDailyPuzzle: () => void;
  highestCampaignStage: number;
  currentCampaignStage: number;
  onSelectCampaignStage: (stageNumber: number) => void;
  leagueCohort: LeagueParticipant[];
  unlockedSkins: ThemeSkinId[];
  equippedSkin: ThemeSkinId;
  onBuyOrEquipSkin: (skinId: ThemeSkinId) => void;
  claimedShopBundles: string[];
  onPurchaseBundle: (bundle: ShopBundle) => void;
  boosterStock: Record<BoosterType, number>;
  onBuySingleBooster?: (booster: BoosterType, costCoins: number) => void;
  onGrantFreeCoins?: (amount: number) => void;
}

export const MetaModals: React.FC<MetaModalsProps> = ({
  activeModal,
  onClose,
  coins,
  gems,
  calendar,
  streakChests,
  onClaimStreakChest,
  onRecoverMissedDay,
  onStartDailyPuzzle,
  highestCampaignStage,
  currentCampaignStage,
  onSelectCampaignStage,
  leagueCohort,
  unlockedSkins,
  equippedSkin,
  onBuyOrEquipSkin,
  claimedShopBundles,
  onPurchaseBundle,
  boosterStock,
  onBuySingleBooster,
  onGrantFreeCoins,
}) => {
  const [selectedBiomePage, setSelectedBiomePage] = useState<number>(0); // 0..9 (50 stages per biome, 500 total)
  const [simulatingAdText, setSimulatingAdText] = useState<string | null>(null);

  if (!activeModal) return null;

  const { currentStreak, completedDaysCount, missedDaysCount } = computeCalendarStreak(calendar);

  const triggerSimulatedRewardedAd = (label: string, onDone: () => void) => {
    setSimulatingAdText(label);
    window.setTimeout(() => {
      setSimulatingAdText(null);
      onDone();
    }, 900);
  };

  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center p-4 bg-black/80 pointer-events-auto"
      role="dialog"
      aria-modal="true"
      aria-label={`RelicGrid ${activeModal} modal`}
    >
      <div className="w-full max-w-4xl max-h-[86vh] flex flex-col rounded-xl bg-[#0B1C16] border-2 border-[#D99B26] shadow-2xl overflow-hidden text-[#F3EFE6]">
        {/* Modal Header */}
        <div className="flex items-center justify-between px-6 py-4 bg-[#07130F] border-b border-[#1D4033]">
          <div className="flex items-center gap-3">
            {activeModal === 'daily' && <CalendarIcon className="w-6 h-6" />}
            {activeModal === 'campaign' && <MapIcon className="w-6 h-6" />}
            {activeModal === 'league' && <TrophyIcon className="w-6 h-6" />}
            {activeModal === 'shop' && <ShopIcon className="w-6 h-6" />}
            <div>
              <h2 className="font-display text-xl font-bold tracking-wide text-amber-300">
                {activeModal === 'daily' && 'Daily Relic Calendar & November Mosaic'}
                {activeModal === 'campaign' && '500-Stage Odyssey & Pastel Macera Map'}
                {activeModal === 'league' && 'Weekly Gold II Cohort Leaderboard (30 Players)'}
                {activeModal === 'shop' && 'Pastel & Relic Market · Temalar & Jokerler'}
              </h2>
              <p className="text-xs text-emerald-200/75">
                {activeModal === 'daily' &&
                  `November 2026 · Mystic Forest Collection · ${completedDaysCount}/30 Mosaic Pieces Revealed`}
                {activeModal === 'campaign' &&
                  `10 Ancient Biomes · 500 Progressive Stages · Highest Reached: Stage ${highestCampaignStage}`}
                {activeModal === 'league' &&
                  'Resets Sunday Midnight (3d 09h 59m left) · Top 3 Win Promotion Chests · Ranks 24-30 Demote'}
                {activeModal === 'shop' &&
                  'Pastel Block Blast & Relic Temaları · 6 Taktiksel Joker Marketi'}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-5">
            <div className="flex items-center gap-1.5 text-sm font-mono-tabular text-amber-300">
              <CoinIcon className="w-4 h-4" />
              <span>{coins}</span>
              <span className="text-emerald-500/50 mx-1">·</span>
              <GemIcon className="w-4 h-4" />
              <span className="text-purple-300">{gems}</span>
            </div>
            <button
              type="button"
              onClick={onClose}
              className="px-3.5 py-1.5 rounded-lg bg-[#122A21] hover:bg-[#1A3B2F] border border-amber-500/40 text-xs font-semibold text-amber-200 transition-colors cursor-pointer whitespace-nowrap shrink-0"
            >
              Close [Esc]
            </button>
          </div>
        </div>

        {/* Simulated Rewarded Ad Toast Banner */}
        {simulatingAdText && (
          <div className="px-6 py-2.5 bg-amber-900/60 border-b border-amber-400/40 flex items-center justify-between text-xs text-amber-100">
            <span>Rewarded Sponsor Preview: {simulatingAdText}...</span>
            <span className="font-mono-tabular font-semibold">Granting Reward...</span>
          </div>
        )}

        {/* Modal Body */}
        <div className="p-6 overflow-y-auto space-y-6">
          {/* 1. DAILY PUZZLE, STREAK CALENDAR & 30-PIECE MOSAIC */}
          {activeModal === 'daily' && (
            <div className="space-y-6">
              {/* Top Summary Bar + Streak Saver Alert */}
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                <div className="p-4 rounded-lg bg-[#0E241C] border border-[#1D4033] flex items-center justify-between">
                  <div>
                    <div className="text-xs text-emerald-300/80 uppercase tracking-wider">Active Login Streak</div>
                    <div className="text-2xl font-mono-tabular font-bold text-amber-300 mt-0.5">
                      {currentStreak} Days
                    </div>
                    <div className="text-xs text-emerald-200/70 mt-1">
                      {missedDaysCount > 0
                        ? 'Recover Nov 4 to link your 7-Day Streak!'
                        : 'Unbroken streak through November!'}
                    </div>
                  </div>
                  <FlameStreakIcon className="w-10 h-10" />
                </div>

                {/* Streak Saver Mechanism Card */}
                <div className="p-4 rounded-lg bg-[#0E241C] border border-amber-500/40 flex flex-col justify-between">
                  <div>
                    <div className="text-xs font-semibold text-amber-300">Streak Saver Mechanism</div>
                    <p className="text-xs text-emerald-100/80 mt-1">
                      {missedDaysCount > 0
                        ? 'Nov 4 was missed! Turn it green now to restore your 7-Day Streak Chest.'
                        : 'All past November dates are green and protected!'}
                    </p>
                  </div>
                  {missedDaysCount > 0 ? (
                    <div className="flex items-center gap-2 mt-3">
                      <button
                        type="button"
                        onClick={() => onRecoverMissedDay(4, 'gems')}
                        className="px-3 py-1.5 rounded bg-purple-700 hover:bg-purple-600 text-xs font-semibold text-white transition-colors cursor-pointer whitespace-nowrap shrink-0"
                      >
                        Recover Nov 4 (15 Gems)
                      </button>
                      <button
                        type="button"
                        onClick={() =>
                          triggerSimulatedRewardedAd('Streak Saver Ad', () =>
                            onRecoverMissedDay(4, 'ad')
                          )
                        }
                        className="px-3 py-1.5 rounded bg-amber-600 hover:bg-amber-500 text-xs font-semibold text-slate-950 transition-colors cursor-pointer whitespace-nowrap shrink-0"
                      >
                        Watch Ad (Free Save)
                      </button>
                    </div>
                  ) : (
                    <div className="text-xs font-semibold text-emerald-400 mt-3">
                      Streak Protected · 0 Missed Days
                    </div>
                  )}
                </div>

                {/* Play Today's Objective CTA */}
                <div className="p-4 rounded-lg bg-[#122E23] border border-emerald-500/40 flex flex-col justify-between">
                  <div>
                    <div className="text-xs font-semibold text-emerald-300">
                      Nov 8 Daily Objective
                    </div>
                    <p className="text-xs text-emerald-100/85 mt-1">
                      Clear 12 Ruby Blocks & Shatter 2 Ice Blocks within 14 Moves.
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={onStartDailyPuzzle}
                    className="mt-3 w-full py-2 px-4 rounded-lg bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs transition-colors cursor-pointer whitespace-nowrap"
                  >
                    Play Today&apos;s Daily Puzzle (+150 Coins)
                  </button>
                </div>
              </div>

              {/* 4-Tier Streak Chest Progression */}
              <div>
                <h3 className="text-sm font-semibold text-amber-200 mb-3">
                  Streak & Monthly Milestone Chests
                </h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                  {streakChests.map((chest) => {
                    const unlocked =
                      chest.daysRequired === 30
                        ? completedDaysCount >= 30
                        : currentStreak >= chest.daysRequired;
                    return (
                      <div
                        key={chest.id}
                        className={`p-3.5 rounded-lg border flex flex-col justify-between ${
                          unlocked
                            ? 'bg-[#133024] border-amber-400'
                            : 'bg-[#0C1D17] border-[#1D4033]'
                        }`}
                      >
                        <div>
                          <div className="text-xs font-mono-tabular text-amber-300">
                            {chest.daysRequired}-Day Milestone
                          </div>
                          <div className="text-sm font-bold text-white mt-0.5">{chest.title}</div>
                          <p className="text-xs text-emerald-200/75 mt-1">{chest.rewardSummary}</p>
                        </div>
                        <div className="mt-3">
                          {chest.claimed ? (
                            <span className="text-xs font-semibold text-emerald-400">
                              Claimed
                            </span>
                          ) : unlocked ? (
                            <button
                              type="button"
                              onClick={() => onClaimStreakChest(chest.id)}
                              className="w-full py-1.5 px-3 rounded bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs transition-colors cursor-pointer"
                            >
                              Claim {chest.daysRequired}-Day Chest
                            </button>
                          ) : (
                            <span className="text-xs text-emerald-200/50 font-mono-tabular">
                              Requires {chest.daysRequired}d Streak ({currentStreak}/{chest.daysRequired})
                            </span>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Calendar + 30-Piece Mystic Forest Mosaic Side-by-Side */}
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* November 30-Day Calendar Grid */}
                <div className="p-4 rounded-lg bg-[#0E241C] border border-[#1D4033]">
                  <div className="flex items-center justify-between mb-3">
                    <h3 className="text-sm font-semibold text-amber-200">
                      November 2026 Login Calendar
                    </h3>
                    <span className="text-xs text-emerald-200/70">
                      Green = Completed · Amber = Missed
                    </span>
                  </div>
                  <div className="grid grid-cols-6 gap-2">
                    {calendar.map((entry) => {
                      const isDone = entry.status === 'completed';
                      const isMissed = entry.status === 'missed';
                      const isToday = entry.status === 'today';
                      return (
                        <div
                          key={entry.day}
                          className={`p-2 rounded border text-center transition-colors ${
                            isDone
                              ? 'bg-emerald-800/70 border-emerald-400 text-emerald-100'
                              : isMissed
                                ? 'bg-amber-900/60 border-amber-400 text-amber-200'
                                : isToday
                                  ? 'bg-amber-500/20 border-amber-300 text-amber-200'
                                  : 'bg-[#091812] border-[#173329] text-emerald-200/40'
                          }`}
                        >
                          <div className="text-xs font-mono-tabular font-bold">Nov {entry.day}</div>
                          <div className="text-[10px] mt-0.5 truncate">
                            {isDone
                              ? 'Solved'
                              : isMissed
                                ? 'Missed'
                                : isToday
                                  ? 'Today'
                                  : 'Locked'}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* 30-Piece Mystic Forest Mosaic Illustration */}
                <div className="p-4 rounded-lg bg-[#0E241C] border border-[#1D4033] flex flex-col justify-between">
                  <div className="flex items-center justify-between mb-3">
                    <div>
                      <h3 className="text-sm font-semibold text-amber-200">
                        November Theme: &ldquo;Mystic Forest&rdquo; 30-Piece Mosaic
                      </h3>
                      <p className="text-xs text-emerald-200/70">
                        Each daily puzzle reveals 1 mosaic tile toward the Grand Reliquary
                      </p>
                    </div>
                    <span className="text-sm font-mono-tabular font-bold text-amber-300">
                      {completedDaysCount}/30
                    </span>
                  </div>

                  <div className="grid grid-cols-6 gap-1.5 p-2 rounded-lg bg-[#07130F] border border-[#1D4033]">
                    {calendar.map((entry) => {
                      const revealed = entry.status === 'completed';
                      return (
                        <div
                          key={entry.day}
                          title={`Piece #${entry.day}: ${entry.mosaicPieceTitle}`}
                          className={`h-11 rounded flex flex-col items-center justify-center p-1 text-center border ${
                            revealed
                              ? 'bg-gradient-to-br from-emerald-700 via-teal-800 to-amber-700/80 border-amber-300/60 text-amber-100'
                              : 'bg-[#0B1C16] border-[#152E24] text-emerald-500/30'
                          }`}
                        >
                          <span className="text-[10px] font-mono-tabular font-bold">
                            #{entry.day}
                          </span>
                          <span className="text-[9px] leading-tight truncate w-full">
                            {revealed ? entry.mosaicPieceTitle : 'Hidden'}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* 2. 500-STAGE CAMPAIGN MAP */}
          {activeModal === 'campaign' && (
            <div className="space-y-5">
              {/* Biome Selector Tabs (10 Biomes x 50 Stages = 500 Stages) */}
              <div className="flex flex-wrap items-center gap-1.5 p-1.5 rounded-lg bg-[#07130F] border border-[#1D4033]">
                {Array.from({ length: 10 }, (_, idx) => {
                  const startStage = idx * 50 + 1;
                  const endStage = (idx + 1) * 50;
                  const active = selectedBiomePage === idx;
                  return (
                    <button
                      key={idx}
                      type="button"
                      onClick={() => setSelectedBiomePage(idx)}
                      className={`px-3 py-1.5 rounded text-xs font-mono-tabular font-semibold transition-colors cursor-pointer whitespace-nowrap shrink-0 ${
                        active
                          ? 'bg-amber-500 text-slate-950'
                          : 'text-emerald-200/75 hover:text-white hover:bg-[#122A21]'
                      }`}
                    >
                      Stages {startStage}–{endStage}
                    </button>
                  );
                })}
              </div>

              {/* Grid of 50 Stages for the selected Biome */}
              <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
                {Array.from({ length: 50 }, (_, i) => {
                  const stageNum = selectedBiomePage * 50 + i + 1;
                  const cfg = getCampaignStageConfig(stageNum);
                  const isUnlocked = stageNum <= highestCampaignStage;
                  const isCurrent = stageNum === currentCampaignStage;

                  return (
                    <button
                      key={stageNum}
                      type="button"
                      disabled={!isUnlocked}
                      onClick={() => onSelectCampaignStage(stageNum)}
                      className={`p-3 rounded-lg border text-left transition-all ${
                        isCurrent
                          ? 'bg-[#173A2D] border-amber-400 shadow-md cursor-pointer'
                          : isUnlocked
                            ? 'bg-[#0E241C] border-emerald-500/40 hover:border-amber-300 cursor-pointer'
                            : 'bg-[#081510] border-[#142B22] opacity-50 cursor-not-allowed'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-mono-tabular font-bold text-amber-300">
                          Stage {stageNum}
                        </span>
                        <span className="text-[10px] text-emerald-300/80 uppercase">
                          {cfg.architecture.replace('_', ' ')}
                        </span>
                      </div>
                      <div className="text-xs font-semibold text-white mt-1 truncate">
                        {cfg.biome}
                      </div>
                      <div className="text-[11px] text-emerald-200/70 mt-1 font-mono-tabular">
                        Target: {cfg.objectives[0].target} pts · {cfg.moveLimit}m
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* 3. WEEKLY 30-PLAYER LEAGUE COHORT */}
          {activeModal === 'league' && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-3.5 rounded-lg bg-[#122E23] border border-amber-400/50">
                  <div className="text-xs text-amber-300 font-semibold">
                    Top 3 · Diamond Promotion & Chest
                  </div>
                  <p className="text-xs text-emerald-100/80 mt-1">
                    Ranks #1–#3 advance to Diamond Tier and earn 500 Coins + Exclusive League Frame.
                  </p>
                </div>
                <div className="p-3.5 rounded-lg bg-[#0E241C] border border-[#1D4033]">
                  <div className="text-xs text-emerald-300 font-semibold">
                    Ranks #4–#10 · Promotion Zone
                  </div>
                  <p className="text-xs text-emerald-100/80 mt-1">
                    Advance to the next tier on Monday&apos;s fresh weekly reset.
                  </p>
                </div>
                <div className="p-3.5 rounded-lg bg-red-950/40 border border-red-500/40">
                  <div className="text-xs text-red-300 font-semibold">
                    Ranks #24–#30 · Demotion Danger Zone
                  </div>
                  <p className="text-xs text-red-200/80 mt-1">
                    Players below #23 demote to Silver Tier on Sunday at midnight!
                  </p>
                </div>
              </div>

              <div className="rounded-lg border border-[#1D4033] overflow-hidden">
                <table className="w-full text-left border-collapse text-xs">
                  <thead>
                    <tr className="bg-[#07130F] text-emerald-300/80 border-b border-[#1D4033]">
                      <th className="py-2.5 px-4 font-semibold">Rank</th>
                      <th className="py-2.5 px-4 font-semibold">Relic Seeker</th>
                      <th className="py-2.5 px-4 font-semibold">Status Zone</th>
                      <th className="py-2.5 px-4 font-semibold text-right">Weekly Score</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-[#152E24]">
                    {leagueCohort.map((entry, index) => {
                      const rank = index + 1;
                      const isTop3 = rank <= 3;
                      const isPromote = rank >= 4 && rank <= 10;
                      const isDemote = rank >= 24;

                      return (
                        <tr
                          key={entry.id}
                          className={
                            entry.isPlayer
                              ? 'bg-amber-500/20 font-semibold text-amber-200'
                              : isDemote
                                ? 'bg-red-950/20 text-red-200/80'
                                : 'bg-[#0B1C16] text-emerald-100'
                          }
                        >
                          <td className="py-2 px-4 font-mono-tabular font-bold">
                            #{rank}
                          </td>
                          <td className="py-2 px-4">
                            <span>{entry.name}</span>
                            <span className="text-emerald-400/50 mx-1.5">·</span>
                            <span className="text-emerald-200/70">{entry.badge}</span>
                          </td>
                          <td className="py-2 px-4">
                            {isTop3
                              ? 'Top 3 Grand Chest + Promote'
                              : isPromote
                                ? 'Promotion Zone'
                                : isDemote
                                  ? 'Demotion Danger Zone'
                                  : 'Safe Cohort Zone'}
                          </td>
                          <td className="py-2 px-4 text-right font-mono-tabular font-bold">
                            {entry.score.toLocaleString()}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* 4. RELIC & PASTEL SHOP: SKINS, JOKERS & F2P REWARDED AD BUNDLES */}
          {activeModal === 'shop' && (
            <div className="space-y-6">
              {/* Cosmetics & Visual Block Skins (Pastel Blast + Relic Themes) */}
              <div>
                <h3 className="text-sm font-semibold text-amber-200 mb-3">
                  🎨 Görsel Temalar & Blok Setleri (Pastel Blast & Relic Koleksiyonu)
                </h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3.5">
                  {Object.values(THEME_SKINS).map((skin) => {
                    const isUnlocked = unlockedSkins.includes(skin.id);
                    const isEquipped = equippedSkin === skin.id;

                    return (
                      <div
                        key={skin.id}
                        className={`p-4 rounded-lg border flex flex-col justify-between ${
                          isEquipped
                            ? 'bg-[#153428] border-amber-400'
                            : 'bg-[#0E241C] border-[#1D4033]'
                        }`}
                      >
                        <div>
                          <div className="flex items-center justify-between">
                            <span className="text-sm font-bold text-white">{skin.name}</span>
                            <div className="flex items-center gap-1">
                              {Object.values(skin.blocks).map((b, i) => (
                                <span
                                  key={i}
                                  className="w-3 h-3 rounded-xs border border-black/40"
                                  style={{ backgroundColor: b.fill }}
                                />
                              ))}
                            </div>
                          </div>
                          <p className="text-xs text-emerald-200/75 mt-1">{skin.subtitle}</p>
                        </div>

                        <div className="mt-4">
                          {isEquipped ? (
                            <span className="text-xs font-bold text-amber-300">
                              ✓ Seçili Tema (Equipped)
                            </span>
                          ) : isUnlocked ? (
                            <button
                              type="button"
                              onClick={() => onBuyOrEquipSkin(skin.id)}
                              className="w-full py-1.5 px-3 rounded bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-xs transition-colors cursor-pointer"
                            >
                              Seç ({skin.name})
                            </button>
                          ) : (
                            <button
                              type="button"
                              onClick={() => onBuyOrEquipSkin(skin.id)}
                              className="w-full py-1.5 px-3 rounded bg-purple-700 hover:bg-purple-600 text-white font-semibold text-xs transition-colors cursor-pointer"
                            >
                              {skin.costCoins
                                ? `Aç (${skin.costCoins} Coin / ${skin.costGems} Gem)`
                                : `Aç (${skin.costGems} Gems)`}
                            </button>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Pastel Blast Individual Joker Market + Free +50 Coin Button */}
              {onBuySingleBooster && (
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <h3 className="text-sm font-semibold text-amber-200">
                      ⚡ Tekli Taktiksel Joker Satın Al (Stok Ekle)
                    </h3>
                    {onGrantFreeCoins && (
                      <button
                        type="button"
                        onClick={() => onGrantFreeCoins(50)}
                        className="px-3 py-1 rounded-lg bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs cursor-pointer transition-colors"
                      >
                        🎁 +50 Coin Ücretsiz Bonus Al
                      </button>
                    )}
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                    {(
                      [
                        { type: 'reroll' as const, title: '↻ Yenile (Shuffle)', cost: 25 },
                        { type: 'rotate' as const, title: '⟳ Döndür (Rotate)', cost: 20 },
                        { type: 'hammer' as const, title: '🔨 Çekiç (Hammer)', cost: 30 },
                        { type: 'bomb_blast' as const, title: '💥 3×3 Bomba', cost: 40 },
                        { type: 'laser' as const, title: '⚡ Satır/Sütun Lazeri', cost: 45 },
                        { type: 'single_star' as const, title: '✨ 1×1 Yıldız Blok', cost: 35 },
                      ]
                    ).map((j) => (
                      <div
                        key={j.type}
                        className="p-3 rounded-lg bg-[#0E241C] border border-[#1D4033] flex flex-col justify-between gap-2"
                      >
                        <div className="flex items-center justify-between">
                          <span className="text-xs font-bold text-white">{j.title}</span>
                          <span className="text-xs font-mono-tabular font-bold text-emerald-300">
                            x{boosterStock[j.type] || 0}
                          </span>
                        </div>
                        <button
                          type="button"
                          onClick={() => onBuySingleBooster(j.type, j.cost)}
                          className="w-full py-1.5 px-2.5 rounded bg-amber-500/90 hover:bg-amber-400 text-slate-950 font-bold text-xs cursor-pointer transition-colors"
                        >
                          +1 Al (🪙 {j.cost})
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Booster Bundles, Value Starter Pack & F2P Daily Ad Chest */}
              <div>
                <h3 className="text-sm font-semibold text-amber-200 mb-3">
                  📦 Avantaj Paketleri & Günlük Ücretsiz Sandık
                </h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  {SHOP_BUNDLES.map((bundle) => {
                    const alreadyClaimed = claimedShopBundles.includes(bundle.id);
                    return (
                      <div
                        key={bundle.id}
                        className="p-4 rounded-lg bg-[#0E241C] border border-[#1D4033] flex flex-col justify-between"
                      >
                        <div>
                          <div className="text-sm font-bold text-amber-200">{bundle.title}</div>
                          <p className="text-xs text-emerald-100/80 mt-1">{bundle.subtitle}</p>
                        </div>
                        <div className="mt-4">
                          {bundle.isRewardedAd ? (
                            alreadyClaimed ? (
                              <span className="text-xs font-semibold text-emerald-400">
                                Daily Chest Claimed Today
                              </span>
                            ) : (
                              <button
                                type="button"
                                onClick={() =>
                                  triggerSimulatedRewardedAd('Daily Sanctuary Chest', () =>
                                    onPurchaseBundle(bundle)
                                  )
                                }
                                className="w-full py-2 px-4 rounded bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs transition-colors cursor-pointer"
                              >
                                Watch Ad · Claim Free Chest (+120 Coins)
                              </button>
                            )
                          ) : (
                            <button
                              type="button"
                              onClick={() => onPurchaseBundle(bundle)}
                              className="w-full py-2 px-4 rounded bg-[#183B2E] hover:bg-[#204D3C] border border-amber-400/50 text-amber-200 font-bold text-xs transition-colors cursor-pointer"
                            >
                              {bundle.costCoins
                                ? `Buy Bundle (${bundle.costCoins} Coins)`
                                : `Buy Value Pack (${bundle.costGems} Gems)`}
                            </button>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};


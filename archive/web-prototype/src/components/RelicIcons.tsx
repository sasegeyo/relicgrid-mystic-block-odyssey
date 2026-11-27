import React from 'react';

export const RelicTitleEmblem: React.FC<{ className?: string }> = ({ className = 'w-full max-w-md' }) => (
  <svg
    viewBox="0 0 540 155"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    className={className}
    aria-label="RelicGrid: Mystic Block Odyssey"
  >
    <defs>
      <linearGradient id="goldPlaque" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stopColor="#FDE68A" />
        <stop offset="45%" stopColor="#F59E0B" />
        <stop offset="100%" stopColor="#B45309" />
      </linearGradient>
      <linearGradient id="emeraldCore" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stopColor="#34D399" />
        <stop offset="100%" stopColor="#065F46" />
      </linearGradient>
      <filter id="titleDrop" x="-10%" y="-10%" width="120%" height="130%">
        <feDropShadow dx="0" dy="5" stdDeviation="4" floodColor="#020806" floodOpacity="0.9" />
      </filter>
    </defs>

    {/* Carved Runestone Backing Crest */}
    <path
      d="M24 34 L56 14 L484 14 L516 34 L516 112 L484 132 L56 132 L24 112 Z"
      fill="#081712"
      stroke="#020806"
      strokeWidth="6"
      filter="url(#titleDrop)"
    />
    <path
      d="M28 36 L58 18 L482 18 L512 36 L512 110 L482 128 L58 128 L28 110 Z"
      fill="#0C221A"
      stroke="url(#goldPlaque)"
      strokeWidth="2.5"
    />
    {/* Top Highlight Line */}
    <path d="M62 22 L478 22" stroke="#FEF3C7" strokeWidth="1.2" strokeOpacity="0.65" />

    {/* Left Isometric Relic Block Emblem */}
    <g transform="translate(46, 36)">
      <rect x="0" y="0" width="34" height="34" rx="5" fill="#040D0A" />
      <rect x="2" y="2" width="30" height="30" rx="4" fill="url(#emeraldCore)" stroke="#A7F3D0" strokeWidth="1.2" />
      <path d="M6 6 H28 V12 H6 Z" fill="#6EE7B7" fillOpacity="0.45" />
      <rect x="38" y="0" width="34" height="34" rx="5" fill="#040D0A" />
      <rect x="40" y="2" width="30" height="30" rx="4" fill="#DC2626" stroke="#FCA5A5" strokeWidth="1.2" />
      <circle cx="55" cy="17" r="6" fill="#FEF08A" />
      <rect x="0" y="38" width="34" height="34" rx="5" fill="#040D0A" />
      <rect x="2" y="40" width="30" height="30" rx="4" fill="#2563EB" stroke="#93C5FD" strokeWidth="1.2" />
      <path d="M9 47 L25 63 M25 47 L9 63" stroke="#DBEAFE" strokeWidth="2.2" strokeLinecap="round" />
      <rect x="38" y="38" width="34" height="34" rx="5" fill="#040D0A" />
      <rect x="40" y="40" width="30" height="30" rx="4" fill="url(#goldPlaque)" stroke="#FEF3C7" strokeWidth="1.2" />
      <polygon points="55,45 58,52 65,52 59,56 61,63 55,59 49,63 51,56 45,52 52,52" fill="#FFFBEB" />
    </g>

    {/* Main Display Lockup Typography */}
    <text
      x="138"
      y="76"
      fill="url(#goldPlaque)"
      stroke="#030B08"
      strokeWidth="5"
      paintOrder="stroke fill"
      fontFamily="Cinzel, Georgia, serif"
      fontWeight="800"
      fontSize="46"
      letterSpacing="3"
    >
      RELIC GRID
    </text>

    {/* Subtitle Divider & Engraving */}
    <line x1="140" y1="90" x2="486" y2="90" stroke="#D99B26" strokeWidth="1" strokeOpacity="0.5" />
    <text
      x="140"
      y="111"
      fill="#A7F3D0"
      stroke="#030B08"
      strokeWidth="3"
      paintOrder="stroke fill"
      fontFamily="Plus Jakarta Sans, sans-serif"
      fontWeight="700"
      fontSize="13.5"
      letterSpacing="4.5"
    >
      MYSTIC BLOCK ODYSSEY
    </text>
  </svg>
);

export const CoinIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <circle cx="12" cy="12" r="10.5" fill="#050C09" />
    <circle cx="12" cy="12" r="9" fill="#D97706" stroke="#FBBF24" strokeWidth="1.5" />
    <path d="M7 7.5 A7 7 0 0 1 17 7.5" stroke="#FEF3C7" strokeWidth="1.5" strokeLinecap="round" />
    <rect x="9.5" y="8" width="5" height="8" rx="1" fill="#FEF3C7" stroke="#92400E" strokeWidth="1" />
  </svg>
);

export const GemIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <polygon points="12,1.5 21.5,8.5 17.5,21.5 6.5,21.5 2.5,8.5" fill="#050C09" />
    <polygon points="12,3 20,9 16.5,20 7.5,20 4,9" fill="#7C3AED" stroke="#DDD6FE" strokeWidth="1.4" />
    <polygon points="12,3 16,9 12,19 8,9" fill="#A855F7" />
    <polygon points="12,3 16,9 8,9" fill="#F3E8FF" fillOpacity="0.75" />
  </svg>
);

export const FlameStreakIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <path
      d="M12 1.5C12 1.5 19.5 7.5 19.5 14C19.5 18.4 16.1 22 12 22C7.9 22 4.5 18.4 4.5 14C4.5 10.5 7 7.2 8.5 5.5C8.5 5.5 8 9 10 9.5C10.5 6 12 1.5 12 1.5Z"
      fill="#050C09"
      stroke="#050C09"
      strokeWidth="2"
    />
    <path
      d="M12 2.5C12 2.5 18.5 8 18.5 14C18.5 17.8 15.6 21 12 21C8.4 21 5.5 17.8 5.5 14C5.5 11 7.6 8 9 6.5C9 6.5 8.7 9.5 10.5 10C11 6.8 12 2.5 12 2.5Z"
      fill="#EA580C"
      stroke="#FDBA74"
      strokeWidth="1.2"
    />
    <path
      d="M12 10.5C12 10.5 15 13 15 15.8C15 17.6 13.7 19 12 19C10.3 19 9 17.6 9 15.8C9 14 10.5 12 12 10.5Z"
      fill="#FEF08A"
    />
  </svg>
);

export const RotateIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <circle cx="12" cy="12" r="10.5" fill="#050C09" />
    <path
      d="M18.5 9.5A7 7 0 1 0 19 14.5"
      stroke="#38BDF8"
      strokeWidth="2.6"
      strokeLinecap="round"
    />
    <polygon points="20.5,5 20.5,11 14.5,11" fill="#BAE6FD" stroke="#0284C7" strokeWidth="1" />
  </svg>
);

export const HammerIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <path d="M4 19 L14 9" stroke="#050C09" strokeWidth="5" strokeLinecap="round" />
    <path d="M4 19 L14 9" stroke="#D97706" strokeWidth="3" strokeLinecap="round" />
    <rect
      x="11"
      y="3"
      width="10"
      height="6"
      rx="1.5"
      transform="rotate(45 14 6)"
      fill="#E2E8F0"
      stroke="#050C09"
      strokeWidth="2"
    />
    <path d="M13 4 L18 9" stroke="#FFFFFF" strokeWidth="1.5" strokeLinecap="round" />
  </svg>
);

export const RerollIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <rect x="2.5" y="2.5" width="19" height="19" rx="4" fill="#050C09" />
    <rect x="4" y="4" width="16" height="16" rx="3" fill="#10B981" stroke="#A7F3D0" strokeWidth="1.5" />
    <circle cx="8.5" cy="8.5" r="1.6" fill="#052E16" />
    <circle cx="15.5" cy="8.5" r="1.6" fill="#052E16" />
    <circle cx="12" cy="12" r="1.6" fill="#FEF08A" />
    <circle cx="8.5" cy="15.5" r="1.6" fill="#052E16" />
    <circle cx="15.5" cy="15.5" r="1.6" fill="#052E16" />
  </svg>
);

export const BombIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <circle cx="11" cy="13.5" r="8.5" fill="#050C09" />
    <circle cx="11" cy="13.5" r="7" fill="#DC2626" stroke="#FCA5A5" strokeWidth="1.4" />
    <path d="M8 10 A4.5 4.5 0 0 1 13 8.5" stroke="#FECACA" strokeWidth="1.6" strokeLinecap="round" />
    <path d="M14.5 7.5 L18.5 3.5" stroke="#FBBF24" strokeWidth="2.2" strokeLinecap="round" />
    <circle cx="19.5" cy="3.5" r="2" fill="#FEF08A" />
  </svg>
);

export const TrophyIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <path d="M6 3H18V9C18 12.3 15.3 15 12 15C8.7 15 6 12.3 6 9V3Z" fill="#F59E0B" stroke="#050C09" strokeWidth="2" />
    <path d="M9 15H15V19H9V15Z" fill="#D97706" stroke="#050C09" strokeWidth="1.5" />
    <rect x="6" y="19" width="12" height="3" rx="1" fill="#FBBF24" stroke="#050C09" strokeWidth="1.5" />
    <path d="M8 5H16" stroke="#FEF3C7" strokeWidth="1.5" strokeLinecap="round" />
  </svg>
);

export const CalendarIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <rect x="2.5" y="4" width="19" height="17.5" rx="3" fill="#050C09" />
    <rect x="4" y="5.5" width="16" height="14.5" rx="2" fill="#0F291E" stroke="#34D399" strokeWidth="1.5" />
    <path d="M4 9.5H20" stroke="#34D399" strokeWidth="1.5" />
    <rect x="7" y="12" width="3" height="3" rx="0.5" fill="#FBBF24" />
    <rect x="14" y="12" width="3" height="3" rx="0.5" fill="#34D399" />
  </svg>
);

export const MapIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <polygon points="2,5 9,3 15,5 22,3 22,19 15,21 9,19 2,21" fill="#050C09" />
    <polygon points="3.5,6 9,4.5 15,6 20.5,4.5 20.5,18 15,19.5 9,18 3.5,19.5" fill="#1E3A8A" stroke="#93C5FD" strokeWidth="1.4" />
    <circle cx="9" cy="11" r="2" fill="#FBBF24" />
    <circle cx="15" cy="13" r="2" fill="#34D399" />
    <path d="M9 11 L15 13" stroke="#FEF08A" strokeWidth="1.5" strokeDasharray="2 2" />
  </svg>
);

export const ShopIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <rect x="2.5" y="6.5" width="19" height="14.5" rx="2.5" fill="#050C09" />
    <rect x="4" y="8" width="16" height="11.5" rx="1.5" fill="#78350F" stroke="#FBBF24" strokeWidth="1.5" />
    <path d="M4 12.5H20" stroke="#FBBF24" strokeWidth="1.5" />
    <rect x="10" y="10.5" width="4" height="4" rx="1" fill="#FEF08A" stroke="#78350F" strokeWidth="1" />
  </svg>
);

export const MuteIcon: React.FC<{ muted: boolean; className?: string }> = ({ muted, className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <polygon points="3,9 8,9 13,4 13,20 8,15 3,15" fill={muted ? '#64748B' : '#FBBF24'} stroke="#050C09" strokeWidth="1.8" />
    {muted ? (
      <path d="M16 9L21 15M21 9L16 15" stroke="#EF4444" strokeWidth="2.2" strokeLinecap="round" />
    ) : (
      <path d="M16 8.5C17.8 10.2 17.8 13.8 16 15.5M19 6C22 9 22 15 19 18" stroke="#34D399" strokeWidth="2" strokeLinecap="round" />
    )}
  </svg>
);

export const PauseIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <rect x="5" y="4" width="5" height="16" rx="1.5" fill="#FBBF24" stroke="#050C09" strokeWidth="1.8" />
    <rect x="14" y="4" width="5" height="16" rx="1.5" fill="#FBBF24" stroke="#050C09" strokeWidth="1.8" />
  </svg>
);

export const RestartIcon: React.FC<{ className?: string }> = ({ className = 'w-5 h-5' }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <path d="M4.5 12A7.5 7.5 0 1 1 7 17.5" stroke="#FBBF24" strokeWidth="2.5" strokeLinecap="round" />
    <polygon points="3.5,7 9.5,7 3.5,13" fill="#FEF08A" stroke="#050C09" strokeWidth="1" />
  </svg>
);

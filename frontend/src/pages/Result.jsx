import { Link, useLocation } from 'react-router-dom'
import {
  Eye, EyeOff, Activity, Keyboard, MonitorSmartphone, MessageSquare,
  CheckCircle, XCircle, MapPin, Zap, Map, TrendingUp, ArrowRight,
} from 'lucide-react'
import { BUILDINGS, BUILDING_TERRITORY, USER_STATS } from '../data/mock'

const SIGNAL_CONFIG = [
  { key: 'gaze', label: 'Gaze', icon: Eye },
  { key: 'posture', label: 'Posture', icon: Activity },
  { key: 'blink', label: 'Blink', icon: EyeOff },
  { key: 'keysMouse', label: 'Keys/Mouse', icon: Keyboard },
  { key: 'tabs', label: 'Tabs', icon: MonitorSmartphone },
  { key: 'checkIn', label: 'Check-in', icon: MessageSquare },
]

function scoreHex(s) {
  if (s >= 70) return '#BFC6A9'
  if (s >= 50) return '#fbbf24'
  return '#ef4444'
}
function scoreBg(s) {
  if (s >= 70) return 'rgba(191,198,169,0.12)'
  if (s >= 50) return 'rgba(251,191,36,0.12)'
  return 'rgba(239,68,68,0.12)'
}

const R = 58
const C = 2 * Math.PI * R

const FALLBACK = {
  focusScore: 84,
  buildingId: 'walc',
  building: 'WALC',
  duration: 120,
  signals: { gaze: 88, posture: 79, blink: 74, keysMouse: 85, tabs: 91, checkIn: 72 },
}

function calcBuildingScore(focusScore, durationMin, consistency) {
  const focusPart = focusScore * 0.5
  const timePart = Math.min(durationMin / 240 * 100, 100) * 0.3
  const consistPart = (consistency / 7) * 100 * 0.2
  return Math.round((focusPart + timePart + consistPart) * 10) / 10
}

export default function Result() {
  const location = useLocation()
  const s = location.state || FALLBACK

  const focusScore = s.focusScore ?? FALLBACK.focusScore
  const buildingId = s.buildingId ?? FALLBACK.buildingId
  const building = s.building ?? FALLBACK.building
  const duration = s.duration ?? FALLBACK.duration
  const signals = s.signals ?? FALLBACK.signals

  const passed = focusScore >= 70
  const bldg = BUILDINGS.find(b => b.id === buildingId) || BUILDINGS[0]
  const territory = BUILDING_TERRITORY[buildingId]
  const myEntry = territory?.topUsers.find(u => u.isYou)

  const buildingScore = calcBuildingScore(focusScore, duration, USER_STATS.weeklyConsistency)
  const oldRank = myEntry?.rank || territory?.yourRankIfOutside?.rank || 5
  const newRank = Math.max(1, oldRank - (passed ? 1 : 0))
  const oldPct = myEntry?.percentage || territory?.yourRankIfOutside?.percentage || 3.0
  const newPct = Math.round((oldPct + (passed ? 2.1 : 0.3)) * 10) / 10

  const gaugeOffset = C * (1 - focusScore / 100)

  return (
    <div className="max-w-md mx-auto py-8">

      {/* ── 1. Pass / Fail header ── */}
      <div className="flex flex-col items-center mb-8">
        <div
          className="w-16 h-16 rounded-full flex items-center justify-center mb-4"
          style={{ background: passed ? 'rgba(191,198,169,0.15)' : 'rgba(239,68,68,0.15)' }}
        >
          {passed
            ? <CheckCircle size={32} style={{ color: 'var(--accent)' }} />
            : <XCircle size={32} style={{ color: 'var(--danger)' }} />}
        </div>
        <h1
          className="text-2xl font-bold mb-1"
          style={{ color: passed ? 'var(--accent)' : 'var(--danger)' }}
        >
          {passed ? 'Session Complete!' : 'You Lost Focus…'}
        </h1>
        <p className="text-sm text-[var(--text-muted)]">
          {passed
            ? `You stayed focused for ${duration / 60}h. Nice work!`
            : `Your focus score fell below the 70-point threshold.`}
        </p>
      </div>

      {/* ── 2. Focus Score gauge ── */}
      <div className="flex flex-col items-center mb-8">
        <div className="relative w-[152px] h-[152px]">
          <svg viewBox="0 0 140 140" className="w-full h-full -rotate-90">
            <circle cx="70" cy="70" r={R} fill="none" stroke="var(--border)" strokeWidth="8" />
            <circle
              cx="70" cy="70" r={R} fill="none"
              stroke={scoreHex(focusScore)}
              strokeWidth="8"
              strokeLinecap="round"
              strokeDasharray={C}
              strokeDashoffset={gaugeOffset}
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-5xl font-bold" style={{ color: scoreHex(focusScore) }}>
              {focusScore}
            </span>
            <span className="text-xs text-[var(--text-muted)]">/ 100</span>
          </div>
        </div>
        <div
          className="mt-3 text-[11px] font-medium px-3 py-1 rounded-full"
          style={{ background: scoreBg(focusScore), color: scoreHex(focusScore) }}
        >
          {passed ? '✓ Passed' : '✗ Failed'} — Target was 70
        </div>
      </div>

      {/* ── 3. Building Score earned ── */}
      <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-5 mb-6">
        <span className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider">Building Score Earned</span>
        <div className="flex items-center justify-between mt-3 mb-4">
          <div>
            <div className="text-3xl font-bold text-[var(--accent)]">+{buildingScore}</div>
            <div className="text-[10px] text-[var(--text-muted)] mt-0.5">points added to {building}</div>
          </div>
          <div className="flex flex-col gap-1 text-right">
            <div className="text-[10px] text-[var(--text-muted)]">
              Focus <span className="text-[var(--text-secondary)] font-medium">{focusScore} × 0.5</span>
            </div>
            <div className="text-[10px] text-[var(--text-muted)]">
              Duration <span className="text-[var(--text-secondary)] font-medium">{duration / 60}h × 0.3</span>
            </div>
            <div className="text-[10px] text-[var(--text-muted)]">
              Consistency <span className="text-[var(--text-secondary)] font-medium">{USER_STATS.weeklyConsistency}/7 × 0.2</span>
            </div>
          </div>
        </div>

        {/* Rank change */}
        <div className="border-t border-[var(--border)] pt-3 flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <TrendingUp size={14} className="text-[var(--accent)]" />
            <span className="text-sm text-[var(--text-secondary)]">
              {newRank < oldRank ? (
                <>
                  Rank at {building}: <strong className="text-[var(--text-primary)]">#{oldRank}</strong>
                  <ArrowRight size={12} className="inline mx-1 text-[var(--accent)]" />
                  <strong className="text-[var(--accent)]">#{newRank}</strong>
                </>
              ) : (
                <>Rank at {building}: <strong className="text-[var(--text-primary)]">#{oldRank}</strong> (held)</>
              )}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <MapPin size={14} className="text-[var(--accent)]" />
            <span className="text-sm text-[var(--text-secondary)]">
              Territory: <strong className="text-[var(--text-primary)]">{oldPct}%</strong>
              <ArrowRight size={12} className="inline mx-1 text-[var(--accent)]" />
              <strong className="text-[var(--accent)]">{newPct}%</strong>
            </span>
          </div>
          {newRank === 1 && (
            <div className="flex items-center gap-2 mt-1">
              <span className="text-sm text-[var(--warning)] font-semibold">
                👑 You became the new {building} King!
              </span>
            </div>
          )}
        </div>
      </div>

      {/* ── 4. Signal summary ── */}
      <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-5 mb-8">
        <span className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider">Signal Breakdown</span>
        <div className="flex flex-col gap-3 mt-3">
          {SIGNAL_CONFIG.map(({ key, label, icon: Icon }) => {
            const v = signals[key] ?? 0
            return (
              <div key={key}>
                <div className="flex items-center justify-between mb-1">
                  <div className="flex items-center gap-2">
                    <Icon size={13} style={{ color: 'var(--text-muted)' }} />
                    <span className="text-sm text-[var(--text-secondary)]">{label}</span>
                  </div>
                  <span className="text-sm font-semibold tabular-nums" style={{ color: scoreHex(v) }}>{v}</span>
                </div>
                <div className="h-1.5 rounded-full bg-[var(--bg-primary)]">
                  <div
                    className="h-full rounded-full"
                    style={{ width: `${v}%`, background: scoreHex(v) }}
                  />
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {/* ── 5. Action buttons ── */}
      <div className="flex gap-3">
        <Link
          to="/start"
          className="flex-1 py-3.5 rounded-xl bg-[var(--accent)] text-[var(--bg-primary)] font-bold text-sm text-center hover:opacity-90 transition-all active:scale-[0.98] flex items-center justify-center gap-2"
        >
          <Zap size={16} />
          Study Again
        </Link>
        <Link
          to={`/building/${buildingId}`}
          className="flex-1 py-3.5 rounded-xl border border-[var(--border)] text-[var(--text-secondary)] font-medium text-sm text-center hover:bg-[var(--bg-secondary)] transition flex items-center justify-center gap-2"
        >
          <Map size={16} />
          View Building
        </Link>
      </div>
    </div>
  )
}

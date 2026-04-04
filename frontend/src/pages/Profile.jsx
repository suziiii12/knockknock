import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Shield, MapPin, ChevronDown, Crown, Zap } from 'lucide-react'
import { BUILDINGS, BUILDING_TERRITORY, USER_STATS } from '../data/mock'

const kingBuildings = BUILDINGS.filter(b => b.king === 'Yewon')

const TERRITORY_DATA = kingBuildings.map(b => {
  const territory = BUILDING_TERRITORY[b.id]
  const topUser = territory?.topUsers[0]
  const secondUser = territory?.topUsers[1]
  const lead = topUser && secondUser ? topUser.score - secondUser.score : 0
  return { id: b.id, name: b.name, score: topUser?.score || b.score, lead, percentage: topUser?.percentage || 0 }
})

const PAST_WEEKS = [
  { week: 13, buildings: ['WALC', 'Lilly Hall', 'CoRec'], count: 3 },
  { week: 12, buildings: ['Hicks Library', 'WALC'], count: 2 },
  { week: 11, buildings: [], count: 0 },
  { week: 10, buildings: ['WALC', 'Lawson CS', 'Knoy Hall', 'CoRec'], count: 4 },
]

export default function Profile() {
  const [pastOpen, setPastOpen] = useState(false)

  return (
    <div className="max-w-md mx-auto py-8">

      {/* ── 1. Profile header ── */}
      <div className="flex flex-col items-center mb-8">
        <div className="w-20 h-20 rounded-full bg-[var(--accent)] flex items-center justify-center text-2xl font-bold text-[var(--bg-primary)] mb-3">
          YC
        </div>
        <h1 className="text-xl font-bold mb-1">{USER_STATS.name}</h1>
        <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[var(--accent-dim)] border border-[var(--accent-border)] mb-4">
          <Shield size={12} style={{ color: 'var(--accent)' }} />
          <span className="text-[11px] font-medium text-[var(--accent)]">Device Verified</span>
        </div>
        <div className="text-4xl font-bold text-[var(--accent)]">{USER_STATS.weeklyScore.toLocaleString()}</div>
        <span className="text-[11px] text-[var(--text-muted)] mt-1">Weekly Score</span>
      </div>

      {/* ── 2. Study stats — 4 cols ── */}
      <div className="grid grid-cols-4 gap-3 mb-6">
        {[
          { label: 'Sessions', value: USER_STATS.totalSessions },
          { label: 'Hours', value: `${USER_STATS.totalHours}h` },
          { label: 'Avg Score', value: USER_STATS.avgFocusScore },
          { label: 'Consistency', value: `${USER_STATS.weeklyConsistency}/7` },
        ].map(s => (
          <div key={s.label} className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-3 text-center">
            <div className="text-base font-bold">{s.value}</div>
            <div className="text-[10px] text-[var(--text-muted)] mt-0.5">{s.label}</div>
          </div>
        ))}
      </div>

      {/* ── 3. Current territory ── */}
      <div className="mb-6">
        <div className="flex items-center gap-2 mb-3">
          <MapPin size={14} style={{ color: 'var(--accent)' }} />
          <span className="text-xs font-semibold">Your Territory — Week 14</span>
          <span className="text-[10px] text-[var(--text-muted)] ml-auto">{TERRITORY_DATA.length} buildings</span>
        </div>

        {TERRITORY_DATA.length > 0 ? (
          <div className="flex flex-col gap-2">
            {TERRITORY_DATA.map(t => (
              <Link
                key={t.id}
                to={`/building/${t.id}`}
                className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-3.5 flex items-center justify-between hover:border-[var(--text-muted)] transition-all"
              >
                <div className="flex items-center gap-2.5">
                  <Crown size={14} style={{ color: 'var(--warning)' }} />
                  <span className="text-sm font-semibold">{t.name}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-sm font-bold text-[var(--accent)]">{t.score.toLocaleString()} pts</span>
                  <span className="text-[10px] text-[var(--text-muted)]">{t.percentage}%</span>
                  {t.lead > 0 && (
                    <span className="text-[10px] text-[var(--text-muted)]">+{t.lead} ahead</span>
                  )}
                </div>
              </Link>
            ))}
          </div>
        ) : (
          <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-5 text-center">
            <p className="text-sm text-[var(--text-muted)]">No buildings claimed this week. Start studying!</p>
          </div>
        )}
      </div>

      {/* ── 4. Past weeks (collapsible) ── */}
      <div>
        <button
          onClick={() => setPastOpen(p => !p)}
          className="w-full flex items-center justify-between py-2 mb-2"
        >
          <span className="text-xs font-semibold">Past Weeks</span>
          <ChevronDown
            size={16}
            className="text-[var(--text-muted)] transition-transform duration-200"
            style={{ transform: pastOpen ? 'rotate(180deg)' : 'rotate(0)' }}
          />
        </button>

        {pastOpen && (
          <div className="flex flex-col gap-2">
            {PAST_WEEKS.map(w => (
              <div
                key={w.week}
                className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-3.5 flex items-center justify-between"
              >
                <span className="text-xs font-semibold text-[var(--text-muted)]">Week {w.week}</span>
                {w.count > 0 ? (
                  <span className="text-xs text-[var(--text-secondary)]">
                    {w.buildings.map((b, i) => (
                      <span key={b}>{i > 0 && ', '}<strong className="text-[var(--text-primary)]">{b}</strong> 👑</span>
                    ))}
                    <span className="text-[var(--text-muted)]"> — {w.count} building{w.count > 1 && 's'}</span>
                  </span>
                ) : (
                  <span className="text-xs text-[var(--text-muted)]">No buildings claimed</span>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

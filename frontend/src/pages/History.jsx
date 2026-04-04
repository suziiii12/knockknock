import { Link } from 'react-router-dom'
import { Clock, MapPin, Zap, Calendar, TrendingUp } from 'lucide-react'
import { SESSIONS, USER_STATS } from '../data/mock'

function scoreColor(score) {
  if (score >= 70) return 'var(--accent)'
  if (score >= 50) return 'var(--warning)'
  return 'var(--danger)'
}

function formatDate(dateStr) {
  const d = new Date(dateStr)
  const now = new Date()
  const diffDays = Math.floor((now - d) / (1000 * 60 * 60 * 24))
  if (diffDays === 0) return 'Today'
  if (diffDays === 1) return 'Yesterday'
  if (diffDays < 7) return `${diffDays}d ago`
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

export default function History() {
  return (
    <div className="max-w-2xl w-full mx-auto">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-lg font-semibold">Session History</h2>
        <Link
          to="/start"
          className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-[var(--accent)] text-[var(--bg-primary)] text-xs font-semibold hover:opacity-90 transition"
        >
          <Zap size={14} /> New Session
        </Link>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-4 gap-3 mb-6">
        {[
          { label: 'Sessions', value: USER_STATS.totalSessions, color: 'var(--text-primary)' },
          { label: 'Hours', value: `${USER_STATS.totalHours}h`, color: 'var(--text-primary)' },
          { label: 'Avg Score', value: USER_STATS.avgFocusScore, color: 'var(--accent)' },
          { label: 'Consistency', value: `${USER_STATS.weeklyConsistency}/7`, color: 'var(--accent)' },
        ].map(s => (
          <div key={s.label} className="bg-[var(--bg-secondary)] rounded-lg p-3 text-center border border-[var(--border)]">
            <div className="text-base font-bold" style={{ color: s.color }}>{s.value}</div>
            <div className="text-[10px] text-[var(--text-muted)]">{s.label}</div>
          </div>
        ))}
      </div>

      {/* Session Cards */}
      <div className="flex flex-col gap-3">
        {SESSIONS.map(session => (
          <div
            key={session.id}
            className="bg-[var(--bg-secondary)] border border-[var(--border)] rounded-xl p-4 hover:border-[var(--text-muted)] transition-all"
          >
            <div className="flex justify-between items-start mb-3">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <MapPin size={12} className="text-[var(--text-muted)]" />
                  <span className="text-sm font-semibold">{session.building}</span>
                </div>
                <div className="flex items-center gap-1.5 text-[var(--text-muted)]">
                  <Calendar size={10} />
                  <span className="text-[11px]">{formatDate(session.date)}</span>
                  <span className="text-[11px]">·</span>
                  <Clock size={10} />
                  <span className="text-[11px]">{session.duration / 60}h session</span>
                </div>
              </div>
              <span
                className="text-[10px] font-medium px-2 py-0.5 rounded-full"
                style={{
                  background: session.focusScore >= 70 ? 'rgba(191,198,169,0.12)' : 'rgba(239,68,68,0.12)',
                  color: session.focusScore >= 70 ? '#BFC6A9' : '#ef4444',
                }}
              >
                {session.focusScore >= 70 ? 'Passed' : 'Failed'}
              </span>
            </div>

            <div className="flex items-center gap-4">
              {/* Focus Score */}
              <div className="flex items-center gap-2">
                <div
                  className="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold border-2"
                  style={{
                    borderColor: scoreColor(session.focusScore),
                    color: scoreColor(session.focusScore),
                  }}
                >
                  {session.focusScore}
                </div>
                <div>
                  <div className="text-[10px] text-[var(--text-muted)]">Focus Score</div>
                </div>
              </div>

              {/* Signal bars mini */}
              <div className="flex-1 flex gap-1">
                {Object.entries(session.signals).map(([key, val]) => (
                  <div key={key} className="flex-1">
                    <div className="h-1.5 rounded-full bg-[var(--bg-primary)]">
                      <div
                        className="h-full rounded-full transition-all"
                        style={{
                          width: `${val}%`,
                          background: val >= 70 ? 'var(--accent)' : val >= 50 ? 'var(--warning)' : 'var(--danger)',
                        }}
                      />
                    </div>
                  </div>
                ))}
              </div>

              {/* Building Score */}
              <div className="flex items-center gap-1.5 shrink-0">
                <TrendingUp size={14} className="text-[var(--accent)]" />
                <span className="text-sm font-bold text-[var(--accent)]">
                  +{session.buildingScore}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Consistency */}
      <div className="mt-6 bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-4 flex items-center justify-between">
        <div>
          <div className="text-xs text-[var(--text-muted)] mb-1">Weekly Consistency</div>
          <div className="text-2xl font-bold text-[var(--accent)]">{USER_STATS.weeklyConsistency}/7 days</div>
        </div>
        <div className="text-right">
          <div className="text-xs text-[var(--text-muted)] mb-1">Weekly Score</div>
          <div className="text-lg font-bold text-[var(--text-secondary)]">{USER_STATS.weeklyScore.toLocaleString()}</div>
        </div>
      </div>
    </div>
  )
}

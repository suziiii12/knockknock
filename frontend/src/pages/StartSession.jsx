import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Clock, MapPin, Zap, Eye, Keyboard, MonitorSmartphone, MessageSquare, Activity } from 'lucide-react'
import { BUILDINGS, USER_STATS, BUILDING_TERRITORY } from '../data/mock'

const DURATIONS = [
  { value: 60, label: '1h', desc: 'Quick sprint' },
  { value: 120, label: '2h', desc: 'Focus session' },
  { value: 240, label: '4h', desc: 'Deep work' },
]

const SIGNALS = [
  { icon: Eye, label: 'Gaze Tracking' },
  { icon: Activity, label: 'Posture' },
  { icon: Keyboard, label: 'Keys/Mouse' },
  { icon: MonitorSmartphone, label: 'Tab Focus' },
  { icon: MessageSquare, label: 'AI Check-in' },
]

export default function StartSession() {
  const navigate = useNavigate()
  const [duration, setDuration] = useState(120)

  const detectedBuilding = BUILDINGS.find(b => b.id === 'walc')
  const territory = BUILDING_TERRITORY[detectedBuilding.id]
  const myEntry = territory?.topUsers.find(u => u.isYou)
  const myRank = myEntry?.rank || territory?.yourRankIfOutside?.rank || '—'

  const handleStart = () => {
    navigate('/session', {
      state: {
        duration,
        buildingId: detectedBuilding.id,
        building: detectedBuilding.name,
      },
    })
  }

  return (
    <div className="max-w-md mx-auto py-8">
      {/* GPS Detection Banner */}
      <div className="flex items-center gap-3 p-4 rounded-xl bg-[var(--accent-dim)] border border-[var(--accent-border)] mb-8">
        <div className="w-10 h-10 rounded-full bg-[var(--accent)] bg-opacity-20 flex items-center justify-center shrink-0">
          <MapPin size={20} className="text-[var(--accent)]" />
        </div>
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-[var(--accent)] animate-pulse" />
            <span className="text-sm font-semibold text-[var(--accent)]">{detectedBuilding.name}</span>
          </div>
          <p className="text-[11px] text-[var(--text-muted)] mt-0.5">GPS verified · Your sessions here count toward Building King</p>
        </div>
        {detectedBuilding.king && (
          <div className="text-right shrink-0">
            <div className="text-[10px] text-[var(--text-muted)]">Current King</div>
            <div className="text-xs font-semibold">👑 {detectedBuilding.king}</div>
          </div>
        )}
      </div>

      {/* Duration Selection */}
      <div className="mb-6">
        <div className="flex items-center gap-2 mb-3">
          <Clock size={16} className="text-[var(--accent)]" />
          <h2 className="text-sm font-semibold">Focus Duration</h2>
        </div>
        <div className="grid grid-cols-3 gap-3">
          {DURATIONS.map(d => (
            <button
              key={d.value}
              onClick={() => setDuration(d.value)}
              className={`flex flex-col items-center gap-1 p-4 rounded-xl border transition-all ${
                duration === d.value
                  ? 'border-[var(--accent)] bg-[var(--accent-dim)]'
                  : 'border-[var(--border)] bg-[var(--bg-secondary)] hover:border-[var(--text-muted)]'
              }`}
            >
              <span className={`text-xl font-bold ${duration === d.value ? 'text-[var(--accent)]' : ''}`}>
                {d.label}
              </span>
              <span className="text-[10px] text-[var(--text-muted)]">{d.desc}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Session Summary Card */}
      <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-4 mb-4">
        <div className="flex justify-between items-center mb-3">
          <span className="text-xs text-[var(--text-muted)]">Session summary</span>
          <div className="flex items-center gap-1.5">
            <Zap size={12} className="text-[var(--accent)]" />
            <span className="text-[10px] text-[var(--accent)] font-medium">AI-verified focus</span>
          </div>
        </div>
        <div className="grid grid-cols-3 gap-3 mb-4">
          <div className="text-center">
            <div className="text-lg font-bold">{duration / 60}h</div>
            <div className="text-[10px] text-[var(--text-muted)]">Duration</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-bold text-[var(--accent)]">{detectedBuilding.abbr}</div>
            <div className="text-[10px] text-[var(--text-muted)]">Building</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-bold">#{myRank}</div>
            <div className="text-[10px] text-[var(--text-muted)]">Your Rank</div>
          </div>
        </div>

        {/* AI Monitoring Signals */}
        <div className="border-t border-[var(--border)] pt-3">
          <div className="text-[10px] text-[var(--text-muted)] mb-2">AI will monitor</div>
          <div className="flex flex-wrap gap-1.5">
            {SIGNALS.map(s => (
              <span key={s.label} className="flex items-center gap-1 text-[10px] px-2 py-1 rounded-md bg-[var(--accent-dim)] text-[var(--accent)]">
                <s.icon size={10} />
                {s.label}
              </span>
            ))}
          </div>
        </div>
      </div>

      {/* Score info */}
      <div className="p-3 rounded-lg bg-[rgba(191,198,169,0.06)] border border-[rgba(191,198,169,0.15)] mb-6">
        <p className="text-[11px] text-[var(--accent)] leading-relaxed">
          Your Building Score is calculated from <strong>Focus (50%)</strong> + <strong>Duration (30%)</strong> + <strong>Consistency (20%)</strong>.
          Study {USER_STATS.weeklyConsistency < 7 ? `${7 - USER_STATS.weeklyConsistency} more day${7 - USER_STATS.weeklyConsistency > 1 ? 's' : ''} this week` : 'every day'} to max out your consistency bonus!
        </p>
      </div>

      {/* Start Button */}
      <button
        onClick={handleStart}
        className="w-full py-4 rounded-xl bg-[var(--accent)] text-[var(--bg-primary)] font-bold text-base hover:opacity-90 transition-all active:scale-[0.98] flex items-center justify-center gap-2"
      >
        <Zap size={18} />
        Start Focus
      </button>

      <p className="text-center text-[10px] text-[var(--text-muted)] mt-3">
        Webcam + browser activity will be monitored during the session
      </p>
    </div>
  )
}

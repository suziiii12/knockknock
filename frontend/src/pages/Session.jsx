import { useState, useEffect, useRef } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import {
  Eye, EyeOff, Activity, Keyboard, MonitorSmartphone, MessageSquare,
  MapPin, TrendingUp, Send, Clock, Camera, Calendar,
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

const CHECK_IN_QUESTIONS = [
  'What are you studying right now? One sentence.',
  'Explain the last concept you just learned.',
  "What's the main topic of your current work?",
  "Summarize what you've done in the last 10 minutes.",
  "What's the next thing you need to figure out?",
]

const R = 58
const C = 2 * Math.PI * R

function scoreColor(s) {
  if (s >= 70) return 'var(--accent)'
  if (s >= 50) return 'var(--warning)'
  return 'var(--danger)'
}
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

function formatTime(sec) {
  const h = Math.floor(sec / 3600)
  const m = Math.floor((sec % 3600) / 60)
  const s = sec % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
function jitter(v, range, lo, hi) { return clamp(Math.round(v + (Math.random() - 0.5) * range), lo, hi) }

const INITIAL_GAZE = [
  { x: 48, y: 42 },
  { x: 52, y: 38 },
  { x: 50, y: 46 },
]

export default function Session() {
  const location = useLocation()
  const navigate = useNavigate()
  const videoRef = useRef(null)
  const streamRef = useRef(null)
  const checkInRef = useRef(null)
  const hasNavigated = useRef(false)

  const {
    duration = 120,
    buildingId = 'walc',
    building = 'WALC',
  } = location.state || {}

  const bldg = BUILDINGS.find(b => b.id === buildingId) || BUILDINGS[0]
  const territory = BUILDING_TERRITORY[buildingId]
  const myEntry = territory?.topUsers.find(u => u.isYou)
  const myRank = myEntry?.rank || territory?.yourRankIfOutside?.rank || '—'

  const [focusScore, setFocusScore] = useState(87)
  const [signals, setSignals] = useState({
    gaze: 90, posture: 82, blink: 78, keysMouse: 85, tabs: 92, checkIn: 80,
  })
  const [timeLeft, setTimeLeft] = useState(duration * 60)
  const [gazeDots, setGazeDots] = useState(INITIAL_GAZE)
  const [webcamReady, setWebcamReady] = useState(false)

  const [showCheckIn, setShowCheckIn] = useState(false)
  const [checkInAnswer, setCheckInAnswer] = useState('')
  const [checkInPhase, setCheckInPhase] = useState('idle')
  const [checkInQ, setCheckInQ] = useState(0)

  const totalSec = duration * 60
  const progress = (totalSec - timeLeft) / totalSec
  const gaugeOffset = C * (1 - focusScore / 100)

  // ── Webcam ──
  useEffect(() => {
    let cancelled = false
    ;(async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { width: 1280, height: 720, facingMode: 'user' },
        })
        if (cancelled) { stream.getTracks().forEach(t => t.stop()); return }
        streamRef.current = stream
        if (videoRef.current) { videoRef.current.srcObject = stream; videoRef.current.play() }
        setWebcamReady(true)
      } catch { setWebcamReady(false) }
    })()
    return () => { cancelled = true; streamRef.current?.getTracks().forEach(t => t.stop()) }
  }, [])

  // ── Timer ──
  useEffect(() => {
    const id = setInterval(() => setTimeLeft(p => Math.max(0, p - 1)), 1000)
    return () => clearInterval(id)
  }, [])

  // ── End session ──
  useEffect(() => {
    if (timeLeft === 0 && !hasNavigated.current) {
      hasNavigated.current = true
      streamRef.current?.getTracks().forEach(t => t.stop())
      navigate('/result', { state: { focusScore, buildingId, building, duration, signals } })
    }
  }, [timeLeft, focusScore, buildingId, building, duration, signals, navigate])

  // ── Score + signal simulation (5 s) ──
  useEffect(() => {
    const id = setInterval(() => {
      setFocusScore(p => jitter(p, 8, 80, 95))
      setSignals(p => ({
        gaze:      jitter(p.gaze,      10, 65, 98),
        posture:   jitter(p.posture,    8, 60, 95),
        blink:     jitter(p.blink,     12, 55, 95),
        keysMouse: jitter(p.keysMouse, 10, 60, 98),
        tabs:      jitter(p.tabs,       8, 70, 98),
        checkIn:   jitter(p.checkIn,    6, 65, 95),
      }))
    }, 5000)
    return () => clearInterval(id)
  }, [])

  // ── 3 gaze dots wander independently ──
  useEffect(() => {
    const ids = [
      setInterval(() => setGazeDots(p => [{ x: 44 + Math.random() * 12, y: 38 + Math.random() * 10 }, p[1], p[2]]), 1800),
      setInterval(() => setGazeDots(p => [p[0], { x: 46 + Math.random() * 10, y: 35 + Math.random() * 12 }, p[2]]), 2200),
      setInterval(() => setGazeDots(p => [p[0], p[1], { x: 42 + Math.random() * 14, y: 40 + Math.random() * 10 }]), 2600),
    ]
    return () => ids.forEach(clearInterval)
  }, [])

  // ── AI check-in every 30 s ──
  useEffect(() => {
    const id = setInterval(() => {
      if (!showCheckIn) {
        setCheckInQ(Math.floor(Math.random() * CHECK_IN_QUESTIONS.length))
        setShowCheckIn(true)
        setCheckInPhase('answering')
        setCheckInAnswer('')
      }
    }, 30000)
    return () => clearInterval(id)
  }, [showCheckIn])

  useEffect(() => {
    if (showCheckIn && checkInPhase === 'answering')
      setTimeout(() => checkInRef.current?.focus(), 300)
  }, [showCheckIn, checkInPhase])

  const submitCheckIn = () => {
    if (!checkInAnswer.trim()) return
    setCheckInPhase('analyzing')
    setTimeout(() => {
      setCheckInPhase('done')
      setSignals(p => ({ ...p, checkIn: clamp(p.checkIn + Math.floor(Math.random() * 10 + 3), 70, 98) }))
      setFocusScore(p => clamp(p + Math.floor(Math.random() * 3 + 1), 82, 96))
      setTimeout(() => { setShowCheckIn(false); setCheckInPhase('idle') }, 1500)
    }, 2000)
  }

  const dotStyles = [
    { size: 28, opacity: 0.6, blur: 24, transition: '1.8s' },
    { size: 20, opacity: 0.45, blur: 18, transition: '2.2s' },
    { size: 14, opacity: 0.35, blur: 14, transition: '2.6s' },
  ]

  return (
    <div className="flex flex-col gap-4 -mx-5 -mt-6 px-4 pt-4 pb-2">

      {/* ── 2-column layout ── */}
      <div className="flex gap-4" style={{ height: 'calc(100vh - 195px)', minHeight: 400 }}>

        {/* ━━ LEFT: Webcam (70%) ━━ */}
        <div className="flex-[7] relative rounded-2xl overflow-hidden bg-[#0e4a32] border border-[var(--border)]">
          <video
            ref={videoRef}
            autoPlay playsInline muted
            className="w-full h-full object-cover"
            style={{ transform: 'scaleX(-1)' }}
          />

          {!webcamReady && (
            <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-[#0e4a32]">
              <Camera size={48} className="text-[var(--text-muted)] opacity-40" />
              <span className="text-sm text-[var(--text-muted)]">Connecting webcam…</span>
            </div>
          )}

          {/* 3 Gaze tracking dots */}
          {gazeDots.map((dot, i) => (
            <div
              key={i}
              className="absolute rounded-full pointer-events-none"
              style={{
                width: dotStyles[i].size,
                height: dotStyles[i].size,
                left: `${dot.x}%`,
                top: `${dot.y}%`,
                transform: 'translate(-50%,-50%)',
                transition: `left ${dotStyles[i].transition} ease-in-out, top ${dotStyles[i].transition} ease-in-out`,
                background: `radial-gradient(circle, rgba(191,198,169,${dotStyles[i].opacity}) 0%, rgba(191,198,169,0) 70%)`,
                boxShadow: `0 0 ${dotStyles[i].blur}px rgba(191,198,169,0.25)`,
              }}
            >
              <div
                className="rounded-full bg-[var(--accent)] absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
                style={{ width: dotStyles[i].size * 0.35, height: dotStyles[i].size * 0.35 }}
              />
            </div>
          ))}

          {/* Tracking active badge */}
          <div className="absolute top-3 left-3 flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-black/60 backdrop-blur-sm">
            <div className="w-1.5 h-1.5 rounded-full bg-[var(--accent)] animate-pulse" />
            <span className="text-[10px] font-medium text-[var(--accent)]">Tracking active</span>
          </div>

          {/* Timer overlay */}
          <div className="absolute top-3 right-3 flex items-center gap-2 px-3 py-1.5 rounded-lg bg-black/60 backdrop-blur-sm">
            <Clock size={12} className="text-[var(--text-secondary)]" />
            <span className="text-sm font-mono font-semibold">{formatTime(timeLeft)}</span>
          </div>

          {/* Score chip */}
          <div className="absolute top-3 left-1/2 -translate-x-1/2 px-3 py-1.5 rounded-lg bg-black/60 backdrop-blur-sm flex items-center gap-2">
            <span className="text-[10px] text-[var(--text-muted)]">Score</span>
            <span className="text-lg font-bold transition-colors duration-500" style={{ color: scoreHex(focusScore) }}>
              {focusScore}
            </span>
          </div>

          {/* ── AI Check-in modal ── */}
          <div
            className="absolute bottom-0 left-0 right-0 p-4 transition-all duration-300"
            style={{
              transform: showCheckIn ? 'translateY(0)' : 'translateY(110%)',
              opacity: showCheckIn ? 1 : 0,
              pointerEvents: showCheckIn ? 'auto' : 'none',
            }}
          >
            <div
              className="border border-[var(--accent-border)] rounded-xl p-4 shadow-2xl"
              style={{ backgroundColor: 'rgba(9,56,36,0.95)', backdropFilter: 'blur(12px)' }}
            >
              <div className="flex items-center gap-2 mb-3">
                <MessageSquare size={14} className="text-[var(--accent)]" />
                <span className="text-xs font-semibold text-[var(--accent)]">AI Check-in</span>
                {checkInPhase === 'analyzing' && <span className="text-[10px] text-[var(--warning)] ml-auto animate-pulse">Analyzing…</span>}
                {checkInPhase === 'done' && <span className="text-[10px] text-[var(--accent)] ml-auto">✓ Score updated</span>}
              </div>

              {checkInPhase === 'answering' && (
                <>
                  <p className="text-sm text-[var(--text-secondary)] mb-3">{CHECK_IN_QUESTIONS[checkInQ]}</p>
                  <div className="flex gap-2">
                    <input
                      ref={checkInRef}
                      type="text"
                      value={checkInAnswer}
                      onChange={e => setCheckInAnswer(e.target.value)}
                      onKeyDown={e => e.key === 'Enter' && submitCheckIn()}
                      placeholder="Type your answer…"
                      className="flex-1 px-3 py-2 rounded-lg bg-[var(--bg-primary)] border border-[var(--border)] text-sm text-[var(--text-primary)] placeholder-[var(--text-muted)] outline-none focus:border-[var(--accent)] transition-colors"
                    />
                    <button onClick={submitCheckIn} className="px-3 py-2 rounded-lg bg-[var(--accent)] text-[var(--bg-primary)] hover:opacity-90 transition">
                      <Send size={14} />
                    </button>
                  </div>
                </>
              )}

              {checkInPhase === 'analyzing' && (
                <div className="flex items-center justify-center py-4 gap-2">
                  <div className="w-4 h-4 border-2 border-[var(--accent)] border-t-transparent rounded-full animate-spin" />
                  <span className="text-sm text-[var(--text-secondary)]">Claude is evaluating your response…</span>
                </div>
              )}

              {checkInPhase === 'done' && (
                <div className="flex items-center justify-center py-4 gap-2">
                  <div className="w-5 h-5 rounded-full bg-[var(--accent)] flex items-center justify-center">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#0f1117" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12" /></svg>
                  </div>
                  <span className="text-sm text-[var(--accent)]">Great answer! Check-in score boosted.</span>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* ━━ RIGHT: Stats panel (30%) ━━ */}
        <div className="flex-[3] flex flex-col gap-3 min-w-[260px] overflow-y-auto">

          {/* Focus Score Gauge */}
          <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-5 flex flex-col items-center">
            <span className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider mb-3">Focus Score</span>
            <div className="relative w-[136px] h-[136px]">
              <svg viewBox="0 0 140 140" className="w-full h-full -rotate-90">
                <circle cx="70" cy="70" r={R} fill="none" stroke="var(--border)" strokeWidth="8" />
                <circle
                  cx="70" cy="70" r={R} fill="none"
                  stroke={scoreHex(focusScore)}
                  strokeWidth="8"
                  strokeLinecap="round"
                  strokeDasharray={C}
                  strokeDashoffset={gaugeOffset}
                  style={{ transition: 'stroke-dashoffset 1s ease, stroke 0.5s ease' }}
                />
              </svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <span className="text-4xl font-bold transition-colors duration-500" style={{ color: scoreHex(focusScore) }}>
                  {focusScore}
                </span>
                <span className="text-[10px] text-[var(--text-muted)]">/ 100</span>
              </div>
            </div>
            <div
              className="mt-3 text-[10px] font-medium px-2.5 py-1 rounded-full"
              style={{ background: scoreBg(focusScore), color: scoreHex(focusScore) }}
            >
              {focusScore >= 70 ? '✓ On track' : focusScore >= 50 ? '⚠ Needs improvement' : '✗ At risk'}
            </div>
          </div>

          {/* Signal Bars */}
          <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-4">
            <span className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider">Signals</span>
            <div className="flex flex-col gap-2.5 mt-3">
              {SIGNAL_CONFIG.map(({ key, label, icon: Icon }) => {
                const v = signals[key]
                return (
                  <div key={key}>
                    <div className="flex items-center justify-between mb-1">
                      <div className="flex items-center gap-1.5">
                        <Icon size={11} style={{ color: 'var(--text-muted)' }} />
                        <span className="text-[11px] text-[var(--text-secondary)]">{label}</span>
                      </div>
                      <span className="text-[11px] font-semibold tabular-nums" style={{ color: scoreHex(v) }}>{v}</span>
                    </div>
                    <div className="h-1.5 rounded-full bg-[var(--bg-primary)]">
                      <div
                        className="h-full rounded-full"
                        style={{ width: `${v}%`, background: scoreHex(v), transition: 'width 1s ease, background 0.5s ease' }}
                      />
                    </div>
                  </div>
                )
              })}
            </div>
          </div>

          {/* Timer + Progress */}
          <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-4">
            <div className="flex justify-between items-center mb-2">
              <span className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider">Time Left</span>
              <span className="text-[10px] text-[var(--text-muted)]">{Math.round(progress * 100)}%</span>
            </div>
            <div className="text-2xl font-mono font-bold mb-2">{formatTime(timeLeft)}</div>
            <div className="h-1.5 rounded-full bg-[var(--bg-primary)]">
              <div className="h-full rounded-full bg-[var(--accent)]" style={{ width: `${progress * 100}%`, transition: 'width 1s linear' }} />
            </div>
          </div>

          {/* Building Info */}
          <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-4">
            <div className="flex items-center gap-2 mb-2.5">
              <MapPin size={12} className="text-[var(--accent)]" />
              <span className="text-xs font-semibold">{bldg.name}</span>
              {bldg.king && <span className="text-[10px] text-[var(--text-muted)] ml-auto">👑 {bldg.king}</span>}
            </div>
            <div className="flex flex-col gap-1.5">
              <div className="flex justify-between">
                <span className="text-[10px] text-[var(--text-muted)]">Your rank</span>
                <span className="text-xs font-semibold text-[var(--accent)]">#{myRank}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-[10px] text-[var(--text-muted)]">Weekly score</span>
                <span className="text-xs font-semibold">{USER_STATS.weeklyScore.toLocaleString()} pts</span>
              </div>
              <div className="flex justify-between">
                <span className="text-[10px] text-[var(--text-muted)]">Consistency</span>
                <span className="text-xs font-semibold">{USER_STATS.weeklyConsistency}/7 days</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ── Bottom bar: 3 cards ── */}
      <div className="grid grid-cols-3 gap-3">
        <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-3 flex items-center gap-3">
          <div className="w-9 h-9 rounded-lg bg-[var(--accent-dim)] flex items-center justify-center shrink-0">
            <TrendingUp size={16} className="text-[var(--accent)]" />
          </div>
          <div>
            <div className="text-[10px] text-[var(--text-muted)]">Building Rank</div>
            <div className="text-sm font-bold text-[var(--accent)]">#{myRank} <span className="text-[10px] font-normal text-[var(--text-muted)]">at {bldg.abbr}</span></div>
          </div>
        </div>

        <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-3 flex items-center gap-3">
          <div className="w-9 h-9 rounded-lg bg-[var(--accent-dim)] flex items-center justify-center shrink-0">
            <MapPin size={16} className="text-[var(--accent)]" />
          </div>
          <div>
            <div className="text-[10px] text-[var(--text-muted)]">Weekly Score</div>
            <div className="text-sm font-bold">{USER_STATS.weeklyScore.toLocaleString()}</div>
          </div>
        </div>

        <div className="bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)] p-3 flex items-center gap-3">
          <div className="w-9 h-9 rounded-lg bg-[rgba(191,198,169,0.12)] flex items-center justify-center shrink-0">
            <Calendar size={16} className="text-[var(--accent)]" />
          </div>
          <div>
            <div className="text-[10px] text-[var(--text-muted)]">Consistency</div>
            <div className="text-sm font-bold">{USER_STATS.weeklyConsistency}/7 days</div>
          </div>
        </div>
      </div>
    </div>
  )
}

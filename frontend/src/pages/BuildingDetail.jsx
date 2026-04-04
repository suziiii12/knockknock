import { useState, useEffect, useMemo, useCallback, useRef } from 'react'
import { useParams, Link } from 'react-router-dom'
import { ArrowLeft, Clock, Users, Zap, Crown } from 'lucide-react'
import { BUILDING_TERRITORY, BUILDINGS } from '../data/mock'

// ═══════════════════════════════════════════════════════
// Hex Grid Engine
// ═══════════════════════════════════════════════════════

const HEX_R = 18
const SQRT3 = Math.sqrt(3)
const SVG_W = 620
const SVG_H = 440
const PAD = 14

// Pointy-top hex vertex string (relative to center, with 1px gap)
const HEX_PTS = (() => {
  const s = HEX_R - 1
  return Array.from({ length: 6 }, (_, i) => {
    const a = (Math.PI / 3) * i - Math.PI / 6
    return `${(s * Math.cos(a)).toFixed(1)},${(s * Math.sin(a)).toFixed(1)}`
  }).join(' ')
})()

function buildGrid() {
  const hDist = SQRT3 * HEX_R
  const vDist = 1.5 * HEX_R
  const cols = Math.floor((SVG_W - 2 * PAD) / hDist)
  const rows = Math.floor((SVG_H - 2 * PAD - HEX_R) / vDist) + 1
  const cells = []
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const cx = PAD + c * hDist + (r & 1 ? hDist / 2 : 0) + hDist / 2
      const cy = PAD + r * vDist + HEX_R
      if (cx - HEX_R >= -2 && cx + HEX_R <= SVG_W + 2 && cy + HEX_R <= SVG_H + 2) {
        cells.push({ col: c, row: r, cx, cy })
      }
    }
  }
  return { cells, cols, rows }
}

// Odd-row offset hex neighbors
function hexNeighbors(col, row, cols, rows) {
  const odd = row & 1
  const dirs = odd
    ? [[0, -1], [1, -1], [-1, 0], [1, 0], [0, 1], [1, 1]]
    : [[-1, -1], [0, -1], [-1, 0], [1, 0], [-1, 1], [0, 1]]
  const out = []
  for (const [dc, dr] of dirs) {
    const nc = col + dc
    const nr = row + dr
    if (nc >= 0 && nc < cols && nr >= 0 && nr < rows) out.push([nc, nr])
  }
  return out
}

function shuffle(a) {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

// Multi-source BFS: each user grows from a seed, 1 cell per round, creating organic clusters
function seedTerritories(cells, cols, rows, users) {
  const n = cells.length
  const own = new Int8Array(n).fill(-1)
  if (users.length === 0 || n === 0) return own

  const quotas = users.map(u => Math.max(1, Math.round((u.percentage / 100) * n)))

  // Fast lookup: col*10000+row -> cell index
  const lk = new Map()
  cells.forEach((c, i) => lk.set(c.col * 10000 + c.row, i))
  const key = (c, r) => c * 10000 + r

  const cCol = Math.floor(cols / 2)
  const cRow = Math.floor(rows / 2)

  // Place seeds: #1 center, rest in a ring
  const seeds = [{ c: cCol, r: cRow }]
  const rad = Math.min(cols, rows) * 0.34
  const ring = users.length - 1
  for (let i = 0; i < ring; i++) {
    const a = (2 * Math.PI * i) / Math.max(ring, 1) - Math.PI / 2
    seeds.push({
      c: Math.max(0, Math.min(cols - 1, Math.round(cCol + rad * Math.cos(a)))),
      r: Math.max(0, Math.min(rows - 1, Math.round(cRow + rad * Math.sin(a)))),
    })
  }

  // Plant seeds
  const frontiers = users.map(() => [])
  for (let u = 0; u < users.length; u++) {
    const idx = lk.get(key(seeds[u].c, seeds[u].r))
    if (idx !== undefined && own[idx] === -1) {
      own[idx] = u
      quotas[u]--
      frontiers[u].push(idx)
    }
  }

  // Grow round-robin
  let active = true
  let safety = n * 4
  while (active && safety-- > 0) {
    active = false
    for (let u = 0; u < users.length; u++) {
      if (quotas[u] <= 0 || frontiers[u].length === 0) continue
      let claimed = false
      const tries = frontiers[u].length
      for (let t = 0; t < tries && !claimed; t++) {
        const fi = Math.floor(Math.random() * frontiers[u].length)
        const ci = frontiers[u][fi]
        const ns = shuffle(hexNeighbors(cells[ci].col, cells[ci].row, cols, rows))
        for (const [nc, nr] of ns) {
          const ni = lk.get(key(nc, nr))
          if (ni !== undefined && own[ni] === -1) {
            own[ni] = u
            quotas[u]--
            frontiers[u].push(ni)
            claimed = true
            active = true
            break
          }
        }
        if (!claimed) {
          const still = hexNeighbors(cells[ci].col, cells[ci].row, cols, rows)
            .some(([nc, nr]) => { const ni = lk.get(key(nc, nr)); return ni !== undefined && own[ni] === -1 })
          if (!still) frontiers[u].splice(fi, 1)
        }
      }
      if (quotas[u] > 0 && frontiers[u].length > 0) active = true
    }
  }
  return own
}

// Find cells on the border between two different owners
function findBorder(own, cells, cols, rows) {
  const lk = new Map()
  cells.forEach((c, i) => lk.set(c.col * 10000 + c.row, i))
  const out = []
  for (let i = 0; i < cells.length; i++) {
    if (own[i] < 0) continue
    for (const [nc, nr] of hexNeighbors(cells[i].col, cells[i].row, cols, rows)) {
      const ni = lk.get(nc * 10000 + nr)
      if (ni !== undefined && own[ni] >= 0 && own[ni] !== own[i]) {
        out.push({ cell: i, neighbor: ni })
        break
      }
    }
  }
  return out
}

// ═══════════════════════════════════════════════════════
// HexTerritory — interactive hex grid with live sim
// ═══════════════════════════════════════════════════════

function HexTerritory({ users, otherPct, hoveredUser, onHoverUser, onCapture }) {
  const grid = useMemo(() => buildGrid(), [])

  const [ownership, setOwnership] = useState(() =>
    seedTerritories(grid.cells, grid.cols, grid.rows, users)
  )
  const [flashSet, setFlashSet] = useState(new Set())
  const [tooltip, setTooltip] = useState(null)

  const svgRef = useRef(null)
  const tickRef = useRef(0)

  // ── Simulation: capture cells every 3s ──
  useEffect(() => {
    const iv = setInterval(() => {
      tickRef.current++
      const isWave = tickRef.current % 5 === 0

      setOwnership(prev => {
        const own = new Int8Array(prev)
        const border = findBorder(own, grid.cells, grid.cols, grid.rows)
        if (border.length === 0) return prev

        const count = isWave
          ? Math.min(3 + Math.floor(Math.random() * 4), border.length)
          : Math.min(1 + Math.floor(Math.random() * 2), border.length)

        const picks = shuffle([...border]).slice(0, count)
        const caps = []
        const flash = new Set()

        for (const { cell, neighbor } of picks) {
          const attacker = own[neighbor]
          const defender = own[cell]
          if (attacker === defender || attacker < 0) continue
          own[cell] = attacker
          flash.add(cell)
          caps.push({ from: defender, to: attacker })
        }

        if (caps.length > 0) {
          setFlashSet(flash)
          setTimeout(() => setFlashSet(new Set()), 400)

          // Group captures by attacker/defender pair
          const grouped = {}
          for (const c of caps) {
            const k = `${c.to}>${c.from}`
            if (!grouped[k]) grouped[k] = { to: c.to, from: c.from, n: 0 }
            grouped[k].n++
          }

          // Detect king change
          const counts = new Array(users.length).fill(0)
          for (let i = 0; i < own.length; i++) if (own[i] >= 0) counts[own[i]]++
          const newKingIdx = counts.indexOf(Math.max(...counts))
          const oldCounts = new Array(users.length).fill(0)
          for (let i = 0; i < prev.length; i++) if (prev[i] >= 0) oldCounts[prev[i]]++
          const oldKingIdx = oldCounts.indexOf(Math.max(...oldCounts))
          const kingChanged = newKingIdx !== oldKingIdx ? users[newKingIdx]?.name : null

          onCapture(Object.values(grouped).map(g => ({
            attacker: users[g.to]?.name,
            defender: users[g.from]?.name,
            count: g.n,
            color: users[g.to]?.color,
            isWave,
          })), kingChanged)
        }
        return own
      })
    }, 3000)
    return () => clearInterval(iv)
  }, [grid, users, onCapture])

  // ── Mouse: find nearest hex ──
  const handleMouse = useCallback((e) => {
    const svg = svgRef.current
    if (!svg) return
    const rect = svg.getBoundingClientRect()
    const mx = (e.clientX - rect.left) * (SVG_W / rect.width)
    const my = (e.clientY - rect.top) * (SVG_H / rect.height)

    let best = -1
    let bestD = HEX_R * HEX_R * 1.3
    for (let i = 0; i < grid.cells.length; i++) {
      const dx = mx - grid.cells[i].cx
      const dy = my - grid.cells[i].cy
      const d = dx * dx + dy * dy
      if (d < bestD) { bestD = d; best = i }
    }

    if (best >= 0 && ownership[best] >= 0) {
      const u = ownership[best]
      onHoverUser(u)
      setTooltip({
        x: e.clientX, y: e.clientY,
        name: users[u].name,
        score: users[u].score,
        pct: users[u].percentage,
        color: users[u].color,
        rank: users[u].rank,
      })
    } else {
      onHoverUser(null)
      setTooltip(null)
    }
  }, [grid.cells, ownership, users, onHoverUser])

  const handleLeave = useCallback(() => {
    onHoverUser(null)
    setTooltip(null)
  }, [onHoverUser])

  return (
    <div className="relative">
      <style>{`
        @keyframes hexPulse {
          0% { fill-opacity: 0.9; }
          50% { fill-opacity: 0.55; }
          100% { fill-opacity: 0.9; }
        }
      `}</style>

      <div
        className="rounded-xl overflow-hidden border border-[var(--border)]"
        style={{ background: '#062818' }}
      >
        <svg
          ref={svgRef}
          viewBox={`0 0 ${SVG_W} ${SVG_H}`}
          className="w-full block select-none"
          onMouseMove={handleMouse}
          onMouseLeave={handleLeave}
        >
          {/* Subtle radial vignette */}
          <defs>
            <radialGradient id="vig" cx="50%" cy="50%" r="60%">
              <stop offset="0%" stopColor="#062818" stopOpacity="0" />
              <stop offset="100%" stopColor="#062818" stopOpacity="0.6" />
            </radialGradient>
          </defs>
          <rect width={SVG_W} height={SVG_H} fill="#062818" />

          {grid.cells.map((cell, i) => {
            const u = ownership[i]
            const user = u >= 0 ? users[u] : null
            const color = user ? user.color : '#0a3522'
            const isFlash = flashSet.has(i)
            const isHi = hoveredUser !== null && u === hoveredUser
            const isDim = hoveredUser !== null && u !== hoveredUser

            let opacity
            if (isFlash) opacity = 1
            else if (isHi) opacity = 0.85
            else if (isDim) opacity = 0.15
            else if (u >= 0) opacity = 0.55
            else opacity = 0.1

            return (
              <polygon
                key={i}
                points={HEX_PTS}
                transform={`translate(${cell.cx},${cell.cy})`}
                fill={isFlash ? '#ffffff' : color}
                fillOpacity={opacity}
                stroke={isHi ? '#ffffff' : u >= 0 ? color : '#07301c'}
                strokeWidth={isHi ? 1.4 : 0.5}
                strokeOpacity={isHi ? 0.9 : 0.2}
                style={{
                  transition: isFlash
                    ? 'none'
                    : 'fill 0.5s ease, fill-opacity 0.3s ease, stroke 0.3s ease, stroke-width 0.2s ease',
                }}
              />
            )
          })}

          <rect width={SVG_W} height={SVG_H} fill="url(#vig)" pointerEvents="none" />
        </svg>
      </div>

      {/* Tooltip */}
      {tooltip && (
        <div
          className="fixed z-50 pointer-events-none px-3 py-2 rounded-lg shadow-xl"
          style={{
            left: tooltip.x + 14,
            top: tooltip.y - 48,
            backgroundColor: 'rgba(6,40,24,0.95)',
            border: `1px solid ${tooltip.color}44`,
            backdropFilter: 'blur(8px)',
          }}
        >
          <div className="flex items-center gap-1.5 mb-0.5">
            {tooltip.rank === 1 && <span className="text-xs">👑</span>}
            <span className="text-xs font-semibold" style={{ color: tooltip.color }}>
              {tooltip.name}
            </span>
          </div>
          <div className="text-[10px] text-[var(--text-muted)]">
            {tooltip.score.toLocaleString()} pts · {tooltip.pct}%
          </div>
        </div>
      )}
    </div>
  )
}

// ═══════════════════════════════════════════════════════
// RankingPanel — right sidebar
// ═══════════════════════════════════════════════════════

function RankingPanel({ data, buildingId, events, kingBanner, hoveredUser, onHoverUser }) {
  const { topUsers, totalParticipants, totalSessions, weeklyReset, yourRankIfOutside } = data

  return (
    <div className="flex flex-col h-full gap-3">
      {/* Header */}
      <div>
        <h2 className="text-lg font-bold">{data.name}</h2>
        <div className="flex items-center gap-3 mt-1">
          <span className="text-[10px] px-2 py-0.5 rounded-full bg-[var(--accent-dim)] text-[var(--accent)] border border-[var(--accent-border)]">
            Week 14
          </span>
          <span className="flex items-center gap-1 text-[10px] text-[var(--warning)]">
            <Clock size={10} />
            Resets in {weeklyReset}
          </span>
        </div>
      </div>

      {/* Rankings */}
      <div className="flex-1 overflow-y-auto flex flex-col gap-1 min-h-0">
        {topUsers.map((user, idx) => {
          const isHi = hoveredUser === idx
          return (
            <div
              key={user.rank}
              className={`flex items-center gap-2 px-2 py-1.5 rounded-lg transition-all cursor-default ${
                user.rank === 1
                  ? 'bg-[rgba(191,198,169,0.08)] border border-[rgba(191,198,169,0.2)]'
                  : isHi
                    ? 'bg-[var(--bg-secondary)]'
                    : 'hover:bg-[var(--bg-secondary)] border border-transparent'
              }`}
              onMouseEnter={() => onHoverUser(idx)}
              onMouseLeave={() => onHoverUser(null)}
            >
              <div
                className="w-5 h-5 rounded-full flex items-center justify-center text-[9px] font-bold shrink-0"
                style={{ background: user.color + '22', color: user.color }}
              >
                {user.rank === 1 ? '👑' : user.rank}
              </div>
              <div
                className="w-6 h-6 rounded-full flex items-center justify-center text-[8px] font-semibold shrink-0"
                style={{ background: user.color + '33', color: user.color }}
              >
                {user.initials}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1">
                  <span className={`text-[11px] font-semibold truncate ${user.rank === 1 ? 'text-[var(--accent)]' : ''}`}>
                    {user.name}
                  </span>
                  {user.isYou && (
                    <span className="text-[6px] font-bold px-1 py-0.5 rounded bg-[var(--accent-dim)] text-[var(--accent)]">
                      YOU
                    </span>
                  )}
                </div>
              </div>
              <div className="text-right shrink-0">
                <span className="text-[10px] font-bold tabular-nums" style={{ color: user.color }}>
                  {user.score.toLocaleString()}
                </span>
                <span className="text-[8px] text-[var(--text-muted)] ml-1">{user.percentage}%</span>
              </div>
              <div className="w-10 h-1 rounded-full bg-[var(--bg-primary)] shrink-0">
                <div
                  className="h-full rounded-full"
                  style={{ width: `${(user.score / topUsers[0].score) * 100}%`, background: user.color }}
                />
              </div>
            </div>
          )
        })}

        {yourRankIfOutside && (
          <>
            <div className="flex items-center gap-2 py-1 px-2">
              <div className="flex-1 h-px bg-[var(--border)]" />
              <span className="text-[8px] text-[var(--text-muted)]">···</span>
              <div className="flex-1 h-px bg-[var(--border)]" />
            </div>
            <div className="flex items-center gap-2 px-2 py-1.5 rounded-lg bg-[rgba(191,198,169,0.05)] border border-[rgba(191,198,169,0.15)]">
              <div className="w-5 h-5 rounded-full flex items-center justify-center text-[9px] font-bold shrink-0 bg-[var(--accent-dim)] text-[var(--accent)]">
                {yourRankIfOutside.rank}
              </div>
              <div className="w-6 h-6 rounded-full flex items-center justify-center text-[8px] font-semibold shrink-0"
                style={{ background: 'rgba(191,198,169,0.2)', color: '#BFC6A9' }}>
                {yourRankIfOutside.initials}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1">
                  <span className="text-[11px] font-semibold truncate">{yourRankIfOutside.name}</span>
                  <span className="text-[6px] font-bold px-1 py-0.5 rounded bg-[var(--accent-dim)] text-[var(--accent)]">YOU</span>
                </div>
              </div>
              <span className="text-[10px] font-bold tabular-nums text-[var(--accent)]">
                {yourRankIfOutside.score.toLocaleString()}
              </span>
            </div>
          </>
        )}
      </div>

      {/* Live Activity Feed */}
      <div className="border-t border-[var(--border)] pt-2">
        <div className="flex items-center gap-1.5 mb-2">
          <div className="w-1.5 h-1.5 rounded-full bg-[var(--danger)] animate-pulse" />
          <span className="text-[9px] text-[var(--text-muted)] uppercase tracking-wider font-medium">Live</span>
        </div>
        <div className="flex flex-col gap-1 max-h-28 overflow-y-auto">
          {events.length > 0 ? events.slice(0, 8).map((ev, i) => (
            <div
              key={ev.id}
              className="text-[10px] leading-tight py-1 px-2 rounded-md"
              style={{
                background: i === 0 ? 'rgba(255,255,255,0.03)' : 'transparent',
                opacity: Math.max(0.4, 1 - i * 0.1),
              }}
            >
              <span>{ev.isWave ? '🔥' : '⚔️'} </span>
              <strong style={{ color: ev.color }}>{ev.attacker}</strong>
              <span className="text-[var(--text-muted)]"> took {ev.count} cell{ev.count > 1 ? 's' : ''} from </span>
              <strong className="text-[var(--text-secondary)]">{ev.defender}</strong>
            </div>
          )) : (
            <div className="text-[10px] text-[var(--text-muted)] text-center py-2">
              Territory battles incoming…
            </div>
          )}
        </div>
      </div>

      {/* Footer stats */}
      <div className="grid grid-cols-2 gap-2 pt-2 border-t border-[var(--border)]">
        <div className="bg-[var(--bg-secondary)] rounded-lg p-2 text-center">
          <div className="flex items-center justify-center gap-1 text-[var(--text-muted)] mb-0.5">
            <Users size={9} />
            <span className="text-[8px]">Participants</span>
          </div>
          <div className="text-xs font-bold">{totalParticipants}</div>
        </div>
        <div className="bg-[var(--bg-secondary)] rounded-lg p-2 text-center">
          <div className="flex items-center justify-center gap-1 text-[var(--text-muted)] mb-0.5">
            <Zap size={9} />
            <span className="text-[8px]">Sessions</span>
          </div>
          <div className="text-xs font-bold">{totalSessions}</div>
        </div>
      </div>

      <Link
        to="/start"
        className="flex items-center justify-center gap-2 py-2.5 rounded-xl bg-[var(--accent)] text-[var(--bg-primary)] font-semibold text-sm hover:opacity-90 transition-all active:scale-[0.98]"
      >
        <Zap size={14} />
        Study Here
      </Link>
    </div>
  )
}

// ═══════════════════════════════════════════════════════
// BuildingDetail — main page export
// ═══════════════════════════════════════════════════════

export default function BuildingDetail() {
  const { id } = useParams()
  const data = BUILDING_TERRITORY[id]

  const [hoveredUser, setHoveredUser] = useState(null)
  const [events, setEvents] = useState([])
  const [kingBanner, setKingBanner] = useState(null)
  const eventId = useRef(0)

  const handleCapture = useCallback((captures, newKingName) => {
    const stamped = captures.map(c => ({ ...c, id: ++eventId.current }))
    setEvents(prev => [...stamped, ...prev].slice(0, 20))
    if (newKingName) {
      setKingBanner(newKingName)
      setTimeout(() => setKingBanner(null), 4000)
    }
  }, [])

  if (!data) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <p className="text-[var(--text-muted)]">Building not found</p>
        <Link to="/map" className="text-sm text-[var(--accent)] hover:underline">← Back to Campus Map</Link>
      </div>
    )
  }

  const isEmpty = data.topUsers.length === 0

  return (
    <div>
      {/* Back nav */}
      <Link
        to="/map"
        className="inline-flex items-center gap-1.5 text-xs text-[var(--text-muted)] hover:text-[var(--text-primary)] transition mb-4"
      >
        <ArrowLeft size={14} />
        Campus Map
      </Link>

      {/* King change banner */}
      {kingBanner && (
        <div className="mb-3 py-2.5 px-4 rounded-xl text-center text-sm font-bold animate-bounce"
          style={{ background: 'rgba(251,191,36,0.15)', border: '1px solid rgba(251,191,36,0.3)', color: '#fbbf24' }}>
          👑 {kingBanner} is the new {data.name} King!
        </div>
      )}

      {isEmpty ? (
        <div className="flex flex-col items-center justify-center py-20 gap-4">
          <div className="w-16 h-16 rounded-full bg-[var(--bg-secondary)] flex items-center justify-center">
            <Crown size={28} className="text-[var(--text-muted)] opacity-40" />
          </div>
          <h2 className="text-lg font-bold">{data.name}</h2>
          <p className="text-sm text-[var(--text-muted)] text-center max-w-xs">
            No one has studied here this week. Be the first to claim this building!
          </p>
          <Link
            to="/start"
            className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-[var(--accent)] text-[var(--bg-primary)] text-sm font-semibold hover:opacity-90 transition"
          >
            <Zap size={16} />
            Claim This Building
          </Link>
        </div>
      ) : (
        <div className="flex gap-5" style={{ minHeight: 'calc(100vh - 160px)' }}>
          {/* Left — Hex Territory (60%) */}
          <div className="flex-[6]">
            <div className="flex items-center gap-2 mb-3">
              <div className="w-1.5 h-1.5 rounded-full bg-[var(--accent)] animate-pulse" />
              <span className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider">Live Territory Map</span>
              <div className="flex-1 h-px bg-[var(--border)]" />
            </div>

            <HexTerritory
              key={id}
              users={data.topUsers}
              otherPct={data.otherPercentage}
              hoveredUser={hoveredUser}
              onHoverUser={setHoveredUser}
              onCapture={handleCapture}
            />

            {/* Color legend */}
            <div className="flex flex-wrap gap-x-3 gap-y-1 mt-3">
              {data.topUsers.slice(0, 6).map(u => (
                <button
                  key={u.name}
                  className="flex items-center gap-1.5 text-[10px] text-[var(--text-secondary)] hover:text-[var(--text-primary)] transition"
                  onMouseEnter={() => setHoveredUser(u.rank - 1)}
                  onMouseLeave={() => setHoveredUser(null)}
                >
                  <div className="w-2.5 h-2.5 rounded-sm" style={{ background: u.color }} />
                  {u.name} {u.rank === 1 && '👑'}
                </button>
              ))}
              {data.topUsers.length > 6 && (
                <span className="text-[10px] text-[var(--text-muted)]">+{data.topUsers.length - 6} more</span>
              )}
            </div>
          </div>

          {/* Right — Rankings + Feed (40%) */}
          <div className="flex-[4] min-w-[280px]">
            <RankingPanel
              data={data}
              buildingId={id}
              events={events}
              kingBanner={kingBanner}
              hoveredUser={hoveredUser}
              onHoverUser={setHoveredUser}
            />
          </div>
        </div>
      )}
    </div>
  )
}

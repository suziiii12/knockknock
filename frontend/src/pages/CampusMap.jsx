import { useNavigate } from 'react-router-dom'
import { BUILDINGS, ROADS, COLOR_MAP } from '../data/mock'

export default function CampusMap() {
  const navigate = useNavigate()

  const getStyle = (b) => {
    if (!b.color) return { fill: 'rgba(255,255,255,0.03)', stroke: 'rgba(255,255,255,0.1)' }
    const c = COLOR_MAP[b.color]
    return { fill: c.bg, stroke: c.border }
  }

  const getTextColor = (b) => {
    if (!b.color) return '#4b5563'
    return COLOR_MAP[b.color].text
  }

  return (
    <div>
      {/* Header */}
      <div className="flex justify-between items-center mb-4">
        <div>
          <h2 className="text-lg font-semibold">Purdue Campus Territory</h2>
          <p className="text-xs text-[var(--text-muted)]">
            Resets in <span className="text-[var(--warning)] font-medium">4d 13h 22m</span> · Click a building to explore
          </p>
        </div>
        <span className="text-[10px] px-2.5 py-1 rounded-full bg-[var(--accent-dim)] text-[var(--accent)] border border-[var(--accent-border)]">
          Week 14 — Spring 2026
        </span>
      </div>

      {/* SVG Map */}
      <div className="bg-[var(--bg-tertiary)] rounded-xl border border-[var(--border)] overflow-hidden">
        <svg viewBox="0 0 680 480" className="w-full block">
          <rect width="680" height="480" fill="var(--bg-tertiary)" />

          {/* Roads */}
          {ROADS.map((r, i) => (
            <g key={i}>
              <line
                x1={r.x1 * 6.8} y1={r.y1 * 4.8}
                x2={r.x2 * 6.8} y2={r.y2 * 4.8}
                stroke="#0a3020" strokeWidth="3" strokeLinecap="round"
              />
              {r.vertical ? (
                <text
                  x={r.x1 * 6.8 + 5} y={20}
                  fontSize="7" fill="#1a5c3e" fontWeight="500"
                  transform={`rotate(90, ${r.x1 * 6.8 + 5}, 20)`}
                >
                  {r.label}
                </text>
              ) : (
                <text x={r.x2 * 6.8 - 80} y={r.y1 * 4.8 - 5} fontSize="7" fill="#1a5c3e" fontWeight="500">
                  {r.label}
                </text>
              )}
            </g>
          ))}

          {/* Buildings */}
          {BUILDINGS.map(b => {
            const style = getStyle(b)
            const textColor = getTextColor(b)
            const px = b.x * 6.8
            const py = b.y * 4.8
            const pw = b.w * 6.8
            const ph = b.h * 4.8
            return (
              <g
                key={b.id}
                onClick={() => navigate(`/building/${b.id}`)}
                className="cursor-pointer hover:opacity-80 transition-opacity"
              >
                <rect
                  x={px} y={py} width={pw} height={ph}
                  rx={4} ry={4}
                  fill={style.fill} stroke={style.stroke} strokeWidth="1.2"
                />
                {b.king && (
                  <text x={px + pw - 2} y={py - 2} fontSize="9" textAnchor="end">👑</text>
                )}
                <text
                  x={px + pw / 2} y={py + ph / 2 - (b.king ? 4 : 0)}
                  fontSize="8" fontWeight="600" textAnchor="middle" dominantBaseline="central"
                  fill={textColor}
                >
                  {b.abbr}
                </text>
                {b.king && (
                  <text
                    x={px + pw / 2} y={py + ph / 2 + 10}
                    fontSize="6" textAnchor="middle" dominantBaseline="central"
                    fill={textColor} opacity="0.7"
                  >
                    {b.king}
                  </text>
                )}
                {!b.king && (
                  <text
                    x={px + pw / 2} y={py + ph / 2 + 10}
                    fontSize="6" textAnchor="middle" dominantBaseline="central"
                    fill="#4a6b52"
                  >
                    Unclaimed
                  </text>
                )}
              </g>
            )
          })}

          {/* You are here dot */}
          <circle cx={240} cy={170} r={4} fill="var(--accent)" opacity="0.7" />
          <text x={248} y={173} fontSize="7" fill="var(--accent)" fontWeight="500">You are here</text>
        </svg>
      </div>

      {/* Legend */}
      <div className="flex gap-3 mt-3 flex-wrap">
        {[
          { label: 'Yewon — 3', color: '#BFC6A9' },
          { label: 'NakJun — 3', color: '#a78bfa' },
          { label: 'Suji — 2', color: '#fb923c' },
          { label: 'Eunho — 2', color: '#60a5fa' },
          { label: 'Mia — 1', color: '#f472b6' },
          { label: 'Unclaimed — 3', color: 'rgba(255,255,255,0.15)' },
        ].map(l => (
          <div key={l.label} className="flex items-center gap-1.5 text-[10px] text-[var(--text-secondary)]">
            <div className="w-2 h-2 rounded-sm" style={{ background: l.color }} />
            {l.label}
          </div>
        ))}
      </div>
    </div>
  )
}

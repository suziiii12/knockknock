import { Outlet, NavLink } from 'react-router-dom'
import { Map, User, Zap, History } from 'lucide-react'
import { USER_STATS } from '../data/mock'

const navItems = [
  { to: '/start', label: 'Focus', icon: Zap },
  { to: '/history', label: 'History', icon: History },
  { to: '/map', label: 'Map', icon: Map },
  { to: '/profile', label: 'Profile', icon: User },
]

export default function Layout() {
  return (
    <div className="min-h-screen flex flex-col">
      {/* Top Nav */}
      <header className="flex items-center justify-between px-5 py-3 border-b border-[var(--border)]">
        <NavLink to="/" className="flex items-center gap-2">
          <Zap size={20} className="text-[var(--accent)]" />
          <span className="text-base font-semibold text-[var(--accent)]">FocusBet</span>
        </NavLink>

        <nav className="flex gap-1">
          {navItems.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                `flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
                  isActive
                    ? 'bg-[var(--accent)] text-[var(--bg-primary)]'
                    : 'text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-secondary)]'
                }`
              }
            >
              <Icon size={14} />
              <span className="hidden sm:inline">{label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="flex items-center gap-3">
          <span className="text-xs px-2.5 py-1 rounded-lg bg-[var(--bg-secondary)] border border-[var(--border)] text-[var(--accent)]">
            Score: {USER_STATS.weeklyScore.toLocaleString()}
          </span>
          <div className="w-7 h-7 rounded-full bg-[var(--accent)] flex items-center justify-center text-[10px] font-semibold text-[var(--bg-primary)]">
            YC
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 px-5 py-6 max-w-6xl mx-auto w-full">
        <Outlet />
      </main>
    </div>
  )
}

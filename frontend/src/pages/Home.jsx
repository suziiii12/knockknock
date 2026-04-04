import { Link } from 'react-router-dom'
import { Map, Zap, Shield, Target, TrendingUp, Users } from 'lucide-react'

export default function Home() {
  return (
    <div className="flex flex-col items-center pt-12 gap-10">
      {/* Hero */}
      <div className="text-center max-w-lg">
        <h1 className="text-4xl font-bold mb-3">
          Own Your <span className="text-[var(--accent)]">Campus</span>
        </h1>
        <p className="text-[var(--text-secondary)] text-base leading-relaxed">
          Study, compete, and conquer campus buildings. AI verifies your concentration
          in real time — climb the leaderboard and become the Building King.
        </p>
      </div>

      {/* CTA */}
      <div className="flex gap-3">
        <Link
          to="/start"
          className="px-5 py-2.5 rounded-xl bg-[var(--accent)] text-[var(--bg-primary)] text-sm font-semibold hover:opacity-90 transition flex items-center gap-2"
        >
          <Zap size={16} />
          Start Studying
        </Link>
        <Link
          to="/map"
          className="px-5 py-2.5 rounded-xl border border-[var(--border)] text-[var(--text-secondary)] text-sm font-medium hover:bg-[var(--bg-secondary)] transition"
        >
          View Campus Map
        </Link>
      </div>

      {/* How it works */}
      <div className="w-full max-w-2xl">
        <h3 className="text-xs text-[var(--text-muted)] uppercase tracking-wider text-center mb-4">How it works</h3>
        <div className="grid grid-cols-4 gap-3">
          {[
            { step: '1', title: 'Walk in', desc: 'GPS detects your building' },
            { step: '2', title: 'Focus', desc: 'AI monitors your session' },
            { step: '3', title: 'Score', desc: 'Earn points based on focus' },
            { step: '4', title: 'Conquer', desc: 'Claim territory on campus' },
          ].map(s => (
            <div key={s.step} className="flex flex-col items-center gap-2 p-3 rounded-xl bg-[var(--bg-secondary)] border border-[var(--border)]">
              <div className="w-7 h-7 rounded-full bg-[var(--accent-dim)] text-[var(--accent)] flex items-center justify-center text-xs font-bold">
                {s.step}
              </div>
              <span className="text-xs font-medium">{s.title}</span>
              <span className="text-[10px] text-[var(--text-muted)] text-center">{s.desc}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Features */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 w-full max-w-3xl">
        {[
          { icon: Target, title: 'Compete', desc: 'Rank up against other students' },
          { icon: Zap, title: 'AI Verified', desc: 'Webcam + behavior tracking' },
          { icon: Map, title: 'Own Territory', desc: 'Become the Building King' },
          { icon: Shield, title: 'World ID', desc: 'One person, one account' },
        ].map(({ icon: Icon, title, desc }) => (
          <div
            key={title}
            className="flex flex-col items-center gap-2 p-4 rounded-xl bg-[var(--bg-secondary)] border border-[var(--border)]"
          >
            <Icon size={20} className="text-[var(--accent)]" />
            <span className="text-xs font-medium">{title}</span>
            <span className="text-[10px] text-[var(--text-muted)] text-center">{desc}</span>
          </div>
        ))}
      </div>

      {/* Live stats */}
      <div className="flex gap-6 text-center">
        <div>
          <div className="text-2xl font-bold text-[var(--accent)]">2,450</div>
          <div className="text-[10px] text-[var(--text-muted)]">Your weekly score</div>
        </div>
        <div>
          <div className="text-2xl font-bold">147</div>
          <div className="text-[10px] text-[var(--text-muted)]">Active studiers</div>
        </div>
        <div>
          <div className="text-2xl font-bold text-[var(--warning)]">11</div>
          <div className="text-[10px] text-[var(--text-muted)]">Buildings claimed</div>
        </div>
      </div>
    </div>
  )
}

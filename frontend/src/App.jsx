import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import StartSession from './pages/StartSession'
import Session from './pages/Session'
import Result from './pages/Result'
import History from './pages/History'
import CampusMap from './pages/CampusMap'
import BuildingDetail from './pages/BuildingDetail'
import Profile from './pages/Profile'

export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/" element={<Home />} />
        <Route path="/start" element={<StartSession />} />
        <Route path="/session" element={<Session />} />
        <Route path="/result" element={<Result />} />
        <Route path="/history" element={<History />} />
        <Route path="/map" element={<CampusMap />} />
        <Route path="/building/:id" element={<BuildingDetail />} />
        <Route path="/profile" element={<Profile />} />
      </Route>
    </Routes>
  )
}

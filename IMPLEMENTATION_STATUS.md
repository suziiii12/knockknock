# FocusBet — Implementation Status

_Last updated: 2026-04-04 (session 3)_

---

## 1. Project Overview

**App name:** FocusBet
**Purpose:** An AI-powered study-session staking platform. Students "bet" focus time on study sessions, compete for territory ownership of campus buildings, and earn on-chain rewards. Focus is verified through AI signals (gaze tracking, tab monitoring, posture detection, AI check-ins).

**Tech Stack:**

| Layer | Technology |
|---|---|
| macOS Frontend | SwiftUI, AVFoundation, CoreLocation, MapKit |
| Web Frontend | React 19, React Router 7, Tailwind CSS 4, Lucide React, Vite |
| Backend | Python 3, FastAPI, SQLAlchemy ORM, SQLite, APScheduler |
| Authentication | World ID v4 (Worldcoin IDKit), JWT (HS256) |
| AI | Anthropic Claude Haiku (check-in evaluation) |
| Real-time | WebSocket (FastAPI native) |
| Future | World Chain (EVM), smart contract for payouts |

**Architecture Diagram:**

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│                                                                 │
│   ┌─────────────────────┐      ┌──────────────────────────┐    │
│   │   macOS SwiftUI App  │      │   React Web App (Vite)   │    │
│   │  - Camera (AVFound.) │      │  - Campus map            │    │
│   │  - GPS (CoreLocation)│      │  - Session UI            │    │
│   │  - MapKit            │      │  - Territory rankings    │    │
│   │  - Focus tracking    │      │  - React Router v7       │    │
│   └──────────┬──────────┘      └─────────────┬────────────┘    │
└──────────────┼───────────────────────────────┼─────────────────┘
               │ HTTP + WebSocket               │ HTTP + WebSocket
               ▼                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FASTAPI BACKEND                            │
│                                                                 │
│  POST /auth/verify-world-id   (World ID → JWT)                  │
│  POST /challenges             (create challenge)                │
│  GET  /challenges             (list open challenges)            │
│  POST /challenges/:id/join    (join + pot update)               │
│  POST /sessions/start         (start session)                   │
│  POST /sessions/:id/score     (score snapshot)                  │
│  POST /sessions/end           (end session, resolve challenge)  │
│  POST /checkin/evaluate       (Claude Haiku AI evaluation)      │
│  GET  /buildings/:id/leaderboard                                │
│  WS   /ws/challenge/:id       (real-time score broadcast)       │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  SQLite  (SQLAlchemy ORM)                                  │  │
│  │  Users · Buildings · Challenges · Participants            │  │
│  │  Sessions · Scores · Territory                            │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────┐
│              EXTERNAL SERVICES                                  │
│  World.org ID API v4  (proof verification)                      │
│  Anthropic Claude Haiku API  (check-in AI)                      │
│  World Chain EVM  (future: smart contract payouts)              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Current Implementation Status

### Backend (Python FastAPI)

#### `backend/main.py`
**What it does:** FastAPI app entry point. Configures CORS, mounts all routers, registers lifespan startup (DB init + APScheduler), and defines global exception handlers.

**Endpoints implemented:**
- `GET /health` — liveness check, returns `{"status": "ok"}`
- `POST /auth/verify-world-id` — receives World ID proof, calls `verify_world_id_proof()`, creates or retrieves user by nullifier hash, issues JWT. Returns `TokenResponse`.

**Status:** Complete. Dev-mode bypass in auth allows local testing without live World ID credentials.

---

#### `backend/auth.py`
**What it does:** JWT token creation/validation and World ID proof verification.

**Functions:**
- `verify_world_id_proof(proof: WorldIDProof)` — POSTs to `https://developer.worldcoin.org/api/v2/verify/{app_id}`. In dev mode (no `WORLD_ID_APP_ID` or value `"dev"`), skips real verification and returns a mock response.
- `create_access_token(data)` — Creates 24h HS256 JWT.
- `get_current_user(token, db)` — HTTPBearer dependency; decodes JWT, loads user from DB. Raises 401 on failure.

**Status:** Complete backend side. Dev bypass works. Missing: Swift frontend integration to call this endpoint.

---

#### `backend/models.py`
**What it does:** SQLAlchemy ORM definitions for all database tables.

**Models:**
- `User` — world_id_nullifier_hash (unique), jwt_token
- `Building` — name, location
- `Challenge` — title, duration_minutes, buy_in_amount, building_id, status (pending/active/ended), threshold_score, pot_total
- `Participant` — challenge_id, user_id, bet_amount, is_winner, payout_amount
- `Session` — challenge_id, user_id, started_at, ended_at, final_score
- `Score` — session_id, gaze_score, tab_score, checkin_score, composite_score (formula: 0.5·gaze + 0.3·tab + 0.2·checkin)
- `Territory` — building_id, user_id, total_score (upserted after each session end)

**Status:** Complete. All relations defined.

---

#### `backend/schemas.py`
**What it does:** Pydantic request/response models.

**Key schemas:**
- `WorldIDProof` — nullifier_hash, merkle_root, proof, verification_level, action, signal
- `TokenResponse` — access_token, token_type
- `ChallengeCreate` / `ChallengeOut`
- `SessionStart` / `SessionOut` / `SessionScoreUpdate`
- `ScoreOut`
- `CheckInEvaluate` / `CheckInResult`
- `BuildingLeaderboardEntry`

**Status:** Complete.

---

#### `backend/database.py`
**What it does:** SQLite database setup. Exports `engine`, `SessionLocal`, `Base`, and `get_db()` FastAPI dependency.

**Status:** Complete. DATABASE_URL is configurable via env var (defaults to SQLite).

---

#### `backend/responses.py`
**What it does:** `success(data)` helper that wraps all responses as `{"success": True, "data": data}`.

**Status:** Complete.

---

#### `backend/seed.py`
**What it does:** Idempotent seed script. Creates 3 buildings (WALC, Hicks Library, HAAS Hall), 3 demo users, 2 challenges with participants, and initial territory scores.

**Status:** Complete for development/demo purposes.

---

#### `backend/routers/challenges.py`
**What it does:** Challenge lifecycle management.

**Endpoints:**
- `POST /challenges` — Create challenge (requires auth). Creator auto-joins, pot = buy_in_amount.
- `GET /challenges` — List all non-ended challenges (public). Returns participant counts.
- `POST /challenges/{challenge_id}/join` — Join challenge (requires auth). Adds buy_in to pot. Auto-transitions `pending → active` when 2+ participants.

**Status:** Complete.

---

#### `backend/routers/sessions.py`
**What it does:** Session lifecycle, real-time WebSocket, and challenge resolution logic.

**Endpoints:**
- `WS /ws/challenge/{challenge_id}` — Real-time score/leaderboard/check-in updates. Tracks subscribers per challenge.
- `POST /sessions/start` — Start session (requires auth). Returns existing active session if one exists. Schedules 2–3 random check-in triggers (APScheduler) in middle 70% of session window.
- `POST /sessions/{session_id}/score` — Record score snapshot. Broadcasts to WebSocket subscribers. Calculates composite.
- `POST /sessions/end` — End session. Averages all Score records → final_score. Marks winner if final_score ≥ threshold. Upserts Territory points. Broadcasts top-5 leaderboard. If all participants finished → resolves challenge (15% commission, winners split pot, refund if no winners).

**Status:** Complete, including APScheduler check-in triggers and payout logic.

---

#### `backend/routers/checkin.py`
**What it does:** AI-powered focus check-in evaluation.

**Endpoints:**
- `POST /checkin/evaluate` — Passes student prompt + answer to Claude Haiku. Returns `passed` (bool), `feedback` (≤80 chars), `score_delta` (+20 or −20). Graceful fallback on API error.

**Status:** Complete. Requires `ANTHROPIC_API_KEY` in `.env`.

---

#### `backend/routers/buildings.py`
**What it does:** Building territory leaderboard.

**Endpoints:**
- `GET /buildings/{building_id}/leaderboard` — Returns top Territory entries for a building, ranked by total_score descending.

**Status:** Complete.

---

#### `backend/.env` / `backend/.env.example`
**Contains:**
```
WORLD_ID_APP_ID=<app_id_from_developer.worldcoin.org>
WORLD_ID_ACTION=<action_identifier>
ANTHROPIC_API_KEY=<sk-ant-...>
DATABASE_URL=sqlite:///./focusbet.db
SECRET_KEY=<random_secret_for_jwt>
```

**Status:** `.env.example` is present. A `.env` file exists but its actual contents need to be verified before deployment. Dev mode bypasses World ID if `WORLD_ID_APP_ID` is unset or `"dev"`.

---

### Frontend — Swift (macOS)

#### `focusbet.entitlements`
- App sandbox entitlements: camera, location, outbound network (`network.client`), inbound network (`network.server`), `com.apple.nsurlsessiond` and `com.apple.accessibility.api` mach-lookup exceptions.
- **Status:** Complete for current feature set. Screen Recording entitlement handled at runtime via `CGRequestScreenCaptureAccess()`; formal entitlement key not required for sandboxed apps using the permission dialog.

#### `focusbetApp.swift`
- Entry point. Single window, min 900×600, default 1200×800, dark theme, no title bar. Instantiates `AuthViewModel` as `@State` and injects it as `@Environment`. Calls `authViewModel.restoreAuthState()` on launch to restore Keychain JWT.
- **Status:** Complete.

#### `ContentView.swift`
- Navigation root using `NavigationStack` + `Route` enum.
- Routes: home, start, session(duration, buildingId), result(focusScore, buildingId, duration), map, building(id), history, profile.
- Tab bar: Focus, History, Map, Profile.
- **Status:** Complete navigation shell. All routes wired.

#### `Models/Building.swift`
- `Building`, `BuildingFloorPlan` (polygon point-in-polygon hit testing), `BuildingPosition`.
- **Status:** Complete.

#### `Models/Session.swift`
- `StudySession` with all score components.
- **Status:** Complete.

#### `Models/User.swift`
- `User` with stats, king buildings, color.
- **Status:** Complete.

#### `Models/FocusScore.swift`
- `FocusScoreData` with 6 signals + computed overall. `buildingScore()` weighted formula (focus 50%, time 30%, consistency 20%).
- **Status:** Complete.

#### `Models/TerritoryData.swift`
- `TerritoryEntry`, `ActivityFeedItem`.
- **Status:** Complete.

#### `Services/APIService.swift`
- Swift `actor` with `baseURL = "http://127.0.0.1:8000"`. Generic `fetch<T: Decodable>` helper unwraps the `{"success": true, "data": ...}` backend envelope, attaches `Authorization: Bearer` header, and posts `Notification.Name.authTokenExpired` on 401.
- Implemented endpoints: `fetchBuildings()` (MockData — no visual building data in backend), `fetchTerritory(buildingId)` → `GET /buildings/{id}/leaderboard`, `fetchUserProfile()` → `GET /users/me`, `startSession(challengeId)` → `POST /sessions/start`, `postScore(sessionId, ...)` → `POST /sessions/{id}/score`, `endSession()` → `POST /sessions/end`, `evaluateCheckIn(...)` → `POST /checkin/evaluate`, `connectWebSocket(challengeId)` → native `URLSessionWebSocketTask`.
- Building slug→int mapping hardcoded: `walc→1, hicks→2, haas→3`.
- **Status:** Complete. All mock data replaced with real HTTP calls.

#### `Services/CameraService.swift`
- AVCaptureSession setup for front camera.
- `configure()`, `start()`, `stop()`.
- **Status:** Complete (hardware setup). Vision framework analysis not yet integrated.

#### `Services/LocationService.swift`
- `@Observable NSObject` with `CLLocationManagerDelegate`. Runs two detection strategies in parallel: `CLCircularRegion` geofencing (50 m radius per building, identified by `com.focusbet.building.<slug>`) + continuous GPS fallback via `findNearestBuilding()`. `didEnterRegion/didExitRegion` update `detectedBuilding`. Falls back to WALC on permission denial or location error.
- **Status:** Complete. Real geofencing active for all buildings in `MockData.buildings`.

#### `Services/FocusTrackingService.swift`
- `@Observable` service. Simulates gaze/posture/blink/keyMouse on a 2-second loop (Vision framework signals deferred to AI team). Preserves `tabs` (driven by `ScreenCaptureService.updateTabScore(_:)`) and `checkIn` (driven by check-in events) across simulation ticks.
- **Status:** Partial. Simulation loop complete. Vision integration intentionally deferred — AI team owns `VNDetectFaceLandmarksRequest` / `VNDetectHumanBodyPoseRequest`.

#### `Services/ScreenCaptureService.swift`
- `@Observable final class`. Polls `NSWorkspace.shared.frontmostApplication` every 5 seconds. Classifies active app: study apps (Xcode, VSCode, Safari, Notes, Terminal, etc.) → 100, distraction apps (YouTube, TikTok, Discord, etc.) → 0, neutral → 40. Calls `focusTrackingService.updateTabScore(_:)` on each tick. Exposes `activeAppName` (String) for SnapshotService.
- **Status:** Complete. NSWorkspace-based monitoring active.

#### `Services/MockDataService.swift`
- Mock data provider.
- **Status:** Used in development; needs to be replaced by real API calls.

#### `ViewModels/SessionViewModel.swift`
- `@Observable @MainActor` class. `startSession(duration:buildingId:focusTracking:screenCapture:)` — calls `PermissionService.shared.requestAllPermissions()`, starts `ScreenCaptureService.startMonitoring(focusTrackingService:)`, and if `challengeId` is set, hits `POST /sessions/start` to get a backend session ID. `endSession()` stops monitoring and calls `POST /sessions/end`. Score posted every 30 seconds via background Task. `updateCompositeScore(from:)` applies formula: `0.5 * gaze + 0.3 * tab + 0.2 * checkIn`.
- **Status:** Complete. API calls, permission gating, and score posting all wired.

#### `ViewModels/BuildingViewModel.swift`
- `load()` calls `APIService.shared.fetchTerritory(buildingId:)` → `GET /buildings/{id}/leaderboard`. Falls back to MockData on any error.
- **Status:** Complete.

#### `ViewModels/HistoryViewModel.swift`
- Sessions from `MockData.sessionHistory`.
- **Status:** Incomplete. Needs real API call for session history.

#### `ViewModels/CameraViewModel.swift`
- Wraps CameraService.
- **Status:** Complete.

#### `ViewModels/MapViewModel.swift`
- `buildings` pre-populated from MockData; `load()` is a no-op stub (building visual data lives in Swift, not backend).
- **Status:** Complete for current needs.

#### `ViewModels/ProfileViewModel.swift`
- `load()` calls `APIService.shared.fetchUserProfile()` → `GET /users/me`. Merges backend stats with UserDefaults name/initials. Falls back to MockData on error.
- **Status:** Complete.

#### `Views/Auth/WelcomeView.swift`
- Landing/splash screen: app logo, "Sign in with World ID" button (calls `onSignIn` callback), "Admin Access" button (opens `AdminLoginView` as sheet).
- **Status:** Complete.

#### `Views/Auth/WorldIDView.swift`
- Uses `@Environment(AuthViewModel.self)`. `.task { await auth.triggerWorldIDFlow() }` auto-starts verification on appear. Three UI states: loading spinner, success checkmark (navigates home), error/idle retry button. `.onChange(of: auth.isAuthenticated)` syncs to `@AppStorage("isLoggedIn")`.
- **Status:** Complete. Wired to real `AuthViewModel` + `WorldIDService` flow.

#### `Views/Auth/ProfileSetupView.swift`
- One-time profile setup form shown after World ID verification. Fields: name, school, major, year (chip selector), expected graduation (horizontal scroll chips), gender. Saves to `UserDefaults`. Sets `@AppStorage("isProfileComplete") = true` on submit.
- **Status:** Complete. Data stored locally in UserDefaults only — not synced to backend.

#### `Views/Admin/AdminLoginView.swift`
- Modal sheet with a `SecureField` for an admin code. Hardcoded code `"hello"` sets `@AppStorage("isAdmin") = true`. Shake animation on wrong entry.
- **Status:** Complete (demo only). Hardcoded password must be replaced with real admin auth before production.

#### `Views/Admin/AdminDashboardView.swift`
- Full admin dashboard using Swift Charts framework. Two tabs:
  - **Facilities**: 4 metric cards (active users, sessions today, avg duration, campus utilization), building usage horizontal bar chart (top 10), peak hours heatmap grid (8 buildings × 18 hours), daily trend line+area chart.
  - **Students**: 3 metric cards, focus score by major bar chart, study hours by year bar chart, preferred buildings by major table, gender distribution donut chart.
- All data is local mock (`AdminData` enum in file). Logout button clears `isAdmin`.
- **Status:** Complete UI with mock data. Not connected to any real backend export API.

#### `Views/Profile/EditProfileView.swift`
- Edit profile sheet. Same fields as `ProfileSetupView`. Reads initial values from `UserDefaults`, saves changes on "Save Changes". Cancel dismisses without saving.
- **Status:** Complete. Local UserDefaults only — no backend sync.

#### `Views/Home/HomeView.swift`
- Hero section, feature cards, live stats.
- **Status:** Complete (UI only, stats are static).

#### `Views/StartSession/StartSessionView.swift`
- Building detection (hardcoded), duration picker, start button.
- **Status:** Partially complete. GPS detection not wired.

#### `Views/Session/SessionView.swift`
- Camera preview, gaze dots, focus gauge, signal bars, check-in modal.
- **Status:** Partially complete. Simulated scores; no real score posting to backend.

#### `Views/Session/CheckInModalView.swift`
- Random question from local pool, 4 buttons.
- **Status:** Incomplete. Answers are dismissed locally; not posted to `/checkin/evaluate`.

#### `Views/Result/ResultView.swift`
- Final score display, pass/fail.
- **Status:** Partially complete. Score is passed from session, not from backend response.

#### `Views/Building/BuildingDetailView.swift`
- Hex grid + rankings.
- **Status:** Partially complete. Uses MockData for territory.

#### `Views/Building/HexGridView.swift`
- Canvas hex grid with owner coloring.
- **Status:** Complete (UI rendering).

#### `Views/Building/RankingListView.swift`
- Ranked list with hover interaction.
- **Status:** Complete (UI).

#### `Views/Map/CampusMapView.swift`
- MapKit, 14 building annotations, WALC "you are here".
- **Status:** Complete (UI). Tap navigation works.

#### `Views/History/HistoryView.swift`
- Session history list.
- **Status:** Partially complete. Data is mock.

#### `Views/Profile/ProfileView.swift`
- Stats, territory, king buildings.
- **Status:** Partially complete. Data is mock.

#### `Views/Components/` (NavigationBar, ScoreBadge, UserAvatar)
- **Status:** Complete.

#### `Utilities/Constants.swift`, `Utilities/Extensions.swift`
- Color palette, font constants, helper extensions.
- **Status:** Complete.

#### `Data/MockData.swift`
- Full mock dataset: 14 Purdue buildings with floor plans, 10 users, session history, territory entries, activity feed, weekly stats.
- **Status:** Complete for development. Must be replaced by live API data.

---

## 3. World ID Integration Status

### Backend (Complete)

| Component | Status | Notes |
|---|---|---|
| `auth.py` — `verify_world_id_proof()` | Complete | POSTs to World.org API v4 |
| `auth.py` — Dev bypass | Complete | Skips verification if `WORLD_ID_APP_ID` unset or `"dev"` |
| `POST /auth/verify-world-id` endpoint | Complete | Returns JWT on success |
| User creation by nullifier_hash | Complete | Idempotent — finds or creates |
| JWT issuance + 24h expiry | Complete | HS256, configurable secret |
| `WORLD_ID_APP_ID` env var | Needs config | Must be set for production |
| `WORLD_ID_ACTION` env var | Needs config | Action string from Worldcoin developer portal |

### Frontend Swift (Complete — Dev Stub Mode)

The full auth flow is wired end-to-end. Verification runs against the real backend using a dev stub proof (no live World App required in development).

**What's done:**
- `WelcomeView.swift` — landing screen with "Sign in with World ID" CTA and admin login access. Complete.
- `WorldIDView.swift` — auto-triggers `AuthViewModel.triggerWorldIDFlow()` on appear. Real spinner/checkmark/error states. No fake delay.
- `Services/WorldIDService.swift` — Generates dev stub proof (`test_<uuid>`), POSTs to `POST /auth/verify-world-id`, returns JWT. IDKit SDK integration point is documented inline with commented-out real implementation.
- `ViewModels/AuthViewModel.swift` — `@Observable @MainActor`. Keychain JWT storage (SecItem), JWT expiry check (base64url decode), auto-logout via `Notification.Name.authTokenExpired` observer, `restoreAuthState()` on launch.
- `focusbetApp.swift` — Injects `AuthViewModel` as `@Environment`, calls `restoreAuthState()` on app launch.
- `Services/APIService.swift` — All requests include `Authorization: Bearer <token>` header. Posts `authTokenExpired` notification on 401.
- `ProfileSetupView.swift` — post-auth profile form. Saves to UserDefaults. Complete.
- `AdminLoginView.swift` + `AdminDashboardView.swift` — full admin dashboard accessible via hardcoded code `"hello"`.

**Still required for production:**

1. **Add IDKit Swift SDK** — Add `com.worldcoin/idkit-swift` as a Swift Package dependency and replace the stub in `WorldIDService.generateProof()` with the real IDKit call (commented template already present in the file).
2. **`WORLD_ID_APP_ID` env var** — Must be set in `backend/.env` for production World ID verification.

### Required `.env` Variables

```env
# World ID (get from developer.worldcoin.org)
WORLD_ID_APP_ID=app_...         # Leave unset or "dev" for local testing
WORLD_ID_ACTION=focus_session   # Your action identifier

# Anthropic (get from console.anthropic.com)
ANTHROPIC_API_KEY=sk-ant-...

# Database
DATABASE_URL=sqlite:///./focusbet.db   # or postgres:// for prod

# JWT
SECRET_KEY=<long-random-string>        # openssl rand -hex 32
```

**Current state:** `.env.example` is committed. A `.env` file exists locally (gitignored). World ID and Anthropic keys need to be filled in for full functionality.

---

## 4. What Still Needs to Be Implemented

### Priority 1 — Swift World ID Integration ✅ Complete (Dev Stub)

- [x] Create `Services/WorldIDService.swift` — dev stub proof + real backend POST
- [x] Create `ViewModels/AuthViewModel.swift` — Keychain JWT storage, expiry check, auto-logout on 401
- [x] Update `Views/Auth/WorldIDView.swift` — real auth flow, three UI states
- [x] Update `focusbetApp.swift` — `AuthViewModel` environment injection + `restoreAuthState()` on launch
- [x] Store JWT in Keychain (`SecItem` APIs)
- [x] Add `Authorization: Bearer` header to all `APIService` requests
- [ ] Add IDKit Swift SDK via Swift Package Manager _(production only — dev stub works today)_

### Priority 2 — Wire APIService to Real Backend ✅ Complete

- [x] `fetchTerritory(buildingId)` → `GET /buildings/{id}/leaderboard`
- [x] `fetchUserProfile()` → `GET /users/me` (backend endpoint added in `backend/routers/users.py`)
- [x] `startSession(challengeId)` → `POST /sessions/start`
- [x] `postScore(sessionId, ...)` → `POST /sessions/{id}/score`
- [x] `endSession()` → `POST /sessions/end`
- [x] `evaluateCheckIn(...)` → `POST /checkin/evaluate`
- [x] WebSocket connection → `WS /ws/challenge/{challengeId}` via `URLSessionWebSocketTask`
- [x] All ViewModels (Building, Map, Profile, History) updated with async `load()` methods
- [x] ATS fix: `NSAllowsLocalNetworking: true` in `Info.plist` (resolves POSIX error 1 on loopback)

### Priority 3 — Real Focus Signal Tracking ✅ Mostly Complete

- [x] `LocationService`: `CLCircularRegion` geofencing — 50 m radius per building, `didEnterRegion/didExitRegion` callbacks, GPS fallback
- [x] `ScreenCaptureService`: `NSWorkspace` frontmost app polling every 5s — study/neutral/distraction classification → `tabScore` 0–100
- [x] `PermissionService`: New singleton — requests screen capture, camera, microphone; tracks all states; `requestAllPermissions()` called on session start
- [x] `SessionViewModel`: Composite score formula `0.5*gaze + 0.3*tab + 0.2*checkIn` wired; permission gating on session start
- [ ] `FocusTrackingService` Vision gaze/posture signals — **intentionally deferred to AI team** (`VNDetectFaceLandmarksRequest`, `VNDetectHumanBodyPoseRequest`)

### Priority 4 — Backend Missing Endpoint ✅ Complete

- [x] `GET /users/me` — Returns user profile with session count, total minutes, avg focus score, total territory score, and king building IDs. Implemented in `backend/routers/users.py`, mounted in `backend/main.py`.

### Priority 5 — World Chain Smart Contract (Building Capture On-Chain)

Goal: Record building captures permanently on World Chain Testnet (Sepolia).
Keep all existing Python payout logic untouched. This is additive only.

#### Step 1 — Write Smart Contract
- [ ] Create `/contracts/StudyWarTerritory.sol`:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract StudyWarTerritory {
    mapping(string => address) public owner;
    mapping(string => uint256) public capturedAt;
    mapping(string => string) public capturedBy; // nullifier_hash

    event BuildingCaptured(
        string buildingId,
        string nullifierHash,
        uint256 timestamp
    );

    function capture(string memory buildingId, string memory nullifierHash) public {
        owner[buildingId] = msg.sender;
        capturedAt[buildingId] = block.timestamp;
        capturedBy[buildingId] = nullifierHash;
        emit BuildingCaptured(buildingId, nullifierHash, block.timestamp);
    }

    function getCapture(string memory buildingId) public view 
        returns (address, uint256, string memory) {
        return (owner[buildingId], capturedAt[buildingId], capturedBy[buildingId]);
    }
}
```

#### Step 2 — Deploy to World Chain Testnet
- [ ] Install Foundry (`curl -L https://foundry.paradigm.xyz | bash`)
- [ ] Deploy to World Chain Sepolia:
  - RPC URL: `https://worldchain-sepolia.g.alchemy.com/public`
  - Chain ID: `4801`
- [ ] Save deployed contract address to `backend/.env` as `WORLD_CHAIN_CONTRACT_ADDRESS`
- [ ] Save deployer private key to `backend/.env` as `WORLD_CHAIN_PRIVATE_KEY`

#### Step 3 — Add World Chain service to backend
- [ ] Create `backend/worldchain.py`:
  - Function `record_capture(building_id, nullifier_hash)`
  - Uses `web3.py` to call `capture()` on the contract
  - Fire-and-forget (non-blocking, doesn't affect existing logic)
- [ ] Add `web3` to `requirements.txt`
- [ ] In `backend/.env.example`, add:
  - `WORLD_CHAIN_CONTRACT_ADDRESS=`
  - `WORLD_CHAIN_PRIVATE_KEY=`
  - `WORLD_CHAIN_RPC_URL=https://worldchain-sepolia.g.alchemy.com/public`

#### Step 4 — Hook into existing building capture endpoint
- [ ] Find where buildings get captured in the routers (likely `routers/buildings.py` or `routers/sessions.py`)
- [ ] After the existing DB write, call `record_capture()` from `worldchain.py`
- [ ] If World Chain call fails, log the error but DO NOT fail the main request
  (existing functionality must never break)

#### Step 5 — Verify on Worldscan
- [ ] Confirm transactions appear at: https://worldchain-sepolia.explorer.alchemy.com
- [ ] Add `WORLDSCAN_URL` to backend responses so the Swift app can show a link

### Priority 6 — Polish

- [ ] Real campus map (MapKit with actual Purdue coordinates) — currently hardcoded position data exists, MapKit is wired
- [ ] Challenge creation UI in Swift (currently no SwiftUI screen for `POST /challenges`)
- [ ] Push notifications for check-in triggers (currently WebSocket only)
- [ ] Session history from real API

### Priority 7 — Advanced Focus Signal Tracking & AI Pipeline

Goal: Replace all simulated signals with real macOS system data, streamed live to an AI model for focus scoring.

#### macOS Permission & Data Collection (Swift)
- [ ] **Screen Recording**: Use `ScreenCaptureKit` (macOS 12.3+) to capture screenshots every 5s during session
- [ ] **Camera**: Stream front camera frames via `AVFoundation` — already partially wired in `CameraService.swift`
- [ ] **Global Keyboard Monitoring**: Use `CGEventTap` with `kCGSessionEventTap` for keystroke frequency (not content). Requires Accessibility permission.
- [ ] **Mouse / Cursor Monitoring**: Track cursor position and click frequency via `CGEventTap`. Requires Accessibility permission.
- [ ] **Active App / Window Monitoring**: Use `NSWorkspace.shared.frontmostApplication` + `CGWindowListCopyWindowInfo` to detect active app and window title at interval
- [ ] **Browser Tab & URL Detection**: AppleScript or Accessibility API to read active tab URL from Safari/Chrome. Requires Accessibility permission.
- [ ] **IP Address & Network Interfaces**: Read active network interface and IP via `Network` framework (informational only, no content)
- [ ] **Microphone Audio Level**: Capture dB level (not content) via `AVAudioEngine` to detect ambient noise / speech

#### Permission Request Flow (Swift)
- [ ] On session start, request all required macOS permissions in sequence:
  - Screen Recording (`CGRequestScreenCaptureAccess()`)
  - Accessibility (`AXIsProcessTrustedWithOptions`)
  - Camera + Microphone (`AVCaptureDevice.requestAccess`)
  - Location (`CLLocationManager.requestWhenInUseAuthorization`)
- [ ] Show a pre-permission explanation screen before requesting
- [ ] Store granted/denied state per permission; degrade gracefully if denied

#### Real-time AI Scoring Pipeline
- [ ] Every 5 seconds during a session, bundle all signals into a snapshot payload:
```json
{
  "screenshot_base64": "...",
  "camera_frame_base64": "...",
  "active_app": "Xcode",
  "active_window_title": "SessionView.swift",
  "browser_tab_url": "https://docs.swift.org/...",
  "cursor_position": {"x": 320, "y": 480},
  "keystroke_count_last_5s": 42,
  "click_count_last_5s": 3,
  "audio_level_db": -24.5,
  "ip_address": "192.168.1.5",
  "network_interface": "en0",
  "timestamp": "2026-04-04T11:40:00Z"
}
```
- [ ] POST snapshot to new endpoint `POST /sessions/{id}/snapshot`
- [ ] Backend: New endpoint `POST /sessions/{id}/snapshot`:
  - Accepts snapshot payload
  - Sends to Claude Sonnet with system prompt asking for focus score 0–100
  - Returns `{"focus_score": 85, "signals": {"on_task": true, "distracted_app": false, "notes": "..."}}`
  - Stores result in new `Snapshot` DB model
  - Broadcasts updated score via existing WebSocket
- [ ] Add `Snapshot` model to `backend/models.py`: `session_id`, `timestamp`, `raw_payload` (JSON), `ai_focus_score`, `ai_signals` (JSON)
- [ ] Add `SnapshotCreate` / `SnapshotOut` schemas to `backend/schemas.py`
- [ ] Create `Services/SnapshotService.swift` — bundles all signals and POSTs every 5s
- [ ] Create `Services/PermissionService.swift` — requests and tracks all macOS permissions

### Priority 8 — B2B Data Platform & Dashboards

Goal: Expose collected focus data as a B2B product via two web dashboards.

#### 8a — Raw Data Export API (Backend)
- [ ] Create `backend/routers/data_export.py`:
  - `GET /export/raw?session_id=&building_id=&from=&to=` — Export raw snapshots as JSON or CSV. Requires admin JWT.
  - `GET /export/stats?building_id=&from=&to=` — Aggregated stats per building, per user cohort, per time window. Requires admin JWT.
  - Stats categories: focus score distribution (mean, median, p90), active app breakdown (% study vs distracted), peak focus hours, session length distribution, building occupancy over time
- [ ] Add `is_admin` and `school_id` fields to `User` model
- [ ] Add `School` model: `id`, `name`, `admin_token`
- [ ] Add `AuditLog` model: `user_id`, `action`, `resource`, `timestamp` — logs every export

#### 8b — Admin Dashboard (React Web, route: `/admin`)
- [ ] Admin login page — username + password → admin JWT
- [ ] **Overview page**: total users, sessions today, active sessions live, revenue (pot totals)
- [ ] **Users page**: table of all users — nullifier hash, session count, avg focus score, last seen
- [ ] **Sessions page**: live + historical sessions, per-session snapshot timeline
- [ ] **Buildings page**: per-building stats — occupancy, top users, avg focus score
- [ ] **Data Export page**: date-range picker → download CSV of raw snapshots or aggregated stats
- [ ] Protect all `/admin/*` routes with admin JWT

#### 8c — School Dashboard (React Web, route: `/school/:schoolId`)
- [ ] School login via unique school admin token (issued by internal admin)
- [ ] All data scoped to `school_id` — school cannot see other schools' data
- [ ] **Overview page**: student engagement metrics, active users this week, avg focus score
- [ ] **Buildings page**: which campus buildings are most used, heat map by hour
- [ ] **Cohort Stats page**: focus score trends over time, peak study hours, app usage breakdown
- [ ] **Leaderboard page**: anonymized top students by focus score (nullifier hash only, no PII)
- [ ] **Data Export page**: export aggregated stats as CSV (NOT raw snapshots or camera frames)

#### 8d — Privacy Rules (enforced in backend)
- [ ] School dashboard NEVER exposes `screenshot_base64` or `camera_frame_base64`
- [ ] Only admin dashboard can access raw snapshot data
- [ ] All export endpoints write to `AuditLog`

---

## 5. File-by-File Summary Table

### Backend

| File | Purpose | Status |
|---|---|---|
| `backend/main.py` | FastAPI app, CORS, startup, auth endpoint | ✅ Done |
| `backend/auth.py` | World ID verification, JWT create/validate | ✅ Done |
| `backend/models.py` | SQLAlchemy ORM (User, Building, Challenge, Session, Score, Territory) | ✅ Done |
| `backend/schemas.py` | Pydantic request/response schemas | ✅ Done |
| `backend/database.py` | SQLite engine, session factory, get_db dependency | ✅ Done |
| `backend/responses.py` | `success()` response wrapper | ✅ Done |
| `backend/seed.py` | Demo data seeder (buildings, users, challenges) | ✅ Done |
| `backend/routers/challenges.py` | Challenge CRUD + join + pot logic | ✅ Done |
| `backend/routers/sessions.py` | Session lifecycle, score posting, WebSocket, challenge resolution | ✅ Done |
| `backend/routers/checkin.py` | Claude Haiku AI check-in evaluation | ✅ Done |
| `backend/routers/buildings.py` | Building territory leaderboard | ✅ Done |
| `backend/routers/users.py` | `GET /users/me` — user profile + stats + king buildings | ✅ Done |
| `backend/.env.example` | Environment variable template | ✅ Done |
| `backend/.env` | Local secrets (gitignored) | 🔧 Needs real keys |
| `backend/routers/data_export.py` | Raw + aggregated stats export API (admin + school) | ❌ Missing |
| `backend/worldchain.py` | World Chain contract caller (fire-and-forget) | ❌ Missing |
| `contracts/StudyWarTerritory.sol` | Solidity building capture contract | ❌ Missing |

### Swift Frontend

| File | Purpose | Status |
|---|---|---|
| `focusbetApp.swift` | App entry point, window config | ✅ Done |
| `ContentView.swift` | NavigationStack root, route enum, tab bar | ✅ Done |
| `Models/Building.swift` | Building data model, floor plan polygon | ✅ Done |
| `Models/Session.swift` | StudySession model with all score fields | ✅ Done |
| `Models/User.swift` | User model with stats and king buildings | ✅ Done |
| `Models/FocusScore.swift` | FocusScoreData, overall + buildingScore formulas | ✅ Done |
| `Models/TerritoryData.swift` | TerritoryEntry, ActivityFeedItem | ✅ Done |
| `Data/MockData.swift` | Full mock dataset (14 buildings, 10 users, sessions) | ✅ Done (dev only) |
| `Utilities/Constants.swift` | Colors, fonts, dimensions | ✅ Done |
| `Utilities/Extensions.swift` | Color(hex:), number formatting, date formatting | ✅ Done |
| `Services/CameraService.swift` | AVCaptureSession front camera setup | ✅ Done |
| `Services/APIService.swift` | HTTP actor — real URLSession calls, JWT auth, WebSocket | ✅ Done |
| `Services/WorldIDService.swift` | Dev stub ZK proof + `POST /auth/verify-world-id` | ✅ Done (IDKit SDK pending) |
| `Services/FocusTrackingService.swift` | Score simulation loop; `updateTabScore()` hook for ScreenCapture | 🔧 Partial (Vision = AI team) |
| `Services/LocationService.swift` | CLCircularRegion geofencing, 50 m per building, GPS fallback | ✅ Done |
| `Services/ScreenCaptureService.swift` | NSWorkspace app monitoring every 5 s; tabScore 0/40/100 | ✅ Done |
| `Services/PermissionService.swift` | Requests + tracks screen/camera/mic/location permissions | ✅ Done |
| `Services/MockDataService.swift` | Mock data helper | ✅ Done (dev only) |
| `ViewModels/AuthViewModel.swift` | Keychain JWT storage, expiry check, auto-logout on 401 | ✅ Done |
| `ViewModels/SessionViewModel.swift` | Session lifecycle, permission gating, composite score, API calls | ✅ Done |
| `ViewModels/BuildingViewModel.swift` | `load()` → `GET /buildings/{id}/leaderboard`, MockData fallback | ✅ Done |
| `ViewModels/HistoryViewModel.swift` | Session history — TODO `GET /sessions/history` | 🔧 Partial (MockData) |
| `ViewModels/CameraViewModel.swift` | Camera start/stop wrapper | ✅ Done |
| `ViewModels/MapViewModel.swift` | Buildings from MockData (visual data in Swift only) | ✅ Done |
| `ViewModels/ProfileViewModel.swift` | `load()` → `GET /users/me`, UserDefaults merge, MockData fallback | ✅ Done |
| `Views/Home/HomeView.swift` | Hero, feature cards, static stats | ✅ Done |
| `Views/StartSession/StartSessionView.swift` | Duration picker, building info, start button | 🔧 Partial (hardcoded building) |
| `Views/Session/SessionView.swift` | Camera preview, gauge, signal bars, check-in modal | 🔧 Partial (simulated scores) |
| `Views/Session/CameraPreview.swift` | NSViewRepresentable for AVCapture preview layer | ✅ Done |
| `Views/Session/FocusGaugeView.swift` | Circular animated focus gauge | ✅ Done |
| `Views/Session/SignalBarsView.swift` | 6 animated signal bar rows | ✅ Done |
| `Views/Session/CheckInModalView.swift` | AI check-in modal (local dismissal only) | 🔧 Partial (not posted to backend) |
| `Views/Result/ResultView.swift` | Final score, pass/fail, breakdown | 🔧 Partial (score from local state) |
| `Views/Building/BuildingDetailView.swift` | Hex grid + rankings split view | 🔧 Partial (MockData territory) |
| `Views/Building/HexGridView.swift` | Canvas hex grid with owner color rendering | ✅ Done |
| `Views/Building/RankingListView.swift` | Territory ranking list with hover | ✅ Done |
| `Views/Map/CampusMapView.swift` | MapKit campus map with 14 building markers | ✅ Done |
| `Views/History/HistoryView.swift` | Session history list with stats | 🔧 Partial (MockData sessions) |
| `Views/Profile/ProfileView.swift` | User profile, stats, king buildings | 🔧 Partial (MockData user) |
| `Views/Components/NavigationBar.swift` | Top nav bar with tabs, score badge, avatar | ✅ Done |
| `Views/Components/ScoreBadge.swift` | Score pill badge component | ✅ Done |
| `Views/Components/UserAvatar.swift` | Color avatar circle with optional crown | ✅ Done |
| `Views/Auth/WelcomeView.swift` | Landing screen with World ID sign-in + admin access buttons | ✅ Done |
| `Views/Auth/WorldIDView.swift` | World ID verification — real AuthViewModel flow, 3 UI states | ✅ Done |
| `Views/Auth/ProfileSetupView.swift` | One-time profile setup form (name, school, major, year, gender) | ✅ Done |
| `Views/Admin/AdminLoginView.swift` | Admin login modal (hardcoded code "hello") | 🔧 Partial |
| `Views/Admin/AdminDashboardView.swift` | Full admin dashboard with Swift Charts (mock data, 2 tabs) | 🔧 Partial (mock data only) |
| `Views/Profile/EditProfileView.swift` | Edit profile sheet reading/writing UserDefaults | ✅ Done |
| `focusbet.entitlements` | Camera, location, network, accessibility mach-lookup exceptions | ✅ Done |
| `Services/SnapshotService.swift` | Bundles all system signals every 5s and POSTs to backend | ❌ Missing |

### React Web Frontend

| File | Purpose | Status |
|---|---|---|
| `frontend/main.jsx` | React entry point | ✅ Done |
| `frontend/App.jsx` | React Router routes | ✅ Done |
| `frontend/components/Layout.jsx` | Header nav, outlet wrapper | ✅ Done |
| `frontend/index.css` | Tailwind directives + CSS variables | ✅ Done |
| `frontend/data/mock.js` | Territory + user mock data | ✅ Done (dev only) |
| `frontend/pages/Home.jsx` | Landing page | ✅ Done |
| `frontend/pages/StartSession.jsx` | Duration picker + start | 🔧 Partial |
| `frontend/pages/Session.jsx` | Timer, scores, check-in | 🔧 Partial |
| `frontend/pages/Result.jsx` | Final score display | 🔧 Partial |
| `frontend/pages/History.jsx` | Session history | 🔧 Partial |
| `frontend/pages/CampusMap.jsx` | Campus map view | 🔧 Partial |
| `frontend/pages/BuildingDetail.jsx` | Territory hex + rankings | 🔧 Partial |
| `frontend/pages/Profile.jsx` | User profile + stats | 🔧 Partial |
| `frontend/pages/Lobby.jsx` | Challenge lobby (empty file) | ❌ Missing |
| `frontend/pages/admin/AdminDashboard.jsx` | Internal ops overview | ❌ Missing |
| `frontend/pages/admin/AdminUsers.jsx` | User management table | ❌ Missing |
| `frontend/pages/admin/AdminSessions.jsx` | Live + historical session viewer | ❌ Missing |
| `frontend/pages/admin/AdminBuildings.jsx` | Per-building stats | ❌ Missing |
| `frontend/pages/admin/AdminExport.jsx` | CSV data export UI | ❌ Missing |
| `frontend/pages/school/SchoolDashboard.jsx` | School B2B overview | ❌ Missing |
| `frontend/pages/school/SchoolBuildings.jsx` | Building usage + hourly heat map | ❌ Missing |
| `frontend/pages/school/SchoolCohortStats.jsx` | Focus trends, app usage breakdown | ❌ Missing |
| `frontend/pages/school/SchoolLeaderboard.jsx` | Anonymized student leaderboard | ❌ Missing |
| `frontend/pages/school/SchoolExport.jsx` | Anonymized stats CSV export | ❌ Missing |

---

_Note: React web frontend has feature parity with Swift UI in terms of mock completeness but also lacks backend API wiring and World ID integration._

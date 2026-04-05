# FocusBet Backend API Endpoints

Last updated: 2026-04-04
Source of truth: backend/main.py and backend/routers/*.py

## 1) Basics

- Base URL (local): http://localhost:8000
- Response envelope (success):
  - {"success": true, "data": ...}
- Auth method:
  - Bearer JWT in Authorization header
  - Example: Authorization: Bearer <access_token>

## 2) Authentication

### GET /health
- Auth: No
- Description: Health check endpoint
- Response data example:
  - {"status": "ok"}

### GET /auth/create-session
- Auth: No
- Description: Returns rpContext data for World ID flow
- Response data fields:
  - app_id: string
  - rp_id: string
  - nonce: string
  - created_at: int (unix seconds)
  - expires_at: int (unix seconds)
  - signature: string

### POST /auth/verify-world-id
- Auth: No
- Description: Verifies World ID proof, creates user if missing, returns JWT
- Request body:
  - nullifier_hash: string
  - merkle_root: string
  - proof: string
  - verification_level: string
  - action: string | optional
  - signal: string | optional
- Response data:
  - access_token: string
  - token_type: "bearer"

## 3) Session APIs

All endpoints below require Authorization: Bearer <access_token>.

### POST /sessions/start
- Auth: Yes
- Description: Starts a solo session. If an active session exists, returns existing one.
- Request body:
  - duration: float (> 0, minutes)
  - building_id: int | optional
- Response data:
  - id: int
  - user_id: int
  - building_id: int | null
  - started_at: datetime string
  - ended_at: datetime string | null
  - duration: float
  - final_score: float | null

### POST /sessions/{session_id}/focus-level
- Auth: Yes
- Description: Records one focus sample for an active session.
- Path params:
  - session_id: int
- Request body:
  - level: float (0.0 to 1.0)
- Response data:
  - id: int
  - session_id: int
  - timestamp: datetime string
  - level: float

### POST /sessions/end
- Auth: Yes
- Description:
  - Ends current active session of the authenticated user
  - Calculates final_score from mean(level) * 100
  - Updates weekly_score, building_score, and territory
- Request body: none
- Response data:
  - id: int
  - user_id: int
  - building_id: int | null
  - started_at: datetime string
  - ended_at: datetime string
  - duration: float
  - final_score: float

## 4) Check-in API

### POST /checkin/evaluate
- Auth: Yes
- Description:
  - Calls Anthropic model to evaluate prompt/answer
  - Returns pass/fail and score delta
  - Note: Current implementation does not persist this result as a DB row
- Request body:
  - session_id: int
  - prompt: string
  - answer: string
- Response data:
  - passed: bool
  - feedback: string
  - score_delta: float

## 5) Building API

### GET /buildings/{building_id}/leaderboard
- Auth: Yes
- Description: Returns ranking by total territory score for a building
- Path params:
  - building_id: int
- Response data (array):
  - rank: int
  - user_id: int
  - user_name: string | null
  - total_score: float

## 6) User APIs

All endpoints below require Authorization: Bearer <access_token>.

### GET /users/me
- Auth: Yes
- Description: Returns profile summary and stats for current user
- Response data:
  - id: int
  - nullifier_hash: string
  - session_count: int
  - total_minutes: float
  - avg_focus_score: float
  - total_score: float
  - weekly_score: float
  - king_building_ids: int[]
  - created_at: datetime string | null

### PATCH /users/me/profile
- Auth: Yes
- Description: Updates onboarding/profile fields
- Request body (all optional):
  - name: string
  - school: string
  - major: string
  - year: string
  - expected_graduation: string
  - gender: string
- Response data:
  - id: int
  - name: string | null
  - school: string | null
  - major: string | null
  - year: string | null
  - expected_graduation: string | null
  - gender: string | null

### GET /users/me/weekly-score
- Auth: Yes
- Description: Returns current month/week score for current user
- Response data:
  - month: int (YYYYMM)
  - week: int (1 to 5)
  - weekly_score: float

## 7) Notes and Error Cases

- 401 Unauthorized:
  - Missing or invalid bearer token
  - User not found for decoded token
- 404 Not Found:
  - Missing session/building/user for the given context
- 422 Validation error:
  - Request body shape/type mismatch

## 8) Deprecated/Unused Router

- routers/challenges.py currently contains only an empty router stub.
- There are no challenge endpoints active in current backend version.

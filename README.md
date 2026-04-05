# LockIn

LockIn is a macOS-native study app that verifies real concentration, not just timer uptime.

Students start a session, receive AI-derived focus signals, earn session scores, and compete for campus territory ownership by building.

## Inspiration

Study timer apps like Forest and Yeolpumta (YPT) track duration, but they do not verify whether someone was actually focused. We wanted to build a system that measures cognitive engagement and turns studying into a competitive, campus-scale game.

## What It Does

Core loop:

Open app -> Start session -> Track focus signals -> End session -> Compute score -> Update territory -> Refresh rankings

Key features:

- AI focus verification from webcam, interaction behavior, and session context
- Session score based on quality + duration (not just elapsed time)
- Campus territory competition with building-level leaderboards
- Building king system with periodic reset
- World ID-based user verification and JWT-authenticated backend APIs
- Admin analytics dashboard for anonymized trend insight

## System Overview

### Frontend (macOS)

- SwiftUI desktop app
- Session UX, authentication flow, profile management, map/territory views
- Camera and permission handling with AVFoundation + CoreLocation + AppKit utilities

### Backend

- FastAPI REST API with modular routers
- SQLAlchemy ORM models and JWT auth pipeline
- SQLite default local DB with cloud migration path

### AI Engine

- Python inference service and training pipeline
- MediaPipe landmark extraction + behavioral signal fusion
- PyTorch EngagementLSTM scoring model

## Architecture

1. User authenticates (World ID flow + backend verification)
2. Frontend starts a study session via backend API
3. Focus signals are collected during the session
4. Backend finalizes session and updates weekly score + territory
5. Frontend fetches updated leaderboard/territory/admin metrics

## Repository Structure

- backend: FastAPI API server, DB models, routers, auth, seed scripts
- frontend/focusbet: macOS SwiftUI app
- EngagementScoreAI: AI model code, inference pipeline, API wrapper, training utilities

## How We Built It

- Frontend: Swift, SwiftUI, MapKit
- Backend: Python, FastAPI, SQLAlchemy, Uvicorn, Pydantic
- AI/ML: PyTorch, LSTM, MediaPipe
- Auth: World ID (IDKit-compatible flow)
- Data: OpenStreetMap Overpass API
- Database: SQLite (local default), PostgreSQL-ready deployment path

## Built With

Languages:

- Python
- Swift
- JavaScript
- SQL

Frameworks and libraries:

- FastAPI
- SQLAlchemy
- Uvicorn
- Pydantic
- SwiftUI
- AVFoundation
- CoreLocation
- MapKit
- AppKit
- PyTorch
- MediaPipe

Platforms and services:

- macOS app
- World ID
- OpenStreetMap Overpass API

Current notes on listed technologies:

- LSTM: implemented and used in EngagementLSTM model pipeline
- TRIBEv2: represented in scoring design and integration stubs/placeholders
- ScreenCaptureKit: planned/integration-notes present, direct runtime integration is pending in current app code

## Challenges We Ran Into

- Map SDK tradeoffs on macOS and migration to Apple MapKit
- App Sandbox networking constraints and entitlement configuration
- Concurrency/race conditions around start/end session API calls
- Merging frontend and backend changes while preserving API contracts
- Integrating World ID flow cleanly into desktop UX

## Accomplishments We Are Proud Of

- Real-time territory gameplay tied to study quality
- End-to-end session scoring pipeline across app, backend, and AI module
- Practical auth flow with bot-resistant identity checks
- Admin-facing metrics dashboard for institutional usage
- Clean modular split across app, API, and AI subsystems

## What We Learned

- Focus measurement is a multimodal problem, not a single metric
- Desktop app sandbox rules heavily influence architecture decisions
- Gamification significantly improves sustained engagement
- Reliability and explainability matter as much as model accuracy

## What Is Next

- Full production deployment with shared cloud database
- Complete ScreenCaptureKit production integration
- Expanded challenge and team competition modes
- iOS companion app
- Pilot rollout with university partners

## Quick Start

Backend:

1. Go to backend directory
2. Install dependencies
3. Run server with uvicorn

Frontend:

1. Open Xcode project in frontend
2. Build and run focusbet target

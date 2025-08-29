# RunBeat Backend Migration Plan - Supabase + Custom Backend

## Overview
Migrate RunBeat to a **hybrid backend architecture** combining a custom Node.js backend for Spotify token management with Supabase for all data storage, real-time features, and authentication. This approach provides maximum reliability for token refresh while leveraging Supabase's superior real-time performance and relational data structure for fitness apps.

## Migration Objectives
- **Primary**: Eliminate Spotify token refresh failures during training sessions (Custom Backend)
- **Secondary**: Improve VO2 Max timer reliability with real-time state management (Supabase)
- **Tertiary**: Reduce iOS app complexity by ~500 lines of code
- **Quaternary**: Enable future fitness analytics with relational data structure

## Hybrid Architecture Overview
```
iOS App
├── Spotify Token Calls → Custom Backend (Railway/Node.js)
├── Settings Sync → Supabase (PostgreSQL + Real-time)
├── Real-time Workout State → Supabase (PostgreSQL + WebSockets)
└── User Authentication → Supabase Auth
```

## Timeline: 1 Week (5-6 days)

### Days 1-2: Custom Backend for Spotify Token Management
**Setup Python Backend (Railway)**
- [ ] Create Railway account and deploy basic FastAPI app
- [ ] Set up Python + FastAPI project structure with requirements.txt
- [ ] Configure environment variables (Spotify Client ID/Secret)
- [ ] Implement Spotify OAuth token refresh with spotipy library
- [ ] Set up APScheduler for proactive token refresh (every 50 minutes)
- [ ] Deploy to Railway and test token refresh API

**Key Endpoints:**
```python
# FastAPI with automatic OpenAPI docs
POST /api/spotify/refresh-token
GET /api/spotify/token/{user_id}
POST /api/users/{user_id}/tokens  # Store initial tokens
```

### Days 3-4: Supabase Setup & Real-Time Integration
**Supabase Project Setup**
- [ ] Create Supabase project and configure authentication
- [ ] Design PostgreSQL schema for workout sessions and user settings
- [ ] Set up Row Level Security (RLS) policies
- [ ] Configure real-time subscriptions for workout state
- [ ] Add Supabase iOS SDK to project
- [ ] Implement real-time workout session management

**Real-Time Features Implementation**
- [ ] Create workout session listeners with PostgreSQL real-time
- [ ] Implement settings sync with immediate cross-device updates
- [ ] Test VO2 interval transitions via Supabase real-time
- [ ] Test network interruption/recovery scenarios

### Day 5: iOS Integration & Firebase Removal
**Remove Firebase & Integrate Supabase**
- [ ] Remove Firebase SDK dependencies from iOS project
- [ ] Replace Firebase auth with Supabase authentication
- [ ] Replace SpotifyService token refresh with custom backend calls
- [ ] Integrate Supabase real-time workout management
- [ ] Remove client-side token refresh logic (~200 lines)
- [ ] Remove complex timer logic, replace with Supabase real-time listeners (~300 lines)

**End-to-End Testing**
- [ ] Test 2+ hour training session with backend token refresh
- [ ] Test real-time interval transitions via Supabase
- [ ] Test settings sync across devices
- [ ] Test offline/online network scenarios

## Backend Architecture

### Custom Python Backend (Railway)
**Purpose**: Reliable Spotify token management
**Technology**: Python + FastAPI
**Hosting**: Railway (always-warm, no cold starts)

```python
# Backend Structure
app/
├── routers/
│   ├── spotify.py        # Token refresh endpoints
│   └── users.py          # User token storage
├── services/
│   ├── spotify_auth.py   # Spotify API integration with spotipy
│   └── scheduler.py      # APScheduler for proactive token refresh
├── middleware/
│   └── auth.py          # Supabase token validation
├── models/
│   ├── tokens.py        # Pydantic models for type safety
│   └── users.py         # User data models
└── database/
    └── supabase.py      # Supabase admin connection
```

**Key Features:**
- **spotipy library**: Mature Spotify OAuth handling with proven edge case coverage
- **APScheduler**: Proactive token refresh every 50 minutes
- **Pydantic validation**: Type-safe data models prevent bad data from reaching iOS
- **Always-warm server**: Zero cold start latency on Railway
- **Batch processing**: Refresh tokens for multiple users efficiently
- **Robust error handling**: Python's mature OAuth ecosystem handles token edge cases

### Supabase Integration
**Purpose**: Real-time workout data, settings sync, and user authentication
**Technology**: PostgreSQL + Real-time subscriptions + Row Level Security

#### PostgreSQL Schema
```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_active_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Heart rate settings
  resting_hr INTEGER DEFAULT 60,
  max_hr INTEGER DEFAULT 190,
  use_auto_zones BOOLEAN DEFAULT true,
  zone1_lower INTEGER DEFAULT 60,
  zone1_upper INTEGER DEFAULT 70,
  zone2_upper INTEGER DEFAULT 80,
  zone3_upper INTEGER DEFAULT 90,
  zone4_upper INTEGER DEFAULT 100,
  zone5_upper INTEGER DEFAULT 110,
  
  settings_updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Active workout sessions
CREATE TABLE active_workouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  session_type TEXT NOT NULL CHECK (session_type IN ('vo2max', 'free')),
  started_at TIMESTAMPTZ DEFAULT NOW(),
  current_interval INTEGER DEFAULT 1,
  current_phase TEXT CHECK (current_phase IN ('high', 'rest')),
  time_remaining INTEGER DEFAULT 0,
  
  -- Real-time heart rate data
  current_heart_rate INTEGER,
  current_zone INTEGER,
  hr_updated_at TIMESTAMPTZ,
  
  -- Ensure only one active workout per user
  UNIQUE(user_id)
);

-- Enable real-time subscriptions
ALTER PUBLICATION supabase_realtime ADD TABLE users;
ALTER PUBLICATION supabase_realtime ADD TABLE active_workouts;
```

**Note**: Spotify tokens stored in custom backend database (PostgreSQL), not Supabase

## Firebase Removal Steps

### 1. Remove Firebase Dependencies from Xcode Project
**In Xcode Package Manager:**
- [ ] Remove `firebase-ios-sdk` package dependency
- [ ] Remove these product dependencies:
  - `FirebaseAnalytics`
  - `FirebaseAuth` 
  - `FirebaseFirestore`
  - `FirebaseFunctions`
  - `FirebaseMessaging`

### 2. Clean Up Firebase Files
- [ ] Delete `GoogleService-Info.plist` from project
- [ ] Delete `RunBeat/Core/Services/FirebaseService.swift`
- [ ] Remove Firebase imports from `RunBeatApp.swift`

### 3. Remove Firebase Code from RunBeatApp.swift
```swift
// REMOVE these imports:
import Firebase
import FirebaseAuth
import FirebaseFirestore  
import FirebaseFunctions

// REMOVE Firebase configuration from init():
FirebaseApp.configure()
configureFirebaseAuth()
```

### 4. Clean Up Project Files
- [ ] Remove any Firebase-related environment variables
- [ ] Delete unused Firebase configuration files
- [ ] Clean build folder in Xcode

## iOS App Changes

### Files to Modify
- `SpotifyService.swift` - Replace token refresh with custom backend HTTP calls
- `VO2MaxTrainingManager.swift` - Replace timer logic with Supabase real-time listeners
- `AppState.swift` - Integrate Supabase workout state management  
- `HeartRateViewModel.swift` - Add Supabase settings sync

### New Dependencies
```swift
// Add Supabase iOS SDK
.package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")

// Target dependencies:
"Supabase"
```

### Key Integration Points
1. **Authentication**: Replace Firebase Auth with Supabase Auth (anonymous users)
2. **Token Management**: Replace `refreshAccessToken()` with HTTP calls to custom backend
3. **Workout Sessions**: Replace local timer with Supabase real-time listeners
4. **Settings Sync**: Bidirectional sync with PostgreSQL + real-time updates
5. **Real-time Updates**: PostgreSQL triggers + WebSocket subscriptions

### Supabase Integration Examples
```swift
import Supabase

class SupabaseService {
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://your-project.supabase.co")!,
        supabaseKey: "your-anon-key"
    )
    
    // Real-time workout state updates
    func subscribeToWorkoutUpdates(userId: String) {
        let channel = supabase.channel("workout-updates")
        
        channel
            .onPostgresChanges(
                AnyAction.self,
                schema: "public",
                table: "active_workouts",
                filter: PostgresChangeFilter(column: "user_id", value: userId)
            ) { change in
                // Handle real-time workout updates
                DispatchQueue.main.async {
                    self.updateWorkoutUI(change.new)
                }
            }
            .subscribe()
    }
    
    // Settings sync
    func syncSettings(_ settings: UserSettings) async {
        try? await supabase.database
            .from("users")
            .update([
                "resting_hr": settings.restingHR,
                "max_hr": settings.maxHR,
                "use_auto_zones": settings.useAutoZones,
                "settings_updated_at": "now()"
            ])
            .eq("id", value: userId)
            .execute()
    }
}

// Custom FastAPI backend integration
class BackendService {
    private let baseURL = "https://runbeat-backend.railway.app"
    
    func refreshSpotifyToken(userId: String) async -> String? {
        // HTTP call to FastAPI backend with automatic OpenAPI docs
        // Pydantic models ensure type-safe responses
    }
}

## Security Configuration

### Supabase Row Level Security (RLS)
```sql
-- Enable RLS on both tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE active_workouts ENABLE ROW LEVEL SECURITY;

-- Users can only access their own data
CREATE POLICY "Users can view own data" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own data" ON users  
  FOR UPDATE USING (auth.uid() = id);

-- Active workouts - users can only access their own
CREATE POLICY "Users can view own workouts" ON active_workouts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own workouts" ON active_workouts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own workouts" ON active_workouts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own workouts" ON active_workouts
  FOR DELETE USING (auth.uid() = user_id);
```

### Custom Backend Environment Variables
```bash
# Railway environment variables for FastAPI
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
DATABASE_URL=postgresql://user:pass@host:port/db
PORT=8000
ENVIRONMENT=production

# FastAPI-specific
RELOAD=false
LOG_LEVEL=info
```

## Testing Strategy

### Critical Test Scenarios
1. **Backend Token Refresh**: Start training, background app for 65+ minutes, verify custom backend refresh
2. **Real-time Interval Transitions**: VO2 training with Supabase real-time updates, verify smooth transitions
3. **Network Interruption**: Airplane mode during training, verify Supabase offline/online sync
4. **Multi-Device Settings Sync**: Change settings on iPhone, verify PostgreSQL + real-time sync
5. **Backend Reliability**: Test custom backend uptime and response times
6. **Hybrid Integration**: Verify backend + Supabase systems work together seamlessly
7. **PostgreSQL Performance**: Test real-time subscriptions under workout load

### Success Criteria
- [ ] 100% token refresh reliability via custom backend (no cold starts)
- [ ] < 500ms latency for real-time interval transitions via Supabase (faster than Firebase)
- [ ] Settings sync across devices within 1 second via PostgreSQL real-time
- [ ] Backend response time < 200ms for token refresh
- [ ] Supabase real-time subscriptions handle network interruptions gracefully
- [ ] No authentication failures during 3+ hour training sessions
- [ ] PostgreSQL queries execute <100ms for workout data

## Risk Mitigation

### Rollback Plan
- Keep existing code in feature flags
- Firebase calls wrapped in try/catch with fallbacks
- Can disable Firebase integration via remote config

### Monitoring
- Firebase Functions error logging
- Crashlytics for iOS crash reporting
- Custom analytics for workout completion rates
- FCM delivery success metrics

## Post-Migration Benefits

### Immediate
- Eliminate Spotify authentication interruptions during training
- Reliable background interval transitions
- Simplified iOS codebase (remove ~500 lines)

### Medium-term Enablement
- Cross-device workout state synchronization
- Real-time social features (workout sharing)
- Advanced workout analytics
- Coach/trainer features with real-time monitoring

## Cost Estimate
```
Hybrid Architecture (1000+ users):
Custom FastAPI Backend (Railway):
- Hobby Plan: $5/month (includes PostgreSQL)
- Pro Plan: $20/month (if scaling needed)
- Python ecosystem: mature spotipy + OAuth libraries

Supabase:
- Pro Plan: $25/month (includes 8GB database, 250GB bandwidth, real-time subscriptions)
- Includes: PostgreSQL, Auth, Real-time, APIs, Storage

Total: $30-45/month (vs $200/month Firebase at scale)
Cost Savings: 70-85% reduction vs Firebase

Benefits vs Firebase:
- Mature Python OAuth ecosystem (spotipy, authlib)
- Better real-time performance for workout apps
- Type safety with Pydantic models
- Relational data model (perfect for fitness analytics)
- No vendor lock-in (standard PostgreSQL)
- Predictable pricing (no surprise costs)
```

## Architecture Benefits

### Why Hybrid + Supabase Beats Firebase-Only:
1. **Reliability**: Custom FastAPI backend eliminates cold start issues for critical token refresh
2. **Mature OAuth**: Python's spotipy library handles Spotify token edge cases better than Node.js alternatives
3. **Type Safety**: Pydantic models prevent bad workout data from reaching iOS app
4. **Performance**: Supabase real-time is faster than Firebase for single-user workout updates  
5. **Cost**: 70-85% cost reduction at scale ($30-45 vs $200/month)
6. **Data Model**: PostgreSQL perfect for fitness analytics and relational workout data
7. **Flexibility**: Can integrate any service, not locked into Google ecosystem
8. **Future-Proof**: Standard PostgreSQL, easy to migrate if needed

### Why Hybrid Beats Custom-Only:
1. **Development Speed**: Supabase real-time features work out-of-the-box
2. **iOS Integration**: Native Supabase Swift SDK with excellent real-time support
3. **Offline Support**: Supabase handles offline/online sync automatically  
4. **Reduced Complexity**: Don't reinvent real-time infrastructure
5. **Built-in Auth**: Anonymous users and session management included

## Decision Points

### Go/No-Go Criteria (End of Day 2)
- [ ] FastAPI backend deployed to Railway and responding to HTTP requests
- [ ] Spotify token refresh working via spotipy library
- [ ] APScheduler job refreshing tokens every 50 minutes
- [ ] FastAPI backend response time < 200ms consistently
- [ ] Pydantic models validating all request/response data

### Go/No-Go Criteria (End of Day 4)
- [ ] Supabase real-time listeners working in iOS app
- [ ] Settings sync to/from Supabase PostgreSQL functional
- [ ] Real-time workout state updates during VO2 training
- [ ] iOS app can communicate with both FastAPI backend and Supabase

### Success Metrics (End of Day 5)
- [ ] Complete 2-hour VO2 training session with hybrid FastAPI + Supabase backend
- [ ] Zero token refresh failures via spotipy library
- [ ] Real-time interval transitions via Supabase < 1 second latency
- [ ] Settings sync across devices within 2 seconds
- [ ] Reduced iOS codebase by 500+ lines

## Next Steps After Migration
1. **Performance Optimization**: Implement offline caching for workout data
2. **Analytics Enhancement**: Add detailed workout completion tracking
3. **Social Features**: Real-time workout sharing and leaderboards
4. **AI Integration**: Personalized training recommendations based on workout data

---

## Summary

**Migration Start Date**: [To be determined]  
**Target Completion**: 5-6 days from start  
**Architecture**: Hybrid (Custom FastAPI Backend + Supabase)
**Primary Success Metric**: Zero Spotify token refresh failures during training sessions
**Secondary Success Metric**: Real-time workout features with <1 second latency

### Ready to Start?
1. 🔄 Supabase project to be created (replacing Firebase)
2. 🟡 FastAPI backend ready to deploy (Railway account needed)
3. 🟡 Backend-Supabase integration points identified
4. 🟡 iOS integration plan complete
5. 🔄 Firebase removal steps documented

**Next Action**: Remove Firebase dependencies and create Railway account for FastAPI backend deployment
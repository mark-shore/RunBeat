# RunBeat Hybrid Backend Migration Plan

## Overview
Migrate RunBeat to a **hybrid backend architecture** combining a custom Node.js backend for Spotify token management with Firebase for real-time workout features. This approach provides the reliability needed for critical token refresh while leveraging Firebase's strengths for real-time data.

## Migration Objectives
- **Primary**: Eliminate Spotify token refresh failures during training sessions (Custom Backend)
- **Secondary**: Improve VO2 Max timer reliability with real-time state management (Firebase)
- **Tertiary**: Reduce iOS app complexity by ~500 lines of code

## Hybrid Architecture Overview
```
iOS App
├── Spotify Token Calls → Custom Backend (Railway/Node.js)
├── Settings Sync → Firebase Firestore  
├── Real-time Workout State → Firebase Firestore
└── User Authentication → Firebase Auth
```

## Timeline: 1 Week (5-6 days)

### Days 1-2: Custom Backend for Spotify Token Management
**Setup Node.js Backend (Railway)**
- [ ] Create Railway account and deploy basic Node.js app
- [ ] Set up TypeScript + Express.js project structure
- [ ] Configure environment variables (Spotify Client ID/Secret)
- [ ] Implement Spotify OAuth token refresh endpoint
- [ ] Set up scheduled job for proactive token refresh (every 50 minutes)
- [ ] Deploy to Railway and test token refresh API

**Key Endpoints:**
```typescript
POST /api/spotify/refresh-token
GET /api/spotify/token/:userId
POST /api/users/:userId/tokens (store initial tokens)
```

### Days 3-4: Firebase Real-Time Integration
**Firebase Setup & Real-Time Features**
- [ ] ✅ Firebase project already created and configured
- [ ] Design Firestore schema for real-time workout sessions
- [ ] Implement iOS listeners for real-time workout state
- [ ] Create workout session start/stop/update methods
- [ ] Test real-time synchronization during VO2 training
- [ ] Implement settings sync to/from Firestore

### Day 5: iOS Integration & Testing
**Connect iOS App to Hybrid Backend**
- [ ] Replace SpotifyService token refresh with custom backend calls
- [ ] Integrate Firebase real-time workout management
- [ ] Remove client-side token refresh logic (~200 lines)
- [ ] Remove complex timer logic, replace with Firebase listeners (~300 lines)
- [ ] End-to-end testing: 2+ hour training session with token refresh
- [ ] Background testing: Verify interval transitions work via Firebase

## Backend Architecture

### Custom Node.js Backend (Railway)
**Purpose**: Reliable Spotify token management
**Technology**: Node.js + TypeScript + Express.js
**Hosting**: Railway (always-warm, no cold starts)

```typescript
// Backend Structure
src/
├── routes/
│   ├── spotify.ts        // Token refresh endpoints
│   └── users.ts          // User token storage
├── services/
│   ├── spotifyAuth.ts    // Spotify API integration
│   └── scheduler.ts      // Proactive token refresh
├── middleware/
│   └── auth.ts          // Firebase token validation
└── database/
    └── firebase.ts      // Firebase admin connection
```

**Key Features:**
- Proactive token refresh every 50 minutes (scheduled job)
- Always-warm server (zero cold start latency)
- Batch token refresh for multiple users
- Robust error handling and retries

### Firebase Integration
**Purpose**: Real-time workout data and settings sync
**Services**: Firestore + Authentication (no Functions needed)

#### Firestore Collections
```
users/{userId}
├── settings: {
│   ├── restingHR: number
│   ├── maxHR: number
│   ├── useAutoZones: boolean
│   └── zones: {...}
│   └── updatedAt: timestamp
└── activeWorkout?: {
    ├── sessionType: 'vo2max' | 'free'
    ├── startedAt: timestamp
    ├── currentInterval: number
    ├── currentPhase: 'high' | 'rest'
    ├── timeRemaining: number
    └── heartRate: {
        ├── current: number
        ├── zone: number
        └── lastUpdate: timestamp
    }
}
```

**Note**: Spotify tokens stored in custom backend database (PostgreSQL), not Firestore

## iOS App Changes

### Files to Modify
- `SpotifyService.swift` - Replace token refresh with custom backend HTTP calls
- `VO2MaxTrainingManager.swift` - Replace timer logic with Firebase real-time listeners
- `AppState.swift` - Integrate Firebase workout state management
- `HeartRateViewModel.swift` - Add Firebase settings sync

### New Dependencies
```swift
// Firebase SDK (already configured)
"FirebaseAuth",
"FirebaseFirestore"
// Note: Removed FirebaseFunctions (using custom backend instead)
```

### Key Integration Points
1. **Token Management**: Replace `refreshAccessToken()` with HTTP calls to custom backend
2. **Workout Sessions**: Replace local timer with Firestore real-time listeners  
3. **Settings Sync**: Bidirectional sync with Firestore on app launch/changes
4. **Real-time Updates**: No push notifications needed - Firebase handles real-time sync

### Custom Backend HTTP Integration
```swift
// New service for backend communication
class BackendService {
    private let baseURL = "https://runbeat-backend.railway.app"
    
    func refreshSpotifyToken(userId: String) async -> String? {
        // HTTP call to custom backend
    }
    
    func storeInitialTokens(userId: String, tokens: SpotifyTokens) async {
        // Store tokens in backend database
    }
}

## Security Configuration

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Custom Backend Environment Variables
```bash
# Railway environment variables
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
FIREBASE_SERVICE_ACCOUNT_KEY=your_firebase_admin_key
DATABASE_URL=postgresql://user:pass@host:port/db
PORT=3000
```

## Testing Strategy

### Critical Test Scenarios
1. **Backend Token Refresh**: Start training, background app for 65+ minutes, verify custom backend refresh
2. **Real-time Interval Transitions**: VO2 training with Firebase state updates, verify smooth transitions
3. **Network Interruption**: Airplane mode during training, verify Firebase offline/online sync
4. **Multi-Device Settings Sync**: Change settings on iPhone, verify Firestore sync
5. **Backend Reliability**: Test custom backend uptime and response times
6. **Hybrid Integration**: Verify both systems work together seamlessly

### Success Criteria
- [ ] 100% token refresh reliability via custom backend (no cold starts)
- [ ] < 1 second latency for real-time interval transitions via Firebase
- [ ] Settings sync across devices within 2 seconds via Firestore
- [ ] Backend response time < 200ms for token refresh
- [ ] Firebase real-time listeners handle network interruptions gracefully
- [ ] No authentication failures during 3+ hour training sessions

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
Custom Backend (Railway):
- Hobby Plan: $5/month (includes PostgreSQL)
- Pro Plan: $20/month (if scaling needed)

Firebase:
- Firestore: ~$10/month (settings + real-time workout data)
- Authentication: Free (anonymous users)
- No Functions needed

Total: $15-30/month (vs $80/month Firebase-only)
Cost Savings: 60-80% reduction
```

## Architecture Benefits

### Why Hybrid Beats Firebase-Only:
1. **Reliability**: Custom backend eliminates cold start issues for critical token refresh
2. **Cost**: 60-80% cost reduction at scale
3. **Performance**: Always-warm backend = instant token refresh
4. **Flexibility**: Can integrate any service, not locked into Google ecosystem
5. **Scalability**: Real-time features via Firebase, business logic via custom backend

### Why Hybrid Beats Custom-Only:
1. **Development Speed**: Firebase real-time features work out-of-the-box
2. **iOS Integration**: Native Firebase SDK vs custom WebSocket implementation
3. **Offline Support**: Firebase handles offline/online sync automatically
4. **Reduced Complexity**: Don't reinvent real-time infrastructure

## Decision Points

### Go/No-Go Criteria (End of Day 2)
- [ ] Custom backend deployed and responding to HTTP requests
- [ ] Spotify token refresh working via backend API
- [ ] Backend scheduled job refreshing tokens every 50 minutes
- [ ] Backend response time < 200ms consistently

### Go/No-Go Criteria (End of Day 4)
- [ ] Firebase real-time listeners working in iOS app
- [ ] Settings sync to/from Firestore functional
- [ ] Real-time workout state updates during VO2 training
- [ ] iOS app can communicate with both backend and Firebase

### Success Metrics (End of Day 5)
- [ ] Complete 2-hour VO2 training session with hybrid backend
- [ ] Zero token refresh failures via custom backend
- [ ] Real-time interval transitions via Firebase < 1 second latency
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
**Architecture**: Hybrid (Custom Backend + Firebase)
**Primary Success Metric**: Zero Spotify token refresh failures during training sessions
**Secondary Success Metric**: Real-time workout features with <1 second latency

### Ready to Start?
1. ✅ Firebase project created and iOS SDK configured
2. 🟡 Custom backend ready to deploy (Railway account needed)
3. 🟡 Backend-Firebase integration points identified
4. 🟡 iOS integration plan complete

**Next Action**: Create Railway account and deploy initial Node.js backend
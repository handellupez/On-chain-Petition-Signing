# Petition Analytics Enhancement

## Overview
This PR introduces a comprehensive **Petition Analytics** system to the existing On-chain Petition Signing contract. The new feature provides real-time analytics, user activity tracking, and performance metrics without requiring any cross-contract calls or external dependencies.

## Technical Implementation

### Key Functions and Data Structures Added

#### Analytics Data Maps
- **`user-analytics`** - Tracks individual user activity including petitions created, signed, and activity timestamps
- **`daily-stats`** - Aggregates daily platform statistics for trend analysis  
- **`petition-performance`** - Monitors individual petition metrics like time-to-first-signature

#### New Read-Only Functions
- `get-user-analytics(user)` - Returns comprehensive user activity statistics
- `get-daily-stats(day)` - Provides daily analytics for specific time periods
- `get-petition-performance(petition-id)` - Shows petition-specific performance metrics
- `get-platform-analytics()` - Platform-wide summary statistics
- `get-creator-leaderboard(creator)` - Creator performance metrics
- `get-signer-leaderboard(signer)` - Most active signers data

#### Enhanced Core Functions
- **Analytics Integration**: All petition creation and signing functions now automatically update analytics data
- **Real-time Tracking**: User activity and daily statistics are updated in real-time during contract interactions
- **Performance Monitoring**: Petition metrics are tracked from creation to completion

## Testing & Validation
- ✅ Contract passes npm tests (3/3 passing)
- ✅ All npm tests successful with vitest framework
- ✅ CI/CD pipeline configured with GitHub Actions
- ✅ Clarity v3 compliant with proper error handling
- ✅ Independent feature with no cross-contract dependencies

## Features Delivered

### 🔍 User Activity Analytics
- Track petition creation and signing activity per user
- Monitor first and last activity timestamps
- Generate user engagement metrics

### 📊 Daily Statistics Aggregation
- Daily petition creation counts
- Daily signature volume tracking
- Platform growth metrics over time

### ⚡ Real-time Performance Metrics  
- Time-to-first-signature tracking
- Petition completion rate monitoring
- Daily signature rate calculations

### 🏆 Leaderboard Functionality
- Most active petition creators
- Top petition signers
- Platform engagement rankings

### 🎛️ Admin Controls
- Toggle analytics collection on/off
- Platform-wide analytics summary
- Contract owner administrative functions

## Value Proposition
This analytics enhancement provides petition creators and platform users with valuable insights into engagement patterns, success rates, and community activity without compromising the decentralized nature of the system. All analytics are computed and stored on-chain, ensuring full transparency and immutability.

# AI Assistant Context for RunBeat

## What You're Working On
Audio-first iOS heart rate training app. Users start workout, put phone away, get audio cues.

## Current Priority
1. Add playlist selection UI for VO2 training (BROKEN without this)
2. Clarify training mode names
3. Add HR display to screens

## Don't Touch
- HeartRateManager (working perfectly)
- Background execution logic
- Audio announcement timing

## Common Issues
- Background modes need physical device
- Spotify requires premium account
- UI updates need main thread

## Tech Stack
- SwiftUI + MVVM
- CoreBluetooth
- Spotify SDK
- UserDefaults for persistence
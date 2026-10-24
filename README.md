# Sports Desk

A personal sports dashboard for following favourite teams on **Apple TV**, **iPhone**, and **iPad**. Built in Swift + SwiftUI with a shared Swift package for models, networking, and data providers.

Defaults are the **Toronto Maple Leafs** (NHL) and **Green Bay Packers** (NFL). Change them in Settings — picks sync across devices via iCloud.

## Requirements

- Xcode 16 or newer (iOS/tvOS 17 SDK)
- An Apple Developer team for device/simulator signing
- The same Apple ID signed into iCloud on each device you want to sync

This repository was assembled on Linux. The shared package builds and its unit tests pass with the Swift 6.2 Linux toolchain. The iOS/tvOS app targets need a Mac.

## Open and run on a Mac

1. Open `SportsDesk.xcodeproj` (or regenerate it with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate`).
2. Select the **SportsDesk** scheme for iPhone/iPad, or **SportsDeskTV** for Apple TV.
3. In Signing & Capabilities, choose your **Team**. Xcode should enable:
   - iCloud Key-Value storage (`com.apple.developer.ubiquity-kvstore-identifier`)
   - CloudKit container `iCloud.com.sportsdesk.SportsDesk`
4. If Xcode asks to create the iCloud container, accept it (or create `iCloud.com.sportsdesk.SportsDesk` in the developer portal).
5. Run on a simulator or device. First launch shows Leafs + Packers.

To run the shared package tests on a Mac:

```bash
swift test
```

## What you get

- One dashboard listing every favourite team; tap a team for a full page.
- Every card opens a detail screen (standings, stats, game, lines/depth, injuries).
- tvOS uses large, focusable cards for the Siri Remote. iPhone is a stacked scroll; iPad uses the same views at a wider width.
- Settings: add/remove/reorder NHL and NFL teams. Stored in `NSUbiquitousKeyValueStore` with a `UserDefaults` fallback.

The data layer is league-agnostic (`League` is a string identifier, providers are protocol-based) so another league can be added later without rewriting settings.

## Data sources (no API keys)

| Data | Source | Notes |
| --- | --- | --- |
| NHL standings, schedule, game landing/boxscore, player stats | [api-web.nhle.com](https://api-web.nhle.com) | Public NHL web API. No auth. |
| NHL team-level rates (PP%, PK%, GF/G) | [api.nhle.com/stats](https://api.nhle.com) | Public stats REST. |
| NHL line combinations | [Daily Faceoff](https://www.dailyfaceoff.com) team pages | Isolated behind `LineCombinationProviding` / `DailyFaceoffLineProvider`. Parses Next.js `__NEXT_DATA__`. Cloudflare often blocks datacenter IPs; the UI then shows a graceful unavailable state. |
| NFL standings, team, schedule, stats, roster, depth chart, game summary | ESPN public site/core APIs (`site.api.espn.com`, `sports.core.api.espn.com`) | No key. Undocumented; treat as best-effort. |
| NFL key injuries | ESPN `.../football/nfl/injuries` | Isolated behind `InjuryProviding` / `ESPNInjuryProvider`. Team-specific `/teams/{id}/injuries` returns `{}`; the league report is filtered to the favourite team. |

Game times are parsed from UTC (NHL `startTimeUTC`, ESPN ISO dates) and shown in the **device’s local time zone**.

## Package layout

```
Package.swift                  SportsDeskCore
Sources/SportsDeskCore/        models, HTTP client, settings, NHL/NFL providers
Tests/SportsDeskCoreTests/     recorded JSON fixtures + mapping tests
Apps/SportsDesk/               shared SwiftUI for iOS, iPadOS, tvOS
SportsDesk.xcodeproj           iOS + tvOS targets, iCloud entitlements
project.yml                    XcodeGen spec (optional regenerate)
```

## What was verified here (Linux)

- `swift test` — 21 tests, all passing (decode NHL/ESPN fixtures, settings defaults + iCloud-style store, line parser, injury key-status filter, fixture-backed NHL/NFL dashboards).
- Live `curl` of NHL standings, club-stats, week schedule, game landing/boxscore; ESPN team/schedule/standings/statistics/depth chart/roster/summary; ESPN league injuries (includes position, injury type, Out/Doubtful/Questionable/IR).
- Daily Faceoff HTML from this VM returned Cloudflare 403. The provider is written against `__NEXT_DATA__` and covered by a recorded fixture; on a home network/device it may succeed.

## Still needs a Mac / Xcode

- Compile and run the iOS, iPadOS, and tvOS targets (SwiftUI is not available on Linux).
- Confirm Siri Remote focus order on a real Apple TV or tvOS simulator.
- Signing: pick a Team, let Xcode create/register `iCloud.com.sportsdesk.SportsDesk`, and verify Key-Value store sync between two devices.
- Asset catalog: placeholder icons only; replace `AppIcon` before shipping.
- Optional: XcodeGen (`xcodegen generate`) if you prefer regenerating the project from `project.yml`.
- Watch a live NHL/NFL game to confirm clock/period and in-game injury updates against the public feeds.

## Known limitations

- NHL and ESPN APIs are unofficial and can change shape without notice.
- Daily Faceoff is a scrape of a public page, not a documented API, and is often bot-gated.
- ESPN’s full NFL injury dump is large; the provider filters to one team in memory.
- Depth charts and projected lines are only as current as the source.
- No official broadcast rights; networks are whatever the public feed lists.

## Licence / terms

Personal project. Respect NHL, ESPN, and Daily Faceoff terms of use. Do not republish their data as your own service.

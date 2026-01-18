# AdMob Native Advanced Design (Activity Tab)

## Goal
- Provide an implementation blueprint aligned with the requirements doc.

## Related Docs
- Requirements: `admob_native_advanced_activity_tab-requirements.md`

## Proposed Files
- `TrainLog/AdMobConfig.swift`
  - Stores app ID, ad unit IDs, and test device IDs.
  - Provides debug vs release switching.
- `TrainLog/Views/Overview/Logic/OverviewNativeAdLoader.swift`
  - `ObservableObject` that owns `GADAdLoader`, load state, and timestamps.
- `TrainLog/Views/Overview/Components/OverviewNativeAdCard.swift`
  - Card-style container aligned with existing overview cards.
- `TrainLog/Views/Overview/Components/NativeAdViewRepresentable.swift`
  - `UIViewRepresentable` wrapper around `GADNativeAdView`.
- Optional helper: `TrainLog/Extensions/UIApplication+RootViewController.swift`
  - Resolves the current root view controller safely.

## Loader API Sketch
- Properties
  - `@Published var nativeAd: GADNativeAd?`
  - `@Published var loadState: LoadState`
  - `private var lastLoadDate: Date?`
  - `private var lastFailureDate: Date?`
- Methods
  - `loadIfNeeded()` for initial load.
  - `refreshIfNeeded()` for scene activation.
  - `reset()` for manual invalidation if needed.
- LoadState
  - `idle`, `loading`, `loaded`, `failed`

## View Composition
- In `OverviewTabView`:
  - Insert between `OverviewActivityRecordCard` and `OverviewMuscleGroupShareCard`.
  - Render only when `nativeAd != nil`.
  - Avoid `Button` or `NavigationLink` wrappers.
- `OverviewNativeAdCard`:
  - Uses the same padding, corner radius, and background as existing cards.
  - Contains the representable view and an "Ad" label.

## View Hierarchy Sketch
- OverviewTabView
  - ScrollView
    - VStack
      - Button -> OverviewActivityRecordCard
      - OverviewNativeAdCard (only when ad loaded)
      - Button -> OverviewMuscleGroupShareCard
      - OverviewMuscleGrid

## Card Layout (SwiftUI)
- Container style: match `OverviewMuscleGroupShareCard`
  - padding: 16
  - background: `secondarySystemGroupedBackground`
  - corner radius: 26
- Layout (VStack, spacing 12)
  - Top row: "Ad" label (small caps) + Spacer + AdChoices host
  - Middle: `NativeAdViewRepresentable` with `minHeight >= 120`
  - Bottom: optional disclaimer or none (keep compact)

## NativeAdViewRepresentable Layout (UIKit)
- Root: `GADNativeAdView`
- Required assets
  - `headlineView`: UILabel, single line, truncates tail
  - `mediaView`: GADMediaView, aspect fit, fixed height
  - `adChoicesView`: GADAdChoicesView, top-right anchor
- Optional assets (show only when provided)
  - `bodyView`: UILabel, 2 lines max
  - `iconView`: UIImageView, fixed size (32x32)
  - `callToActionView`: UIButton, min height 28
- Layout idea (vertical stack)
  - Header row: icon (optional) + headline
  - Media row: mediaView
  - Footer row: body (optional) + CTA (optional, trailing)
- Always set `nativeAdView.nativeAd = nativeAd`
- Build a fresh `GADNativeAdView` per ad to avoid stale asset bindings

## GADNativeAdView Mapping
- Required assets:
  - Headline -> `headlineView`
  - Media -> `mediaView`
  - AdChoices -> `adChoicesView`
- Optional assets shown only if present:
  - Body -> `bodyView`
  - Icon -> `iconView`
  - CTA -> `callToActionView`
- Always assign `nativeAdView.nativeAd = nativeAd` to enable tracking.

## Lifecycle and Reload Policy
- Call `loadIfNeeded()` on first appearance.
- Call `refreshIfNeeded()` when `scenePhase` becomes `.active`.
- Enforce a cooldown interval (for example 30 minutes).
- Enforce a retry interval after failure (for example 60 seconds).

## State Machine
- idle -> loadIfNeeded -> loading
- loading -> didReceiveAd -> loaded
- loading -> didFail -> failed
- failed -> refreshIfNeeded (after retry interval) -> loading
- loaded -> refreshIfNeeded (after cooldown) -> loading

## Scene Phase Flow
- On `.active`:
  - If `nativeAd == nil`: attempt `loadIfNeeded()`
  - If `nativeAd != nil`: attempt `refreshIfNeeded()` (cooldown gate)
- On `.background` or `.inactive`:
  - Do not load or refresh

## Threading and Safety
- Delegate callbacks must update `@Published` state on the main thread.
- Keep a strong reference to `GADAdLoader` while loading.
- If `rootViewController` is nil, skip load and keep hidden.

## Accessibility
- "Ad" label should be readable and not hidden by `GADNativeAdView`.
- Ensure headline and CTA are accessible elements.

## UIKit Constraint Note
- AdMob requires `GADNativeAdView` (UIKit). Use `UIViewRepresentable` only.
- Do not introduce new UIKit view controllers or screens.

## Logging and Safety
- Log only on state changes to avoid spam.
- If `rootViewController` is missing, skip load and keep the ad hidden.

# Repository Guidelines

## Project Structure & Module Organization
BrainFish is a SwiftUI macOS app under `BrainFish/`. `BrainFishApp.swift` owns lifecycle and status bar wiring; `AppMain.swift` hosts task animation, persistence, and window composition. Assets live in `BrainFish/Assets.xcassets`, previews in `BrainFish/Preview Content`. The root houses `BrainFish.xcodeproj`, the experimental `BrainFishAppResolutionChangesFix.swift`, and reference docs (`spec.md`, `mistakes.md`, `improvement_plan.md`). Read those specs before changing movement math or UX assumptions.

## Build, Test, and Development Commands
- `open BrainFish.xcodeproj` to work in Xcode.
- `xcodebuild -project BrainFish.xcodeproj -scheme BrainFish -configuration Debug build` for CI-style builds (run `sudo xcodebuild -license` once per machine).
- `xcodebuild test -project BrainFish.xcodeproj -scheme BrainFish -destination 'platform=macOS' -enableCodeCoverage YES` runs XCTest cases with coverage.
- When debugging avoidance overlays, toggle `defaults write com.aricf.brainfish debugFish 1` and revert with `defaults delete com.aricf.brainfish`.

## Coding Style & Naming Conventions
Stick to 4-space indentation and Swift’s standard brace placement. Use UpperCamelCase for types, lowerCamelCase for properties, function names, and `@State` vars. Group logic with `// MARK:` and split views once they exceed ~100 lines or manage distinct state. Let SwiftUI modifiers read top-to-bottom, and prefer environment values or dependency injection over singletons. Document non-obvious animation constants inline.

## Testing Guidelines
Add XCTest targets named `<Feature>Tests` under `BrainFishTests`; import the app with `@testable import BrainFish`. Mirror file structure inside the test bundle and name methods `test_<ExpectedBehaviour>`. Stub time-sensitive code by fixing the seed passed to `randomForLoop`. Run `xcodebuild test ...` locally before submitting and attach coverage summaries when touching animation, persistence, or shortcut handling.

## Commit & Pull Request Guidelines
Use concise, imperative commit subjects similar to history (`Fix:`, `Add:`). Limit each commit to one functional change and expand background in the body when behaviour shifts. Pull requests should include: context, testing checklist (task window toggle, mouse avoidance, screen resize), and screenshots or recordings for UI changes. Reference issue numbers and note any new preferences or entitlements reviewers must enable.

## Security & Environment Notes
Respect the existing sandbox in `BrainFish.entitlements`; discuss additional capabilities before committing. Reset local state with `defaults delete com.aricf.brainfish` for clean verification. The app relies on Accessibility permission for global mouse tracking—call out the System Settings path in docs whenever that workflow changes.

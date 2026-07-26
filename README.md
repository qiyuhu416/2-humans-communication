# Between Us — iOS SwiftUI Prototype

A minimal, local-first prototype for turning an abstract relationship feeling into concrete, face-to-face scenario comparisons.

## What is implemented

1. **Two personalized entry points**
   - Qiyu and Samar each have Hard-coded and AI question sources
   - Samar’s Hard-coded tab preserves five repeatable question sets about work, planning, space, support, and closeness

2. **Abstract feeling input**
   - Starts with `I don’t feel connected.` but is editable

3. **Two scenario sources**
   - Hard-coded uses deterministic local scenario families for stable UX review
   - AI uses Apple’s on-device Foundation Models framework after the user types a moment or question
   - When Apple’s model is unavailable, AI calls the separately configured backend
   - The generation request includes the selected person, both saved profiles, and neutral-question research constraints

4. **Face-to-face split view**
   - Upper half is rotated for the person sitting opposite the phone
   - Qiyu selects what she would prefer
   - Samar predicts what Qiyu would prefer
   - Scenario order is reversed across the two halves
   - Answers remain hidden after locking until both people are ready

5. **Reveal screen**
   - Shows alignment or difference without scoring
   - Produces a working hypothesis and a discussion prompt

## Run in Xcode

1. Unzip the project.
2. Open `BetweenUsPrototype.xcodeproj` in Xcode.
3. Select an iPhone simulator.
4. Press **Run** (`⌘R`).

The deployment target is iOS 17.0 and the app has no external dependencies.

## On-device AI

Open either person’s card and choose **AI**. No API key or network request is used. The app checks `SystemLanguageModel.default.availability` before enabling generation.

On-device generation requires iOS 26 or later, an Apple Intelligence-capable device, Apple Intelligence enabled, and the system model downloaded. When it is unavailable—such as in the Simulator—the AI tab calls the configured backend. It never substitutes hard-coded scenarios.

For Simulator development, run the dependency-free service in `Backend/README.md`. The default URL is `http://127.0.0.1:8787`.

The provider abstraction and Apple implementation live in:

`BetweenUsPrototype/LocalAdaptiveScenarioEngine.swift` → `ScenarioGenerationProvider` and `OnDeviceScenarioService`

To use a non-Apple on-device model later, add a Core ML-backed type conforming to `ScenarioGenerationProvider`. That provider must handle tokenization and decoding and return validated `[ScenarioRound]` values.

## Recommended next build

- Generate the next scenario adaptively from the previous choice
- Add a separate reason-selection round for each person
- Save a session as a shareable “working model”
- Build Samar’s independent entry flow
- Add private answer shielding / haptics for face-to-face use

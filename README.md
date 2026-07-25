# Between Us — iOS SwiftUI Prototype

A minimal, local-first prototype for turning an abstract relationship feeling into concrete, face-to-face scenario comparisons.

## What is implemented

1. **Two entry points**
   - Qiyu: working reflection flow about connection
   - Samar: placeholder screen for a future independent flow

2. **Abstract feeling input**
   - Starts with `I don’t feel connected.` but is editable

3. **AI-factor draft screen**
   - Uses a local `ReflectionEngine` stub so the prototype runs without credentials
   - Factors are explicitly framed as hypotheses, not conclusions

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

## Where to connect a real AI model

Replace the implementation of:

`BetweenUsPrototype/AppState.swift` → `ReflectionEngine.possibleFactors(for:)`

Keep the returned model as `[ReflectionFactor]`. A future service can use:

- the abstract feeling
- previously selected factors
- prior scenario choices
- relationship context explicitly supplied by the users

The model should generate neutral hypotheses and balanced scenario pairs. It should not diagnose users or optimize for agreement.

## Recommended next build

- Generate the next scenario adaptively from the previous choice
- Add a separate reason-selection round for each person
- Save a session as a shareable “working model”
- Build Samar’s independent entry flow
- Add private answer shielding / haptics for face-to-face use

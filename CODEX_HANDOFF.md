# Codex handoff

Continue this SwiftUI prototype without redesigning the existing visual language.

## Product principles

- One idea per screen
- Minimal copy and no dashboard chrome
- No compatibility score, right/wrong framing, or diagnosis
- AI outputs are hypotheses
- Scenario pairs must keep both choices plausible and change one major variable at a time
- Face-to-face answers stay hidden until both participants lock

## Next task

Implement an adaptive round after the reveal:

1. Ask Qiyu why the selected scenario mattered using 4–6 AI-generated factors.
2. Ask Samar why he predicted that choice.
3. Show whether the selected reasons align.
4. Generate a deeper scenario that isolates the leading underlying factor.
5. Add “Continue / Change question / Skip this layer” before entering the deeper layer.

Use local mock data behind a protocol so a real model endpoint can be connected later.

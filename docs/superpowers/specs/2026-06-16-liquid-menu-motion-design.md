# Liquid Menu Motion Design

## Goal

Add liquid-feel motion to Orbis without changing the current liquid-glass material.

## Approved Direction

Use the existing glass layers, icon layout, center content, and hit testing. The motion should make the menu feel like soft glass under surface tension:

- Appear: quick vertical compression, slight overshoot, settle.
- Dismiss: shorter inward squeeze and fade.
- Icon focus change: selected icon floats outward slightly, scales gently, and the running dot breathes.
- Center text/music state: short cross-fade with a small blur/scale, not a large layout movement.

## Constraints

- Do not change `glassEffect` material parameters.
- Do not add gooey icon connections, water trails, or new visual themes.
- Do not rotate or re-layout the app icons during selection changes.
- Keep settings hit testing independent from the animation.

## Target Timing

- Menu appear: about 220-240 ms.
- Menu dismiss: about 140-170 ms.
- Icon focus switch: about 130-180 ms.
- Center content swap: about 120-160 ms.

## Files

- `Sources/PieMenu/PieMenuView.swift`: visual motion only.
- `Sources/PieMenu/PieMenuWindow.swift`: keep dismiss delay aligned with the new close animation if needed.
- `work/orbis-liquid-motion-contract-test.py`: lightweight source contract check for the motion boundary.

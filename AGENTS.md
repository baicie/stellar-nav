# Project Instructions

- Read the exact Expo SDK 57 documentation at https://docs.expo.dev/versions/v57.0.0/ before changing framework-specific code.
- Keep `src/core` deterministic and free of React, React Native, Expo, Skia, and Zustand imports.
- Run `pnpm verify` before committing behavior changes.
- Preserve the data nature boundary: observed, derived, simulated, and fictional values must remain distinguishable.
- Prefer Skia/Reanimated shared values for per-frame animation; never update React or Zustand state every frame.
- Use Chinese product copy and accessible labels; keep code identifiers and filenames in English.

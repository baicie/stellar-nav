# Project Instructions

## Product Baseline

- Treat the current Flutter + Rust implementation as a clean architecture reset. Expo, React Native, TypeScript, Skia, Reanimated, Zustand, pnpm, and the former `src/` tree are retired and must not be restored.
- Build a Chinese-first, science-education solar-system navigation app with science-fiction presentation. The product is an educational simulator, never a real mission-planning or flight-control tool.
- Keep implemented, planned, and fictional capabilities explicit. Do not describe a Rust placeholder or schema as a shipped UI feature.
- Use Chinese product copy and accessible labels. Keep code identifiers and filenames in English.

## Architecture Boundaries

- Flutter owns product UI, accessibility, responsive layout, gestures, map composition, and presentation formatting.
- Riverpod owns low-frequency product state only: search, selection, route choice, submitted simulation time, layer settings, and navigation start/stop.
- Keep per-frame values in `AnimationController`, painters, render objects, or equivalent render-local mechanisms. Never write Riverpod state or call Rust once per frame.
- Rust owns deterministic catalog access, teaching ephemerides, transfer windows, route calculations, search, spatial queries, and offline-pack formats.
- Keep reusable Rust logic in `native/crates/*`. Only `native/astro_engine` may depend on `flutter_rust_bridge`; domain crates must remain independent of Flutter and platform APIs.
- Flutter code must reach Rust through `NavigationRepository` and the generated bridge. UI widgets must not parse bundled catalog files or call generated FRB functions directly.
- Bridge responses are versioned contracts. Preserve `schemaVersion`, `catalogVersion`, camelCase JSON, and backward-compatible semantics unless an ADR and migration accompany the change.
- Do not hand-edit `lib/src/rust/frb_generated*.dart` or `native/astro_engine/src/frb_generated.rs`; regenerate them from `flutter_rust_bridge.yaml`.

## Data Nature Boundary

- Every scientific object and numeric fact must retain one of exactly four natures: `observed`, `derived`, `simulated`, or `fictional`.
- `observed` values require a source URL and access timestamp. `derived` values require an honest method note. `simulated` values require model provenance and a teaching disclaimer. `fictional` values must remain visibly fictional at object and field level.
- Never present simplified J2000 positions as real-time ephemerides. Never present route duration, Delta-v, risk, recommendation, space weather, or facilities as observed unless the underlying model and source genuinely change.
- Preserve `systemId` and `parentId` on catalog objects. The current runtime scope is `sol`; deeper-space systems must be added as new versioned domains, not by breaking existing IDs.
- Validate catalog changes with the Python data pipeline and Rust contract tests. Do not silently invent missing scientific values.

## Verification

- Run `./scripts/verify.sh` before committing any behavior, bridge, catalog, build, or dependency change.
- For focused work, run the narrowest relevant test first, then the full verification script before handoff.
- Use `dart analyze`, not `flutter analyze`, while the workspace path contains Chinese characters and the Flutter analyzer wrapper has the known LSP parsing failure.
- Rust changes must pass `cargo fmt`, `cargo clippy --workspace --all-targets -- -D warnings`, and `cargo test --workspace` from `native/`.
- UI changes must include Widget tests for interaction and Chinese accessibility labels, then be checked at phone and wide desktop sizes. Map changes require a nonblank canvas check and overlap inspection.
- Data changes must include validator coverage for every new invariant and must preserve deterministic Rust tests.

## Change Rules

- Prefer small vertical changes that follow existing repository, controller, model, and crate boundaries.
- Ask before adding runtime network services, accounts, databases, telemetry, paid infrastructure, user-data collection, a new rendering engine, or a new data-nature category.
- Record expensive-to-reverse framework, contract, data-model, and rendering decisions in `docs/decisions/`.
- Update `docs/spec.md`, README, tests, and ADRs when behavior or scope changes. Do not leave the docs describing the retired Expo implementation.
- Never commit secrets, user data, generated build directories, unlicensed assets, or claims that the teaching model is suitable for operational use.

See `docs/spec.md` for product scope and `docs/decisions/` for the rationale behind these boundaries.

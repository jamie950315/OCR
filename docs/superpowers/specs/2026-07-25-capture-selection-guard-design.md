# Capture Selection Re-entry Guard

## Goal

Prevent a second OCR shortcut from starting another capture-selection session while one is already open. The first selection remains visible and usable; subsequent shortcuts have no effect until that session completes or is cancelled.

## Scope

- Gate `AppState.startCapture()` while a capture-selection overlay exists.
- Make overlay cleanup idempotent and run it during deallocation as a safety net.
- Preserve the existing successful-selection, cancellation, OCR, and toast behaviour.
- Add automated coverage for the capture-session state transitions.

## Design

`AppState` owns at most one `ScreenCaptureOverlay`. Starting a capture first acquires a small session gate. If that gate is already active, the call exits without creating an overlay or changing the in-progress selection.

The gate is released only when the overlay reports completion or cancellation. `ScreenCaptureOverlay` tracks whether it has installed resources (cursor override, keyboard monitor, and overlay windows). Its cleanup operation returns immediately when resources are already released, allowing normal completion and deallocation to use the same cleanup safely.

## Error Handling

- A duplicate shortcut is intentionally a no-op.
- If an overlay is released unexpectedly, its deinitializer cleans up any resources it still owns.
- Existing capture-permission and network errors retain their current behaviour.

## Tests

- Starting a session succeeds once and marks it active.
- A second start while active is rejected without changing session state.
- Ending a session releases the gate and permits a later start.
- Cleanup can run more than once without an extra cursor pop or monitor removal.

## Acceptance Criteria

- Repeated shortcuts during region selection do not create a second selection session.
- Cancel, successful selection, and unexpected overlay release leave no active session.
- The project builds and all automated tests pass.

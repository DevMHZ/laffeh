# Preview camera smoothness

Switching the route preview into 3D could interrupt its own camera animation:
the tilt button started a native animation while playback immediately sent
another camera position. Follow/Cinematic also changed zoom and pitch in one
step, and a shared 33 ms throttle allowed camera callbacks and state updates to
interrupt display pacing.

## Changes

- Locked preview has one camera owner: its display ticker. Zoom, pitch and
  deliberate heading changes ease together over 400 ms from the current pose.
  Reversing a transition continues from its current pose, including when paused.
- Moving road headings update the transition endpoint without restarting it.
  Once settled, the existing heading smoother controls turns directly.
- Native camera callbacks and cubit updates no longer publish preview frames.
  Playback renders on display ticks; native writes still coalesce to the latest
  frame. Live GPS rendering retains its existing throttle.
- Cached route distances/bearings replace repeated full-route calculations.
  The geographic vehicle and completed trail retain their exact shared endpoint.
- Delayed overview zoom adjustments cannot overwrite a new camera mode. Resetting
  the free camera applies both angles in one operation.

## Validation

- `flutter test --no-pub test/route_planner test/navigation_engine_test.dart`:
  476 tests passed, including 14 new camera/geometry regressions.
- Scoped Flutter analysis and `git diff --check`: clean.
- Built and launched on the iPhone 17 Pro simulator (iOS 26.5). Exercised
  Cinematic/2D/3D playback, paused angle changes, repeated angle taps, manual
  exploration, re-centering and completion.
- Recorded simulator playback and tracked the vehicle across consecutive
  frames. In a five-second straight 3D segment (594 recorded frames), horizontal
  position stayed constant and vertical variation was at most 3 physical
  pixels (about one logical point). A five-second 2D segment varied by at most
  1 physical pixel. Transitioning sprite orientation prevents reliable
  fixed-template measurement of the mode switch itself.

The recording checks this simulator route, not physical-device performance or
all route sizes. Camera and GeoJSON updates remain separate native operations;
the change does not assume their rendering is atomic.

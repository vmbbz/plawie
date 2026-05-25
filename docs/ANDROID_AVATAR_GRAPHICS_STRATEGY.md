# Android Avatar Graphics Strategy

Last updated: 2026-05-25

This is the visual contract for Plawie's Android chat avatar. Do not use broad
UI reverts to change this screen; make small, named changes and test with a
screenshot.

## Target Look

- Avatar should feel full-size and present, like the screenshot reference.
- The body should be centered by measured VRM bounds, not raw model origin.
- The avatar may sit behind the transparent chat tray.
- The head can sit high behind the app bar, but the body should not drift left.
- The voice orb belongs near the top edge of the chat tray, not above the head.

## Current Implementation

- Renderer: `assets/vrm/avatar_scene.html`
- Flutter host: `lib/widgets/vrm_avatar_widget.dart`
- Chat layout: `lib/screens/chat_screen.dart`

Important constants in `avatar_scene.html`:

- `targetHeight = 1.8`
- `MAX_RENDER_PIXEL_RATIO` is capped for mobile but keeps high-quality DPR.
- `ZOOM_FACTOR` controls avatar size. Larger value means closer camera and a
  larger avatar.
- `PAN_Y_OFFSET` controls vertical framing. Lower/negative values lift the avatar
  in frame.
- `avatarMetrics.centerX` comes from the scaled VRM bounding box center.
- `avatarMetrics.lookY` is refreshed by camera framing so the render loop does
  not drift away from the intended body framing.
- `ENABLE_HEAD_POSITION_BRIDGE = false` because the orb is no longer head-tracked.

## Performance Rules

- Avoid live Flutter `BackdropFilter` over Android WebView/WebGL surfaces.
- Do not fade/scale the Android PlatformView during normal avatar switches.
- Do not stream `HEAD:` bridge messages unless the UI truly tracks the head.
- Do not reduce avatar DPR or antialiasing without a measured memory reason and
  a before/after screenshot.

## Safe Future Work

- Native renderer exploration: Filament or Unity-as-Library.
- Keep WebView/WebGL for now, but treat it as the expensive layer.
- If memory pressure returns, reduce chat/home decorative blur first before
  lowering avatar quality.

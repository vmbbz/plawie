# Investigation Findings: Avatar Overlay, Gaze, and Physics Issues

## 1. Overlay "White Washout" & Transition Issues
**Symptoms:** 
- Tapping the overlay/PIP mode causes a white washout of the chat screen.
- App does not minimize correctly to the home screen.
- Overlay transitions are failing.
**Initial Hypothesis:** 
- The `flutter_overlay_window` might be competing for viewport focus or the `VrmAvatarWidget` is being rendered on both isolates simultaneously without proper disposal, causing a WebGL context conflict or a transparency layering bug in Android.
- The "white washout" suggests the background of the overlay or the main screen is not being set to transparent correctly in the native layer.

## 2. Gaze Tracking: 360 Head Rotation Frenzy
**Symptoms:**
- Single tap causes the head to rotate uncontrollably.
**Initial Hypothesis:**
- The rotation lerp or clamping in `avatar_scene.html` is likely missing a modulo wrapping or a hard clamp on the `bone.rotation.y/x` values.
- If the target reaches a certain threshold, the math might be triggering a "shortest path" rotation that flips the head around the back.

## 3. Procedural Wind Physics: Non-Functional
**Symptoms:**
- Wind effects on hair/clothes are not visible.
**Initial Hypothesis:**
- `currentVrm.springBoneManager.joints` might be empty if the VRM model is a VRM 0.x model being loaded into a VRM 1.0 logic path, or vice versa.
- The `gravityDir` injection might be being overwritten by the `currentVrm.update(delta)` call if it happens in the wrong order.

## 4. Lighting: Poor Visibility (Dark Eyes)
**Symptoms:**
- Eyes are invisible/dark.
**Initial Hypothesis:**
- The current 3-point lighting intensity is either too low or the `DirectionalLight` is angled too steeply from above, creating shadows in the eye sockets (the "raccoon" effect).
- We need to revert to a flatter, more front-facing lighting setup as per previous successful commits.

---

# Next Steps: Fixed & Patches
1. **Surgical Clamping:** Add hard limits to head/neck rotation to prevent the 360-spin.
2. **Order of Operations:** Ensure Wind injection happens *after* any internal resets but *before* the final matrix update.
3. **Transparency Debug:** Audit the `AndroidManifest.xml` and `avatar_overlay.dart` for `isOpaque: false` and surface z-ordering.
4. **Lighting Revert:** Adjust `AmbientLight` and `DirectionalLight` positions to ensure eyes are brightened.
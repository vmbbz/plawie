# OpenClaw Wearable Avatars: Architecture Blueprint
*Version: 2.0 (Epic Upgrade) | Reference: Project Airi, OpenClaw Core*

## 1. Executive Summary: Avatars as "Wearable" UX
In the OpenClaw ecosystem, the 3D VRM Avatar is not just a visual gimmick; it is an **AI-Native Wearable Interface**. 
Just as hardware wearables (smart glasses, watches) provide ambient computing, the Floating Avatar provides a persistent, ambient visual presence for the OpenClaw Agent. The avatar "wears" the intelligence of the agent. 

When an OpenClaw Agent thinks, speaks, or executes a **Skill**, the avatar physically reacts. The architecture acts as the translational tissue between abstract LLM logic (Skills, TTS, reasoning) and physical 3D expression (gestures, visemes, saccades).

## 2. The Core Orchestration Pipeline
The pipeline ensures that the Agent's internal state is perfectly synchronized with the 3D WebGL renderer, across both the Main App UI and the disjointed background Android Overlay.

**Flow:**
`OpenClaw Agent State (LLM/Skill)` ➔ `Flutter UI/Isolate Data Bridge` ➔ `WebView Javascript Interface (ClawaBridge)` ➔ `Three.js Procedural Matrix`

### 2.1 Cross-Isolate Communication (The Overlay Bridge)
Because the "Floating Companion" widget runs `flutter_overlay_window` in a completely separate background Flutter Engine (Isolate) to bypass Android PiP limitations, it does not share memory with the main app.
- **The Bridge:** We utilize `FlutterOverlayWindow.shareData(data)` to broadcast real-time telemetry (Speech Intensity, Thinking boolean, Current Skill Gesture, Current Emotion).
- **The Receiver:** The background Isolate listens via `FlutterOverlayWindow.overlayListener` and pipes these directly into the floating instance of the `VrmAvatarWidget`.

### 2.2 Skill-to-Gesture Mapping
When an OpenClaw Agent executes a skill (e.g., `_createSearchSkill`), the framework emits a state change. 
- Thinking state triggers the avatar to gaze upwards and sway (`isThinking = true`).
- Specific skills map directly to `.vrma` files (e.g., executing a calculation skill might trigger `playGesture('gesture_smart')`).

## 3. The 3D Render Engine (`avatar_scene.html`)
To achieve top-tier visual fidelity (par with Project Airi), the Three.js scene employs:

### 3.1 Studio-Grade 3-Point Lighting
To avoid the "flat/washed-out" look endemic to basic WebGL:
1. **Key Light:** (Top-front-right, warm) Provides primary illumination and facial shadows.
2. **Fill Light:** (Front-left, cool) Softens harsh shadows.
3. **Rim Light:** (Directly behind/above, intense) Carves the silhouette out from the background, adding physical weight to the avatar.

### 3.2 Dynamic Framing & Grounding
The camera mathematical engine operates on a single `ZOOM_FACTOR`. 
- By capturing the bounding box of the avatar (`size.y`), the camera computes the exact `dist` and `tan(fov)` required to fit the avatar.
- It dynamically anchors the **bottom of the screen** to the very bottom of the avatar's feet, panning the camera up `PAN_Y_OFFSET` to prevent the UI from occluding the feet. 
- During `?overlay=true` mode, `ZOOM_FACTOR` explodes to `2.5x`, naturally framing a perfect bust/headshot for the floating bubble.

## 4. The "Airi-Style" Procedural Animation Matrix
Linear state-machine animations feel robotic. Our architecture uses a **Layered Procedural Matrix** so the avatar is *always* moving.

### 4.1 Base Procedural Layer (Javascript Math)
- **Breathing:** Synchronous sine waves applied to the `upperChest` and `spine` rotation vectors.
- **Micro-Saccades:** Complex intersecting `Math.cos/sin` equations applied to the `neck` and `head` to create constant, organic weight-shifting.

### 4.2 Interactive Gaze Tracking Layer
- Vector tracking captures user touch/pointer events on the screen canvas.
- Using `THREE.MathUtils.lerp`, the head and spine bones smoothly rotate to look at the user's focal point.

### 4.3 Additive Gesture Mixer Layer
- When a Skill triggers a `.vrma` gesture (e.g., waving), it is played on a `THREE.AnimationMixer`.
- Crucially, this animation is applied **on top** of the underlying procedural breathing and saccades. The avatar waves while still physically shifting weight.

### 4.4 Emotion-Driven Viseme Audio-Sync
- TTS audio power (`speechIntensity`) drives the mouth bone openness.
- However, the mapping overrides standard visemes (`aa`, `ih`, `oh`) based on the current Agent Emotion.
- If the agent is `angry`, the logic suppresses `oh` shapes and forces bared-teeth `ee` constraints, achieving complex emotive lip-sync.

---
*This architecture ensures the OpenClaw Agent possesses a 3D interface that is performant, interactive, visually premium, and capable of operating as a persistent Wearable companion in the Android OS layer.*

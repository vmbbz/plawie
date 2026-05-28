<p align="center">
  <img src="assets/images/release_banner_v2.jpg" alt="Plawie v2.2.1" width="800"/>
</p>

# Plawie v2.2.1 — "The Unified Agent Milestone"

> [!IMPORTANT]
> This release marks the first stable point where Plawie's cloud lane, local NDK lane, Gateway tools, native Android skills, and VRMA avatar controls operate as one coherent agent surface.

---

## 🛰️ The Unified Agent Layer
This release locks in the model/tool architecture that keeps cloud models on the full Gateway path while giving local NDK and HTTP-bridge models compact, tool-aware context that fits their practical limits.

---

## 🚀 Key Improvements

### 1. Shared Model Execution Policy
- Cloud models keep the full Gateway context and tool surface.
- Local NDK and local HTTP bridge models receive compact context plus native tool schemas.
- Provider/model choices now resolve through a shared policy instead of scattered hard-coded behavior.

### 2. Reliable Phone Tool Invocation
- Android node calls use the explicit paired node handle instead of fragile auto-routing.
- Tool availability messaging now distinguishes real missing capabilities from provider or transition failures.
- Chat timeouts now watch backend activity instead of falsely failing while tools are still running.

### 3. Renderer-Acknowledged Avatar Gestures
- Gestures now queue, start, complete, and report status through the VRM renderer.
- Full-body and limb VRMA files play smoothly in sequence.
- Dance and other looping gestures are bounded by duration instead of running forever.
- Sitting aliases now resolve to the available seated VRMA files.

### 4. Polished Avatar Stage
- The old sitting prop has been replaced with a smaller translucent sci-fi globe seat.
- Procedural idle/speech motion no longer fights full-body and limb VRMA playback.

---

## 📄 Installation & Migration
1. Download the APK from the GitHub Releases page.
2. Install normally over an existing Plawie build.
3. Open Settings if you need to refresh provider keys or switch model lanes.

---

<p align="center">
  <sub><i>"Run OpenClaw fully local. Private, always-on, and under your absolute control."</i></sub><br/>
  <b>Plawie — OpenClaw in your Pocket.</b>
</p>

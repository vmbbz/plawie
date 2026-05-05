<p align="center">
  <img src="assets/images/local_llm.jpg" alt="Plawie v1.9" width="800"/>
</p>

# 🎙️ Plawie v1.9.0 — "The Voice-First Milestone"

> [!NOTE]
> This release transformed Plawie from a text-first chat app into a **hands-free, vision-capable AI companion**. We introduced multi-engine TTS, offline video analysis, and the revolutionary "Plawie" wake word.

---

## 🚀 Key Improvements

### 🔊 1. Multi-Engine TTS Pipeline
Switch between four high-performance voice engines to find your perfect companion.
- **Piper (Default)**: Fully offline, high-quality VITS synthesis.
- **Android Native**: Uses your device's installed voice engines (Google, Samsung).
- **ElevenLabs**: Cloud-grade ultra-realism (API required).
- **OpenAI TTS**: Access to the industry-standard `alloy`, `coral`, and `shimmer` voices.

### 📹 2. Video Vision AI (Offline + Cloud)
Plawie can now see and interpret the physical world.
- **Offline Analysis**: Record clips and extract frames via PRoot `ffmpeg` for 100% local analysis using Qwen2-VL or LLaVA.
- **Gemini Native**: Direct cloud-routing for massive multimodal context on Gemini 1.5/2.0 Pro.

### 🗣️ 3. Wake Word "Plawie"
Say *"Plawie"* to activate your agent from across the room.
- **Vosk Powered**: Grammar-constrained speech recognition ensures near-zero false positives.
- **Background Watchdog**: A dedicated Kotlin service keeps the listener alive without draining battery.

### 🔄 4. Continuous Conversation Mode
Enabled hands-free back-and-forth loops. After the agent finishes speaking, the microphone automatically restarts, allowing for a natural, flowing dialogue.

---

## 🏗️ Technical Architecture

| Component | Status | Purpose |
| :--- | :---: | :--- |
| **Vosk ASR** | `OFFLINE` | Grammatically-constrained wake word |
| **FFmpeg (PRoot)** | `INTEGRATED` | Frame extraction for local vision |
| **TTS Facade** | `DYNAMIC` | Multi-engine switching layer |

---

<p align="center">
  <sub><i>"Intelligence that listens, speaks, and sees. The next evolution of your personal agent."</i></sub><br/>
  <b>Plawie — Pushing the boundaries of on-device AI.</b>
</p>

# Contributing to OpenClaw

Welcome to the forefront of AI Wearable interfaces! We are excited to have you join our mission to build the world's most advanced, transparent, and autonomous digital companions.

## 🌟 Vision for Contributors
OpenClaw is more than a repo—it's an ecosystem. We are looking for masters of **Flutter**, **Three.js**, **Solana Dev**, and **Procedural Animation Math**.

---

## 🏗️ Technical Standards

### **1. Flutter Development**
- **Architecture:** We use a strict multi-isolate pattern. UI logic must stay in the main isolate, while background overlay logic and the Node.js gateway stay in their respective sandboxes.
- **State Management:** Use `Provider` for reactive UI updates.
- **Analysis:** Always run `flutter analyze` before committing. We maintain 0 warnings in the main branch.

### **2. 3D & AgentVRM (Three.js)**
- **Optimization:** Mobile WebViews are sensitive. Procedural math should be frame-rate independent using `delta` time.
- **Physics:** When adding to the **Ambient World Engine**, ensure wind/force functions are continuous (sum-of-sines) to prevent jitter in SpringBone physics.
- **Gestures:** New `.vrma` files should be added to `assets/vrm/gestures/`.

### **3. Solana & Web3**
- All blockchain operations must be non-blocking and include thorough error handling for RPC instability.
- Use Jupiter Ultra API for all swap/DCA logic to ensure best-in-class pricing and slippage protection.

---

## 🚀 Workflow

1.  **Fork & Branch:** Create a feature branch from `main`.
    `git checkout -b feature/your-awesome-feature`
2.  **Meticulous Code:** Follow the existing "Surgical & Comprehensive" style. Do not remove unrelated code.
3.  **Documentation:** If you add a new "Skill" or "Procedural Layer," update `AVATAR_ARCHITECTURE.md`.
4.  **Submission:** Submit a PR with a clear description of the impact on both the **Logic Layer** (Gateway) and the **Expression Layer** (VRM).

---

## 🎨 Aesthetic Guidelines
OpenClaw follows a **"2026 Glassmorphic"** design language:
- **Dark Mode First:** All UI should be optimized for OLED screens.
- **Micro-Animations:** Use subtle lerping for all state transitions (look-at targets, intensity changes).
- **Premium Feel:** Avoid generic colors. Use curated gradients and blurred backdrops.

---

## ⚖️ License
By contributing to OpenClaw, you agree that your contributions will be licensed under the **MIT License**.

Thank you for helping us bring Clawa to life!

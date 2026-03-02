# OpenClaw Android (gateway-first)

This repository runs the OpenClaw AI gateway inside a PRoot Ubuntu environment on Android and provides a Flutter UI to install, manage, and access the gateway.

Key points:
- Gateway-first architecture: the app installs and starts OpenClaw (Node.js) inside an Ubuntu rootfs (PRoot).
- The app captures the OpenClaw dashboard token and opens the dashboard at `http://localhost:18789` in an embedded WebView.
- Upstream supports configuring hosted/cloud AI providers (API keys and model selection) via onboarding. It does not include native local LLM hosting or local model packaging by default.

Upstream project: https://github.com/mithun50/openclaw-termux

Quick start (Flutter app):

```bash
flutter pub get
flutter build apk --release
```

For details and the full upstream README, see the upstream repo linked above.
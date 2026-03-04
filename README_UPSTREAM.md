# OpenClaw Android (gateway-first + enhanced agent capabilities)

This repository runs OpenClaw AI gateway inside a PRoot Ubuntu environment on Android and provides a Flutter UI to install, manage, and access the gateway.

**Enhanced Features Beyond Upstream:**
- **Advanced AgentOS**: 56 tools + 35 skills + MCP integration
- **Solana Integration**: Swaps, DCA, transfers via Jupiter + MWA
- **Telegram Bot**: Full reactions, file sharing, inline keyboards (12 commands)
- **Device Control**: Battery, GPS, camera, SMS, clipboard, TTS access
- **Persistent Memory**: Personality, daily notes, ranked keyword search
- **Web Intel**: Brave/DuckDuckGo/Perplexity search + caching
- **Natural Scheduling**: Cron jobs with natural language parsing
- **Security**: Prompt injection defense + transaction confirmations

**Inspired by SeekerClaw**: https://github.com/sepivip/SeekerClaw

Key points:
- Gateway-first architecture: app installs and starts OpenClaw (Node.js) inside an Ubuntu rootfs (PRoot).
- The app captures OpenClaw dashboard token and opens the dashboard at `http://localhost:18789` in an embedded WebView.
- Enhanced agent capabilities with local Solana integration and advanced device control.
- Security-first approach with confirmations for all financial actions.

Upstream project: https://github.com/mithun50/openclaw-termux

Quick start (Flutter app):

```bash
flutter pub get
flutter build apk --release
```

For details and the full upstream README, see the upstream repo linked above.
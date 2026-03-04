---
name: device_vibrate
description: "Trigger a physical haptic vibration on the Android device."
metadata:
  openclaw:
    version: "1.0"
---

# Android Haptic Vibration

To vibrate the Android device and provide physical feedback to the user, you can send a POST request to the local Android Bridge HTTP server.

Run the following command in bash, adjusting the `durationMs` as needed (e.g., 200 for a short tap, 1000 for a long pulse):
```bash
curl -X POST -H "Content-Type: application/json" -d '{"durationMs": 200}' http://127.0.0.1:8765/vibrate
```

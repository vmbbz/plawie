---
name: device_battery
description: "Check the current battery level and charging status of the Android device."
metadata:
  openclaw:
    version: "1.0"
---

# Android Battery Status

To check the battery level of the Android device you are running on, you can query the local Android Bridge HTTP server via `curl`.

Run the following command in bash:
```bash
curl -s http://127.0.0.1:8765/battery
```

This will return a JSON object with `level` (percentage) and `isCharging` (boolean).

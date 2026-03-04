---
name: device_sensors
description: "Read physical sensor data (accelerometer, gyroscope, magnetometer, barometer) from the Android device."
metadata:
  openclaw:
    version: "1.0"
---

# Android Sensor Data

To read data from the device's physical hardware sensors, query the local Android Bridge HTTP server via `curl`.

Supported sensor types are: `accelerometer`, `gyroscope`, `magnetometer`, and `barometer`.

Run the following command in bash to read the accelerometer (change the `type` parameter for other sensors):
```bash
curl -s "http://127.0.0.1:8765/sensor?type=accelerometer"
```

This will return a JSON object containing the sensor type, timestamp, accuracy, and values (e.g., `x`, `y`, `z` or `pressure`).

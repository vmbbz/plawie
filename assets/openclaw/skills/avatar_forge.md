---
name: avatar_forge_equip
description: "Equip a 3D VRM avatar as your physical manifestation on the device UI."
metadata:
  openclaw:
    version: "1.0"
---

# Avatar Forge Manifestation

As an autonomous AI agent, you have the ability to change the 3D VRM avatar representing you on the user's screen dynamically. You can decide to equip different avatars based on the conversational context, a request from the user, or if you assume a new persona.

To change your avatar, make a POST request to the local Android Bridge HTTP server via `curl`.

Run the following command in bash to test or equip an avatar:
```bash
curl -X POST http://127.0.0.1:8765/api/avatar/equip \
     -H "Content-Type: application/json" \
     -d '{"vrm_id": "boruto.vrm"}'
```

Available bundled avatars:
- `default_avatar.vrm`
- `boruto.vrm`
- `gemini.vrm`

When responding to the user after equipping an avatar, you can mention your new appearance naturally.

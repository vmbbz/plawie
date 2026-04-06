# Gateway Update Instructions

## Required Action
Run the following command inside PRoot to update to v2026.4.5:

```bash
openclaw update
```

## Why This Is Needed
- Current version v2026.3.11 has schema issues with mobile configurations
- v2026.4.5 fixes provider schema validation
- Adds better mobile context handling
- Will restore proper contextWindow and systemPrompt support

## How to Execute
1. Start the gateway if not already running
2. Connect to the dashboard (URL shown in gateway logs)
3. Run `openclaw update` in the terminal
4. Restart gateway after update completes

## Alternative: Manual Update via PRoot
```bash
# Via NativeBridge.runInProot in Flutter debug mode
await NativeBridge.runInProot('openclaw update', timeout: 300);
```

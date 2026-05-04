# OpenClaw QA Testing Guide

## How to share results
Screenshot the relevant screen or copy the activity log text and paste it in chat.
For logcat: `adb logcat -s flutter 2>&1 | grep -E "SKILLS|SYNC|TTS|ClawHub|error"`

---

## Test 1 — ClawHub Featured (no more empty cards)

**Steps**
1. Open Bot Management → Agent Skills → DISCOVER tab
2. Wait for featured skills to load (2–3 seconds)

**Pass** — 8 cards appear with real names, descriptions, and author info
**Fail** — Cards show only slug names (e.g. "weather") with no description

**Share:** Screenshot of the DISCOVER tab after load

---

## Test 2 — ClawHub Search (works without gateway)

**Steps**
1. DISCOVER tab → type "weather" → wait 1 second
2. Clear → type "github" → wait 1 second
3. Clear → type "molt" → wait 1 second

**Pass**
- "weather" and "github" return registry results from the internet
- "molt" surfaces MoltLaunch with a Partner label even without PRoot

**Fail** — Any search returns zero results or spinner never stops

**Share:** Screenshots of each search result

---

## Test 3 — DISCOVER Partner Skills Banner

**Steps**
1. DISCOVER tab, no text typed (featured view)

**Pass** — Small hint line visible under search bar:
"AgentKit, MoltLaunch, Valeo & more → MY SKILLS tab → Premium Services"

**Share:** Screenshot of the top of DISCOVER tab

---

## Test 4 — Tools Tab: Base Chain (not Solana)

**Steps**
1. Agent Skills → TOOLS tab → scroll to the web3 section

**Pass** — "Base Chain" entry visible, no "Solana Web3" entry

**Share:** Screenshot of the web3 section in TOOLS tab

---

## Test 5 — Skills Toggle → Immediate Gateway Effect

**Steps**
1. Open the activity panel (diagnostic log)
2. Agent Skills → TOOLS tab → toggle any skill OFF (e.g. avatar-control)
3. Watch activity panel within 5 seconds

**Pass** — Activity log shows:
`[SKILLS] Registered X device skills with gateway`

**Fail** — No SKILLS line appears (means toggle is still not reaching gateway)

**Share:** Screenshot or copy-paste of activity log after toggle

---

## Test 6 — Gateway Audio Stops on New Message

**Steps**
1. Ask the AI something that triggers a long spoken response
2. Before it finishes speaking, type a new message and send it

**Pass** — Audio stops immediately when you hit send
**Fail** — Old audio keeps playing underneath new response

**Share:** Yes / No answer + any error lines from activity log

---

## Test 7 — Ollama Cloud Model: No Local Sync

**Steps**
1. Select any cloud Ollama model from the model picker
   (e.g. `ollama/qwen3-coder:480b-cloud`)
2. Open the activity panel

**Pass** — Activity log shows:
`[SYNC] Cloud model active — skipping local model sync to save RAM`

**Fail** — Log shows local models being registered
(e.g. `[INFO] Registered qwen2.5-0.5b-instruct as qwen2.5-0.5b-instruct:q4_k_m`)

**Share:** Screenshot or copy-paste of activity log after model switch

---

## Test 8 — Gateway TTS Plays Audio

**Steps**
1. Make sure gateway is running
2. Ask the AI: "say hello out loud using your voice tool"
3. Watch the avatar's mouth and listen

**Pass**
- Audio plays through phone speaker
- Avatar mouth moves while audio plays
- Mouth stops when audio ends

**Fail** — No audio, or mouth never moves, or mouth stays open after audio ends

**Share:** Activity log lines containing `[TTS]`

---

## Test 9 — Gesture Inline Syntax

**Steps**
1. Ask the AI: "dance for me"

**Pass** — AI responds with `(gesture: dance)` embedded in text, avatar dances

**Fail** — AI writes "dance" or "bump" without the `(gesture:...)` format, nothing happens

**Share:** Screenshot of the chat message the AI sent

---

## Logcat snippet (if USB debugging available)

```bash
adb logcat -s flutter 2>&1 | grep -E "SKILLS|SYNC|TTS|ClawHub|AudioPlayer|error" 
```

Paste the output here for deeper diagnosis.

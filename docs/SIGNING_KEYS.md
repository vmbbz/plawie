# Signing Keys — Dependency Pack Manifests

**DO NOT COMMIT THE PRIVATE KEY TO GIT. KEEP IT BACKED UP.**

## Key ID
`838fff1844341501`

## Private Key (ed25519)
```
-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VwBCIEIF6wijZVlVTVBzsWKamN3kq/H7MzayXUmKw/ZA9vbPcj
-----END PRIVATE KEY-----
```

## Public Key (ed25519)
```
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEATMgPQFa95wsW0yRuLIIzO5fYThR73fv+UyR+Ofn5O1U=
-----END PUBLIC KEY-----
```

## Backup Files
- `C:\Users\cosyc\AppData\Local\Temp\opencode\signing-private.pem`
- `C:\Users\cosyc\AppData\Local\Temp\opencode\signing-public.pem`

## Signing Script
`sign_manifest.py` is at `C:\Users\cosyc\AppData\Local\Temp\opencode\sign_manifest.py`

Usage:
```
python sign_manifest.py <project_dir> <tmp_dir>
```

## How to Re-sign
1. Ensure `signing-private.pem` is in `<tmp_dir>`
2. Run: `python sign_manifest.py C:\dev-shared\openclaw-projects\openclaw_final <tmp_dir>`
3. The script updates `android-arm64-v8a.json` and `lib/services/signing_keys.dart`
4. Commit and push both files

## Verified Signatures
All 7 packs in `android-arm64-v8a.json` are currently signed with this key.
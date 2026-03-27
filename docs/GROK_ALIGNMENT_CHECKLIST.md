# Grok Review Alignment Checklist — Local LLM

**Status as of:** 2026-03-27
**Grok confirmed:** All 7 bugs in `TECHNICAL_INCIDENT_REPORT_LOCAL_LLM.md` are correct.
**Grok recommended:** Compile-from-source as the only viable path (confirmed).

---

## Checklist: Grok Recommendation vs Our Implementation

### ✅ ALIGNED

| Item | Grok Said | Our Code | Status |
|------|-----------|----------|--------|
| Compile from source | Only viable path | `_compileBinary()` 5-stage cmake | ✅ |
| Repo owner | `ggml-org/llama.cpp` | URL updated to `ggml-org` | ✅ |
| `runInProot` contract | No positional args, throws on non-zero exit | All calls use try/catch | ✅ |
| `_isBinaryInstalled()` non-zero size check | `[ -s file ]` | `stat -c%s > 1048576` | ✅ (stricter) |
| No `--mlock` / `--no-mmap` | Remove both | Already removed in `_startServer()` | ✅ |
| Skills fallback via `try/catch` | Wrap Stage 1 in try/catch | Implemented | ✅ |
| Store binary at `/root/.openclaw/bin/llama-server` | Yes | Yes | ✅ |

---

### ⚠️ GAPS — Fixes Applied Below

| Item | Grok Said | Our Code | Gap |
|------|-----------|----------|-----|
| Source version | Pinned `b8546` | `master.tar.gz` | Should pin for reproducibility |
| cmake server flag | `-DLLAMA_BUILD_SERVER=ON -DLLAMA_SERVER=ON` | Not present | **Critical: server target might not build** |
| cmake ARM flag | `-DGGML_CPU_ARM_V8=ON` | Not present | Missing ARM64 optimisation |
| cmake example exclusion | Not in their script | `-DLLAMA_BUILD_EXAMPLES=OFF` | **Critical: may block server build in some versions** |
| Binary install method | `install -D -m 755` | `find + cp + chmod` | Functionally equivalent; align for clarity |
| Build parallelism | `-j$(nproc)` | `-j2` | Documented disagreement (see below) |
| Stage timeout | 1800s (30 min) | 2400s (40 min) | Conservative is safer; keep 2400s |

---

### 📋 Documented Disagreement: `-j$(nproc)` vs `-j2`

**Grok recommends:** `-j$(nproc)` — use all CPU cores, estimates 15–25 min on flagship Snapdragon.

**Our choice:** `-j2` — conservative cap to protect against Android LMKD.

**Reasoning:** Android's Low Memory Killer Daemon (LMKD) monitors RSS per-process. Compiling llama.cpp with 8 parallel jobs on a 6GB device during compilation can push the Gradle/build processes to 2–4 GB combined RSS. LMKD has been observed killing background processes even with `foreground` priority on low-RAM devices. A build killed at minute 25 requires a full restart.

**Risk of `-j$(nproc)` on mobile:** Build process killed → user must retry from Stage 4.
**Risk of `-j2`:** Compilation takes 30–40 min instead of 15–25 min.

**Decision:** Keep `-j2`. If Grok verifies that PRoot processes are protected from LMKD on their test devices, we can increase.

---

## Code Changes Applied (commit `see below`)

### 1. cmake flags — critical fix

```diff
- '-DLLAMA_NATIVE=OFF '
- '-DGGML_NATIVE=OFF '
- '-DLLAMA_BUILD_TESTS=OFF '
- '-DLLAMA_BUILD_EXAMPLES=OFF '   ← REMOVED: blocks server in some versions
- '-DBUILD_SHARED_LIBS=OFF '
+ '-DCMAKE_BUILD_TYPE=Release '
+ '-DGGML_NATIVE=OFF '           ← keep: no host-specific ISA
+ '-DGGML_CPU_ARM_V8=ON '        ← ADDED: explicit ARM64 SIMD path
+ '-DLLAMA_NATIVE=OFF '
+ '-DLLAMA_BUILD_TESTS=OFF '
+ '-DLLAMA_BUILD_SERVER=ON '     ← ADDED: explicit server target
+ '-DLLAMA_SERVER=ON '           ← ADDED: Grok's recommendation
+ '-DBUILD_SHARED_LIBS=OFF '
```

### 2. Source URL — pin to b8546

```diff
- '"https://github.com/ggml-org/llama.cpp/archive/refs/heads/master.tar.gz"'
+ '"https://github.com/ggml-org/llama.cpp/archive/refs/tags/b8546.tar.gz"'
```

### 3. Binary installation — align with Grok

```diff
- r'BINARY=$(find /tmp/llama_build/build -name "llama-server" -type f | head -1) && '
- r'[ -n "$BINARY" ] || { echo "ERROR: llama-server binary not found after build"; exit 1; } && '
- r'cp "$BINARY" /root/.openclaw/bin/llama-server && '
- 'chmod +x /root/.openclaw/bin/llama-server && '
+ 'install -D -m 755 /tmp/llama_build/build/bin/llama-server /root/.openclaw/bin/llama-server || '
+ r'install -D -m 755 $(find /tmp/llama_build/build -name "llama-server" -type f | head -1) /root/.openclaw/bin/llama-server && '
```

---

## Still Open (for Grok follow-up)

1. **`LMKD` + `-j$(nproc)` risk on 4–6 GB devices** — can Grok test and confirm it won't kill the build process?
2. **Vulkan/GPU acceleration** — Grok offered to provide exact commands for Adreno. We'll need: vulkan-tools, libvulkan1 install + Android Vulkan ICD copy into PRoot.
3. **`node-llama-cpp` prebuilt npm binding** — could replace the HTTP server entirely; Grok should advise on the PRoot Node.js integration path.
4. **Skills install / clawhub** — see companion document `GROK_SKILLS_INQUIRY.md`.

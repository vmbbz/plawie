# Technical Specification: Integrated Ollama Sync Architecture

**Date**: 2026-04-01  
**Status**: Implementation Finalized  
**Target Audience**: Systems Engineers / DevSecOps  

## 1. Executive Summary
OpenClaw implements a "Zero-Config" Integrated Agent Hub by deploying a native Linux binary for Ollama within an unprivileged PRoot-based sandbox (Ubuntu distribution). This allows for local inference without external dependencies (Termux/ADB) while maintaining access to the shared Host-Guest file system for LLM weight reuse.

## 2. Sandbox Environment & Runtime
The environment is orchestrated via a custom `ProcessManager` in Kotlin, simulating a `systemd` environment.

### 2.1 PRoot Configuration
-   **Binary**: Compiled `proot` library (`libproot.so`) with `seccomp` syscall filtering.
-   **Kernel Emulation**: Fakes `6.17.0-PRoot-Distro` to satisfy modern GLIBC and binary requirements.
-   **Key Bind Mounts**:
    -   `/root/.openclaw/models` -> `${FILES_DIR}/rootfs/root/.openclaw/models` (Persistent model store)
    -   `/dev/urandom` -> `/dev/random` (Entropy for inference)
    -   `/tmp` -> Shared host temp space.

### 2.2 Process Lifecycle (`ProcessManager.kt`)
-   **Startup**: Executed via standard `ProcessBuilder` with `env -i` to clean the Android environment.
-   **Teardown**: Uses `pkill -9 -f 'ollama'` within the guest namespace. The PRoot wrapper is invoked with `--kill-on-exit` to ensure orphaned inference workers are reaped by the Android OS if the main activity dies.

## 3. Storage Architecture: The "Zero-Copy" Bridge

To support both the NDK-based `fllama` inference (GGUF direct) and the `ollama` REST API, a bridging strategy is used.

### 3.1 Model Registration Workflow
1.  **GGUF Ingestion**: Models are downloaded into the standard OpenClaw model store.
2.  **Manifest Creation**: The app invokes the Ollama `POST /api/create` endpoint.
3.  **Bridging Directive**: A transient `Modelfile` is passed:
    ```dockerfile
    FROM "/root/.openclaw/models/qwen2.5-1.5b.gguf"
    ```
4.  **Deduplication**: 
    > [!NOTE]
    > While Ollama's standard behavior is to ingest into `~/.ollama/models/blobs`, this bridge ensures that the source of truth remains the `/root/.openclaw/models` directory, allowing the `fllama` NDK engine to read the same bytes concurrently.

## 4. Networking & API Interaction
-   **Endpoint**: `http://127.0.0.1:11434`
-   **Namespace**: Shared Android Network Namespace (Host-Guest parity).
-   **Inbound/Outbound**: Since PRoot behaves as a user-space process, it inherits the application's network permissions (`android.permission.INTERNET`).

## 5. Security & Isolation
-   **Privilege Level**: Runs entirely as the unprivileged Android application user (UID/GID).
-   **Filesystem Scrubbing**: All binary extractions are verified via size/hash checks during the Bootstrap phase.
-   **Memory Management**: Constrained by the Android OOM Killer. The `Integrated Hub` reports status to the host to allow the UI to perform proactive process restarts.

## 6. Known Constraints & Future Iterations
-   **Vulkan/GPU**: Currently limited to CPU inference. GGML_VULKAN enablement is planned for Q3 2026.
-   **IO Throughput**: PRoot syscall interception adds a ~5% overhead on file IO; however, since models are memory-mapped (mmap), inference latency is minimally impacted.

---
*OpenClaw Engineering Team*

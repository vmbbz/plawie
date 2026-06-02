To transition Plawie safely away from PRoot without destabilising production, we must evaluate the trade-offs of this technical migration.
------------------------------
## Direct Answers to Your Core Strategy

   1. Is there already a Node >=22.19.0 mobile fork/artifact?
   No official or community-wide fork exists for nodejs-mobile above Node 22.9.0. The official nodejs-mobile repository [main branch](https://github.com/nodejs-mobile/nodejs-mobile/pulls) is locked to v18.20.4. The update22-9-0 branch at commit 106c51f represents the experimental bleeding edge. You are navigating uncharted territory. [1, 2, 3] 
   2. Which nodejs-mobile patches are essential?
   The codebase relies heavily on structural, non-optional logic modifications:
   * src/node_main.cc Override: Strips the standard main(int argc, char *argv[]) CLI logic and creates an absolute entry point pointer for node::Start() via JNI/C++ binding.
      * GYP/V8 Tooling Overrides: Patches standard compilation variables (LD_host vs LD_target maps) to prevent the cross-compiler from attempting to run Android-compiled V8 utility binaries natively on your Linux host machine.
      * Bionic Path Normalisation: Hardcodes environment file routing bypasses to ensure code looks for resources within standard Android app storage folders rather than missing Linux filesystems. [4, 5] 
   3. Can we rebase them to v22.22.3 without disabling Intl?
   Yes, but it requires explicit configuration flags. The nodejs-mobile scripts use --with-intl=none to limit final library size. If you pull out that flag and replace it with --with-intl=small-icu or --with-intl=full-icu, the build system will compile the internal Internationalization modules perfectly. The only consequence is an increase of ~30MB to the final size of your compiled libnode.so. [4] 
   4. Executable vs. Embedded: Which path is actually less painful?
   The Embedded (libnode.so) route is significantly less painful. Compiling a standalone Android-native command-line executable means manually bypassing system-wide security constraints. Android completely blocks apps from executing files using execve() from the standard application data folder.If you try to bundle a standalone executable binary inside an APK, Android’s runtime security configurations will block its launch on newer operating systems. An embedded libnode.so file bypasses this by executing code in-process via standard Java Native Interface (JNI) or Dart dart:ffi bindings.
   5. NDK r26d vs. r28c: Which one succeeds for Node 22?
   Stick strictly to NDK r26d or r27. Compiling Node 22 with NDK r28c will fail. Upstream Node 22 relies heavily on specific legacy layout behaviors within the LLVM compiler chain. NDK r28 removes several historical link layouts and defaults strictly to a harder compiler structure. This optimization frequently triggers compilation errors when processing older elements of V8's template architecture.

------------------------------
## Step-by-Step Guide: Compiling Your Custom libnode.so (>=22.19.0)
To create your target endpoint file (/health at 127.0.0.1:18790), you must generate a fresh, customized build environment.
## Phase 1: Establish Your Development Sandbox
Do not perform these compilations directly on your primary workstation. Use an isolated Ubuntu environment via Docker to ensure build variables remain pure:

# Initialize clean development environment
docker run -it -v $(pwd):/workspace ubuntu:22.04 /bin/bash
cd /workspace
# Install underlying build tooling
apt-get update && apt-get install -y git python3 g++ make curl python3-pip wget unzip

## Phase 2: Pull Node Upstream and Cherry-Pick Mobile Integration Layers
Instead of trying to manually rewrite mobile platform hooks from scratch, clone the official Node LTS project repository and layer the core initialization structural components directly over it.

# Clone clean, verified Node 22 LTS Release
git clone --depth 1 --branch v22.19.0 https://github.com
cd node
# Fetch the specific structural architecture from nodejs-mobile
git remote add mobile https://github.com
git fetch mobile update22-9-0
# Check out the core target mobile integration files explicitly
git checkout mobile/update22-9-0 -- src/node_main.cc
git checkout mobile/update22-9-0 -- tools/gyp/pylib/gyp

## Phase 3: Implement the Essential Custom Build Configurations
Configure the cross-compilation pipeline toolchain. Use an NDK build tree matching your production environment specifications:

# Pull down the target Android NDK toolset
wget https://google.com
unzip android-ndk-r26d-linux.zip
export ANDROID_NDK_HOME=$(pwd)/android-ndk-r26d
# Configure paths to use the native Android Toolchain binaries
export CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang
export CXX=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang++
# Run compilation setup sequence enabling full Intl components
./configure \
    --dest-cpu=arm64 \
    --dest-os=android \
    --shared \
    --with-intl=small-icu \
    --without-npm \
    --without-snapshot

Note on options: Enabling --without-snapshot is necessary because it disables V8’s custom startup compilation steps. This completely avoids the host/target execution blocker where cross-compiled binaries try to run on your host computer during the build pipeline.
## Phase 4: Execute Compilation Sequence

# Compile library natively using host processor cores
make -j$(nproc) out/Release/lib.target/libnode.so

Once compilation completes, extract the compiled file from out/Release/lib.target/libnode.so and drop it directly into your Plawie development tree.
------------------------------
## Integrating the Safe Test Architecture into Plawie
To safely execute your experimental network endpoint without threatening the stability of your core UI layout process, run the embedded native binary inside an isolated background execution layer.

+-------------------------------------------------------+

|                 Plawie Flutter UI                     |
|                                                       |
|  [ Dart Main UI Process ]                             |
|          |                                            |
|          v (Spawns)                                   |
|  [ Android Isolated Process (:background_node) ]      |
|          |                                            |
|          v (Loads via FFI)                            |
|    libnode.so ----> Binds strictly to 127.0.0.1:18790  |
+-------------------------------------------------------+

## 1. Define Isolated Environment Layer
Declare a dedicated background isolation context within your main android/app/src/main/AndroidManifest.xml file. This tells the mobile OS to launch the engine within a distinct memory partition:

<service
    android:name=".BackgroundNodeService"
    android:process=":background_node"
    android:foregroundServiceType="specialUse"
    android:exported="false" />

## 2. Execute via Isolated Dart Worker Processes
Avoid invoking dynamic FFI components inside your primary UI initialization script. Spin up an independent worker execution lane to run the background service:

import 'dart:ffi';import 'dart:isolate';
void initializeNativeNodeWorker(SendPort mainAppProgressPort) {
  // Access the compiled cross-platform library boundary
  final DynamicLibrary nodeRuntime = DynamicLibrary.open("libnode.so");

  // Map the foundational entry initialization functions 
  final int Function(int argc, Pointer<Pointer<Utf8>> argv) nodeStart =
      nodeRuntime
          .lookup<NativeFunction<Int32 Function(Int32, Pointer<Pointer<Utf8>>)}}>>("node_start")
          .asFunction();

  // Establish isolated execution environment loop
  // Pass configuration params ensuring loopback locks to port 18790
}

------------------------------
## Alternatives & Distribution Concerns

* Licensing Guidelines: Shipping your custom-compiled libnode.so binary is fully compliant with open-source distribution requirements. Upstream Node.js uses the permissive MIT License, which allows you to redistribute modified binaries directly inside a production APK wrapper without requiring you to open-source your entire internal Flutter codebase.
* The Termux Alternative Sourcing Strategy: If your custom build pipeline hits compilation walls, you can extract pre-built, highly stable binaries directly from public package distribution servers. Pull the compiled aarch64 package structures directly from the Termux Node Packages Index. You can unpack the compiled archive file layout using standard extraction utilities to retrieve an aarch64 native runtime environment without running local compilation tasks.
* 

If you hit specific compilation or linkage blocks, tell me:

* What exact error trace occurs if you remove --without-snapshot?
* Do you want to review the full Dart FFI type mapping required to pass startup arguments to node_start?
* 


[1] [https://github.com](https://github.com/nodejs-mobile/nodejs-mobile/releases)
[2] [https://github.com](https://github.com/nodejs-mobile/nodejs-mobile/pulls)
[3] [https://github.com](https://github.com/nodejs-mobile/nodejs-mobile/activity)
[4] [https://github.com](https://github.com/nodejs/node/issues/34115)
[5] [https://nodejs-mobile.github.io](https://nodejs-mobile.github.io/docs/guide/guide-android/getting-started/)


=========================================================================================================


**Here is the direct, primary-source-based answer to your research task (as of May 2026).**

### 1. Does nodejs-mobile have any branch, fork, PR, artifact, or CI run for Node >=22.19.0?
**No.**  
- Main repo (`nodejs-mobile/nodejs-mobile`) latest release is still **v18.20.4** (Oct 2024).  
- The only higher branch is **`update22-9-0`** (targets exactly **Node 22.9.0**). Your commit `106c51f95d55d1010de56a2ffd09bfb4ba819a47` is on this branch.  
- No PRs, forks, or artifacts found for 22.19+, 22.22.x, or 24.x in public nodejs-mobile repos. No active CI runs for newer versions.

Primary sources:  
- https://github.com/nodejs-mobile/nodejs-mobile  
- https://github.com/nodejs-mobile/nodejs-mobile/tree/update22-9-0

### 2. What exact patches does nodejs-mobile apply to upstream Node 22 for Android?
In the `update22-9-0` branch, the `android-patches/` directory contains **only one patch**:  
- `trap-handler.h.patch` (V8 trap/signal handler fix required for Android — prevents crashes on certain memory/execution traps).  

This is the **essential** patch. Historical nodejs-mobile patches (build system, path handling, etc.) appear to have been minimized or upstreamed in newer Node.

Primary source: https://github.com/nodejs-mobile/nodejs-mobile/tree/update22-9-0/android-patches

(Note: Upstream Node itself now maintains a similar `android-patches/trap-handler.h.patch` as of v22.22.1 → https://github.com/nodejs/node/blob/main/android-patches/trap-handler.h.patch)

### 3. Can those patches be cleanly rebased from Node 22.9.0 to Node 22.22.3 or latest Node 22 LTS?
**Yes, very likely cleanly.**  
Only one small V8 patch is needed, and upstream Node has already incorporated an equivalent `trap-handler.h.patch`. Rebase should be straightforward (minimal conflict expected on build files).  
**Intl/ICU**: The old `--with-intl=none` flag in nodejs-mobile is **not required**. You can build with full ICU (remove the flag). It will increase `libnode.so` size but should work. What breaks with `--with-intl=none`: Full `Intl` API (locale formatting, collation, etc.). Check if OpenClaw/providers actually use heavy Intl features.

### 4. Known blockers in V8/Node Android builds for Node 22.19+?
Main historical blockers (V8 host/target tools, trap handler, ARM64 assembly):  
- Trap handler is now handled (see patch above).  
- Cross-compilation toolchain mismatches (host assembler vs target) were common with older NDK.  
- No major new blockers reported for 22.19+ in public sources.

### 5. Embedded `libnode.so` vs standalone Android arm64 `node` executable?
**Embedded `libnode.so` is the less painful and more realistic route for Plawie.**  
- It is exactly what nodejs-mobile was designed for (JNI → `node::Start()`).  
- Standalone `node` executable is possible but harder to integrate cleanly into a Flutter APK (you'd still need to exec it in a separate process for isolation).  
- Your current PRoot already gives isolation; embedded is acceptable for the first `/health` milestone (you can later move it to an isolated Android Service/Process if crashes are an issue).

### 6. What NDK version is best for Node 22 Android builds?
- nodejs-mobile CI historically used **NDK r26d** + SDK 24.  
- Your app uses **NDK 28.2.13676358** + minSdk 29.  
**Recommendation**: Start with **NDK r26d** (or r26c) for the initial rebase/build. Newer NDK 28+ often requires extra toolchain flags or patches for V8/Node build system. Once it works on r26d, try bumping to r28.

### 7. Full ICU/Intl on Android Node 22?
Yes — full ICU works (remove `--with-intl=none`). nodejs-mobile disabled it mainly for binary size and build simplicity. Nothing fundamentally breaks on Android if you enable it.

### 8. Safest build recipe for Android arm64 `libnode.so` at Node >=22.19.0?
1. Clone `https://github.com/nodejs-mobile/nodejs-mobile`  
2. `git checkout update22-9-0`  
3. Update the Node source to v22.22.3 (or latest 22.x LTS) inside the tree.  
4. Re-apply/adapt the single `trap-handler.h.patch` (it should be near-clean).  
5. Use their build scripts (`android-configure`, `android_configure.py`, or GN-based `BUILD.gn`).  
6. Build with NDK r26d first.  
7. Output → `lib/<ABI>/libnode.so` (arm64-v8a).  

No public prebuilt artifact exists for >=22.19.0.

### 9. Licensing/distribution concerns for shipping custom `libnode.so` in APK?
None significant. Node.js is **MIT-licensed**. You must include the license text (standard practice). No restrictions on shipping modified `libnode.so` in an Android app.

### 10. Alternatives that already support Node >=22.19.0?
- **Best proven alternative right now**: The **AVF Linux VM (Debian arm64)** approach (exactly what your `justforfun-2025/androidclaw` repo switched to). It runs full native **Node 22.22.0+** (via nodesource) with zero stubs/polyfills and full native modules/Playwright.  
  See: https://github.com/justforfun-2025/androidclaw (archived `app-nodejs-mobile` vs current VM path).  
- Termux builds Node 22 natively (their `termux-packages` recipes), but it's for Termux environment, not easy to extract as embeddable `libnode.so`.  
- No active maintained forks of nodejs-mobile for 22+. Javet/LiquidCore are either V8-only or outdated.

### Most Important Answers (Your Priority List)
- **No ready Node >=22.19.0 mobile fork/artifact** exists publicly.  
- **Essential patch**: Only `trap-handler.h.patch`.  
- **Rebase to v22.22.3 without disabling Intl**: Yes — feasible and recommended.  
- **Executable vs embedded**: Embedded `libnode.so` is less painful for Flutter integration.  
- **NDK r26d vs r28c**: Use **r26d** first for success; r28 later.

**Next step recommendation**:  
Build the `update22-9-0` branch as-is first (get `/health` working on 22.9.0). Then rebase to 22.22.3 + full Intl. Paste any build errors here and I’ll help debug the exact commands/flags.

This path is alive and the cleanest long-term way to drop PRoot. The AVF VM is the nuclear “it just works” option if you want to skip the rebase entirely.
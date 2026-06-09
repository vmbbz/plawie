# Android Terminal Tmux Payload

OpenClaw bundles one APK-local Android arm64 `tmux` payload to satisfy the
`android-terminal-pack` dependency pack. The payload is intentionally narrow:
only the executable and the shared libraries required by the ELF loader are
bundled.

```text
Package source: Termux official apt repository
Repository index: https://packages.termux.dev/apt/termux-main/dists/stable/main/binary-aarch64/Packages.gz
Termux package version: 3.6b
Runtime-reported version: tmux 3.6a
APK pack id: android-terminal-pack
APK pack version: termux-tmux-3.6b-apk-v1
Primary smoke: LD_LIBRARY_PATH=<managed .openclaw/lib> tmux -V
```

The runtime-reported version is recorded separately because the verified Termux
package metadata says `3.6b`, while `tmux -V` on the device prints `tmux 3.6a`.
The APK readiness gate follows the real on-device command result.

## Termux Package Inputs

```text
tmux
  version: 3.6b
  filename: pool/main/t/tmux/tmux_3.6b_aarch64.deb
  sha256: d52ab2155b036d03b47cfb824be41e9fe4fe67b80b457716d81faa38ec1c7319
  depends: ncurses, libevent, libandroid-support, libandroid-glob

ncurses
  version: 6.6.20260307+really6.5.20250830
  filename: pool/main/n/ncurses/ncurses_6.6.20260307+really6.5.20250830_aarch64.deb
  sha256: f44bbfdc3d42ec0217bffa978309390e59cea5a48a9a83226d4a496c42ad0b99

libevent
  version: 2.1.12-3
  filename: pool/main/libe/libevent/libevent_2.1.12-3_aarch64.deb
  sha256: 9db37dd4a000ae43eff4e87422e5280be9b6348581702f582d2fe8bddc0f4572

libandroid-support
  version: 29-1
  filename: pool/main/liba/libandroid-support/libandroid-support_29-1_aarch64.deb
  sha256: f2f145d6135ad4843ac9670153be3e3944dc1e6f1736d46d2306c28f2b86f517

libandroid-glob
  version: 0.6-3
  filename: pool/main/liba/libandroid-glob/libandroid-glob_0.6-3_aarch64.deb
  sha256: 2276ae8adedf0db76c2f4ffc94cc4cceb2f4f5d78e021b54e2e046d1233e7826
```

## APK Payload Files

```text
assets/openclaw/terminal/bin/tmux
  bytes: 986016
  sha256: 9db38fdb4178abd13d19a32f40d265b61473694487e5c6ffc60e43ba11f1ca96

assets/openclaw/terminal/lib/libandroid-glob.so
  bytes: 10536
  sha256: e47405b23e40aea9bd5aad4c3cbf518065cba8ef1c4e24c8aae7fd77e10fe850

assets/openclaw/terminal/lib/libandroid-support.so
  bytes: 20736
  sha256: 739cf829511d71dafd6c67fdbb70f3f0c6048642ea2e1967790ee961fde14430

assets/openclaw/terminal/lib/libevent_core-2.1.so
  bytes: 192056
  sha256: 3e5697cf20492127371704d935ef8c7538a6ea82a6dd0fc9b427f8a55b8001f3

assets/openclaw/terminal/lib/libncursesw.so.6
  bytes: 384496
  sha256: 795f855f5a988d9e89116847b2c9aa03720cedbc02026259ca735be25398c4c5
```

`libncursesw.so.6` is copied from the Termux package file
`libncursesw.so.6.5` because its ELF SONAME is `libncursesw.so.6`, and `tmux`
declares `NEEDED libncursesw.so.6`.

## ELF Loader Proof

Device `readelf -d` on the extracted Termux payload reported:

```text
tmux RUNPATH:
  /data/data/com.termux/files/usr/lib:/data/data/com.termux/files/usr/lib
tmux NEEDED:
  libandroid-support.so
  libandroid-glob.so
  libncursesw.so.6
  libevent_core-2.1.so
  libm.so
  libc.so
```

The pack smoke uses `LD_LIBRARY_PATH` pointing at managed `.openclaw/lib`, so
the absolute Termux RUNPATH does not require the Termux app prefix.

## Rebuild

Use:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/terminal/build_tmux_termux_payload.ps1
```

The script downloads the pinned Termux `.deb` files, verifies SHA256 values,
extracts only the files listed above, and prints payload hashes.

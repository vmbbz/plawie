# AVF Linux VM Runtime Option

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## Decision Summary

AVF is now a first-class runtime research lane for Plawie.

It is not a universal PRoot replacement, but it is the strongest known path for
running full upstream OpenClaw on eligible Android devices because it keeps a
real Linux userspace instead of forcing OpenClaw through Android/Bionic
compatibility.

The practical runtime lanes are now:

| Lane | Role | Current verdict |
| --- | --- | --- |
| PRoot | Universal production fallback | Keep default |
| AVF Linux VM | Full-fidelity OpenClaw on eligible devices | Best full-feature candidate |
| Embedded `libnode.so` | Broad-device lightweight native runtime | Still research; not full OpenClaw yet |
| Standalone Android Node executable | Isolated native process | Keep as lower-priority research |

## Primary Sources Checked

| Source | Finding |
| --- | --- |
| `https://github.com/justforfun-2025/androidclaw` | Public `main` branch exists at commit `da863001763003030d29ea2808ddba3a6cccdea2` |
| `androidclaw/README.md` | Documents current AVF/Debian VM architecture, Node `22.22.0`, OpenClaw `2026.2.9`, Playwright + Chromium, and VM bridge `192.168.0.2:18790` |
| `androidclaw/app-nodejs-mobile/README.md` | Documents the archived embedded nodejs-mobile lane and why it was abandoned |
| `androidclaw/app-proxy/README.md` | Documents a VM-to-Android proxy app for screenshot/input/app control, but requires privileged/system-app installation |
| Android AVF docs | AVF is Android's virtualization stack for protected/isolated VMs: `https://source.android.com/docs/core/virtualization` |

## What AVF Solves

AVF solves the hard part that embedded `libnode.so` does not:

- Node `>=22.19.0` works through normal Debian/NodeSource installation.
- Native npm modules are Linux arm64 packages, not Android/Bionic rebuilds.
- Playwright and Chromium can run in the Linux VM.
- OpenClaw can run upstream with far fewer stubs, polyfills, or bundle rewrites.
- Gateway crashes are isolated from the Flutter process.

For full OpenClaw parity, AVF is currently more realistic than embedded Node.

## What AVF Does Not Solve

AVF is not free:

- device support is limited;
- setup may depend on Android's Terminal/Linux VM app;
- resource use is higher than embedded Node or PRoot;
- the VM has its own filesystem, lifecycle, networking, logs, and secrets;
- Android device skills need a bridge back to the app;
- privileged control APIs from the reference proxy are not shippable for normal
  users as-is because they require shell UID/system-app installation.

AVF should therefore be an eligibility-gated runtime, not the default for every
device.

## Plawie Integration Shape

The safe Plawie shape is:

```text
Flutter UI
  -> GatewayRuntime
  -> AvfGatewayRuntime diagnostics/canary
  -> AVF Debian VM
  -> OpenClaw on VM port 18790
  -> Android node/device bridge back to Plawie app
```

The Android node/device bridge is the part where AndyClaw-style patterns are
useful: Gateway WebSocket callbacks, app-native capability tiers, permission
gates, and optional Termux/extension sidecars. Those patterns should live in
Plawie, not inside the VM, unless a future privileged-device build explicitly
allows a deeper VM-to-Android proxy.

During research:

- PRoot remains production on `127.0.0.1:18789`.
- AVF must use a non-production endpoint first, normally
  `http://192.168.0.2:18790` / `ws://192.168.0.2:18790`.
- Plawie should probe AVF readiness before offering it.
- Plawie must not assume `192.168.0.2` forever; it should be configurable or
  discovered when possible.

## Minimum AVF Eligibility Checks

When a device is connected, run:

```powershell
.\scripts\avf\check_avf_eligibility.ps1
```

The checker records:

- connected ADB device;
- Android release and SDK;
- device manufacturer/model;
- hypervisor support props;
- presence of virtualization/terminal packages;
- optional reachability of `192.168.0.2:18790`.

Important props/packages to inspect:

```text
ro.boot.hypervisor.protected_vm.supported
ro.boot.hypervisor.vm.supported
com.android.virt.terminal
com.android.virtualization
```

Absence of any single signal should not be treated as final proof of no AVF,
because OEM builds vary. It is an eligibility screen, not a legal judgment.

## Runtime Strategy

AVF becomes the first candidate for full OpenClaw parity on eligible devices.

Embedded `libnode.so` remains useful because:

- it may work on more Android devices;
- it can be much lighter;
- it may support cloud chat, routing, and app-native tools without browser or
  desktop modules;
- it gives Plawie a native runtime option where AVF is unavailable.

That means the sane product plan is:

```text
Default: PRoot
Eligible high-end/beta: AVF VM
Future broad-device native: embedded libnode
```

## Next Safe Phase

The next implementation phase should not boot or mutate AVF automatically.

Build these first:

1. A Plawie AVF eligibility diagnostic.
2. A hidden AVF endpoint probe that checks a configured host/port.
3. A read-only AVF runtime status panel/log lane.
4. A manual setup guide for users with eligible devices.
5. Only after that, a canary `AvfGatewayRuntime` that can talk to a VM Gateway
   without changing production PRoot state.

## Open Questions

1. Can Plawie programmatically start/stop the Android Terminal AVF VM, or is
   user interaction required?
2. Can VM port forwarding/discovery be made reliable without root/ADB?
3. What is the minimum Android/API/device matrix for the Terminal VM?
4. How should Plawie sync provider keys into the VM without leaking secrets?
5. Should Android node/device skills stay in the app and connect to VM
   OpenClaw, or should a VM-side proxy call back into Plawie?
6. Can the AVF lane be packaged for non-Pixel devices in a supportable way?
7. Which AndyClaw-style Gateway client or capability bridge patterns are worth
   reimplementing in Plawie for VM-to-app `node.invoke`?

## Non-Negotiables

- Do not replace PRoot with AVF globally.
- Do not assume all users have AVF-capable Android 15+ devices.
- Do not use privileged shell/system-app proxy requirements in normal builds.
- Do not route user chat to AVF until manual readiness and parity checks pass.
- Do not store provider keys in the VM without explicit user consent.

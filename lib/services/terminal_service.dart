import 'package:flutter/services.dart';
import '../constants.dart';

/// Provides proot shell configuration for the terminal and onboarding screens.
/// Must match ProcessManager.kt's gateway mode (command_login) exactly.
class TerminalService {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  static const _fakeKernelRelease = '6.17.0-PRoot-Distro';
  static const _fakeKernelVersion =
      '#1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000';

  /// Get paths and host-side proot environment variables.
  /// Host env should ONLY contain proot-specific vars — guest env is
  /// set via `env -i` inside the command, matching proot-distro.
  static Future<Map<String, String>> getProotShellConfig() async {
    final filesDir = await _channel.invokeMethod<String>('getFilesDir') ?? '';
    final nativeLibDir = await _channel.invokeMethod<String>('getNativeLibDir') ?? '';
    final arch = await _channel.invokeMethod<String>('getArch') ?? 'aarch64';

    final rootfsDir = '$filesDir/rootfs/ubuntu';
    final tmpDir = '$filesDir/tmp';
    final configDir = '$filesDir/config';
    final homeDir = '$filesDir/home';
    final prootPath = '$nativeLibDir/libproot.so';
    final libDir = '$filesDir/lib';

    return {
      'executable': prootPath,
      'rootfsDir': rootfsDir,
      'tmpDir': tmpDir,
      'configDir': configDir,
      'homeDir': homeDir,
      'libDir': libDir,
      'nativeLibDir': nativeLibDir,
      'arch': arch,
      // Host-side proot env — ONLY proot-specific vars.
      // Do NOT set PROOT_NO_SECCOMP (proot-distro doesn't set it).
      // Do NOT set HOME/TERM/LANG here (those go in guest env via env -i).
      'PROOT_TMP_DIR': tmpDir,
      'PROOT_LOADER': '$nativeLibDir/libprootloader.so',
      'PROOT_LOADER_32': '$nativeLibDir/libprootloader32.so',
      'LD_LIBRARY_PATH': '$libDir:$nativeLibDir',
    };
  }

  /// Build proot arguments matching ProcessManager.kt's gateway mode
  /// (proot-distro command_login). Uses `env -i` for a clean guest
  /// environment — prevents Android JVM vars from leaking into proot.
  static List<String> buildProotArgs(Map<String, String> config,
      {int columns = 80, int rows = 24}) {
    final procFakes = '${config['configDir']}/proc_fakes';
    final sysFakes = '${config['configDir']}/sys_fakes';
    final rootfsDir = config['rootfsDir']!;

    // Detect architecture for uname struct
    final String arch = config['arch'] ?? 'aarch64';
    final String machine = arch == 'arm' ? 'armv7l' : arch;

    // Full uname struct matching proot-distro command_login
    final kernelRelease = '\\Linux\\localhost\\$_fakeKernelRelease'
        '\\$_fakeKernelVersion\\$machine\\localdomain\\-1\\';

    final flags = [
      // proot-distro command_login style
      '--change-id=0:0',
      '--sysvipc',
      '--kernel-release=$kernelRelease',
      '--link2symlink',
      '-L',
      '--kill-on-exit',
      '--rootfs=$rootfsDir',
      '--cwd=/root',
      // Core device binds (matching proot-distro)
      '--bind=/dev',
      '--bind=/dev/urandom:/dev/random',
      '--bind=/proc',
      '--bind=/proc/self/fd:/dev/fd',
      '--bind=/proc/self/fd/0:/dev/stdin',
      '--bind=/proc/self/fd/1:/dev/stdout',
      '--bind=/proc/self/fd/2:/dev/stderr',
      '--bind=/sys',
      // Fake /proc entries
      '--bind=$procFakes/loadavg:/proc/loadavg',
      '--bind=$procFakes/stat:/proc/stat',
      '--bind=$procFakes/uptime:/proc/uptime',
      '--bind=$procFakes/version:/proc/version',
      '--bind=$procFakes/vmstat:/proc/vmstat',
      '--bind=$procFakes/cap_last_cap:/proc/sys/kernel/cap_last_cap',
      '--bind=$procFakes/max_user_watches:/proc/sys/fs/inotify/max_user_watches',
      '--bind=$procFakes/fips_enabled:/proc/sys/crypto/fips_enabled',
      // Shared memory (proot-distro binds rootfs/tmp to /dev/shm)
      '--bind=$rootfsDir/tmp:/dev/shm',
      // SELinux override
      '--bind=$sysFakes/empty:/sys/fs/selinux',
      // App-specific binds
      '--bind=${config['configDir']}/resolv.conf:/etc/resolv.conf',
      '--bind=${config['homeDir']}:/root/home',
      '--bind=$rootfsDir:$rootfsDir', // CRITICAL: Self-bind for absolute paths
    ];

    // Hardware acceleration binds (GPU)
    for (final dev in ['/dev/kgsl-3d0', '/dev/mali0', '/dev/dri']) {
      // Note: We can't use File(dev).exists() synchronously here easily for all,
      // but we can pass them as args; if they don't exist PRoot usually just warns.
      // However, for stability, let's just match ProcessManager.kt logic if we could.
      // Since this is Dart, we'll keep it to the confirmed ones.
    }
    
    // Add guest environment and command
    flags.addAll([
      '/usr/bin/env', '-i',
      'HOME=/root',
      'USER=root',
      'LANG=C.UTF-8',
      'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      'TERM=xterm-256color',
      'TMPDIR=/tmp',
      'COLUMNS=$columns',
      'LINES=$rows',
      'NODE_OPTIONS=--require /root/.openclaw/bionic-bypass.js',
      '/bin/bash',
      '-l',
    ]);

    return flags;
  }

  /// Host-side environment map for Pty.start().
  /// Only proot-specific vars — no guest vars (those are in env -i).
  static Map<String, String> buildHostEnv(Map<String, String> config) {
    return {
      'PROOT_TMP_DIR': config['PROOT_TMP_DIR']!,
      'PROOT_LOADER': config['PROOT_LOADER']!,
      'PROOT_LOADER_32': config['PROOT_LOADER_32']!,
      'LD_LIBRARY_PATH': config['LD_LIBRARY_PATH']!,
    };
  }
}

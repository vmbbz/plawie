import contextlib
import ctypes
import io
import json
import os
import runpy
import sys
import traceback


def _as_list(value):
    if isinstance(value, list):
        return [str(item) for item in value]
    return []


def _apply_sys_path(paths):
    for raw_path in reversed(_as_list(paths)):
        if raw_path and raw_path not in sys.path:
            sys.path.insert(0, raw_path)


def _native_lib_sort_key(path):
    name = os.path.basename(path).lower()
    if name == "libc++_shared.so" or name.startswith("libc++_shared"):
        return (0, name)
    if name.startswith("libgfortran"):
        return (1, name)
    if name.startswith("libquadmath"):
        return (2, name)
    if name.startswith("libopenblas"):
        return (3, name)
    return (10, name)


def _native_lib_dirs(paths):
    seen = set()
    result = []
    for root in _as_list(paths):
        if not root or not os.path.isdir(root):
            continue
        candidates = [os.path.join(root, "chaquopy", "lib")]
        try:
            for name in os.listdir(root):
                if name.endswith(".libs"):
                    candidates.append(os.path.join(root, name))
        except OSError:
            pass
        for directory in candidates:
            if directory in seen or not os.path.isdir(directory):
                continue
            seen.add(directory)
            result.append(directory)
    return result


def _preload_native_libs(paths):
    libs = []
    for directory in _native_lib_dirs(paths):
        try:
            libs.extend(
                os.path.join(directory, name)
                for name in os.listdir(directory)
                if name.endswith(".so") or ".so." in name
            )
        except OSError:
            continue
    mode = getattr(os, "RTLD_GLOBAL", 0)
    mode |= getattr(os, "RTLD_NOW", 0)
    for lib in sorted(libs, key=_native_lib_sort_key):
        try:
            ctypes.CDLL(lib, mode=mode)
        except OSError:
            # The import smoke/test path reports the actual failing module.
            # Some wheels ship optional sidecar libraries for other ABIs.
            pass


def _run_pip(args):
    # Runtime network installs are intentionally not performed from inside the
    # Python bridge. Skill dependencies are satisfied by the verified Native
    # dependency pack provisioner, then this command acts as a compatibility
    # shim for skills whose setup text still invokes pip.
    action = args[0] if args else "help"
    if action in {"install", "list", "show", "check", "--version", "-V"}:
        return 0, (
            "OpenClaw Native Python: pip is managed by verified dependency "
            "packs; requested pip command treated as already provisioned.\n"
        ), ""
    return 1, "", (
        "OpenClaw Native Python only permits provisioner-managed pip commands "
        f"inside skills, got: {' '.join(args)}\n"
    )


def run(payload_json):
    payload = json.loads(payload_json or "{}")
    args = _as_list(payload.get("args"))
    cwd = payload.get("cwd")
    env = payload.get("env") if isinstance(payload.get("env"), dict) else {}
    python_paths = _as_list(payload.get("pythonPaths"))

    stdout = io.StringIO()
    stderr = io.StringIO()
    old_argv = sys.argv[:]
    old_cwd = os.getcwd()
    old_env = os.environ.copy()

    exit_code = 0
    try:
        if cwd:
            os.chdir(str(cwd))
        for key, value in env.items():
            if value is None:
                os.environ.pop(str(key), None)
            else:
                os.environ[str(key)] = str(value)
        _apply_sys_path(python_paths)
        _preload_native_libs(python_paths)

        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            if not args:
                print("OpenClaw Native Python bridge ready")
            elif args[0] == "-c":
                if len(args) < 2:
                    raise ValueError("python -c requires code")
                sys.argv = ["-c", *args[2:]]
                exec(compile(args[1], "<openclaw-python-bridge>", "exec"), {
                    "__name__": "__main__",
                    "__file__": "<openclaw-python-bridge>",
                    "__package__": None,
                })
            elif args[0] == "-m":
                if len(args) < 2:
                    raise ValueError("python -m requires a module name")
                module = args[1]
                if module == "pip":
                    exit_code, pip_stdout, pip_stderr = _run_pip(args[2:])
                    stdout.write(pip_stdout)
                    stderr.write(pip_stderr)
                else:
                    sys.argv = [module, *args[2:]]
                    runpy.run_module(module, run_name="__main__", alter_sys=True)
            elif args[0] in {"--version", "-V"}:
                print(sys.version)
            else:
                script = args[0]
                sys.argv = [script, *args[1:]]
                runpy.run_path(script, run_name="__main__")
    except SystemExit as error:
        code = error.code
        if isinstance(code, int):
            exit_code = code
        elif code is None:
            exit_code = 0
        else:
            exit_code = 1
            stderr.write(str(code))
            stderr.write("\n")
    except BaseException:
        exit_code = 1
        stderr.write(traceback.format_exc())
    finally:
        sys.argv = old_argv
        try:
            os.chdir(old_cwd)
        except Exception:
            pass
        os.environ.clear()
        os.environ.update(old_env)

    return json.dumps({
        "ok": exit_code == 0,
        "exitCode": exit_code,
        "stdout": stdout.getvalue(),
        "stderr": stderr.getvalue(),
        "runtime": "chaquopy-python-bridge",
        "python": sys.version,
    })

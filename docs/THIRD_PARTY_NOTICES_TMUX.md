# Third-Party Notices: Tmux Terminal Pack

OpenClaw bundles an APK-local Android arm64 `tmux` executable and the minimum
shared libraries needed for `tmux -V` under the `android-terminal-pack`.

```text
primary component: tmux
Termux package version: 3.6b
runtime-reported version: tmux 3.6a
payload: assets/openclaw/terminal/bin/tmux
payload sha256: 9db38fdb4178abd13d19a32f40d265b61473694487e5c6ffc60e43ba11f1ca96
```

Bundled shared libraries:

```text
libandroid-glob.so
libandroid-support.so
libevent_core-2.1.so
libncursesw.so.6
```

Upstream and license references:

- tmux: https://github.com/tmux/tmux
- tmux license: ISC-style license in the tmux source tree
- Termux tmux package recipe: https://github.com/termux/termux-packages/blob/master/packages/tmux/build.sh
- libevent: https://libevent.org/
- libevent license: BSD-style license in the libevent source tree
- ncurses: https://invisible-island.net/ncurses/
- ncurses license: permissive ncurses license
- libandroid-support: https://github.com/termux/libandroid-support
- libandroid-glob package source: Termux package recipe and Android/Bionic
  compatibility library source used by Termux

Release packaging must keep this notice and
`docs/ANDROID_TERMINAL_TMUX_PAYLOAD.md` with the app's third-party notices or
source/provenance materials.

# Termux ARM64 Neovim C++ IDE and Ubuntu Chroot

## Overview

This setup provides:

- A lightweight Neovim C++ IDE running natively in Termux.
- Native C++20 compilation through `g++` only.
- clangd-based completion and diagnostics.
- LuaSnip snippets, auto-pairing, and Blink completion.
- A competitive-programming (CP) build/run workflow.
- An Ubuntu 24.04 ARM64 command-line chroot.
- A safe file-sharing design that never bind-mounts Android FUSE storage into the chroot.

## Environment

| Item | Value |
| --- | --- |
| Device architecture | ARM64 |
| Termux prefix | `/data/data/com.termux/files/usr` |
| Neovim config | `/data/data/com.termux/files/home/.config/nvim` |
| Neovim | `v0.12.6` |
| Termux UID/GID | `10368` |
| Termux g++ / clang++ | clang `21.1.8` wrappers |
| Native clangd | `21.1.8` |
| Ubuntu rootfs | `/data/local/chroot/ubuntu` |
| Ubuntu user | `lamlam`, UID `1000`, primary GID `100` |
| Ubuntu g++ | `13.3.0` |
| Ubuntu clang/clangd | `18.1.3` |
| Root provider | KernelSU + BusyBox |
| Leader key | `<Space>` |

There is no F5/F6/F7 dependency. The editor is designed for terminal use on Android.

## Neovim Layout

```text
~/.config/nvim/
├── init.lua
├── install.sh
├── install-stl.sh
├── lua/
│   ├── config/
│   │   ├── cp.lua
│   │   ├── keymaps.lua
│   │   ├── lazy.lua
│   │   ├── lsp.lua
│   │   ├── options.lua
│   │   └── pairs.lua
│   ├── plugins/
│   │   └── editor.lua
│   └── snippets/
│       └── cpp.lua
└── summary.md
```

## Installation Scripts

The setup is split into two independent scripts:

- `install.sh`: installs or updates the Ubuntu 24.04 ARM64 chroot, launcher, sudo setup, shared directory, and file-exchange helpers.
- `install-stl.sh`: installs the native Termux `bits/stdc++.h` compatibility header. It does not touch the Ubuntu chroot.

Run them separately:

```bash
cd ~/.config/nvim
./install-stl.sh
./install.sh
```

## Plugins

Managed by `lazy.nvim`:

- `LuaSnip`
- `saghen/blink.cmp` pinned to `v1.10.2`
- `akinsho/bufferline.nvim`
- `nvim-lualine/lualine.nvim`
- `echasnovski/mini.icons`
- `nvim-tree/nvim-tree.lua`
- `Mofiqul/vscode.nvim`

`matchparen` and `matchit` are enabled. Do not upgrade Blink to v2 without also installing `saghen/blink.lib`.

## Editor Behavior

### Options

- `cursorline = true`
- `showmatch = true`
- `matchtime = 2`
- Persistent undo under `stdpath("state")/undo`
- Conditional Termux clipboard integration
- C/C++ `commentstring` fallback
- `.cpp`, `.cc`, and `.cxx` detected as `cpp`

### Auto-pairing

Implemented in `lua/config/pairs.lua`:

- `(` inserts `()`
- `[` inserts `[]`
- `{` inserts `{}`
- `"` inserts `""`
- `'` inserts `''`
- Closing delimiters are skipped rather than duplicated.
- Backspace removes a matching pair.
- `<CR>` inside `{}`, `[]`, or `()` expands to a multi-line block.
- Pair insertion is suppressed inside strings and comments.
- A heuristic handles adjacent quote characters.

### Completion and Snips

Implemented in `lua/plugins/editor.lua`:

- `<Tab>`:
  1. Expand LuaSnip snippet if possible.
  2. Jump to the next snippet placeholder if possible.
  3. Accept the visible completion item.
  4. Otherwise fall back to normal Tab behavior.
- `<S-Tab>`:
  1. Jump to the previous snippet placeholder.
  2. Select the previous completion item.
  3. Otherwise fall back to normal Shift-Tab behavior.

The `cpp` snippet remains exactly as defined in `lua/snippets/cpp.lua`.

clangd uses:

```lua
fallbackFlags = { "-std=c++20" }
```

and is launched with `--enable-config`.

## Key Mappings

| Mapping | Mode | Action |
| --- | --- | --- |
| `<Space>e` | Normal | Toggle file explorer |
| `<Space>E` | Normal | Focus file explorer |
| `<Space>w` | Normal | Save |
| `<Space>q` | Normal | Quit window |
| `<Space>h` | Normal | Clear search highlight |
| `<Space>x` | Normal | Close buffer |
| `<S-l>` | Normal | Next buffer |
| `<S-h>` | Normal | Previous buffer |
| `<Space>j` | Normal | Move line down |
| `<Space>k` | Normal | Move line up |
| `J` / `K` | Visual | Move selection |
| `<Space>/` | Normal/Visual | Toggle comment |
| `<Space>D` | Normal/Visual | Duplicate line or selection |
| `<Space>sw` | Normal | Search word under cursor |
| `<Space>sr` | Normal | Replace word in file |
| `<Space>b` | Normal | Build |
| `<Space>R` | Normal | Rebuild |
| `<Space>r` | Normal | Build and run |
| `<Space>i` | Normal | Open input file |
| `<Space>o` | Normal | Open output file |

## C++ Build and Run

Implemented in `lua/config/cp.lua`.

Commands:

- `:CPBuild`
- `:CPRebuild`
- `:CPRun`
- `:CPInput`
- `:CPOutput`

Behavior:

- Saves the current buffer before building.
- Uses `g++` exclusively, never `gcc`.
- Default flags: `-std=c++20 -O2 -pipe`.
- Builds to a temporary executable path.
- Atomically renames the executable only after a successful build.
- Preserves the previous successful executable when compilation fails.
- Sends compiler diagnostics to the quickfix list.
- Runs in a terminal with optional `< .INP` input redirection.
- Prints `[exit N]` after execution.

The native Termux header `/data/data/com.termux/files/usr/include/bits/stdc++.h` exists and supports C++20 use of `bits/stdc++.h`, `std::ranges`, and `std::span`.

## Ubuntu Chroot

The launcher is installed at:

```text
/data/data/com.termux/files/usr/bin/ubuntu
```

Usage:

```bash
ubuntu
ubuntu --exec "whoami"
ubuntu -c "g++ --version"
ubuntu --no-shared
ubuntu --no-storage
```

The chroot is CLI-only. It does not include a desktop environment.

Installed packages include:

```text
ca-certificates curl locales tzdata g++ make libc6-dev clang clangd git cmake ninja-build sudo
```

`lamlam` has passwordless sudo. Android networking groups are added for network access.

## Safe Shared-Storage Design

### Why Android storage is not mounted

Bind-mounting Android FUSE storage into the chroot and then force-unmounting it can abort the shared FUSE connection. The observed error was:

```text
Transport endpoint is not connected
```

This affects `/sdcard` and `/storage/emulated/0`.

The safe rules are:

- Never bind-mount `/sdcard` or `/storage/emulated/0` into the chroot.
- Never run `umount -f` or `umount -lf` on Android FUSE storage.
- Never recursively change permissions or ownership on Android shared storage.
- Use the Termux-private shared directory instead.

### Shared directory

Termux host path:

```text
/data/data/com.termux/files/home/ubuntu-shared
```

Chroot path:

```text
/mnt/shared
```

Properties:

- Owner inside chroot: `lamlam`
- Host UID view: `1000` (shown by Android/Termux tools as `system`)
- Group: Termux GID `10368`
- Mode: `2770` (setgid)
- Chroot group `termux` has GID `10368`
- `lamlam` is a member of group `termux`

The directory is on Termux's ext4-backed private storage, so bind-mounting it is safe.

`UBUNTU_SHARED=/mnt/shared` is exported only when `/mnt/shared` is actually a mountpoint. With `--no-shared`, it is unset.

### Exchange helpers

Two Termux-side helpers exchange files with Android safely:

```bash
ubuntu-publish FILE_OR_DIR [...]
ubuntu-import FILE_OR_DIR [...]
```

Defaults:

- `ubuntu-publish`: `~/ubuntu-shared` -> `/sdcard/UbuntuShared`
- `ubuntu-import`: `/sdcard/UbuntuShared` -> `~/ubuntu-shared`

Both helpers:

- Refuse paths outside their allowed source root.
- Use normal Termux file copies.
- Do not mount FUSE storage.
- Do not change Android storage permissions.
- Use the private shared directory as the chroot-visible staging area.

Published files appear on Android as FUSE-owned files (for example `u0_a294:media_rw`, mode `660`). Imported files appear in `~/ubuntu-shared` as Termux-owned files (`10368:10368`, mode `660`, with group inheritance from the setgid directory). The chroot can read them because `lamlam` is in group `10368`.

## Launcher Safety

The launcher:

- Tracks every mount it creates and unmounts only those.
- Uses normal unmount first, then lazy detach only as a fallback.
- Never force-unmounts FUSE storage.
- Refuses to start if a legacy `/sdcard` bind mount is detected.
- Mounts `/dev`, `/proc`, `/sys`, `/dev/pts`, and a 256 MB `/dev/shm`.
- Mounts the private shared directory only when sharing is enabled.
- Cleans up mounts on normal exit, interrupt, or error.

If a legacy `/sdcard` mount is detected, reboot the device to clear it, then rerun `ubuntu`. Do not force-unmount Android FUSE storage.

## Verified Tests

- Neovim starts successfully and exits with status `0`.
- `.cpp`, `.cc`, and `.cxx` filetype detection works with the loaded config.
- Auto-pair basics work: `()`, `[]`, `{}`, `""`, `''`.
- `(` inside a string does not pair.
- Paired backspace works.
- `<CR>` inside braces expands to multiple lines.
- LuaSnip registers one `cpp` snippet.
- Tab expands the `cpp` snippet interactively.
- Tab accepts a visible clangd completion snippet.
- Native C++20 compilation with `bits/stdc++.h`, `std::ranges`, and `std::span` works.
- CP build produces a runnable executable.
- A failed rebuild preserves the previous executable.
- Compiler errors populate quickfix.
- Ubuntu chroot starts and runs as `lamlam`.
- Chroot g++ reports `13.3.0`.
- `/mnt/shared` is writable from the chroot.
- Files written in `/mnt/shared` are visible from Termux.
- `ubuntu-publish` copies to `/sdcard/UbuntuShared`.
- `ubuntu-import` copies into `~/ubuntu-shared`.
- The chroot can read imported files.
- `--no-shared` skips the shared mount and leaves `UBUNTU_SHARED` unset.
- Legacy `/sdcard` mount detection aborts the launcher safely.
- Launcher cleanup leaves no chroot mounts behind.
- `/sdcard` remained readable after publish/import and repeated launches.

## Known Limitations and Unverified Areas

- Android File Manager UI behavior cannot be automated from the shell. Only ownership, path, and access checks were performed.
- clangd code actions returned zero results in one headless request. This is not yet proven interactive.
- The first Tab immediately after entering Insert mode can miss Blink/LuaSnip lazy-load timing. Normal typing delay works.
- Interactive Shift-Tab was not fully automated; direct mapping tests indicate the behavior is implemented.
- Some auto-pair `<CR>` and quote tests were affected by headless/feedkeys artifacts. Direct mapping tests passed.
- Termux `termux-clipboard-set` and `termux-clipboard-get` are not currently installed, so clipboard integration is conditional.
- Neovim TUI cannot change terminal line spacing. Patched fonts are required for icons.
- During validation, Android `/sdcard` disconnected twice. The first incident was traced to bind-mount plus force-unmount. The second occurred after the installer even though it did not mount FUSE; the exact trigger was not confirmed. Both were recovered with:

```bash
su -c 'sm unmount "emulated;0"; sm mount "emulated;0"'
```

Underlying `/data/media/0` data remained intact.

## Recovery

If Android shared storage is disconnected:

```bash
su -c 'sm unmount "emulated;0"; sm mount "emulated;0"'
```

Then verify:

```bash
touch /sdcard/.storage-test && rm -f /sdcard/.storage-test
```

If a chroot mount is stale:

```bash
grep chroot/ubuntu /proc/mounts
```

Do not use `umount -f` on FUSE storage. Reboot if a legacy unsafe mount cannot be cleared normally.

## Quick Start

```bash
cd ~/.config/nvim
./install-stl.sh   # native Termux bits/stdc++.h header
./install.sh       # Ubuntu chroot and launcher
nvim

# In Neovim
<Space>b    # build
<Space>r    # build and run
<Space>i    # input file
<Space>o    # output file

# Ubuntu
ubuntu
ubuntu --exec "whoami"

# File exchange
ubuntu-publish main.cpp
ubuntu-import UbuntuShared/input.txt
```

## Safety Summary

- C++ compilation uses `g++` only.
- Android FUSE storage is never bind-mounted into the chroot.
- Android storage permissions are never changed recursively.
- The private shared directory is the only chroot-visible shared path.
- Android file exchange is performed by Termux copy helpers.

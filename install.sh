#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOTFS="${ROOTFS:-/data/local/chroot/ubuntu}"
CHROOT_PARENT="${CHROOT_PARENT:-/data/local/chroot}"
UBUNTU_USER="${UBUNTU_USER:-lamlam}"
UBUNTU_UID="${UBUNTU_UID:-1000}"
UBUNTU_GID="${UBUNTU_GID:-100}"
RELEASE="${RELEASE:-24.04}"
ROOTFS_FILE="${ROOTFS_FILE:-ubuntu-base-24.04.4-base-arm64.tar.gz}"
BASE_URL="${BASE_URL:-https://cdimage.ubuntu.com/ubuntu-base/releases/${RELEASE}/release}"
TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
LAUNCHER="$TERMUX_PREFIX/bin/ubuntu"
TERMUX_HOME="${TERMUX_HOME:-/data/data/com.termux/files/home}"
TERMUX_GID="${TERMUX_GID:-$(stat -c %g "$TERMUX_HOME" 2>/dev/null || printf '10368')}"
SHARED_HOST="${UBUNTU_SHARED_HOST:-$TERMUX_HOME/ubuntu-shared}"
SHARED_GUEST="/mnt/shared"
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SELF_DIR/$(basename -- "${BASH_SOURCE[0]}")"

log() { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2
  exit 1
}

if [ "$(id -u)" -ne 0 ]; then
  command -v su >/dev/null 2>&1 || die "su is not available. Install Termux root support (KernelSU/Magisk) first."

  log "Checking root access through su..."
  if ! su -c 'test "$(id -u)" -eq 0' >/dev/null 2>&1; then
    die "Root was denied. Open KernelSU or Magisk and grant root permission to Termux, then rerun this installer."
  fi

  BASH_BIN="${BASH:-$TERMUX_PREFIX/bin/bash}"
  [ -x "$BASH_BIN" ] || die "Cannot find the Termux bash binary."
  [ -x "$SELF" ] || chmod +x "$SELF" 2>/dev/null || true

  cmd="UBUNTU_INSTALL_REEXEC=1 $(printf '%q' "$BASH_BIN") $(printf '%q' "$SELF")"
  for arg in "$@"; do
    cmd="$cmd $(printf '%q' "$arg")"
  done
  log "Re-executing installer as root..."
  exec su -c "$cmd"
fi

[ "$(id -u)" -eq 0 ] || die "Installer is not running as root (uid=$(id -u))."

export PATH="$TERMUX_PREFIX/bin:/system/bin:/system/xbin:/data/adb/ksu/bin:/data/adb/magisk:${PATH:-}"
[ "${UBUNTU_INSTALL_REEXEC:-0}" = 1 ] && log "Root confirmed: uid=$(id -u)"

find_busybox() {
  local c
  for c in \
    /data/adb/ksu/bin/busybox \
    /data/adb/magisk/busybox \
    /system/xbin/busybox \
    /system/bin/busybox \
    "$TERMUX_PREFIX/bin/busybox"; do
    [ -x "$c" ] && {
      printf '%s\n' "$c"
      return 0
    }
  done
  command -v busybox 2>/dev/null || return 1
}

BB="$(find_busybox)" || die "BusyBox not found. Install BusyBox NDK (Magisk) or use KernelSU's bundled BusyBox."
[ -x "$BB" ] || die "BusyBox is not executable: $BB"
applets="$("$BB" --list 2>/dev/null)" || die "Cannot query BusyBox applets: $BB"
for applet in mount umount chroot tar; do
  printf '%s\n' "$applets" | grep -qx "$applet" || die "BusyBox is missing the '$applet' applet: $BB"
done
ok "BusyBox validated: $BB"

command -v curl >/dev/null 2>&1 || die "curl is missing. Run: pkg install curl"
command -v tar >/dev/null 2>&1 || die "tar is missing. Run: pkg install tar"
CURL="$(command -v curl)"
TAR="$(command -v tar)"

[ -d /data/local ] || die "/data/local is missing."
mkdir -p "$CHROOT_PARENT"
chmod 755 "$CHROOT_PARENT"
chown 0:0 "$CHROOT_PARENT"

is_mounted() {
  awk -v p="$1" '$2 == p { found = 1 } END { exit(found ? 0 : 1) }' /proc/mounts
}

CLEANUP_ACTIVE=1
CLEANUP_MOUNTS=()
cleanup_mounts() {
  [ "${CLEANUP_ACTIVE:-0}" = 1 ] || return 0
  CLEANUP_ACTIVE=0
  set +e
  local i m
  for ((i = ${#CLEANUP_MOUNTS[@]} - 1; i >= 0; i--)); do
    m="${CLEANUP_MOUNTS[i]}"
    if is_mounted "$m"; then
      if "$BB" umount "$m" 2>/dev/null; then
        log "Unmounted $m"
      elif "$BB" umount -l "$m" 2>/dev/null; then
        log "Detached $m"
      else
        warn "Could not unmount $m"
      fi
    fi
  done
  CLEANUP_MOUNTS=()
}
trap cleanup_mounts EXIT INT TERM HUP

ensure_bind() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  if is_mounted "$dst"; then
    log "Already mounted: $dst"
    return 0
  fi
  "$BB" mount --bind "$src" "$dst" || die "Failed to bind-mount $src -> $dst"
  CLEANUP_MOUNTS+=("$dst")
  log "Mounted $src -> $dst"
}

ensure_devpts() {
  local dst="$ROOTFS/dev/pts"
  mkdir -p "$dst"
  if is_mounted "$dst"; then
    log "Already mounted: $dst"
    return 0
  fi
  "$BB" mount -t devpts -o gid=5,mode=620 devpts "$dst" || die "Failed to mount devpts at $dst"
  CLEANUP_MOUNTS+=("$dst")
  log "Mounted devpts at $dst"
}

ensure_tmpfs() {
  local dst="$1" size="$2"
  mkdir -p "$dst"
  if is_mounted "$dst"; then
    log "Already mounted: $dst"
    return 0
  fi
  "$BB" mount -t tmpfs -o "size=$size,mode=1777" tmpfs "$dst" || die "Failed to mount tmpfs at $dst"
  CLEANUP_MOUNTS+=("$dst")
  log "Mounted tmpfs ($size) at $dst"
}

rootfs_arch_ok() {
  local hex
  hex="$(od -An -tx1 -j18 -N2 "$ROOTFS/bin/bash" 2>/dev/null | tr -d ' \n' || true)"
  [ "$hex" = "b700" ]
}

if [ -x "$ROOTFS/bin/bash" ] && [ -f "$ROOTFS/etc/os-release" ]; then
  log "Existing Ubuntu rootfs detected: $ROOTFS"
else
  if [ -d "$ROOTFS" ] && [ -n "$(ls -A "$ROOTFS" 2>/dev/null || true)" ]; then
    die "$ROOTFS exists but is not a usable Ubuntu rootfs. Move it aside and rerun."
  fi
  mkdir -p "$ROOTFS"
  chmod 755 "$ROOTFS"
  chown 0:0 "$ROOTFS"

  archive="$CHROOT_PARENT/$ROOTFS_FILE"
  if [ ! -f "$archive" ]; then
    log "Downloading Ubuntu $RELEASE ARM64 rootfs..."
    "$CURL" -fL --retry 3 --connect-timeout 20 \
      "$BASE_URL/$ROOTFS_FILE" -o "$archive.part" || die "Rootfs download failed."
    mv -f "$archive.part" "$archive"
  else
    log "Using cached rootfs archive: $archive"
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    if "$CURL" -fsSL --connect-timeout 20 "$BASE_URL/SHA256SUMS" -o "$CHROOT_PARENT/SHA256SUMS" 2>/dev/null; then
      expected="$(awk -v f="$ROOTFS_FILE" '$2 == f || $2 == "*" f { print $1; exit }' "$CHROOT_PARENT/SHA256SUMS")"
      if [ -n "$expected" ]; then
        actual="$(sha256sum "$archive" | awk '{print $1}')"
        [ "$actual" = "$expected" ] || die "Rootfs checksum mismatch."
        ok "Rootfs checksum verified."
      else
        warn "Rootfs checksum not listed in SHA256SUMS; continuing."
      fi
    else
      warn "Could not download SHA256SUMS; skipping checksum verification."
    fi
  fi

  log "Extracting rootfs (this can take a minute)..."
  "$TAR" -xpf "$archive" -C "$ROOTFS" --numeric-owner || die "Rootfs extraction failed."
  rm -f "$archive"
  ok "Ubuntu rootfs extracted."
fi

rootfs_arch_ok || die "Rootfs is not ARM64 (expected ELF e_machine AArch64): $ROOTFS/bin/bash"
ok "Rootfs architecture: ARM64"

log "Preparing mounts..."
"$BB" mount -o remount,dev,suid /data 2>/dev/null || warn "Could not remount /data with dev,suid; continuing."
mkdir -p "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/dev/pts" "$ROOTFS/dev/shm" "$ROOTFS$SHARED_GUEST"
ensure_bind /dev "$ROOTFS/dev"
ensure_bind /proc "$ROOTFS/proc"
ensure_bind /sys "$ROOTFS/sys"
ensure_devpts
ensure_tmpfs "$ROOTFS/dev/shm" 256M

chroot_run() {
  "$BB" chroot "$ROOTFS" /usr/bin/env -i \
    HOME=/root USER=root LOGNAME=root \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM="${TERM:-xterm}" \
    DEBIAN_FRONTEND=noninteractive "$@"
}

log "Configuring DNS and hostname..."
if [ -L "$ROOTFS/etc/resolv.conf" ]; then
  rm -f "$ROOTFS/etc/resolv.conf"
fi
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' >"$ROOTFS/etc/resolv.conf"
chmod 644 "$ROOTFS/etc/resolv.conf"
printf '127.0.0.1 localhost\n127.0.1.1 ubuntu\n::1 localhost ip6-localhost ip6-loopback\n' >"$ROOTFS/etc/hosts"
printf 'ubuntu\n' >"$ROOTFS/etc/hostname"
printf '#!/bin/sh\nexit 101\n' >"$ROOTFS/usr/sbin/policy-rc.d"
chmod 755 "$ROOTFS/usr/sbin/policy-rc.d"

ensure_group() {
  local name="$1" gid="$2"
  if ! chroot_run getent group "$name" >/dev/null 2>&1; then
    chroot_run groupadd -g "$gid" "$name" || die "Failed to create group $name ($gid)."
    log "Created group $name ($gid)"
  fi
}

log "Configuring Android networking groups..."
ensure_group aid_inet 3003
ensure_group aid_net_raw 3004
ensure_group aid_graphics 1003
ensure_group storage 3005
ensure_group wheel 3006
ensure_group users "$UBUNTU_GID"

if chroot_run getent passwd "$UBUNTU_USER" >/dev/null 2>&1; then
  log "Updating user $UBUNTU_USER..."
  chroot_run usermod -s /bin/bash -g users \
    -aG wheel,audio,video,storage,aid_inet,aid_net_raw "$UBUNTU_USER" ||
    die "Failed to update user $UBUNTU_USER."
else
  log "Creating user $UBUNTU_USER..."
  chroot_run useradd -m -u "$UBUNTU_UID" -g users \
    -G wheel,audio,video,storage,aid_inet,aid_net_raw \
    -s /bin/bash "$UBUNTU_USER" || die "Failed to create user $UBUNTU_USER."
fi

chroot_run usermod -aG aid_inet,aid_net_raw root 2>/dev/null || warn "Could not add root to Android network groups."
if chroot_run getent passwd _apt >/dev/null 2>&1; then
  chroot_run usermod -aG aid_inet,aid_net_raw _apt 2>/dev/null || warn "Could not add _apt to Android network groups."
fi

log "Configuring safe shared directory..."
mkdir -p "$SHARED_HOST"
chown "$UBUNTU_UID:$TERMUX_GID" "$SHARED_HOST" 2>/dev/null || warn "Could not set shared directory ownership."
chmod 2770 "$SHARED_HOST"
termux_group="$(chroot_run getent group "$TERMUX_GID" 2>/dev/null | cut -d: -f1 || true)"
if [ -z "$termux_group" ]; then
  chroot_run groupadd -g "$TERMUX_GID" termux || die "Failed to create group $TERMUX_GID."
  termux_group=termux
fi
chroot_run usermod -aG "$termux_group" "$UBUNTU_USER" || warn "Could not add $UBUNTU_USER to group $termux_group."
ok "Shared directory ready: $SHARED_HOST -> $SHARED_GUEST"

pw_status="$(chroot_run passwd -S "$UBUNTU_USER" 2>/dev/null | awk '{print $2}' || true)"
if [ "$pw_status" != "P" ]; then
  if [ -t 0 ] && [ -t 1 ]; then
    printf '\n'
    log "No usable password is set for $UBUNTU_USER. Set one now."
    chroot_run passwd "$UBUNTU_USER" || die "Failed to set password for $UBUNTU_USER."
    ok "Password set for $UBUNTU_USER."
  else
    die "No password is set for $UBUNTU_USER. Run this installer from an interactive Termux session to set it."
  fi
fi

log "Configuring sudo..."
mkdir -p "$ROOTFS/etc/sudoers.d"
printf '%s ALL=(ALL:ALL) ALL\n' "$UBUNTU_USER" >"$ROOTFS/etc/sudoers.d/90-$UBUNTU_USER"
chmod 0440 "$ROOTFS/etc/sudoers.d/90-$UBUNTU_USER"
chown 0:0 "$ROOTFS/etc/sudoers.d/90-$UBUNTU_USER"

printf '# snap is not usable inside a Termux chroot\nPackage: snapd\nPin: release a=*\nPin-Priority: -10\n' \
  >"$ROOTFS/etc/apt/preferences.d/nosnap.pref" 2>/dev/null ||
  { mkdir -p "$ROOTFS/etc/apt/preferences.d"; printf '# snap is not usable inside a Termux chroot\nPackage: snapd\nPin: release a=*\nPin-Priority: -10\n' >"$ROOTFS/etc/apt/preferences.d/nosnap.pref"; }
chmod 644 "$ROOTFS/etc/apt/preferences.d/nosnap.pref"

packages="ca-certificates curl locales tzdata g++ make libc6-dev clang clangd git cmake ninja-build sudo"
if ! chroot_run /bin/sh -c 'command -v nvim >/dev/null 2>&1'; then
  packages="$packages neovim"
else
  log "Existing nvim binary found; leaving it in place."
fi

log "Running apt update..."
chroot_run apt-get update || die "apt-get update failed. Check DNS and Android network groups."
log "Installing CLI toolchain (no GUI packages)..."
chroot_run apt-get install -y --no-install-recommends \
  -o Dpkg::Options::=--force-confdef \
  -o Dpkg::Options::=--force-confold \
  $packages || die "Package installation failed."
chroot_run apt-get clean
ok "Toolchain packages installed."

log "Configuring locale..."
chroot_run /bin/sh -c '
  if grep -qE "^# *en_US\.UTF-8 UTF-8" /etc/locale.gen; then
    sed -i "s/^# *en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
  elif ! grep -qE "^en_US\.UTF-8 UTF-8" /etc/locale.gen; then
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
  fi
' || warn "Could not update /etc/locale.gen."
chroot_run locale-gen || warn "locale-gen failed."
chroot_run update-locale LANG=en_US.UTF-8 || warn "update-locale failed."

log "Configuring shell initialization and PATH..."
cat >"$ROOTFS/etc/profile.d/00-termux-chroot.sh" <<'PROFILE'
export LANG=en_US.UTF-8
export TERM="${TERM:-xterm-256color}"
case ":$PATH:" in
  *:/usr/local/bin:*) ;;
  *) PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" ;;
esac
export PATH
if mountpoint -q /mnt/shared 2>/dev/null; then
  export UBUNTU_SHARED=/mnt/shared
fi
PROFILE
chmod 644 "$ROOTFS/etc/profile.d/00-termux-chroot.sh"

user_bashrc="$ROOTFS/home/$UBUNTU_USER/.bashrc"
touch "$user_bashrc"
if ! grep -q '>>> termux-chroot >>>' "$user_bashrc"; then
  cat >>"$user_bashrc" <<'BASHRC'

# >>> termux-chroot >>>
export PATH="$HOME/.local/bin:$PATH"
export LANG=en_US.UTF-8
if mountpoint -q /mnt/shared 2>/dev/null; then
  export UBUNTU_SHARED=/mnt/shared
fi
# <<< termux-chroot <<<
BASHRC
fi
chown "$UBUNTU_USER:users" "$user_bashrc" 2>/dev/null || true

if chroot_run visudo -cf /etc/sudoers >/dev/null 2>&1; then
  ok "sudoers syntax validated."
else
  warn "visudo validation failed; check /etc/sudoers.d/90-$UBUNTU_USER."
fi

log "Installing launcher: $LAUNCHER"
mkdir -p "$TERMUX_PREFIX/bin"
cat >"$LAUNCHER" <<'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOTFS="/data/local/chroot/ubuntu"
UBUNTU_USER="lamlam"
UBUNTU_UID="$(awk -F: -v u="$UBUNTU_USER" '$1 == u { print $3; exit }' "$ROOTFS/etc/passwd" 2>/dev/null || true)"
[ -n "$UBUNTU_UID" ] || UBUNTU_UID=1000
TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
TERMUX_HOME="${TERMUX_HOME:-/data/data/com.termux/files/home}"
TERMUX_GID="${TERMUX_GID:-$(stat -c %g "$TERMUX_HOME" 2>/dev/null || printf '10368')}"
SHARED_HOST="${UBUNTU_SHARED_HOST:-$TERMUX_HOME/ubuntu-shared}"
SHARED_GUEST="/mnt/shared"
SHARED=1
COMMAND=""
ORIG_ARGS=("$@")

log() { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ubuntu [--no-shared] [--exec COMMAND | -c COMMAND]

  (no options)        Interactive Ubuntu shell as lamlam
  --no-shared         Do not mount the private shared directory
  --no-storage        Alias for --no-shared
  --exec COMMAND      Run COMMAND as lamlam and exit
  -c COMMAND          Same as --exec
  -h, --help          Show this help

Shared files: ~/ubuntu-shared in Termux appears at /mnt/shared in Ubuntu.
Use ubuntu-publish and ubuntu-import from Termux to exchange files safely
with /sdcard/UbuntuShared. Android FUSE storage is never bind-mounted.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-shared | --no-storage)
      SHARED=0
      shift
      ;;
    --exec | -c)
      [ "$#" -ge 2 ] || die "Missing command after $1"
      COMMAND="$2"
      shift 2
      ;;
    --exec=*)
      COMMAND="${1#*=}"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      [ "$#" -gt 0 ] || die "Missing command after --"
      COMMAND="$*"
      break
      ;;
    *)
      die "Unknown option: $1 (use --help)"
      ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  command -v su >/dev/null 2>&1 || die "su is not available. Install KernelSU/Magisk root support."
  if ! su -c 'test "$(id -u)" -eq 0' >/dev/null 2>&1; then
    die "Root was denied. Grant root permission to Termux in KernelSU/Magisk, then retry."
  fi

  SELF="${BASH_SOURCE[0]:-$0}"
  SELF="$(readlink -f "$SELF" 2>/dev/null || printf '%s' "$SELF")"
  BASH_BIN="${BASH:-$TERMUX_PREFIX/bin/bash}"
  [ -x "$BASH_BIN" ] || die "Cannot find Termux bash."
  cmd="UBUNTU_LAUNCHER_REEXEC=1 $(printf '%q' "$BASH_BIN") $(printf '%q' "$SELF")"
  for arg in "${ORIG_ARGS[@]}"; do
    cmd="$cmd $(printf '%q' "$arg")"
  done
  exec su -c "$cmd"
fi

[ "$(id -u)" -eq 0 ] || die "Launcher is not root (uid=$(id -u))."

export PATH="$TERMUX_PREFIX/bin:/system/bin:/system/xbin:/data/adb/ksu/bin:/data/adb/magisk:${PATH:-}"

find_busybox() {
  local c
  for c in \
    /data/adb/ksu/bin/busybox \
    /data/adb/magisk/busybox \
    /system/xbin/busybox \
    /system/bin/busybox \
    "$TERMUX_PREFIX/bin/busybox"; do
    [ -x "$c" ] && {
      printf '%s\n' "$c"
      return 0
    }
  done
  command -v busybox 2>/dev/null || return 1
}
BB="$(find_busybox)" || die "BusyBox not found. Install BusyBox NDK or use KernelSU's bundled BusyBox."
applets="$("$BB" --list 2>/dev/null)" || die "Cannot query BusyBox applets."
for applet in mount umount chroot; do
  printf '%s\n' "$applets" | grep -qx "$applet" || die "BusyBox lacks '$applet': $BB"
done

[ -x "$ROOTFS/bin/bash" ] || die "Ubuntu rootfs not found at $ROOTFS. Run install.sh first."

is_mounted() {
  awk -v p="$1" '$2 == p { found = 1 } END { exit(found ? 0 : 1) }' /proc/mounts
}

CLEANUP_ACTIVE=1
CLEANUP_MOUNTS=()
cleanup() {
  [ "${CLEANUP_ACTIVE:-0}" = 1 ] || return 0
  CLEANUP_ACTIVE=0
  set +e
  local i m
  for ((i = ${#CLEANUP_MOUNTS[@]} - 1; i >= 0; i--)); do
    m="${CLEANUP_MOUNTS[i]}"
    if is_mounted "$m"; then
      if "$BB" umount "$m" 2>/dev/null; then
        log "Unmounted $m"
      elif "$BB" umount -l "$m" 2>/dev/null; then
        log "Detached $m"
      else
        warn "Could not unmount $m"
      fi
    fi
  done
  CLEANUP_MOUNTS=()
}

trap 'cleanup; exit 130' INT TERM HUP
trap cleanup EXIT

ensure_bind() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  if is_mounted "$dst"; then
    log "Already mounted: $dst"
    return 0
  fi
  "$BB" mount --bind "$src" "$dst" || die "Failed to bind-mount $src -> $dst"
  CLEANUP_MOUNTS+=("$dst")
  log "Mounted $src -> $dst"
}

ensure_devpts() {
  local dst="$ROOTFS/dev/pts"
  mkdir -p "$dst"
  if is_mounted "$dst"; then
    log "Already mounted: $dst"
    return 0
  fi
  "$BB" mount -t devpts -o gid=5,mode=620 devpts "$dst" || die "Failed to mount devpts."
  CLEANUP_MOUNTS+=("$dst")
  log "Mounted devpts at $dst"
}

ensure_tmpfs() {
  local dst="$1" size="$2"
  mkdir -p "$dst"
  if is_mounted "$dst"; then
    log "Already mounted: $dst"
    return 0
  fi
  "$BB" mount -t tmpfs -o "size=$size,mode=1777" tmpfs "$dst" || die "Failed to mount tmpfs at $dst"
  CLEANUP_MOUNTS+=("$dst")
  log "Mounted tmpfs ($size) at $dst"
}

if is_mounted "$ROOTFS/sdcard"; then
  die "Legacy /sdcard bind mount detected. Reboot to clear it, then rerun ubuntu. Android FUSE storage is never unmounted automatically."
fi
rmdir "$ROOTFS/sdcard" 2>/dev/null || true

"$BB" mount -o remount,dev,suid /data 2>/dev/null || warn "Could not remount /data with dev,suid; continuing."
mkdir -p "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/dev/pts" "$ROOTFS/dev/shm" "$ROOTFS$SHARED_GUEST"
ensure_bind /dev "$ROOTFS/dev"
ensure_bind /proc "$ROOTFS/proc"
ensure_bind /sys "$ROOTFS/sys"
ensure_devpts
ensure_tmpfs "$ROOTFS/dev/shm" 256M

if [ "$SHARED" = 1 ]; then
  mkdir -p "$SHARED_HOST"
  chown "$UBUNTU_UID:$TERMUX_GID" "$SHARED_HOST" 2>/dev/null || warn "Could not set shared directory ownership."
  chmod 2770 "$SHARED_HOST"
  termux_group="$("$BB" chroot "$ROOTFS" /usr/bin/getent group "$TERMUX_GID" 2>/dev/null | cut -d: -f1)"
  if [ -z "$termux_group" ]; then
    "$BB" chroot "$ROOTFS" /usr/sbin/groupadd -g "$TERMUX_GID" termux 2>/dev/null || warn "Could not create chroot group $TERMUX_GID."
    termux_group=termux
  fi
  "$BB" chroot "$ROOTFS" /usr/sbin/usermod -aG "$termux_group" "$UBUNTU_USER" 2>/dev/null || warn "Could not add $UBUNTU_USER to group $termux_group."
  ensure_bind "$SHARED_HOST" "$ROOTFS$SHARED_GUEST"
fi

CHROOT_ENV=(
  /usr/bin/env -i
  HOME="/home/$UBUNTU_USER"
  USER="$UBUNTU_USER"
  LOGNAME="$UBUNTU_USER"
  SHELL=/bin/bash
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  TERM="${TERM:-xterm-256color}"
  LANG=en_US.UTF-8
)
if [ "$SHARED" = 1 ]; then
  CHROOT_ENV+=(UBUNTU_SHARED="$SHARED_GUEST")
fi

set +e
if [ -n "$COMMAND" ]; then
  log "Running in Ubuntu as $UBUNTU_USER: $COMMAND"
  "$BB" chroot "$ROOTFS" "${CHROOT_ENV[@]}" /bin/su - "$UBUNTU_USER" -c "$COMMAND"
  status=$?
else
  log "Entering Ubuntu as $UBUNTU_USER (exit to return to Termux)..."
  "$BB" chroot "$ROOTFS" "${CHROOT_ENV[@]}" /bin/su - "$UBUNTU_USER"
  status=$?
fi
set -e

cleanup
trap - EXIT
exit "$status"
LAUNCHER
chmod 755 "$LAUNCHER"
ok "Launcher installed: $LAUNCHER"

log "Installing shared-storage helpers..."
cat >"$TERMUX_PREFIX/bin/ubuntu-publish" <<'PUBLISH'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

TERMUX_HOME="${TERMUX_HOME:-/data/data/com.termux/files/home}"
SHARED="${UBUNTU_SHARED_HOST:-$TERMUX_HOME/ubuntu-shared}"
DEST="${UBUNTU_ANDROID_SHARE:-/sdcard/UbuntuShared}"

die() {
  printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2
  exit 1
}

[ "$#" -gt 0 ] || die "Usage: ubuntu-publish FILE_OR_DIR [...]"
[ -d "$SHARED" ] || die "Shared directory is missing: $SHARED (run: ubuntu)"
[ -d /sdcard ] || die "Android shared storage is unavailable at /sdcard."

shared_abs="$(realpath -m -- "$SHARED")"
mkdir -p "$DEST" || die "Cannot create $DEST"
umask 022

for item in "$@"; do
  if [[ "$item" = /* ]]; then
    src="$item"
  else
    src="$SHARED/$item"
  fi
  [ -e "$src" ] || die "Not found: $src"
  src_abs="$(realpath -m -- "$src")"
  case "$src_abs" in
    "$shared_abs"/*) ;;
    *) die "Refusing path outside shared directory: $item" ;;
  esac
  cp -R -- "$src_abs" "$DEST/" || die "Copy failed: $src_abs"
  printf 'Published: %s -> %s/\n' "$(basename -- "$src_abs")" "$DEST"
done
PUBLISH
chmod 755 "$TERMUX_PREFIX/bin/ubuntu-publish"

cat >"$TERMUX_PREFIX/bin/ubuntu-import" <<'IMPORT'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

TERMUX_HOME="${TERMUX_HOME:-/data/data/com.termux/files/home}"
SHARED="${UBUNTU_SHARED_HOST:-$TERMUX_HOME/ubuntu-shared}"
SRC_ROOT="${UBUNTU_ANDROID_ROOT:-/sdcard}"

die() {
  printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2
  exit 1
}

[ "$#" -gt 0 ] || die "Usage: ubuntu-import FILE_OR_DIR [...]"
[ -d "$SRC_ROOT" ] || die "Android storage is unavailable: $SRC_ROOT"

mkdir -p "$SHARED" || die "Cannot create $SHARED"
chmod 2770 "$SHARED" 2>/dev/null || true
umask 002

src_root_abs="$(realpath -m -- "$SRC_ROOT")"
for item in "$@"; do
  if [[ "$item" = /* ]]; then
    src="$item"
  else
    src="$SRC_ROOT/$item"
  fi
  [ -e "$src" ] || die "Not found: $src"
  src_abs="$(realpath -m -- "$src")"
  case "$src_abs" in
    "$src_root_abs"/*) ;;
    *) die "Refusing path outside Android storage: $item" ;;
  esac
  cp -R -- "$src_abs" "$SHARED/" || die "Copy failed: $src_abs"
  printf 'Imported: %s -> %s/\n' "$(basename -- "$src_abs")" "$SHARED"
done
IMPORT
chmod 755 "$TERMUX_PREFIX/bin/ubuntu-import"
ok "Shared-storage helpers installed: ubuntu-publish, ubuntu-import"

log "Validating installation..."
printf '  architecture: '; chroot_run dpkg --print-architecture
for cmd in g++ make clang clangd nvim git cmake ninja sudo; do
  if path="$(chroot_run /bin/sh -c "command -v $cmd" 2>/dev/null)"; then
    printf '  %-8s %s\n' "$cmd" "$path"
  else
    warn "Missing command inside chroot: $cmd"
  fi
done
if chroot_run visudo -cf /etc/sudoers >/dev/null 2>&1; then
  ok "sudoers syntax OK"
else
  warn "sudoers syntax check failed"
fi
if chroot_run sudo -l -U "$UBUNTU_USER" >/dev/null 2>&1; then
  ok "sudo permission entry found for $UBUNTU_USER"
else
  warn "Could not verify sudo permission entry for $UBUNTU_USER"
fi
if chroot_run dpkg-query -W -f='${Package}\n' 2>/dev/null |
  grep -qE '^(xserver-xorg|ubuntu-desktop|xfce4|gnome-shell|kde-plasma-desktop|lubuntu-desktop|wayland)$'; then
  warn "A desktop/X11 package is present in the rootfs (not installed by this script)."
else
  ok "No desktop/X11 metapackages detected."
fi
if [ -d "$SHARED_HOST" ]; then
  printf '  shared: '
  stat -c '%U:%G %a %n' "$SHARED_HOST" 2>/dev/null || true
  ok "Shared directory configured without mounting Android FUSE storage."
else
  warn "Shared directory was not created: $SHARED_HOST"
fi
if is_mounted "$ROOTFS/sdcard"; then
  warn "Legacy /sdcard bind mount is still present under the rootfs."
else
  ok "No Android FUSE bind mount is configured."
fi
for helper in ubuntu-publish ubuntu-import; do
  [ -x "$TERMUX_PREFIX/bin/$helper" ] && ok "Helper installed: $helper" || warn "Helper missing: $helper"
done

CLEANUP_ACTIVE=1
cleanup_mounts
trap - EXIT INT TERM HUP

ok "Ubuntu chroot installation complete."
printf '\nRun: ubuntu\nRun one command: ubuntu --exec "whoami"\n'

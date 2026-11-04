
pkg install -y curl && su -c 'bash -s' <<'ROOT'
set -e

ROOTFS=/data/local/chroot/ubuntu
BASE=/data/local/chroot
PREFIX=/data/data/com.termux/files/usr
URL=https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz

echo "=== Ubuntu 24.04 CLI Installer ==="

# Check BusyBox
command -v busybox >/dev/null || {
    echo "ERROR: BusyBox NDK is required!"
    exit 1
}

# Download rootfs
mkdir -p "$BASE"
if [ ! -f "$BASE/ubuntu.tar.gz" ]; then
    "$PREFIX/bin/curl" -fL "$URL" -o "$BASE/ubuntu.tar.gz"
fi

# Extract rootfs
mkdir -p "$ROOTFS"
if [ ! -x "$ROOTFS/bin/bash" ]; then
    busybox tar -xpf "$BASE/ubuntu.tar.gz" -C "$ROOTFS"
fi

# Configure DNS
mkdir -p "$ROOTFS/dev/shm" "$ROOTFS/sdcard"
echo "nameserver 1.1.1.1" > "$ROOTFS/etc/resolv.conf"
echo "nameserver 8.8.8.8" >> "$ROOTFS/etc/resolv.conf"

cat > "$ROOTFS/etc/hosts" <<'EOF'
127.0.0.1 localhost
::1 localhost
EOF

# Mount system directories
busybox mount -o remount,dev,suid /data 2>/dev/null || true

for d in dev sys proc; do
    busybox mountpoint -q "$ROOTFS/$d" ||
        busybox mount --bind "/$d" "$ROOTFS/$d"
done

mkdir -p "$ROOTFS/dev/pts" "$ROOTFS/dev/shm"

busybox mountpoint -q "$ROOTFS/dev/pts" ||
    busybox mount -t devpts devpts "$ROOTFS/dev/pts"

busybox mountpoint -q "$ROOTFS/dev/shm" ||
    busybox mount -t tmpfs -o size=256M tmpfs "$ROOTFS/dev/shm"

busybox mountpoint -q "$ROOTFS/sdcard" ||
    busybox mount --bind /sdcard "$ROOTFS/sdcard"

echo "=== Installing Ubuntu packages ==="

busybox chroot "$ROOTFS" /bin/bash -c '
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

apt-get install -y \
    sudo adduser nano vim git curl wget \
    ca-certificates locales tzdata \
    net-tools iproute2 iputils-ping \
    procps htop unzip zip \
    build-essential cmake python3 python3-pip

# Android groups
for entry in "3003 aid_inet" "3004 aid_net_raw" "1003 aid_graphics"; do
    set -- $entry
    getent group "$2" >/dev/null || {
        getent group "$1" >/dev/null || groupadd -g "$1" "$2"
    }
done

for g in storage wheel audio video; do
    getent group "$g" >/dev/null || groupadd "$g"
done

# Create lamlam
if ! id lamlam >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" lamlam
fi

usermod -s /bin/bash lamlam
usermod -aG sudo,wheel,storage,audio,video,aid_inet,aid_net_raw lamlam

# Sudo privileges
echo "lamlam ALL=(ALL:ALL) ALL" > /etc/sudoers.d/lamlam
chmod 440 /etc/sudoers.d/lamlam

# Locale
sed -i "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# Timezone
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
echo Asia/Ho_Chi_Minh > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Disable Snap
mkdir -p /etc/apt/preferences.d
cat > /etc/apt/preferences.d/nosnap.pref <<EOF
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

apt-get clean
'

# Set password
echo "=== Set password for lamlam ==="
busybox chroot "$ROOTFS" /usr/bin/passwd lamlam

# Create Termux command
cat > "$PREFIX/bin/ubuntu" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

ROOT=/data/local/chroot/ubuntu

[ -x "$ROOT/bin/bash" ] || {
    echo "Ubuntu rootfs not found!"
    exit 1
}

su -c '
ROOT=/data/local/chroot/ubuntu

busybox mount -o remount,dev,suid /data 2>/dev/null || true

for d in dev sys proc; do
    busybox mountpoint -q "$ROOT/$d" ||
        busybox mount --bind "/$d" "$ROOT/$d"
done

mkdir -p "$ROOT/dev/pts" "$ROOT/dev/shm"

busybox mountpoint -q "$ROOT/dev/pts" ||
    busybox mount -t devpts devpts "$ROOT/dev/pts"

busybox mountpoint -q "$ROOT/dev/shm" ||
    busybox mount -t tmpfs -o size=256M tmpfs "$ROOT/dev/shm"

busybox mountpoint -q "$ROOT/sdcard" ||
    busybox mount --bind /sdcard "$ROOT/sdcard"

exec busybox chroot "$ROOT" /bin/su - lamlam
'
EOF

chmod 755 "$PREFIX/bin/ubuntu"
chown "$(stat -c %u "$PREFIX")":"$(stat -c %g "$PREFIX")" "$PREFIX/bin/ubuntu"

echo
echo "================================"
echo " UBUNTU 24.04 INSTALLED!"
echo " User: lamlam"
echo " GUI: Not installed"
echo " Command: ubuntu"
echo "================================"

ROOT


pkg install -y curl && su -c '/data/data/com.termux/files/usr/bin/bash -s' <<'ROOT'
set -e

BASE=/data/local/chroot
ROOTFS=$BASE/ubuntu
PREFIX=/data/data/com.termux/files/usr

UBUNTU_URL=https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz
NVIM_URL=https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz
CONFIG_URL=https://github.com/nglam0205/NeovimConfig.git

echo "======================================"
echo "       UBUNTU CHROOT INSTALLER"
echo "======================================"

# 1. Check requirements
command -v busybox >/dev/null || {
    echo "ERROR: Install BusyBox NDK first!"
    exit 1
}

# 2. Download Ubuntu
mkdir -p "$BASE"

if [ ! -x "$ROOTFS/bin/bash" ]; then
    echo "[1/10] Downloading Ubuntu 24.04..."

    "$PREFIX/bin/curl" -fL --retry 3 \
        "$UBUNTU_URL" -o "$BASE/ubuntu.tar.gz"

    mkdir -p "$ROOTFS"
    busybox tar -xpf "$BASE/ubuntu.tar.gz" -C "$ROOTFS"
fi

# 3. Configure mounts
echo "[2/10] Mounting system directories..."

mkdir -p "$ROOTFS/dev/pts" "$ROOTFS/dev/shm" "$ROOTFS/sdcard"

busybox mount -o remount,dev,suid /data 2>/dev/null || true

for d in dev sys proc; do
    busybox mountpoint -q "$ROOTFS/$d" ||
        busybox mount --bind "/$d" "$ROOTFS/$d"
done

busybox mountpoint -q "$ROOTFS/dev/pts" ||
    busybox mount -t devpts devpts "$ROOTFS/dev/pts"

busybox mountpoint -q "$ROOTFS/dev/shm" ||
    busybox mount -t tmpfs -o size=256M tmpfs "$ROOTFS/dev/shm"

busybox mountpoint -q "$ROOTFS/sdcard" ||
    busybox mount --bind /sdcard "$ROOTFS/sdcard"

# 4. Ubuntu configuration and packages
echo "[3/10] Installing development environment..."

busybox chroot "$ROOTFS" /bin/bash -s <<'UBUNTU'
set -e
export DEBIAN_FRONTEND=noninteractive

cat > /etc/resolv.conf <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

cat > /etc/hosts <<'EOF'
127.0.0.1 localhost
::1 localhost
EOF

apt-get update
apt-get upgrade -y

apt-get install -y \
    git \
    nodejs npm \
    wget curl \
    python3 python3-pip python3-venv \
    clang clangd clang-format clang-tidy \
    gcc g++ build-essential \
    cmake ninja-build make pkg-config \
    gdb \
    ripgrep fd-find \
    unzip zip \
    sudo adduser \
    nano vim \
    ca-certificates \
    locales tzdata \
    net-tools iproute2 iputils-ping \
    procps htop \
    bash-completion less

# Android groups
for entry in "3003 aid_inet" "3004 aid_net_raw" "1003 aid_graphics"; do
    set -- $entry

    if ! getent group "$2" >/dev/null; then
        if ! getent group "$1" >/dev/null; then
            groupadd -g "$1" "$2"
        fi
    fi
done

for g in storage wheel audio video; do
    getent group "$g" >/dev/null || groupadd "$g"
done

# Configure APT network permissions
usermod -aG aid_inet,aid_net_raw root

if id _apt >/dev/null 2>&1; then
    usermod -aG aid_inet,aid_net_raw _apt
fi

# Create user
if ! id lamlam >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" lamlam
fi

usermod -s /bin/bash lamlam

usermod -aG \
    sudo,wheel,storage,audio,video,aid_inet,aid_net_raw \
    lamlam

# Sudo
echo 'lamlam ALL=(ALL:ALL) ALL' > /etc/sudoers.d/lamlam
chmod 440 /etc/sudoers.d/lamlam

# Locale
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# Timezone
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
echo Asia/Ho_Chi_Minh > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Disable Snap
mkdir -p /etc/apt/preferences.d

cat > /etc/apt/preferences.d/nosnap.pref <<'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

# 5. Install latest Neovim ARM64
echo "[4/10] Downloading Neovim..."

cd /tmp

curl -fL --retry 3 "$NVIM_URL" \
    -o nvim-linux-arm64.tar.gz

echo "[5/10] Installing Neovim..."

rm -rf /opt/nvim-linux-arm64

tar -xzf nvim-linux-arm64.tar.gz -C /opt

test -x /opt/nvim-linux-arm64/bin/nvim

ln -sfn /opt/nvim-linux-arm64/bin/nvim /usr/local/bin/nvim

nvim --version | head -n 3

# 6. Clone configuration
echo "[6/10] Cloning NeovimConfig..."

cd /home/lamlam

if [ -d NeovimConfig/.git ]; then
    git -C NeovimConfig pull --ff-only
elif [ ! -e NeovimConfig ]; then
    git clone --depth 1 "$CONFIG_URL" NeovimConfig
else
    echo "ERROR: NeovimConfig exists but is not a Git repository."
    exit 1
fi

CONFIG_DIR=/home/lamlam/NeovimConfig
HOME_DIR=/home/lamlam

# Validate repository structure
if [ -f "$CONFIG_DIR/bashrc" ]; then
    BASHRC="$CONFIG_DIR/bashrc"
elif [ -f "$CONFIG_DIR/.bashrc" ]; then
    BASHRC="$CONFIG_DIR/.bashrc"
else
    echo "ERROR: bashrc not found in NeovimConfig!"
    exit 1
fi

if [ ! -d "$CONFIG_DIR/nvim" ]; then
    echo "ERROR: nvim directory not found!"
    exit 1
fi

# 7. Install configuration
echo "[7/10] Installing Bash configuration..."

if [ -f "$HOME_DIR/.bashrc" ] &&
   [ ! -f "$HOME_DIR/.bashrc.backup" ]; then
    cp "$HOME_DIR/.bashrc" "$HOME_DIR/.bashrc.backup"
fi

cp "$BASHRC" "$HOME_DIR/.bashrc"

echo "[8/10] Installing Neovim configuration..."

mkdir -p "$HOME_DIR/.config"

if [ -d "$HOME_DIR/.config/nvim" ] &&
   [ ! -d "$HOME_DIR/.config/nvim.backup" ]; then
    cp -a "$HOME_DIR/.config/nvim" \
        "$HOME_DIR/.config/nvim.backup"
fi

rm -rf "$HOME_DIR/.config/nvim"
cp -a "$CONFIG_DIR/nvim" "$HOME_DIR/.config/nvim"

# Ownership
chown -R lamlam:lamlam \
    "$HOME_DIR/.config" \
    "$HOME_DIR/NeovimConfig"

chown lamlam:lamlam "$HOME_DIR/.bashrc"

# Clean
rm -f /tmp/nvim-linux-arm64.tar.gz
apt-get clean

echo "[9/10] Ubuntu configuration completed!"

UBUNTU

# 8. Set user password
echo
echo "======================================"
echo "Set password for user: lamlam"
echo "======================================"

busybox chroot "$ROOTFS" /usr/bin/passwd lamlam </dev/tty

# 9. Create ubuntu command in Termux
echo "[10/10] Creating Termux command..."

cat > "$PREFIX/bin/ubuntu" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

ROOT=/data/local/chroot/ubuntu

if [ ! -x "$ROOT/bin/bash" ]; then
    echo "Ubuntu rootfs not found!"
    exit 1
fi

exec su -c '
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

echo
echo "======================================"
echo "       INSTALLATION COMPLETED"
echo "======================================"
echo "Ubuntu       : 24.04 LTS ARM64"
echo "User         : lamlam"
echo "GUI          : None"
echo "Neovim       : Latest ARM64"
echo "Node.js      : Installed"
echo "NPM          : Installed"
echo "Python       : Installed"
echo "GCC/G++      : Installed"
echo "Clang/Clangd : Installed"
echo "CMake/Ninja  : Installed"
echo "Git          : Installed"
echo "Config       : NeovimConfig"
echo "Command      : ubuntu"
echo "======================================"

echo "Starting Ubuntu..."
exec busybox chroot "$ROOTFS" /bin/su - lamlam

ROOT

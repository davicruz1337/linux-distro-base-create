#!/bin/bash

# Fail on errors
set -e

# Define paths
BUILD_DIR="/nytonix-tmp"
SOURCE_DIR="$HOME/nytonix"
ISO_DIR="$HOME/iso"
KERNEL_VERSION="5.15.132"
ARCH="x86_64"
DISTRO_NAME="nytonixOS"
PRIMARY_COLOR="blue"

# Logo ASCII for NytonixOS
LOGO_ASCII="""
[...     [..
[. [..   [..
[.. [..  [..
[..  [.. [..
[..   [. [..
[..    [. ..
[..      [..
"""

echo "Setting up environment..."
mkdir -p "$BUILD_DIR"
mkdir -p "$ISO_DIR"
mkdir -p "$SOURCE_DIR"

# Install dependencies
echo "Installing base dependencies..."
sudo pacman -Syu --noconfirm base-devel grub efibootmgr xorriso squashfs-tools wget vim git gcc clang lightdm sway foot flatpak apparmor firejail networkmanager zsh neofetch dmenu papirus-icon-theme bc perl python cpio flex bison elfutils openssl

# Configure Flatpak
echo "Configuring Flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Check if kernel is already compiled
if [ ! -d "$BUILD_DIR/linux-$KERNEL_VERSION" ]; then
    echo "Downloading Linux kernel..."
    cd "$BUILD_DIR"
    wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz
    tar -xf linux-$KERNEL_VERSION.tar.xz
    cd linux-$KERNEL_VERSION

    echo "Compiling Linux kernel..."
    make clean
    make mrproper
    make defconfig
    if ! make -j$(nproc); then
        echo "Kernel compilation failed. Please check the output for errors."
        exit 1
    fi
    make modules_install
    make install
else
    echo "Kernel already compiled. Skipping compilation."
fi

# Configure GRUB
echo "Configuring GRUB..."
sudo grub-install --target=i386-pc --boot-directory=/boot --recheck /dev/sda
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Create minimal root filesystem
echo "Creating root filesystem..."
cd "$BUILD_DIR"
mkdir -p rootfs/{bin,sbin,etc,proc,sys,usr/bin,usr/sbin,home/nytonix,boot}
cp -a /bin/{bash,ls,mkdir,cat} rootfs/bin/
cp -a /usr/bin/{foot,dmenu} rootfs/usr/bin/

# Customize Neofetch for NytonixOS
echo "Configuring Neofetch with NytonixOS branding..."
mkdir -p rootfs/usr/share/neofetch/ascii
cat > rootfs/etc/neofetch/config.conf <<EOF
info "Custom Linux Distribution"
distro_logo="custom"
EOF

cat > rootfs/usr/share/neofetch/ascii/nytonix <<EOF
$LOGO_ASCII
EOF

# Install and customize Sway
mkdir -p rootfs/etc/sway
cat > rootfs/etc/sway/config <<EOF
# Sway Configuration for NytonixOS
set \$mod Mod4

# Default terminal
bindsym \$mod+Return exec foot

# Application launcher
bindsym \$mod+d exec dmenu_run

# Focus
bindsym \$mod+h focus left
bindsym \$mod+l focus right
bindsym \$mod+j focus down
bindsym \$mod+k focus up

# Layouts
bindsym \$mod+e splith
bindsym \$mod+s splitv
bindsym \$mod+f fullscreen
bindsym \$mod+q kill

# Background
output * bg #0000FF fill
EOF

# Set LightDM to use Sway
cat > rootfs/etc/lightdm/lightdm.conf <<EOF
[Seat:*]
session-wrapper=/usr/bin/sway
EOF

# Create installer script
echo "Creating installer script..."
cat > "$BUILD_DIR/install.sh" <<'EOF'
#!/bin/bash

set -e

# Display disks for user
echo "Available disks:"
lsblk -d -o NAME,SIZE | sort -k2 -h

echo -n "Enter the disk to install NytonixOS (e.g., /dev/sda): "
read DISK

cryptsetup luksFormat $DISK
cryptsetup open $DISK cryptroot

pvcreate /dev/mapper/cryptroot
vgcreate nytonix-vg /dev/mapper/cryptroot
lvcreate -L 20G -n root nytonix-vg
lvcreate -L 4G -n swap nytonix-vg
lvcreate -l 100%FREE -n home nytonix-vg

mkfs.ext4 /dev/nytonix-vg/root
mkfs.ext4 /dev/nytonix-vg/home
mkswap /dev/nytonix-vg/swap

mount /dev/nytonix-vg/root /mnt
mkdir /mnt/home
mount /dev/nytonix-vg/home /mnt/home
swapon /dev/nytonix-vg/swap

echo -n "Set root password: "
read -s ROOT_PASSWORD

echo -n "Enter a username: "
read USERNAME

echo -n "Set password for $USERNAME: "
read -s USER_PASSWORD

echo "Configuring the system..."
arch-chroot /mnt /bin/bash -c "echo root:$ROOT_PASSWORD | chpasswd"
arch-chroot /mnt useradd -m \$USERNAME
arch-chroot /mnt /bin/bash -c "echo \$USERNAME:$USER_PASSWORD | chpasswd"
arch-chroot /mnt systemctl enable sway
arch-chroot /mnt systemctl enable apparmor
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt grub-install --target=i386-pc --boot-directory=/boot --recheck /dev/sda
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot /mnt flatpak install flathub org.mozilla.firefox -y
EOF
chmod +x "$BUILD_DIR/install.sh"

# Create build script for ISO
cat > "$SOURCE_DIR/build.sh" <<'EOF'
#!/bin/bash
set -e
ISO_DIR="$HOME/iso"
DISTRO_NAME="nytonixOS"
BUILD_DIR="/nytonix-tmp"

# Prepare root filesystem
cd "$BUILD_DIR/rootfs"
find . | cpio -o -H newc | gzip > "$BUILD_DIR/initramfs.img"

# Build ISO
echo "Building ISO image..."
xorriso -as mkisofs -o "$ISO_DIR/$DISTRO_NAME.iso" -b boot/grub/i386-pc/eltorito.img -no-emul-boot -boot-load-size 4 -boot-info-table "$BUILD_DIR"
echo "NytonixOS ISO has been created at $ISO_DIR/$DISTRO_NAME.iso"
EOF
chmod +x "$SOURCE_DIR/build.sh"

# Final build process
echo "Starting ISO build process..."
cd "$SOURCE_DIR"
./build.sh

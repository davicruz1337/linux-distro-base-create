#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <distro-name>"
    exit 1
fi

DISTRO_NAME=$1
DISTRO_DIR=~/$DISTRO_NAME-dev
ISO_OUTPUT=~/$DISTRO_NAME.iso

mkdir -p "$DISTRO_DIR"
sudo pacman -S --needed --noconfirm gcc nasm make grub wget xorriso

cd "$DISTRO_DIR"
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.5.tar.xz
tar -xf linux-6.5.tar.xz
cd linux-6.5
make defconfig
make -j$(nproc)

mkdir -p "$DISTRO_DIR/boot"
cp arch/x86/boot/bzImage "$DISTRO_DIR/boot/vmlinuz-$DISTRO_NAME"

mkdir -p "$DISTRO_DIR/iso/boot/grub"
cat > "$DISTRO_DIR/iso/boot/grub/grub.cfg" <<EOF
menuentry "$DISTRO_NAME" {
    linux /boot/vmlinuz-$DISTRO_NAME
}
EOF

cd "$DISTRO_DIR"
mkdir -p "$DISTRO_DIR/rootfs/bin"

wget https://ftp.gnu.org/gnu/libc/glibc-2.38.tar.gz
wget https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.gz
wget https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.gz

tar -xf glibc-2.38.tar.gz
cd glibc-2.38
mkdir build
cd build
../configure --prefix="$DISTRO_DIR/rootfs" --host=x86_64-linux-gnu --disable-multi-arch
make -j$(nproc)
make install
cd ../../

mkdir -p binutils-build
cd binutils-build
tar -xf ../binutils-2.40.tar.gz -C . --strip-components=1
./configure --prefix="$DISTRO_DIR/rootfs" --disable-nls --enable-shared --disable-werror
make -j$(nproc)
make install
cd ../

mkdir -p gcc-build
cd gcc-build
tar -xf ../gcc-13.2.0.tar.gz -C . --strip-components=1
./configure --prefix="$DISTRO_DIR/rootfs" --disable-multilib --enable-languages=c --disable-bootstrap
make -j$(nproc)
make install
cd ../

echo "Compilers and basic tools installed. Environment is ready at $DISTRO_DIR"

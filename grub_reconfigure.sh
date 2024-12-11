#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <DISTRO_PATH>"
    exit 1
fi

DISTRO_PATH=$1
GRUB_CFG_PATH="$DISTRO_PATH/iso/boot/grub"

# Ensure required directories exist
mkdir -p "$GRUB_CFG_PATH"

# Create the grub.cfg file
cat > "$GRUB_CFG_PATH/grub.cfg" <<EOF
menuentry "Custom Linux" {
    linux /boot/vmlinuz-custom root=/dev/ram rw init=/init console=ttyS0
}
EOF

# Install GRUB
grub-mkrescue -o "$DISTRO_PATH/custom.iso" "$DISTRO_PATH/iso"

echo "GRUB configured and ISO generated at $DISTRO_PATH/custom.iso"

#!/usr/bin/env bash
# Installs a boot-time NVIDIA Xorg regeneration service so AMIs do not retain
# the Packer build instance's PCI BusID mappings.

set -euo pipefail

echo "[install-runtime-xorg-regeneration] Installing NVIDIA Xorg regeneration helper..."
cat <<'EOF' | sudo tee /usr/local/sbin/regenerate-nvidia-xorg.sh >/dev/null
#!/usr/bin/env bash
set -euo pipefail

echo "[regenerate-nvidia-xorg] Removing stale Xorg configuration..."
rm -f /etc/X11/xorg.conf /etc/X11/XF86Config /etc/X11/XF86Config-*

echo "[regenerate-nvidia-xorg] Generating NVIDIA xorg.conf for current hardware..."
nvidia-xconfig --enable-all-gpus --allow-empty-initial-configuration
EOF

sudo chmod 0755 /usr/local/sbin/regenerate-nvidia-xorg.sh

echo "[install-runtime-xorg-regeneration] Installing systemd unit..."
cat <<'EOF' | sudo tee /etc/systemd/system/regenerate-nvidia-xorg.service >/dev/null
[Unit]
Description=Regenerate NVIDIA Xorg configuration for current EC2 GPU topology
Documentation=https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-prereq.html
Wants=systemd-udev-settle.service
After=systemd-udev-settle.service
Before=display-manager.service gdm3.service dcvserver.service
ConditionPathExists=/usr/bin/nvidia-xconfig

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/regenerate-nvidia-xorg.sh

[Install]
WantedBy=graphical.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable regenerate-nvidia-xorg.service

echo "[install-runtime-xorg-regeneration] Removing bake-time xorg.conf from AMI..."
sudo rm -f /etc/X11/xorg.conf /etc/X11/XF86Config /etc/X11/XF86Config-*

echo "[install-runtime-xorg-regeneration] Runtime NVIDIA Xorg regeneration installed."

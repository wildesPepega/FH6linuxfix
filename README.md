# Forza Horizon 6 – Linux Fix Guide

> **Disclaimer**
> This guide is based on my personal setup and experience. I cannot guarantee that any of these fixes will work for everyone. Results may vary depending on your hardware, drivers, distro, and game version. These fixes aim to make the game **more playable** on Linux — they do not resolve every issue, as the game was not officially developed for Linux.
>
> **Recommendation:** Capping your FPS to 60 results in significantly more consistent frametimes. In an arcade racer like Forza Horizon the difference to higher framerates is barely noticeable, while stability improves considerably.

---

## Tested System

| | |
|---|---|
| **Distro** | CachyOS |
| **Kernel** | 7.0.9-1-cachyos |
| **Desktop / Compositor** | KDE Plasma |
| **Display Protocol** | Wayland |
| **CPU** | AMD Ryzen 9 5900X |
| **GPU** | NVIDIA GeForce RTX 3060 12 GB |
| **RAM** | 16 GB |
| **NVIDIA Driver** | 595.71.05 |
| **Proton** | CachyOS-Proton 11.0 |

---

## Fix 1 — NVIDIA Power Management

**Fixes: Crashes and severe frametime spikes**

NVIDIA aggressively puts the GPU to sleep when idle. When the game suddenly demands GPU work, the driver can't wake up in time — causing an **Xid 109 CTX SWITCH TIMEOUT** → crashes or massive frametime spikes.

**Run once, then reboot:**

```bash
echo 'options nvidia-drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_DynamicPowerManagement=2' \
| sudo tee /etc/modprobe.d/nvidia.conf
```

Then rebuild your initramfs — command depends on your distro:

| Distro | Command |
|---|---|
| Arch / CachyOS / Manjaro / EndeavourOS | `sudo mkinitcpio -P` |
| Ubuntu / Debian / Mint / Pop!_OS | `sudo update-initramfs -u` |
| Fedora / RHEL / CentOS | `sudo dracut --force` |
| openSUSE | `sudo mkinitrd` |

Then reboot:

```bash
sudo reboot
```

**What each parameter does:**

| Parameter | Effect |
|---|---|
| `NVreg_DynamicPowerManagement=2` | GPU stays in an active state while gaming instead of going fully to sleep. Still saves power when the PC is idle. |
| `NVreg_PreserveVideoMemoryAllocations=1` | Preserves VRAM contents across suspend/resume — prevents black screen after standby. |
| `nvidia-drm modeset=1` | Enables Kernel Mode Setting for NVIDIA — required for Wayland and proper VRR/G-Sync. |

---

## Fix 2 — CPU Governor (GameMode)

**Fixes: Periodic EKG-like stutter after a few minutes**

With the CPU governor set to `powersave`, the Ryzen 9 5900X drops to ~1.5 GHz between frames and boosts back to ~4.5 GHz for the next frame. This frequency bounce produces a regular EKG pattern (0ms / 64ms) in the frametimes. GameMode automatically sets the governor to `performance` while the game is running and restores it afterwards.

**Step 1 — Enable GameMode daemon (survives reboots):**

```bash
systemctl --user enable --now gamemoded
```

**Step 2 — Create GameMode config:**

```bash
cat > ~/.config/gamemode.ini << 'EOF'
[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
nv_powermizer_mode=1

[cpu]
park_cores=no
pin_cores=yes
EOF
```

| Option | Effect |
|---|---|
| `CPU Governor → performance` | GameMode automatically sets the governor to `performance` while gaming — then back to `powersave`. |
| `nv_powermizer_mode=1` | Sets NVIDIA to Maximum Performance Mode during gaming — prevents GPU P-state jumps. |
| `pin_cores=yes` | Prevents the kernel from migrating game threads between CPU cores. |

---

## Fix 3 — Audio (PipeWire + GoXLR / USB Audio)

**Fixes: Audio dropouts and crackling**

Two separate system-level issues — not specific to Forza Horizon 6. Any Proton game with a USB audio interface could have the same problems.

**Issue 1 — USB Autosuspend:**
PipeWire suspends USB audio devices when no audio is playing. When the game plays a sound and the device needs to wake up → dropout or crackling.

Replace `1220` and `8fe4` with your device's vendor and product ID (find it with `lsusb`):

```bash
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1220", ATTR{idProduct}=="8fe4", ATTR{power/autosuspend}="-1"' \
| sudo tee /etc/udev/rules.d/99-usb-audio-nosuspend.rules

sudo udevadm control --reload-rules
sudo udevadm trigger --attr-match=idVendor=1220
```

**Issue 2 — PipeWire quantum too high:**
The default `min-quantum=1024` is too large for Wine/Proton audio. Wine requests smaller buffers, PipeWire rejects them → buffer mismatch → crackling.

```bash
mkdir -p ~/.config/pipewire/pipewire.conf.d
cat > ~/.config/pipewire/pipewire.conf.d/10-gaming.conf << 'EOF'
context.properties = {
    default.clock.min-quantum = 32
    default.clock.quantum     = 512
}
EOF

systemctl --user restart pipewire pipewire-pulse
```

---

## Steam Launch Options

Right-click FH6 → Properties → Launch Options:

```
PULSE_LATENCY_MSEC=60 PROTON_ENABLE_WAYLAND=1 PROTON_DLSS_UPGRADE=1 PROTON_LOCAL_SHADER_CACHE=1 PROTON_NVIDIA_LIBS=1 PROTON_USE_NTSYNC=1 PROTON_ENABLE_NVAPI=1 PROTON_ENABLE_NGX_UPDATER=1 PROTON_VKD3D_HEAP=1 VKD3D_CONFIG=descriptor_heap gamemoderun gamescope -f -W 1920 -H 1080 -r 180 --mangoapp --force-grab-cursor --adaptive-sync -- %command%
```

> **`PROTON_USE_NTSYNC=1`** requires a kernel with NTsync support. Without it the argument is silently ignored — no errors.

> **Resolution & refresh rate:** `-W 1920 -H 1080` and `-r 180` must match your monitor. Example for 2560x1440 @ 144Hz: `-W 2560 -H 1440 -r 144`

> **Adaptive Sync (FreeSync / G-Sync):**
> - **Monitor supports Adaptive Sync:** Enable VRR in your display settings (KDE: System Settings → Display → Variable Refresh Rate → Automatic), turn in-game VSync **off** — Gamescope handles frame pacing.
> - **No Adaptive Sync:** Remove `--adaptive-sync` from the launch options and turn in-game VSync **on**.

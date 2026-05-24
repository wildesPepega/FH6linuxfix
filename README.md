# Forza Horizon 6 – Linux Fix Guide

> All issues documented in this guide were diagnosed and resolved by **[Claude](https://claude.ai)** (Anthropic's AI) through systematic analysis of system logs, GPU error codes, and Steam configuration — no manual research required.

> **Disclaimer**
> This guide is based on personal experience. There is no guarantee that any of these fixes will work for everyone. Results may vary depending on your hardware, drivers, distro, and game version. These fixes aim to make the game **more playable** on Linux — they do not resolve every issue, as the game was not officially developed for Linux.
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

> **Graphics settings:** All testing was done on the **Medium** preset with no individual settings changed (e.g. Environment Texture Quality or similar were left at their preset defaults).
>
> **Ray tracing:** Ray tracing either does not work at all or only on the lowest setting. This is a known limitation on Linux and is not addressed by this guide.

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

> **Note:** This fix does **not** resolve the "EKG Frametime" issue (the name comes from the frametime graph in MangoHUD resembling an EKG monitor — regular spikes alternating between near-zero and high values). That was caused by `--mangoapp` in Gamescope — see the launch options section. However, GameMode still provides real benefits and is worth keeping.

**What it does:** When the CPU governor is set to `powersave`, the CPU can drop to low clock speeds during brief idle moments and take time to boost back up. GameMode switches the governor to `performance` for the duration of the game session, keeping all cores at a stable base clock. This reduces scheduling jitter, prevents thread migration overhead, and ensures consistent CPU availability — especially noticeable during loading screens and the first few minutes of gameplay.

**Step 1 — Enable GameMode daemon (survives reboots):**

```bash
systemctl --user enable --now gamemoded
```

**Step 2 — Add your user to the gamemode group (required for governor switching):**

```bash
sudo usermod -aG gamemode $USER
```

Log out and back in (or reboot) for the group change to take effect.

**Step 3 — Create GameMode config:**

```bash
cat > ~/.config/gamemode.ini << 'EOF'
[general]
renice=0

[cpu]
park_cores=no
pin_cores=yes
EOF
```

**Step 4 — Verify GameMode works correctly:**

```bash
gamemoded -t 2>&1 | grep -E "Passed|Failed"
```

All entries should show `Passed`.

| Option | Effect |
|---|---|
| `CPU Governor → performance` | GameMode automatically sets the governor to `performance` while gaming — then back to `powersave`. |
| `pin_cores=yes` | Prevents the kernel from migrating game threads between CPU cores. |

> **Note:** `gamemoderun` must be placed **after** the `--` inside the Gamescope command in the launch options (see below), not before it. Placing it before Gamescope causes it to lose its DBus connection due to Gamescope's environment isolation, meaning GameMode never actually activates.

---

## Steam Launch Options

Right-click FH6 → Properties → Launch Options:

```
MANGOHUD=1 PROTON_ENABLE_WAYLAND=1 PROTON_DLSS_UPGRADE=1 PROTON_LOCAL_SHADER_CACHE=1 PROTON_NVIDIA_LIBS=1 PROTON_USE_NTSYNC=1 PROTON_ENABLE_NVAPI=1 PROTON_ENABLE_NGX_UPDATER=1 PROTON_VKD3D_HEAP=1 VKD3D_CONFIG=descriptor_heap gamescope -f -W 1920 -H 1080 -r 180 --force-grab-cursor --adaptive-sync -- gamemoderun %command%
```

> **`--mangoapp` vs `MANGOHUD=1`:** Do **not** use `--mangoapp` in Gamescope. In Gamescope's mangoapp mode the overlay runs as a separate process synchronized with Gamescope's frame output — meaning it samples 60 times per second regardless of any `update_rate` config, consuming ~30% of a CPU core and causing periodic frametime spikes (the "EKG Frametime"). `MANGOHUD=1` injects directly into the game process, respects the config, and uses minimal CPU.
>
> **Known issue:** The combination of Gamescope and `--mangoapp` has reportedly caused similar or identical frametime problems for other users across different games and setups — this is not specific to Forza Horizon 6.

> **`PROTON_USE_NTSYNC=1`** requires a kernel with NTsync support. Without it the argument is silently ignored — no errors.

> **Resolution & refresh rate:** `-W 1920 -H 1080` and `-r 180` must match your monitor. Example for 2560x1440 @ 144Hz: `-W 2560 -H 1440 -r 144`

> **Adaptive Sync (FreeSync / G-Sync):**
> - **Monitor supports Adaptive Sync:** Enable VRR in your display settings (KDE: System Settings → Display → Variable Refresh Rate → Automatic), turn in-game VSync **off** — Gamescope handles frame pacing.
> - **No Adaptive Sync:** Remove `--adaptive-sync` from the launch options and turn in-game VSync **on**.

> **Black screen on launch:** If the game starts but the screen stays black, pressing **Alt+Enter** often fixes it.

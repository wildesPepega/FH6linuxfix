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

---

## Fix 3 — Zram Swap Optimisation

**Fixes: Microstutter caused by slow swap access**

Forza Horizon 6 uses a lot of memory. On systems with 16 GB of RAM, the OS will start swapping out parts of the game process to compressed RAM (zram). The default compression algorithm `zstd` prioritises compression ratio over speed. Switching to `lz4` makes decompression ~3× faster at the cost of slightly less compression — which is the right trade-off when the game is actively reading swapped pages.

Doubling the zram size also gives the kernel much more headroom before it has to make difficult eviction decisions, reducing the frequency of swap activity in the first place.

**Check if you are using zram:**

```bash
zramctl
```

If you see a `/dev/zram0` entry, you are using zram and this section applies to you.

**Create a drop-in config that overrides the defaults:**

```bash
sudo nano /etc/systemd/zram-generator.conf
```

Paste the following:

```ini
[zram0]
compression-algorithm = lz4
zram-size = ram * 2
swap-priority = 100
fs-type = swap
```

The change takes effect after the next reboot.

| Option | Effect |
|---|---|
| `compression-algorithm = lz4` | ~3× faster decompression compared to zstd — reduces stutter when swapped game memory is accessed |
| `zram-size = ram * 2` | Doubles the available compressed swap space, reducing how often swap is needed at all |

---

## Fix 4 — Kernel Mitigations

**Fixes: CPU overhead from Spectre/Meltdown patches**

The Linux kernel applies a set of security patches by default to mitigate CPU vulnerabilities (Spectre, Meltdown, etc.). These patches add overhead to every system call — and Wine/Proton games are system-call-heavy due to the translation layer. Disabling them can reduce this overhead by roughly 5–15%.

> **Security note:** This trades a security mitigation for performance. On a personal gaming PC that is not a shared server, the risk is minimal. Do not apply this on machines with multiple users or exposed services.

The method depends on your bootloader:

**Arch / CachyOS with Limine:**

```bash
sudo nano /etc/default/limine
```

Add `mitigations=off` at the end of your `KERNEL_CMDLINE[default]` line:

```
KERNEL_CMDLINE[default]+="... mitigations=off"
```

Then regenerate the boot config:

```bash
sudo limine-update
```

**Arch / CachyOS / Manjaro with systemd-boot:**

```bash
sudo nano /etc/kernel/cmdline
```

Add `mitigations=off` to the line and run:

```bash
sudo reinstall-kernels
```

**Ubuntu / Debian / Mint / Pop!_OS (GRUB):**

```bash
sudo nano /etc/default/grub
```

Find `GRUB_CMDLINE_LINUX_DEFAULT` and add `mitigations=off` inside the quotes, then run:

```bash
sudo update-grub
```

**Fedora / RHEL (GRUB):**

```bash
sudo grubby --update-kernel=ALL --args="mitigations=off"
```

Reboot afterwards. Verify it is active:

```bash
grep mitigations /proc/cmdline
```

---

## Fix 5 — NVIDIA GPU Interrupt Affinity

**Fixes: GPU interrupts disrupting game threads**

Every time the GPU signals the CPU (e.g. when a frame finishes rendering), it triggers a hardware interrupt. By default, the kernel distributes these interrupts across all CPU cores — which means they can land on the exact core that is currently running a critical game thread, briefly interrupting it.

Pinning the NVIDIA interrupt to a specific, lightly-loaded core keeps it out of the way of the game.

**Step 1 — Create a systemd service that pins the IRQ on every boot:**

```bash
sudo nano /etc/systemd/system/nvidia-irq-affinity.service
```

Paste the following:

```ini
[Unit]
Description=Pin NVIDIA GPU IRQ to last CPU core
After=systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c "IRQ=$(grep nvidia /proc/interrupts | head -1 | cut -d: -f1 | tr -d ' '); LAST=$(nproc --all); MASK=$(printf '%x' $((1 << ($LAST - 1)))); echo $MASK > /proc/irq/$IRQ/smp_affinity"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

**Step 2 — Enable the service:**

```bash
sudo systemctl enable --now nvidia-irq-affinity.service
```

**Verify it is working:**

```bash
sudo systemctl status nvidia-irq-affinity.service
grep nvidia /proc/interrupts
```

The interrupt count column for your last CPU core should be the highest, and all others should be near zero after a gaming session.

> **Note:** This pinning resets after every reboot, which is why the systemd service is needed. The service finds the NVIDIA IRQ dynamically, so it works even if the IRQ number changes between reboots (which is normal).

---

## Fix 6 — NMI Watchdog

**Fixes: Unnecessary kernel interrupt overhead**

The kernel fires a Non-Maskable Interrupt (NMI) on all CPU cores at regular intervals to detect deadlocked processes. On a gaming PC this serves no practical purpose and wastes CPU cycles.

```bash
echo 'kernel.nmi_watchdog=0' | sudo tee -a /etc/sysctl.d/99-gaming.conf
sudo sysctl kernel.nmi_watchdog=0
```

The first command makes the change permanent. The second applies it immediately without a reboot.

---

## VKD3D Shader Cache

**What it is:** Forza Horizon 6 uses DirectX 12, which is translated to Vulkan by VKD3D-Proton. Every time the game encounters a new shader combination it has never seen before, VKD3D compiles it on the fly — causing a brief stutter. This is called **pipeline compilation stutter** and is a known limitation of DX12 games on Linux.

**What helps:**
- `PROTON_LOCAL_SHADER_CACHE=1` in the launch options (already included above) saves compiled pipelines to disk so they do not need to be recompiled next session.
- `VKD3D_CONFIG=descriptor_heap,no_upload_hvv` (already included above) reduces overhead during shader compilation.
- The cache **grows naturally as you play**. After several hours across different areas of the map, most common shader combinations will be cached and stutter will reduce significantly.

**Cache location:**
```
~/.local/share/Steam/steamapps/shadercache/2483190/VKD3D_shader_cache/
```

It is safe to back this file up. If you reinstall the game or switch Proton versions, copying your cache back can save hours of re-warming time. Caches are GPU-architecture-specific — a cache from another RTX 30-series user may work, but is not guaranteed.

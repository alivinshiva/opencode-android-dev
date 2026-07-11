# OpenCode on Android - Complete Setup Guide

> *"What if I could run a full Linux dev environment on my phone?"*
> — Me, at 3am, with zero good reasons to do this

## The Story

Let me be honest: **I didn't invent anything here.** I just duct-taped a bunch of existing tools together and called it a "development setup." Here's the ingredient list:

- **Termux** — A terminal emulator that somehow runs Linux on Android
- **proot-distro** — Runs Ubuntu inside Termux without root access (yes, it's as hacky as it sounds)
- **OpenCode** — An AI coding agent that now lives on my phone for some reason
- **Cloudflare Tunnel** — Makes my phone accessible from the internet like it's a server
- **ADB** — Let me type commands from my laptop because typing on a phone keyboard is pain
- **3am energy** — The real MVP

None of these tools were designed to work together. I just refused to accept that they shouldn't.

## What You'll Get

- Full Ubuntu Linux environment on your Android phone
- OpenCode AI coding agent running natively on ARM64
- SSH access from any laptop (like an EC2 instance, but it's a phone)
- Public URL for your dev server via Cloudflare Tunnel
- A story to tell at parties (if you go to the right kind of parties)
- Bragging rights that your phone is now a server

## Is This a Good Idea?

**For development and testing:** Absolutely. It works way better than it has any right to.

**For production:** Please don't. Your phone will overheat, the battery will die, and Cloudflare will judge you.

**For showing off to friends:** 10/10, highly recommend.

## Prerequisites

- Android phone with USB debugging enabled
- [Termux](https://f-droid.org/en/packages/com.termux/) (install from F-Droid, not Play Store)
- A laptop with ADB installed (for initial setup, or just type everything on the phone like a brave soul)
- ~1GB free storage
- WiFi connection
- A questionable sense of what constitutes a "valid use of time"

## Step 1: Install Termux & Grant Storage Access

Install Termux from [F-Droid](https://f-droid.org/en/packages/com.termux/), then open it and run:

```bash
pkg update -y && pkg upgrade -y
termux-setup-storage
```

Tap "Allow" when prompted for storage permission.

## Step 2: Install Dependencies

```bash
pkg upgrade -y
pkg install -y libicu nodejs git curl
```

### Error: `CANNOT LINK EXECUTABLE "node": library "libicui18n.so.78" not found`

This means the ICU library is missing. Fix:

```bash
pkg install -y libicu
pkg install -y nodejs
```

### Error: `Unable to locate package icu`

The package name is `libicu`, not `icu`:

```bash
pkg install -y libicu
```

## Step 3: Install OpenCode

### Error: `npm error code EBADPLATFORM` - Unsupported platform for opencode-ai

OpenCode doesn't officially support Android. Use the install script instead:

```bash
curl -fsSL https://opencode.ai/install | bash
```

### Error: `npm error code E404` - opencode-android-arm64 not found

This package doesn't exist on npm. Ignore it and use the curl installer above.

### After Installation

Add OpenCode to your PATH:

```bash
export PATH=/data/data/com.termux/files/home/.opencode/bin:$PATH
```

To make this permanent:

```bash
echo 'export PATH=/data/data/com.termux/files/home/.opencode/bin:$PATH' >> ~/.bashrc
```

### Error: `has unexpected e_type: 2`

The installer downloaded the wrong binary. The fix requires proot-distro (Step 4).

## Step 4: Install proot-distro & Ubuntu

Since OpenCode's binary requires glibc (which Termux doesn't have), we use proot-distro:

```bash
pkg install -y proot-distro
proot-distro install ubuntu
```

This installs a minimal Ubuntu rootfs (~200-300MB). It works like a lightweight container using `proot` (user-space chroot) — no root access needed on your phone.

## Step 5: Install OpenCode Inside Ubuntu

Log into Ubuntu:

```bash
proot-distro login ubuntu --bind /sdcard:/sdcard
```

Install dependencies and OpenCode:

```bash
apt update
apt install -y curl git
curl -fsSL https://opencode.ai/install | bash
```

Add to PATH:

```bash
echo 'export PATH=/data/data/com.termux/files/home/.opencode/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

Test it:

```bash
opencode --version
```

## Step 6: Create Convenience Scripts

Exit Ubuntu (`exit`) and back in Termux, create a shortcut script:

```bash
echo 'proot-distro login ubuntu --bind /sdcard:/sdcard -- bash -c "cd /sdcard/projects && bash"' > ~/ubuntu.sh
chmod +x ~/ubuntu.sh
```

Now you can enter Ubuntu with:

```bash
~/ubuntu.sh
```

### Error: `Permission denied` when running ubuntu.sh

```bash
chmod +x ~/ubuntu.sh
```

### Error: `bind: warning: line editing not enabled`

You're using spaces instead of colon in the bind mount. Correct syntax:

```bash
proot-distro login ubuntu --bind /sdcard:/sdcard
```

Not: `--bind /sdcard /sdcard` (spaces)

## Step 7: Access Your Files

Files created inside `/sdcard/` are visible in your Android file manager. Always work inside `/sdcard/`:

```bash
cd /sdcard/Download/projects
opencode
```

**Important:** Files created outside `/sdcard/` (like in Ubuntu's home `~`) are NOT visible in your file manager.

## Step 8: Set Up SSH Server (Optional)

Inside Ubuntu:

```bash
apt update && apt install -y openssh-server iproute2
```

Set a password:

```bash
passwd
```

Start SSH:

```bash
mkdir -p /run/sshd
/usr/sbin/sshd -p 8022
```

### Error: `ssh: unrecognized service`

The `service` command doesn't work in proot. Start sshd directly:

```bash
mkdir -p /run/sshd
/usr/sbin/sshd -p 8022
```

### Error: `ss: command not found`

```bash
apt install -y iproute2
```

## Step 9: Expose SSH via Cloudflare Tunnel

Cloudflare Tunnel is free and doesn't require a credit card (unlike ngrok).

Inside Ubuntu, install cloudflared:

```bash
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
```

Start the tunnel:

```bash
cloudflared tunnel --url tcp://localhost:8022
```

It will output a URL like:

```
Your quick Tunnel has been created! Visit it at:
https://your-keywords.trycloudflare.com
```

### Error: ngrok requires credit card for TCP

ngrok now requires a credit card for TCP tunnels on the free plan. Use Cloudflare Tunnel instead (shown above).

### Error: Tailscale doesn't work in proot

Tailscale requires kernel-level access (TUN devices) which proot can't provide. Use Cloudflare Tunnel instead.

## Step 10: SSH from Your Laptop

**Install cloudflared on your Mac/Linux:**

```bash
# macOS
brew install cloudflare/cloudflare/cloudflared

# Linux
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
```

**SSH into your phone:**

```bash
ssh root@localhost -o ProxyCommand="cloudflared access tcp --hostname YOUR-KEYWORDS.trycloudflare.com" -p 8022
```

Enter the password you set with `passwd`.

### Error: `Permission denied, please try again`

SSH is rejecting password login. Inside Ubuntu, fix the config:

```bash
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
pkill sshd
mkdir -p /run/sshd
/usr/sbin/sshd -p 8022
```

## Step 11: Access Your Web App from Laptop

If your app runs on `localhost:3000` inside Ubuntu, access it from your Mac:

**Option A: SSH tunnel (from Mac, open new terminal)**

```bash
ssh -L 3000:localhost:3000 root@localhost -o ProxyCommand="cloudflared access tcp --hostname YOUR-KEYWORDS.trycloudflare.com" -p 8022
```

Then open `http://localhost:3000` in your browser.

**Option B: Another Cloudflare tunnel (from inside Ubuntu)**

```bash
cloudflared tunnel --url http://localhost:3000
```

This gives you a public HTTPS URL to share with anyone.

## Step 12: Keep Services Running on Lock Screen

Android kills background processes when the screen locks. Fix this:

### Option 1: Disable battery optimization

Settings → Apps → Termux → Battery → **Unrestricted**

### Option 2: Use Termux wakelock

```bash
pkg install termux-api
termux-wakelock
```

### Option 3: Stay awake while charging

Settings → Developer Options → Enable **Stay Awake**

**Recommended:** Do all three and keep your phone plugged in while hosting.

## Creating a Home Screen Shortcut

Install [Termux:Widget](https://f-droid.org/en/packages/com.termux.widget/) from F-Droid, then:

```bash
mkdir -p ~/.shortcuts
cp ~/ubuntu.sh ~/.shortcuts/ubuntu.sh
```

Add the Termux:Widget widget to your home screen. Tap "ubuntu" to launch directly into Ubuntu with storage mounted.

## Device Specs & Performance

Tested on **Nothing Phone (2)**:

| Spec | Value |
|------|-------|
| Processor | Snapdragon 8+ Gen 1 (4nm) |
| CPU | Octa-core (1x 3.0GHz + 3x 2.5GHz + 4x 1.8GHz) |
| RAM | 12 GB |
| Storage | 256 GB UFS 3.1 |
| Android | 16 |

This setup works well for:
- JavaScript/TypeScript development
- Python projects
- Running dev servers
- Using OpenCode AI agent
- Light compilation tasks

Not recommended for:
- Heavy C++/Rust compilation (thermal throttling)
- Long-running production servers
- Database-heavy workloads

## Phone vs EC2 Comparison

| Feature | Phone (This Setup) | EC2 |
|---------|-------------------|-----|
| Cost | Free | $5-100+/month |
| Uptime | Battery dependent | 24/7 |
| Public IP | Changes on restart | Static |
| CPU | Shares with Android | Dedicated |
| Storage | Phone storage | EBS volumes |
| Best for | Dev/Testing | Production |

## Useful Commands Reference

```bash
# Enter Ubuntu
~/ubuntu.sh

# Exit Ubuntu
exit

# Run OpenCode
cd /sdcard/projects
opencode

# Start SSH server (inside Ubuntu)
/usr/sbin/sshd -p 8022

# Start Cloudflare tunnel (inside Ubuntu)
cloudflared tunnel --url tcp://localhost:8022

# Access phone storage from Ubuntu
ls /sdcard/Download

# Check storage usage
du -sh /sdcard/* | sort -rh | head -10
```

## Contributing

Found a fix or improvement? Open an issue or PR. If you found a way to make this even more unnecessarily complex, I want to hear about it.

## Tech Stack (a.k.a. The Duct Tape)

| Tool | What It Does | Why We Need It |
|------|-------------|----------------|
| Termux | Terminal emulator on Android | Because Android doesn't have a real shell |
| proot-distro | Runs Ubuntu without root | Because Android doesn't have glibc |
| OpenCode | AI coding agent | Because why not have AI on your phone |
| Cloudflare Tunnel | Public URL for SSH | Because your phone doesn't have a public IP |
| ADB | Control phone from laptop | Because typing on a phone keyboard is suffering |
| 3am energy | Glue that holds it together | Because this only makes sense at night |

## Disclaimer

This project was born at 3am and raised on coffee and questionable decisions. It is not affiliated with Nothing, Termux, OpenCode, Cloudflare, or any sane engineering practice. Use at your own risk. If your phone starts mining crypto, that's between you and your therapist.

## License

MIT (because even hacky projects deserve freedom)

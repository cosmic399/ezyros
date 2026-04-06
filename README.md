# EzyROS
> Zero-friction ROS2 installer for Ubuntu

## Install in one command

```bash
bash <(curl -sSL https://raw.githubusercontent.com/cosmic399/ezyros/master/install.sh)
```

## Supported

| ROS2 Distro | Ubuntu Version | Status |
|---|---|---|
| Humble | 22.04 Jammy | ✅ Recommended |
| Iron | 22.04 Jammy | ⚠️ EOL |
| Jazzy | 24.04 Noble | ✅ Recommended |

## What it does

- Auto-detects Ubuntu version
- Shows only compatible distros
- Handles all GPG keys and repos
- Sets up workspace automatically
- Configures bashrc cleanly
- Logs everything to `~/.ezyros/install.log`

## Requirements

- Ubuntu 22.04 (Jammy) or 24.04 (Noble)
- Non-root user with sudo access
- Internet connection
- At least 5GB free disk space

## After install

Close and reopen your terminal, then verify:

```bash
ros2 --version
```

Your workspace is at `~/ros2_ws`. Build packages with:

```bash
cd ~/ros2_ws
colcon build
```

## Logs

All output is saved to:

```
~/.ezyros/install.log
```

If anything fails, check the log and re-run `bash install.sh`.

## Built by

gcsr

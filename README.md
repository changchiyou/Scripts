# Scripts

Remote power/boot scripts for a dual-boot homelab server (Windows + Ubuntu on
separate disks, managed over SSH from an always-on Ubuntu box).

The server is woken via Wake-on-LAN and reached through an SSH tunnel.
Windows is the firmware default (daily-driver/gaming OS); Ubuntu can be
booted on demand with a one-shot firmware boot sequence that auto-reverts.

## Layout

```
wake.sh                 # WOL + wait for SSH (OS-agnostic; same NIC)
env.sh.example          # config template — copy to env.sh (gitignored)
lib/common.sh           # shared config loader + win() helper
win/
  sleep.sh              # power off while running Windows
  front.sh              # bring a game window to the foreground (scheduled-task trick)
ubuntu/
  sleep.sh              # power off while running Ubuntu
  boot-ubuntu.sh        # one-shot next boot into Ubuntu (run while Windows is up)
```

## Setup

```bash
cp env.sh.example env.sh   # then edit REMOTE_HOST / WOL_MAC / GAME_APP
```

`env.sh` holds machine-specific values (MAC address, host alias, app names)
and is gitignored on purpose — never commit it.

## Usage

```bash
./wake.sh                    # power on (boots Windows)
./win/front.sh               # focus the game window on Windows
./win/sleep.sh               # shut down Windows
./ubuntu/boot-ubuntu.sh      # reboot once into Ubuntu, then back to Windows
./ubuntu/sleep.sh            # shut down Ubuntu
```

## Notes

- `boot-ubuntu.sh` must run while Windows is up; it arms the UEFI boot
  sequence through `bcdedit`. The Ubuntu entry is resolved by its EFI path
  (`\EFI\ubuntu\shimx64.efi`), so it survives GUID changes from GRUB
  reinstalls and localized Windows editions.
- Both OS installs run a cloudflared connector for the same tunnel, so the
  host is reachable whichever one booted. `~/.ssh/config` needs one alias per
  OS (`WHS` = Windows user, `WHS-UBUNTU` = Ubuntu user), each with its own
  `HostKeyAlias` — the same hostname presents different host keys per OS.
- `ubuntu/sleep.sh` additionally needs a NOPASSWD sudoers rule for shutdown
  (see header comment in the script).
- Windows SSH output is CRLF and locale-encoded; `lib/common.sh`'s `win()`
  strips CR so parsing stays sane.

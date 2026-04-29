# VinMail v1.0.0

> "Bash-ing out an email."

First stable release. Modular architecture, full TUI, send mail, PKGBUILD.

## What's new in v1.0.0

- **Modular split** — `core.sh`, `ui.sh`, `accounts.sh`, `compose.sh`
- **Send mail** — To, Cc, Subject, body in `$EDITOR`, proper RFC 2822 headers
- **Abort anywhere** — leave any `addAccount` prompt empty to cancel
- **Tracked temp files** — cleaned up on exit/Ctrl-C
- **PKGBUILD** — `makepkg -si` on Arch Linux
- **Man page** — `man vinmail`
- **`/usr/bin/vinmail`** — proper system install path

## Install (Arch Linux)
```bash
makepkg -si
```

## Install (any Linux)
```bash
sudo ./setup.sh
```

## Module layout
```
/usr/bin/vinmail              <- entry point
/usr/lib/vinmail/
├── core.sh                   <- globals, init, validation, registry
├── ui.sh                     <- key reader, navigation, headers
├── accounts.sh               <- add/edit/delete/switch/status + sendMail
└── compose.sh                <- MIME builder, attachments, GPG sign
```

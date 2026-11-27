# Kubernetes for All — companion scripts

Companion scripts for [*Kubernetes for All*](https://leanpub.com/k8s4all) by Joel Bryan Juliano.

Book: [https://leanpub.com/k8s4all](https://leanpub.com/k8s4all)

This repository is the public script download for the book. Files are grouped by chapter and use the same paths the book describes, so you can source them as written.

## Chapter 6 — Terminal Colors and Logging

[`chapter-06-terminal-colors-and-logging/lib/logging.sh`](chapter-06-terminal-colors-and-logging/lib/logging.sh) is the complete logging library from Chapter 6: `tput_or_ansi`, `colour_init`, `log`, and `verbose_print`.

`colour_init` sets the text-attribute and 8-color foreground/background variables used by `log`. It leaves those variables empty when `--no-colour` is set (`no_colour`), when the `NO_COLOR` environment variable is set, or when standard output is not a terminal. It uses `tput` when available and falls back to ANSI escape sequences otherwise.

### How to use

From a clone of this repository:

```bash
source chapter-06-terminal-colors-and-logging/lib/logging.sh
colour_init
log "Starting up..."
log "Warning" "$fg_yellow"
log "Error occurred" "$fg_red"
```

To follow the book’s `lib/logging.sh` layout, copy the file into a `lib` directory next to your script:

```bash
mkdir -p lib
cp chapter-06-terminal-colors-and-logging/lib/logging.sh lib/logging.sh
source lib/logging.sh
colour_init
```

The Chapter 6 exercises should then work as printed: `source lib/logging.sh`, then call `log` and `colour_init`. If you call `colour_init` without first running the book’s `init` function, `ta_none` is treated as empty; that is safe.

To confirm colours are off:

```bash
no_colour=true
colour_init
log "Is this plain?" | cat -v
```

You can also set `NO_COLOR=1`, or pipe the output, which also disables colours.

## License

MIT License. See [LICENSE](LICENSE). Copyright (c) 2026 Joel Bryan Juliano.

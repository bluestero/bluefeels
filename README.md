# bluefeels

A look for [unikit](https://github.com/bluestero/unikit): a layer whose parts are the
fk kit's (the toolkit's `fk` is empty until a layer like this one fills it). Everything here is
only about looks, so the toolkit itself stays about work.

| Part | What it gives you |
|---|---|
| `k-config` | Edit `bluefeels/kitty/kitty.conf` (the file kitty reads through the link) in `$EDITOR` (else nano); warns if the link is missing. kitty reloads it by itself on save (0.47+). |
| `k-bg` | Kitty background picker: live preview, brightness, opacity, accent colours taken from the image |
| `k-theme` | Kitty colour themes with live preview: your short list plus kitty's 400+ |
| `k-icon` | Extra kitty app icons to pick from |
| `k-rofi` | Writes rofi's colours from the kitty theme and background in use |
| kitty accents, centered windows | Prompt, pickers, cursor and selection follow the background; new windows open in the middle |
| GNOME presets | Dash to Panel (one bar) or Dash2Dock, Vitals (+ chip icons), Blur my Shell, rounded corners, no window animations |

The toolkit works without it: rofi and btop just keep their default colours.

Dash to Panel and Dash2Dock both sit on the bottom edge of the screen, so installing both gives
two bars on top of each other. Pick one (`fk install` asks once when both are
ticked, or one is ticked and the other already in); the other can be added or removed any time.

## Install

You need the toolkit first (see its README), then:

```bash
uk layer add https://github.com/bluestero/bluefeels.git bluefeels   # clones into layers/bluefeels, offers to set it up
```

Its parts are fk's (the file `kit`), so `fk install` sets them up, never `tk install`:

```bash
fk install            # a tab each for Kitty looks and GNOME looks, then a summary; enter sets it up
fk install kitty-theme   # just that part (fk install ls lists them)
fk uninstall          # remove parts, your own settings put back
```

`uk update` keeps it current (bluefeels has its own tab there: fixes, new parts, clean-ups), `tk status` and
`tk doctor` show one line on how much of it is set up. Everything asks first.

## Parts

What `fk install <part>` sets up, and what `fk uninstall <part>` puts back.

| Part | What it sets up |
|---|---|
| `kitty` | the kitty terminal itself: the latest official build (checksum-checked) in `~/.local/kitty.app`; `kitty`/`kitten` in `~/.local/bin`, the app menu entry and Ctrl+Alt+T point at it. Ubuntu's apt kitty stays as the fallback (uninstall goes back to it). `./install.sh ls` shows when there's a newer one |
| `kitty-config` | `~/.config/kitty/kitty.conf` → `bluefeels/kitty/kitty.conf` |
| `kitty-nautilus` | `bluefeels/kitty/install-kitty-gnome.sh` (kitty as default terminal, Open in Terminal in Files; Ctrl+Alt+T focuses the open kitty window, or starts kitty, via `bluefeels/kitty/bin/kitty-focus`, and Ctrl+Shift+Alt+T opens a new window) |
| `btop` | installs btop (apt) if missing, writes `~/.config/btop/btop.conf` from `bluefeels/btop/btop.conf` with your patch over it (fk configs), and has k-theme write btop's colours from your kitty theme (re-done on every theme change). Uninstall puts your own btop config back |
| `yazi` | yazi 26.9.1 (terminal file manager) from GitHub in `~/.local/bin`, checked against a pinned sha256; also `ya`. The `y` command (`bluefeels/shell/y.sh`, loaded by its `shell/init.sh`) opens it and leaves your shell in the folder you quit in (`q`; `Q` quits without cd). Colours follow the kitty theme through the terminal palette. Uninstall removes the binaries; `~/.config/yazi` stays |
| `yazi-keys` | Two keys for yazi: `>` picks a folder inside the current one with fzf (up to 6 levels, no hidden folders), and ctrl+backspace deletes a word in yazi's text fields. Written as one marked block (`# >>> work toolkit >>>`) in `~/.config/yazi/keymap.toml`, from `bluefeels/yazi/keymap.toml`: added to your file if you have one (the rest stays yours), the file is made if not; if yours already has `prepend_keymap = [ ... ]` lines it says so and leaves it alone. Uninstall removes only the block |
| `starship` | `~/.config/starship.toml` → `bluefeels/starship/starship.toml`, and starship itself (latest from GitHub, sha256-checked) in `~/.local/bin` if it isn't installed |
| `keys` | `~/.inputrc` → `bluefeels/shell/inputrc` (case-insensitive Tab, Up/Down search by what's typed) |
| `zsh` | apt `zsh zsh-autosuggestions`; `~/.zshenv` gets one managed block |
| `login-shell` | `chsh` to zsh (log out once) |
| `bashrc-tidy` | Your old `~/.bashrc`: PATH, nvm, direnv/starship hooks and exact copies of `shell/common.sh`'s aliases come out (both shells get them from bluefeels), clashing leftovers (ble.sh, old okcli hooks, duplicate nvm) go; unikit's own line stays. Uninstall puts your lines back |
| `kitty-bg` | apt `imagemagick` (and fzf if there's none) for the `k-bg` picker, then a first pick (live preview; Esc = no background). Uninstall: background off, resized copies removed |
| `kitty-theme` | kitty's theme collection (about 0.6 MB from GitHub), a current fzf if yours is older than 0.60, then an optional first pick with `k-theme`. Uninstall: back to kitty's colours (your Mine list stays) |
| `kitty-accents` | `k-bg accents on`: a vivid colour from the background (always readable against it, never red) for the prompt's directory, `❯` and git branch, the toolkit's pickers and highlights, and kitty's cursor, selection, links, active tab and border. Terminal colours and red prod warnings stay put |
| `kitty-icons` | `bluefeels/kitty-icons/install-kitty-icons.sh` (icons + desktop entry for `k-icon`) |
| `kitty-centered` | GNOME setting `org.gnome.mutter center-new-windows`, so new windows (kitty included) open in the middle of the screen; the old value is put back on uninstall |
| `dash-to-panel` | Dash to Panel (GNOME extension) from extensions.gnome.org: the dock and the top bar merged into one bar (app icons with window previews on the left; clock, Vitals and system menu on the right; no Activities button). Preset look from `bluefeels/gnome/dash-to-panel/` (bottom, 35 px, dark, own apps-button icon). Your choice: on its own or together with `dash2dock`; asked separately, default No; `fk install dash-to-panel` on an installed one opens the same settings menu as `vitals`; the uninstall asks whether to put your old settings back or go to the app's defaults; log out once after installing |
| `dash2dock` | Dash2Dock Animated (macOS-style GNOME dock at the bottom) from extensions.gnome.org, with the toolkit's patches in `bluefeels/gnome/dash2dock/`: a click on an app with several windows shows window previews, calm drag-to-reorder, no gap above the dock; plus a preset look. Replaces Ubuntu's dock; your choice, alone or together with Dash to Panel; asked separately, default No; the uninstall puts that back; log out once after installing |
| `vitals` | Vitals (GNOME extension) from extensions.gnome.org: CPU, memory and temperature in the top bar. Asks whether to use the toolkit's look (`bluefeels/gnome/vitals/`: which sensors show, fixed widths). Your earlier settings are kept once; the uninstall asks whether to put them back or go to the app's defaults. `fk install vitals` on an installed one opens a menu: keep your settings, re-apply the look, reset to the app's defaults, or undo the last change (the settings from just before it are kept once); log out once after installing |
| `vitals-icons` | Two SVGs in `bluefeels/gnome/vitals-icons` (CPU chip with a solid core, RAM chip with pins) copied over the Vitals extension's `icons/original` icons, and its dropdown is centred under the pill (`menu-centered`, old value put back on uninstall); stock ones kept as `*.toolkit-orig` for the uninstall. An extension update restores the stock icons, so run it again after one |
| `blur-my-shell` | Blur my Shell (GNOME extension) from extensions.gnome.org with an optional look from `bluefeels/gnome/blur-my-shell/` (blurred overview in Liquid Glass and Alt+Tab, applications untouched). Same settings menu as `vitals`; log out once after installing |
| `rounded-corners` | Rounded Window Corners Reborn (GNOME extension) from extensions.gnome.org with an optional look from `bluefeels/gnome/rounded-window-corners/` (15 px, off for maximized and fullscreen windows). Same settings menu as `vitals`; log out once after installing |
| `no-animations` | GNOME setting `org.gnome.desktop.interface enable-animations = false`: no window zoom animations (snappier, and no blurry flash when the rofi launcher opens and closes fast); asked with default No: browsers then reduce motion too (websites drop their CSS animations); old value put back on uninstall |
| `notification-key` | GNOME setting `org.gnome.shell.keybindings toggle-message-tray = ['<Super>v']`: only Super+V opens the notification list, Super+M is freed (handy with `dash-to-panel`, where the list sits bottom right while popups show top centre); the uninstall puts back GNOME's default (Super+V and Super+M) |

## zsh

`zsh/zshrc` is small: shared history, the bash keys, an arrow-key Tab menu (case-insensitive),
and faded grey suggestions from history (Shift+Tab, → or End accepts, Alt+F one word; Tab is normal completion).
`~/.zshrc` loads unikit's `shell/init.sh` (its `zsh-hook` part), which loads this layer's
`shell/init.sh`, which loads `zsh/zshrc` first: zsh gets exactly the same aliases and tools as bash. Your own zsh tweaks go in `~/.zshrc` outside the managed block.

## What's in the folder

```
components.sh     the installer components (kitty-bg, kitty-theme, ..., rounded-corners)
bin/              k-config, k-bg, k-theme, k-icon, k-rofi
fk/               dash2dock (`fk dash2dock`); the extensions' presets are in `fk configs` (config_<id> in components.sh)
shell/            init.sh (loaded by every shell), common.sh (aliases, PATH, nvm), inputrc, y.sh and the tab-completion hooks
tools             what fk's picker and `fk help` show for these commands
backgrounds/      the images k-bg offers (licences in backgrounds/SOURCES.md)
themes/           team themes for k-theme (yours go in ~/.config/kitty/themes)
kitty-icons/      the kitty icon installer and cleanup
starship/         starship.toml (the prompt) and toml_patch.py (your patch laid over it)
btop/             btop.conf (btop)
yazi/             keymap.toml (yazi-keys)
zsh/              zshrc (zsh's own setup, loaded by shell/init.sh in zsh)
bash/             bashrc_plan.py and bashrc_restore.py (the bashrc-tidy part)
kitty/            kitty.conf (kitty-config), the "Open in Terminal" / Ctrl+Alt+T installer, bin/kitty-focus
gnome/            one folder per GNOME extension: the preset look (settings.dconf), patches
                  (dash2dock/check-patch.sh tries the patch against the newest release: `fk dash2dock`)
```

How a layer is laid out is described in the toolkit's README, under Layers.

## Licences

The background photos each have their own licence (some CC BY-SA, which means changed copies are
shared under the same licence): see `backgrounds/SOURCES.md`.

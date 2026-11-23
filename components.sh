# bluefeels: a look (kitty background, theme, accents, icons, window placement;
# the GNOME bar, dock, blur, corners, Vitals). A layer of the toolkit (lib/layers.sh): it
# adds its components to the installer, and the helpers they use (ask, ok, gx_*, look_*, ...)
# come from the toolkit's lib/components.sh, which loads this file at its end.
fk="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --------------------------------------------------------------- Kitty ---
# The kitty terminal (came from unikit, tasks/14): the program, its settings, Files' "Open in
# Terminal" and Ctrl+Alt+T (kitty/install-kitty-gnome.sh; kitty/bin/kitty-focus).
COMPONENTS+=(kitty kitty-config kitty-nautilus)
group_kitty() { echo Kitty; }; group_kitty_config() { echo Kitty; }; group_kitty_nautilus() { echo Kitty; }
requires_kitty() { echo linux; }; requires_kitty_nautilus() { echo gnome apt; }
GROUP_ABOUT[Kitty]="The kitty terminal, its settings, and Files' \"Open in Terminal\"."
# The official kitty build in ~/.local/kitty.app (no sudo). Ubuntu's apt kitty
# stays installed as a fallback; uninstalling this goes back to it.
kapp="$HOME/.local/kitty.app"
kapp_bin="$kapp/bin/kitty"
kitty_desktop="$HOME/.local/share/applications/kitty.desktop"
kapp_ver() { [[ -x "$kapp_bin" ]] && "$kapp_bin" --version 2>/dev/null | awk '{print $2}'; }
kapp_arch() { case "$(uname -m)" in x86_64|amd64) echo x86_64 ;; aarch64|arm64) echo arm64 ;; esac; }
# Newest release from GitHub: sets KL_VER KL_URL KL_SHA (empty when offline). Asked once per run.
kitty_latest_info() {
  [[ -n "${KL_DONE:-}" ]] && return
  KL_DONE=1 KL_VER="" KL_URL="" KL_SHA=""
  local out
  out=$(curl -fsS -m 6 https://api.github.com/repos/kovidgoyal/kitty/releases/latest 2>/dev/null |
    python3 -Ic '
import json, sys
r = json.load(sys.stdin); arch = sys.argv[1]; ver = r["tag_name"].lstrip("v")
for a in r["assets"]:
    if a["name"] == f"kitty-{ver}-{arch}.txz" and a.get("digest", "").startswith("sha256:"):
        print(ver, a["browser_download_url"], a["digest"][7:])
' "$(kapp_arch)" 2>/dev/null) || return 0
  read -r KL_VER KL_URL KL_SHA <<<"$out"
}
kapp_desktop_ok() { grep -q "^Exec=$kapp_bin" "$kitty_desktop" 2>/dev/null; }
term_alt() { update-alternatives --query x-terminal-emulator 2>/dev/null | sed -n 's/^Value: //p'; }

label_kitty() { echo "Kitty (latest)"; }
title_kitty() { echo "The kitty terminal itself, latest release (Ubuntu's is years old)"; }
detail_kitty() { echo "official build in ~/.local/kitty.app, kitty/kitten in ~/.local/bin, app menu entry; apt kitty kept as a fallback"; }
state_kitty() {
  NOTE=""
  [[ -n "$(kapp_arch)" ]] || { STATE=unsupported; NOTE="no kitty build for $(uname -m)"; return; }
  local v; v=$(kapp_ver)
  if [[ -z "$v" ]]; then
    STATE=missing
    type -P kitty >/dev/null && NOTE="now: $(kitty --version 2>/dev/null | awk '{print $2}') (apt)"
    return
  fi
  kitty_latest_info
  if ! linked "$HOME/.local/bin/kitty" "$kapp_bin" || ! kapp_desktop_ok; then STATE=partial; NOTE="$v, not hooked up everywhere"
  elif [[ -n "$KL_VER" ]] && ver_lt "$v" "$KL_VER"; then STATE=partial; NOTE="update: $v → $KL_VER"
  else STATE=installed; NOTE="$v"; fi
}
install_kitty() {
  local v tmp sum
  v=$(kapp_ver); kitty_latest_info
  if [[ -z "$v" ]] || { [[ -n "$KL_VER" ]] && ver_lt "$v" "$KL_VER"; }; then
    [[ -n "$KL_VER" ]] || { fail "couldn't reach GitHub to find the latest kitty (offline?)"; return 1; }
    if ask "Download kitty $KL_VER${v:+ (you have $v)} into ~/.local/kitty.app? (about 40 MB, no sudo)"; then
      tmp=$(mktemp -d)
      if ! curl -fsSL --retry 2 -o "$tmp/kitty.txz" "$KL_URL" 2>>"$log_file"; then
        rm -rf "$tmp"; fail "download failed (see the log)"; return 1
      fi
      sum=$(sha256sum "$tmp/kitty.txz" | cut -d' ' -f1)
      [[ "$sum" == "$KL_SHA" ]] || { rm -rf "$tmp"; fail "download didn't match GitHub's checksum, so nothing was installed"; return 1; }
      mkdir -p "$tmp/app" && tar xJf "$tmp/kitty.txz" -C "$tmp/app" 2>>"$log_file" &&
        "$tmp/app/bin/kitty" --version >/dev/null 2>&1 || { rm -rf "$tmp"; fail "the download doesn't run on this machine"; return 1; }
      rm -rf "$kapp.old"; [[ -d "$kapp" ]] && mv "$kapp" "$kapp.old"
      mkdir -p "$(dirname "$kapp")" && mv "$tmp/app" "$kapp" && rm -rf "$kapp.old" "$tmp"
      logf "  kitty $KL_VER from $KL_URL (sha256 $KL_SHA)"
      ok "kitty $KL_VER installed (checksum verified)"
    else skip; return 0; fi
  else ok "kitty $v is the latest"; fi

  if ! linked "$HOME/.local/bin/kitty" "$kapp_bin" || ! linked "$HOME/.local/bin/kitten" "$kapp/bin/kitten"; then
    if ask "Use it for the ${B}kitty${R} and ${B}kitten${R} commands? (links in ~/.local/bin)"; then
      link_file "$HOME/.local/bin/kitty" "$kapp_bin"
      link_file "$HOME/.local/bin/kitten" "$kapp/bin/kitten"
    else skip; fi
  fi

  # The app menu / dock entry. A user copy may already exist (kitty-icons keeps the
  # icon you picked there); only its Exec lines change.
  if ! kapp_desktop_ok && ask "Open the new kitty from the app menu and dock?"; then
    mkdir -p "$(dirname "$kitty_desktop")"
    if [[ ! -f "$kitty_desktop" ]]; then
      cp "$kapp/share/applications/kitty.desktop" "$kitty_desktop"
      sed -i "s|^Icon=kitty$|Icon=$kapp/share/icons/hicolor/256x256/apps/kitty.png|" "$kitty_desktop"
    fi
    sed -i -E "s#^(Try)?Exec=kitty( |$)#\1Exec=$kapp_bin\2#" "$kitty_desktop"
    type -P update-desktop-database >/dev/null && update-desktop-database "$(dirname "$kitty_desktop")" 2>/dev/null
    kapp_desktop_ok && ok "done" || fail "couldn't update $kitty_desktop"
  fi

  # Ctrl+Alt+T and Files' "Open in Terminal" (set up by kitty-nautilus) use this.
  if [[ "$(term_alt)" == /usr/bin/kitty ]] &&
     ask "Make Ctrl+Alt+T and \"Open in Terminal\" use the new kitty too? (needs sudo)"; then
    as_root update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$kapp_bin" 30 >>"$log_file" 2>&1 &&
      as_root update-alternatives --set x-terminal-emulator "$kapp_bin" >>"$log_file" 2>&1 && ok "done" || fail "update-alternatives failed (see the log)"
  fi
  warn "quit kitty fully (every window) and reopen it to start the new version"
}
uninstall_kitty() {
  [[ -d "$kapp" ]] || { ok "not installed"; return 0; }
  if [[ "$(term_alt)" == "$kapp_bin" ]]; then
    if [[ -x /usr/bin/kitty ]]; then as_root update-alternatives --set x-terminal-emulator /usr/bin/kitty >>"$log_file" 2>&1
    else as_root update-alternatives --auto x-terminal-emulator >>"$log_file" 2>&1; fi
  fi
  as_root update-alternatives --remove x-terminal-emulator "$kapp_bin" >>"$log_file" 2>&1 || true
  if [[ -f "$kitty_desktop" ]]; then
    sed -i -E "s#^(Try)?Exec=$kapp_bin#\1Exec=kitty#" "$kitty_desktop"
    type -P update-desktop-database >/dev/null && update-desktop-database "$(dirname "$kitty_desktop")" 2>/dev/null
  fi
  unlink_file "$HOME/.local/bin/kitty" "$kapp_bin"
  unlink_file "$HOME/.local/bin/kitten" "$kapp/bin/kitten"
  rm -rf "$kapp"
  if [[ -x /usr/bin/kitty ]]; then ok "removed; back to apt's kitty $(/usr/bin/kitty --version | awk '{print $2}') (quit and reopen kitty)"
  else warn "removed, and there's no apt kitty: install one with: sudo apt install kitty"; fi
}

# -------------------------------------------------------- kitty-config ---
kc="$HOME/.config/kitty/kitty.conf"; kc_src="$fk/kitty/kitty.conf"
label_kitty_config() { echo "Kitty settings"; }
config_kitty_config() { echo "file|kitty|kitty|$kc|$kc_src|link|kitty.conf|terminal settings"; }
config_after_kitty_config() { echo "  (kitty: ctrl+shift+f5 reloads it)"; }
config_saved_kitty_config() { echo "✓ kitty: your patch saved (ctrl+shift+f5 reloads kitty)"; }
title_kitty_config() { echo "Use bluefeels' kitty terminal settings"; }
detail_kitty_config() { echo "~/.config/kitty/kitty.conf from bluefeels/kitty/kitty.conf"; }
state_kitty_config() { NOTE=""
  type -P kitty >/dev/null || { STATE=n/a; NOTE="kitty isn't installed"; return; }
  if linked "$kc" "$kc_src"; then STATE=installed; else STATE=missing; fi; }
install_kitty_config() { linked "$kc" "$kc_src" && { ok "already linked"; return; }
  if [[ -f "$kc" && ! -L "$kc" ]] && ! cmp -s "$kc" "$kc_src"; then
    warn "your current kitty.conf differs from kitty/kitty.conf (it's kept as a backup)"
    (( details )) && diff -u "$kc" "$kc_src" | sed 's/^/    /'
  fi
  ask "Link kitty.conf to the repo copy?" && link_file "$kc" "$kc_src" || skip; }
touches_kitty_config() { echo "$kc"; }
uninstall_kitty_config() {
  points_at "$kc" "$kc_src" || return 0
  rm -f "$kc"
  local b; b=$(latest_backup "$kc")
  if [[ -n "$b" ]]; then mv "$b" "$kc"; ok "unlinked, put back ${b/#$HOME/\~}"
  else cp "$kc_src" "$kc"; ok "unlinked (left a plain copy so kitty keeps its settings)"; fi
}

# ------------------------------------------------------ kitty-nautilus ---
nat_ext="$HOME/.local/share/nautilus-python/extensions/nautilus_open_any_terminal.py"
nat_schema="com.github.stunkymonkey.nautilus-open-any-terminal"
label_kitty_nautilus() { echo "Kitty in Files"; }
title_kitty_nautilus() { echo "Make kitty the default terminal and add \"Open in Terminal\" to Files"; }
detail_kitty_nautilus() { echo "kitty as default terminal, 'Open in Terminal' in Files"; }
state_kitty_nautilus() { NOTE=""
  type -P nautilus >/dev/null || { STATE=unsupported; NOTE="needs Nautilus (GNOME Files)"; return; }
  type -P kitty >/dev/null || { STATE=n/a; NOTE="kitty isn't installed"; return; }
  local n=0
  [[ -f "$nat_ext" ]] && (( n++ ))
  [[ "$(gsettings get "$nat_schema" terminal 2>/dev/null)" == "'kitty'" ]] && (( n++ ))
  [[ "$(term_alt)" == /usr/bin/kitty || "$(term_alt)" == "$kapp_bin" ]] && (( n++ ))
  if (( n == 3 )); then STATE=installed; elif (( n )); then STATE=partial; else STATE=missing; fi; }
install_kitty_nautilus() { ask "Run kitty/install-kitty-gnome.sh (may need sudo)?" && bash "$fk/kitty/install-kitty-gnome.sh" || skip; }
uninstall_kitty_nautilus() { bash "$fk/kitty/uninstall-kitty-gnome.sh"; }

COMPONENTS+=(kitty-bg kitty-theme kitty-accents kitty-icons kitty-centered dash2dock dash-to-panel no-animations notification-key vitals vitals-icons blur-my-shell rounded-corners)
# Its parts are fk's (the file "kit"): fk install / fk uninstall, never in
# tk install. Its tabs (a layer names its own groups), what each needs from the machine, and
# which ones have a settings menu (fk install <id> on an installed one).
group_kitty_bg() { echo "Kitty looks"; }; group_kitty_theme() { echo "Kitty looks"; }; group_kitty_accents() { echo "Kitty looks"; }
group_kitty_icons() { echo "Kitty looks"; }; group_kitty_centered() { echo "Kitty looks"; }
group_dash2dock() { echo "GNOME looks"; }; group_dash_to_panel() { echo "GNOME looks"; }
group_no_animations() { echo "GNOME looks"; }; group_notification_key() { echo "GNOME looks"; }
group_vitals() { echo "GNOME looks"; }
group_vitals_icons() { echo "GNOME looks"; }; group_blur_my_shell() { echo "GNOME looks"; }
group_rounded_corners() { echo "GNOME looks"; }
GROUP_ABOUT["Kitty looks"]="How kitty looks: background images, colour themes, accents from the background, app icons, centred windows."
GROUP_ABOUT["GNOME looks"]="How GNOME looks: one bar or a dock, Vitals in the top bar, blur, rounded corners, no animations, Super+V alone opens notifications."
# Dash2Dock and Dash to Panel both sit on the bottom edge: with both ticked (or one ticked
# and the other in already) the summary asks once.
CLASHES+=("dash2dock dash-to-panel|Both bars use the same space. Keep both?")
requires_kitty_bg() { echo apt; }; requires_kitty_icons() { echo apt; }
requires_kitty_centered() { echo gnome; }; requires_dash2dock() { echo gnome; }
requires_dash_to_panel() { echo gnome; }; requires_no_animations() { echo gnome; }
requires_notification_key() { echo gnome; }
requires_vitals() { echo gnome; }; requires_vitals_icons() { echo gnome; }
requires_blur_my_shell() { echo gnome; }; requires_rounded_corners() { echo gnome; }
LOOK_PARTS+=(dash-to-panel vitals blur-my-shell rounded-corners)
NEEDS+=([kitty-bg]=kitty-config [kitty-theme]=kitty-config [kitty-accents]=kitty-config [kitty-icons]=kitty [vitals-icons]=vitals)
wants_launcher_entry() { d2d_present || d2d_other_bar; }

# ------------------------------------------------------------ kitty-bg ---
# k-bg itself comes with the toolkit (kitty/bin); this sets up what it needs and
# the first pick. Its state is ~/.config/kitty/background.conf ("none" counts).
kbg_conf="$HOME/.config/kitty/background.conf"
kbg_pkgs=(imagemagick)
label_kitty_bg() { echo "Kitty backgrounds"; }
title_kitty_bg() { echo "Background images with live preview, brightness and opacity (k-bg)"; }
detail_kitty_bg() { echo "imagemagick (apt) to resize images, fzf for the picker; your pick in ~/.config/kitty/background.conf"; }
state_kitty_bg() { NOTE=""
  type -P kitty >/dev/null || { STATE=n/a; NOTE="kitty isn't installed"; return; }
  linked "$kc" "$kc_src" || { STATE=n/a; NOTE="needs kitty-config first"; return; }
  local missing; missing=$(missing_pkgs "${kbg_pkgs[@]}")
  type -P fzf >/dev/null || missing+="fzf "
  if [[ -z "$missing" && -f "$kbg_conf" ]]; then STATE=installed; NOTE="$("$kbg" current 2>/dev/null)"
  elif [[ -n "$missing" && ! -f "$kbg_conf" ]]; then STATE=missing
  else STATE=partial; NOTE="${missing:+needs: $missing}"; [[ -f "$kbg_conf" ]] || NOTE="no background picked yet"; fi; }
install_kitty_bg() {
  linked "$kc" "$kc_src" || { skip "needs kitty-config first"; return; }
  local missing; missing=$(missing_pkgs "${kbg_pkgs[@]}")
  if [[ -n "$missing" ]]; then
    if ask "Install $missing(apt, needs sudo; it resizes the images)?"; then
      dry || apt_install "${kbg_pkgs[@]}" && ok "installed" || { fail "apt failed (see $log_file)"; return 1; }
    else skip; return 0; fi
  fi
  type -P fzf >/dev/null || install_fzf
  [[ -f "$kbg_conf" ]] && { ok "background: $("$kbg" current 2>/dev/null) ${D}(k-bg to change)${R}"; return; }
  dry && { say "      ${D}would open the k-bg picker${R}"; return; }
  if [[ $mode == ask && -t 1 ]] && ask "Pick a background now? (↑/↓ previews it live; esc = none for now)"; then
    "$kbg" </dev/tty >/dev/tty 2>&1
  fi
  [[ -f "$kbg_conf" ]] || "$kbg" off >>"$log_file" 2>&1
  ok "background: $("$kbg" current 2>/dev/null) ${D}(k-bg any time)${R}"
}
uninstall_kitty_bg() {
  [[ -f "$kbg_conf" ]] || { ok "nothing set"; return 0; }
  [[ "$("$kbg" __accents_state 2>/dev/null)" == on ]] && uninstall_kitty_accents
  "$kbg" off >>"$log_file" 2>&1
  rm -f "$kbg_conf"
  rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/k-bg" "${XDG_STATE_HOME:-$HOME/.local/state}/k-bg"
  ok "background off, picks and resized copies removed ${D}(fzf and imagemagick stay installed)${R}"
}

# --------------------------------------------------------- kitty-theme ---
# k-theme comes with the toolkit; this downloads kitty's theme collection and
# offers a first pick. Your own themes go in bluefeels/themes (k-theme add).
kth="$fk/bin/k-theme"
kth_conf="$HOME/.config/kitty/theme.conf"
kth_data="${XDG_DATA_HOME:-$HOME/.local/share}/k-theme"
label_kitty_theme() { echo "Kitty themes"; }
title_kitty_theme() { echo "Colour themes with live preview, yours plus kitty's 400+ (k-theme)"; }
detail_kitty_theme() { echo "kitty's theme collection into ${kth_data/#$HOME/\~} (about 0.6 MB); fzf $FZF_MIN+ for the picker; your list in ~/.config/k-theme/mine"; }
state_kitty_theme() { NOTE=""
  type -P kitty >/dev/null || { STATE=n/a; NOTE="kitty isn't installed"; return; }
  linked "$kc" "$kc_src" || { STATE=n/a; NOTE="needs kitty-config first"; return; }
  local n=0
  local v; v=$(fzf_ver)
  [[ -n "$v" ]] && ! ver_lt "$v" "$FZF_MIN" && (( n++ ))
  [[ -s "$kth_data/kitty/index.tsv" ]] && (( n++ ))
  if (( n == 2 )); then STATE=installed; NOTE="$("$kth" current 2>/dev/null)"
  elif (( n )); then STATE=partial; [[ -n "$v" ]] && ver_lt "$v" "$FZF_MIN" && NOTE="fzf $v: no Mine / All tabs (needs $FZF_MIN+)"
  else STATE=missing; fi; }
install_kitty_theme() {
  linked "$kc" "$kc_src" || { skip "needs kitty-config first"; return; }
  local v; v=$(fzf_ver)
  [[ -n "$v" ]] && ! ver_lt "$v" "$FZF_MIN" || install_fzf   # the tabs need a current fzf
  if [[ ! -s "$kth_data/kitty/index.tsv" ]]; then
    if "$kth" __ready 2>/dev/null; then ok "kitty's collection: $(grep -c . "$kth_data/kitty/index.tsv") themes"
    elif ask "Download kitty's theme collection? (about 0.6 MB from GitHub)"; then
      dry || "$kth" update >>"$log_file" 2>&1 && ok "$(grep -c . "$kth_data/kitty/index.tsv" 2>/dev/null) themes" ||
        { fail "download failed (offline?); later: k-theme update"; return 1; }
    else skip "your own themes in bluefeels/themes still work"; fi
  fi
  [[ -f "$kth_conf" ]] && { ok "theme: $("$kth" current) ${D}(k-theme to change)${R}"; return; }
  dry && return
  if [[ $mode == ask && -t 1 ]] && ask "Pick a colour theme now? (↑/↓ previews it live; esc keeps kitty's colours)" n; then
    "$kth" </dev/tty >/dev/tty 2>&1
  fi
  ok "theme: $("$kth" current) ${D}(k-theme any time)${R}"
}
uninstall_kitty_theme() {
  [[ -f "$kth_conf" || -d "$kth_data" ]] || { ok "nothing set"; return 0; }
  [[ -f "$kth_conf" ]] && "$kth" default >>"$log_file" 2>&1
  rm -rf "$kth_data"
  ok "back to kitty's colours; downloaded collection removed ${D}(your themes in bluefeels/themes stay)${R}"
}

# ------------------------------------------------------- kitty-accents ---
kbg="$fk/bin/k-bg"
# on only in a saved background.conf (k-bg reads a missing one as accents on)
ka_on() { [[ -f $kbg_conf && "$("$kbg" __accents_state 2>/dev/null)" == on ]]; }
label_kitty_accents() { echo "Kitty accents"; }
title_kitty_accents() { echo "Prompt, pickers, cursor and selection take a colour from the background"; }
detail_kitty_accents() { echo "k-bg accents on: colour lines in ~/.config/kitty/background.conf (terminal colours unchanged)"; }
state_kitty_accents() { NOTE=""
  type -P kitty >/dev/null || { STATE=n/a; NOTE="kitty isn't installed"; return; }
  linked "$kc" "$kc_src" || { STATE=n/a; NOTE="needs kitty-config first"; return; }
  if ka_on; then STATE=installed; else STATE=missing; fi; }
install_kitty_accents() {
  ka_on && { ok "already on"; return; }
  linked "$kc" "$kc_src" || { skip "needs kitty-config first"; return; }
  if ask "Tint kitty's accents to match each background?"; then
    logf "  $("$kbg" accents on 2>&1)"
    ok "on (restart kitty once if it doesn't show yet; ${C}k-bg accents off${R} undoes it)"
  else skip; fi
}
uninstall_kitty_accents() {
  ka_on || { ok "already off"; return; }   # (no background.conf: nothing to turn off, none made)
  "$kbg" accents off >>"$log_file" 2>&1 && ok "off (kitty's default accent colours)"
}

# --------------------------------------------------------- kitty-icons ---
icon_dir="$HOME/.local/share/icons/kitty-custom"
label_kitty_icons() { echo "Kitty icons"; }
title_kitty_icons() { echo "Extra kitty app icons to pick from (k-icon)"; }
detail_kitty_icons() { echo "extra kitty icons + the k-icon picker"; }
state_kitty_icons() { NOTE=""
  [[ -f /usr/share/applications/kitty.desktop || -f "$kapp/share/applications/kitty.desktop" ]] ||
    { STATE=n/a; NOTE="kitty isn't installed"; return; }
  local n; n=$(find "$icon_dir" -maxdepth 1 -name '*.png' 2>/dev/null | wc -l)
  if (( n >= 3 )) && grep -q "^Icon=$icon_dir/" "$kitty_desktop" 2>/dev/null; then STATE=installed
  elif (( n )); then STATE=partial   # (kitty.desktop alone is the kitty part's, not ours)
  else STATE=missing; fi; }
install_kitty_icons() { ask "Run bluefeels/kitty-icons/install-kitty-icons.sh?" && bash "$fk/kitty-icons/install-kitty-icons.sh" || skip; }
uninstall_kitty_icons() { bash "$fk/kitty-icons/cleanup-kitty-icons.sh"; }

# ------------------------------------------------------ kitty-centered ---
# GNOME places new windows by itself; this makes it open them in the middle of
# the screen (kitty can't choose its own position on Wayland).
ctr_schema=org.gnome.mutter ctr_key=center-new-windows
label_kitty_centered() { echo "Centered windows"; }
title_kitty_centered() { echo "Open new windows (kitty included) in the middle of the screen"; }
detail_kitty_centered() { echo "GNOME setting $ctr_schema $ctr_key = true (your old value is kept for the uninstall)"; }
state_kitty_centered() { NOTE=""
  type -P gsettings >/dev/null && gsettings list-keys "$ctr_schema" 2>/dev/null | grep -qx "$ctr_key" ||
    { STATE=unsupported; NOTE="needs GNOME"; return; }
  if [[ "$(gsettings get "$ctr_schema" "$ctr_key")" == true ]]; then STATE=installed; else STATE=missing; fi; }
install_kitty_centered() {
  [[ "$(gsettings get "$ctr_schema" "$ctr_key")" == true ]] && { ok "already on"; return; }
  ask "Open new windows in the middle of the screen?" || { skip; return; }
  remember_setting kitty-centered "$(gsettings get "$ctr_schema" "$ctr_key")"
  gsettings set "$ctr_schema" "$ctr_key" true && ok "new windows open centered"
}
uninstall_kitty_centered() {
  local prev; prev=$(recall_setting kitty-centered)
  [[ -n "$prev" ]] || { ok "nothing of ours to undo"; return; }
  gsettings set "$ctr_schema" "$ctr_key" "$prev" && ok "back to $prev"
  forget_setting kitty-centered
}

# ------------------------------------------------------- no-animations ---
# GNOME's window zoom animations make fast open/close windows (the rofi launcher) flash blurry.
anim_schema=org.gnome.desktop.interface anim_key=enable-animations
label_no_animations() { echo "No window animations"; }
title_no_animations() { echo "Turn off GNOME's window animations (browsers then drop CSS animations too: reduced motion)"; }
detail_no_animations() { echo "GNOME setting $anim_schema $anim_key = false (your old value is kept for the uninstall)"; }
state_no_animations() { NOTE=""
  type -P gsettings >/dev/null && gsettings list-keys "$anim_schema" 2>/dev/null | grep -qx "$anim_key" ||
    { STATE=unsupported; NOTE="needs GNOME"; return; }
  if [[ "$(gsettings get "$anim_schema" "$anim_key")" == false ]]; then STATE=installed; else STATE=missing; fi; }
install_no_animations() {
  [[ "$(gsettings get "$anim_schema" "$anim_key")" == false ]] && { ok "already off"; return; }
  ask "Turn off GNOME's window animations?" n || { skip; return; }
  remember_setting no-animations "$(gsettings get "$anim_schema" "$anim_key")"
  gsettings set "$anim_schema" "$anim_key" false && ok "animations off"
}
uninstall_no_animations() {
  local prev; prev=$(recall_setting no-animations)
  [[ -n "$prev" ]] || { ok "nothing of ours to undo"; return; }
  gsettings set "$anim_schema" "$anim_key" "$prev" && ok "back to $prev"
  forget_setting no-animations
}

# ---------------------------------------------------- notification-key ---
# GNOME opens the notification list with Super+V and the older Super+M. Super+V alone leaves
# Super+M free; with Dash to Panel the list is bottom right while popups show top centre.
nk_schema=org.gnome.shell.keybindings nk_key=toggle-message-tray
label_notification_key() { echo "Super+V alone for notifications"; }
title_notification_key() { echo "Only Super+V opens the notification list (Super+M freed)"; }
detail_notification_key() { echo "GNOME setting $nk_schema $nk_key = ['<Super>v'] (the uninstall puts back GNOME's default, Super+V and Super+M)"; }
state_notification_key() { NOTE=""
  type -P gsettings >/dev/null && gsettings list-keys "$nk_schema" 2>/dev/null | grep -qx "$nk_key" ||
    { STATE=unsupported; NOTE="needs GNOME"; return; }
  if [[ "$(gsettings get "$nk_schema" "$nk_key")" == "['<Super>v']" ]]; then STATE=installed; else STATE=missing; fi; }
install_notification_key() {
  [[ "$(gsettings get "$nk_schema" "$nk_key")" == "['<Super>v']" ]] && { ok "already Super+V only"; return; }
  ask "Open notifications with Super+V only (free Super+M)?" || { skip; return; }
  gsettings set "$nk_schema" "$nk_key" "['<Super>v']" && ok "Super+V only"
}
uninstall_notification_key() {
  gsettings reset "$nk_schema" "$nk_key" && ok "back to Super+V and Super+M"
}

# --------------------------------------------------------------- vitals ---
# Vitals (CPU, memory, temperature in the top bar) with its look: which sensors show,
# fixed widths, alphabetical dropdown. vitals-icons (below) adds the chip icons.
vt_uuid="Vitals@CoreCoding.com"; vt_path=/org/gnome/shell/extensions/vitals/; vt_file="$fk/gnome/vitals/settings.dconf"
label_vitals() { echo "Vitals"; }
title_vitals() { echo "CPU, memory and temperature in the top bar (GNOME extension; log out once)"; }
detail_vitals() { echo "GNOME extension $vt_uuid from extensions.gnome.org + preset look bluefeels/gnome/vitals (sensors shown, fixed widths); the uninstall offers your earlier settings or the defaults"; }
state_vitals() { gx_state "$vt_uuid" "$vt_path" "$vt_file"; }
config_vitals() { echo "dconf|Vitals|$vt_uuid|$vt_path|$vt_file|$vt_uuid|CPU, memory and network readings in the top bar|"; }
install_vitals() { gx_install "$vt_uuid" "Vitals" "$vt_path" "$vt_file"; }
uninstall_vitals() { gx_uninstall "$vt_uuid" "Vitals" "$vt_path"; }

# -------------------------------------------------------- blur-my-shell ---
# Blur my Shell: blurred overview (Liquid Glass), Alt+Tab and panel; applications untouched.
bm_uuid="blur-my-shell@aunetx"; bm_path=/org/gnome/shell/extensions/blur-my-shell/; bm_file="$fk/gnome/blur-my-shell/settings.dconf"
label_blur_my_shell() { echo "Blur my Shell"; }
title_blur_my_shell() { echo "Blurred overview and Alt+Tab (GNOME extension; log out once)"; }
detail_blur_my_shell() { echo "GNOME extension $bm_uuid from extensions.gnome.org + preset look bluefeels/gnome/blur-my-shell; the uninstall offers your earlier settings or the defaults"; }
state_blur_my_shell() { gx_state "$bm_uuid" "$bm_path" "$bm_file"; }
config_blur_my_shell() { echo "dconf|Blur my Shell|$bm_uuid|$bm_path|$bm_file|$bm_uuid|blurs the top bar, the overview and the dock|"; }
install_blur_my_shell() { gx_install "$bm_uuid" "Blur my Shell" "$bm_path" "$bm_file"; }
uninstall_blur_my_shell() { gx_uninstall "$bm_uuid" "Blur my Shell" "$bm_path"; }

# ------------------------------------------------------ rounded-corners ---
# Rounded Window Corners Reborn: 15 px corners, kept off for maximized and fullscreen windows.
rc_uuid="rounded-window-corners@fxgn"; rc_path=/org/gnome/shell/extensions/rounded-window-corners-reborn/; rc_file="$fk/gnome/rounded-window-corners/settings.dconf"
label_rounded_corners() { echo "Rounded corners"; }
title_rounded_corners() { echo "Rounded corners on every window (GNOME extension; log out once)"; }
detail_rounded_corners() { echo "GNOME extension $rc_uuid from extensions.gnome.org + preset look bluefeels/gnome/rounded-window-corners (15 px); the uninstall offers your earlier settings or the defaults"; }
state_rounded_corners() { gx_state "$rc_uuid" "$rc_path" "$rc_file"; }
config_rounded_corners() { echo "dconf|Rounded Window Corners|$rc_uuid|$rc_path|$rc_file|$rc_uuid|rounded corners on every window|"; }
install_rounded_corners() { gx_install "$rc_uuid" "Rounded Window Corners" "$rc_path" "$rc_file"; }
uninstall_rounded_corners() { gx_uninstall "$rc_uuid" "Rounded Window Corners" "$rc_path"; }

# -------------------------------------------------------- vitals-icons ---
# Clear CPU and memory icons for the Vitals top-bar extension (bluefeels/gnome/vitals-icons).
# They go over the extension's "original" icon style; the old files are kept as
# *.toolkit-orig for the uninstall. An extension update puts the stock icons back,
# so run the setup again after one. Also centres the dropdown under the Vitals pill.
vi_dir="$HOME/.local/share/gnome-shell/extensions/Vitals@CoreCoding.com/icons/original"
vi_files=(cpu-symbolic.svg memory-symbolic.svg)
vi_gs() { gsettings --schemadir "$vi_dir/../../schemas" "$@"; }
vi_key=org.gnome.shell.extensions.vitals
vi_centered() { [[ "$(vi_gs get $vi_key menu-centered 2>/dev/null)" == true ]]; }
vi_same() { local f; for f in "${vi_files[@]}"; do cmp -s "$fk/gnome/vitals-icons/$f" "$vi_dir/$f" || return 1; done; }
label_vitals_icons() { echo "Vitals icons"; }
title_vitals_icons() { echo "Clear CPU chip and RAM chip icons in the Vitals top bar, dropdown centred under it"; }
detail_vitals_icons() { echo "two SVGs copied into the Vitals extension's icons/original folder (stock ones kept for the uninstall); Vitals setting menu-centered = true"; }
state_vitals_icons() { NOTE=""
  [[ -d "$vi_dir" ]] || { STATE=n/a; NOTE="needs the Vitals extension"; return; }
  if vi_same && vi_centered; then STATE=installed; else STATE=missing; fi; }
install_vitals_icons() {
  vi_same && vi_centered && { ok "already in place"; return; }
  ask "Replace Vitals' CPU and memory icons with the chip icons and centre its dropdown?" || { skip; return; }
  dry && return
  local f
  for f in "${vi_files[@]}"; do
    [[ -e "$vi_dir/$f.toolkit-orig" ]] || cp "$vi_dir/$f" "$vi_dir/$f.toolkit-orig"
    cp "$fk/gnome/vitals-icons/$f" "$vi_dir/$f"
  done
  remember_setting vitals-menu-centered "$(vi_gs get $vi_key menu-centered)"
  vi_gs set $vi_key menu-centered true
  ok "icons copied, dropdown centred ${D}(turn the extension off and on, or log out, to see the icons)${R}"
}
uninstall_vitals_icons() {
  local f n=0
  for f in "${vi_files[@]}"; do
    [[ -e "$vi_dir/$f.toolkit-orig" ]] && { mv "$vi_dir/$f.toolkit-orig" "$vi_dir/$f"; n=1; }
  done
  local prev; prev=$(recall_setting vitals-menu-centered)
  [[ -n "$prev" ]] && { vi_gs set $vi_key menu-centered "$prev"; forget_setting vitals-menu-centered; n=1; }
  (( n )) && ok "stock icons and dropdown position back" || ok "nothing of ours to undo"
}

# ---------------------------------------------------------- dash2dock ---
# Dash2Dock Animated (GNOME extension, macOS-style dock) from extensions.gnome.org, with
# the toolkit's patches (bluefeels/gnome/dash2dock/dash2dock.patch, written against release 92):
#  - a click on an app with several windows shows live window previews (the app icon for a minimized window);
#  - dragging an icon to reorder no longer flickers;
#  - windows stop exactly at the dock (no extra gap); the dock panel catches the mouse.
# Plus a preset look (bluefeels/gnome/dash2dock/settings.dconf). Replaces Ubuntu's dock while it's on.
# Pick this, dash-to-panel (below), or both.
d2d_uuid="dash2dock-lite@icedman.github.com"
d2d_dir="$HOME/.local/share/gnome-shell/extensions/$d2d_uuid"; d2d_src="$fk/gnome/dash2dock"
d2d_path=/org/gnome/shell/extensions/dash2dock-lite/
d2d_present() { [[ -d "$d2d_dir" ]]; }
d2d_patched() { grep -q "work-toolkit patch" "$d2d_dir/dock.js" 2>/dev/null; }
# a release our patches don't fit: it runs without them, and asking again changes nothing
d2d_unfit() { ! patch -p1 -N --dry-run -s -d "$d2d_dir" <"$d2d_src/dash2dock.patch" >/dev/null 2>&1; }
d2d_enabled() { gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -q "'$d2d_uuid'"; }
label_dash2dock() { echo "Dash2Dock dock"; }
title_dash2dock() { echo "macOS-style dock with window previews on click (replaces Ubuntu's dock; log out once)"; }
detail_dash2dock() { echo "GNOME extension $d2d_uuid from extensions.gnome.org + bluefeels/gnome/dash2dock patches and preset look; turns Ubuntu's dock off (put back by the uninstall)"; }
state_dash2dock() { NOTE=""
  type -P gnome-shell >/dev/null || { STATE=unsupported; NOTE="needs GNOME"; return; }
  if d2d_present && d2d_patched && d2d_enabled; then STATE=installed
  elif d2d_present && d2d_enabled && d2d_unfit; then STATE=installed; NOTE="without our patches (they don't fit this release)"
  elif d2d_present || d2d_enabled; then STATE=partial
  else STATE=missing; fi; }
install_dash2dock() {
  if d2d_present && d2d_enabled && { d2d_patched || d2d_unfit; }; then ok "already installed"; return; fi
  ask "Install the Dash2Dock dock (replaces Ubuntu's dock)?" n || { skip; return; }
  type -P patch >/dev/null || { fail "the 'patch' tool is missing (sudo apt install patch)"; return 1; }
  d2d_present || ext_download "$d2d_uuid" Dash2Dock || return 1
  if d2d_patched; then ok "patches already in"
  elif patch -p1 -N --dry-run -s -d "$d2d_dir" <"$d2d_src/dash2dock.patch" >>"$log_file" 2>&1; then
    patch -p1 -N -s -b -z .orig -d "$d2d_dir" <"$d2d_src/dash2dock.patch" >>"$log_file" 2>&1 &&
      ok "patched: window previews, calm drag, no gap (originals kept as *.orig)"
  else
    warn "this Dash2Dock release ($(grep -o '"version": *[0-9]*' "$d2d_dir/metadata.json" | grep -o '[0-9]*$')) doesn't match our patches (written for 92): the dock works, but without them (fk doctor shows which parts fail)"
  fi
  if ask "Use the toolkit's look for it (size, full-width panel, colours)? Your current settings are kept for the uninstall."; then
    mkdir -p "$orig_dir"
    [[ -f "$orig_dir/dash2dock.dconf" ]] || dconf dump "$d2d_path" >"$orig_dir/dash2dock.dconf" 2>/dev/null
    dconf load "$d2d_path" <"$d2d_src/settings.dconf" && ok "look applied"
  else skip; fi
  install_launcher_entry
  if ext_is_on ubuntu-dock@ubuntu.com; then   # Ubuntu's dock would sit next to it
    remember_setting dock-ubuntu on
    gnome-extensions disable ubuntu-dock@ubuntu.com >>"$log_file" 2>&1 && ok "Ubuntu's dock off"
  fi
  ext_list add "$d2d_uuid" && ok "enabled"
  warn "log out and back in once (Wayland loads new extensions only at login)"
}
uninstall_dash2dock() {
  ext_list del "$d2d_uuid"
  if d2d_present; then
    gnome-extensions disable "$d2d_uuid" >/dev/null 2>&1
    gnome-extensions uninstall "$d2d_uuid" >/dev/null 2>&1 || rm -rf "$d2d_dir"
    ok "dock removed"
  fi
  dconf reset -f "$d2d_path"
  [[ -f "$orig_dir/dash2dock.dconf" ]] && { dconf load "$d2d_path" <"$orig_dir/dash2dock.dconf"; rm -f "$orig_dir/dash2dock.dconf"; }
  if [[ "$(recall_setting dock-ubuntu)" == on ]]; then
    gnome-extensions enable ubuntu-dock@ubuntu.com >/dev/null 2>&1 && ok "Ubuntu's dock back on"
    forget_setting dock-ubuntu
  fi
  remove_launcher_entry
}
d2d_other_bar() { [[ -d "$HOME/.local/share/gnome-shell/extensions/dash-to-panel@jderose9.github.com" ]]; }

# ------------------------------------------------------- dash-to-panel ---
# Dash to Panel (GNOME extension) from extensions.gnome.org: dock and top bar merged into one
# bar. App icons (with window previews) on the left, clock, Vitals and system menu on the
# right; no Activities button (Super opens the overview). The preset (your own tuned look:
# bluefeels/gnome/dash-to-panel/settings.dconf) puts it at the bottom with a new apps-button icon.
# Pick this, dash2dock (above), or both.
dtp_uuid="dash-to-panel@jderose9.github.com"
dtp_dir="$HOME/.local/share/gnome-shell/extensions/$dtp_uuid"; dtp_src="$fk/gnome/dash-to-panel"
dtp_path=/org/gnome/shell/extensions/dash-to-panel/
dtp_ignore='^panel-(anchors|element-positions|lengths|positions|sizes)$'   # stored per monitor id
dtp_present() { [[ -d "$dtp_dir" ]]; }
dtp_enabled() { gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -q "'$dtp_uuid'"; }
label_dash_to_panel() { echo "One bar (Dash to Panel)"; }
title_dash_to_panel() { echo "dock and top bar merged into one bar, no Activities button (log out once)"; }
detail_dash_to_panel() { echo "GNOME extension $dtp_uuid from extensions.gnome.org + preset look bluefeels/gnome/dash-to-panel; turns Ubuntu's dock off (put back by the uninstall)"; }
config_dash_to_panel() { echo "dconf|Dash to Panel|$dtp_uuid|$dtp_path|$dtp_src/settings.dconf|dash-to-panel|a taskbar in place of the top bar and the dock|$dtp_ignore"; }
state_dash_to_panel() { NOTE=""
  type -P gnome-shell >/dev/null || { STATE=unsupported; NOTE="needs GNOME"; return; }
  if dtp_present && dtp_enabled; then
    if look_applied "$dtp_path" "$dtp_src/settings.dconf" "$dtp_ignore" dash-to-panel; then STATE=installed
    else STATE=partial; NOTE="settings differ from the toolkit's look"; fi
  elif dtp_present || dtp_enabled; then STATE=partial
  else STATE=missing; fi; }
install_dash_to_panel() {
  if dtp_present && dtp_enabled; then
    look_menu "$dtp_path" "$dtp_src/settings.dconf" dash-to-panel "Dash to Panel" "$dtp_ignore"
    return
  fi
  ask "Merge the dock and top bar into one bar (Dash to Panel)?" n || { skip; return; }
  dtp_present || ext_download "$dtp_uuid" "Dash to Panel" || return 1
  if ask "Use the toolkit's look for it (bottom bar, 35 px, dark, new apps-button icon)? Your current settings are kept for the uninstall."; then
    look_apply "$dtp_path" "$dtp_src/settings.dconf" dash-to-panel && ok "look applied"
  else skip; fi
  install_launcher_entry
  if ext_is_on ubuntu-dock@ubuntu.com; then
    remember_setting dock-ubuntu on
    gnome-extensions disable ubuntu-dock@ubuntu.com >>"$log_file" 2>&1 && ok "Ubuntu's dock off"
  fi
  ext_list add "$dtp_uuid" && ok "enabled"
  warn "log out and back in once (Wayland loads new extensions only at login)"
}
uninstall_dash_to_panel() {
  ext_list del "$dtp_uuid"
  if dtp_present; then
    gnome-extensions disable "$dtp_uuid" >/dev/null 2>&1
    gnome-extensions uninstall "$dtp_uuid" >/dev/null 2>&1 || rm -rf "$dtp_dir"
    ok "bar removed"
  fi
  look_reset "$dtp_path" dash-to-panel
  rm -rf "$(look_copy "$dtp_src/settings.dconf")"   # the apps-button icon the look pointed at
  if [[ "$(recall_setting dock-ubuntu)" == on ]] && ! d2d_present; then
    gnome-extensions enable ubuntu-dock@ubuntu.com >/dev/null 2>&1 && ok "Ubuntu's dock back on"
    forget_setting dock-ubuntu
  fi
  remove_launcher_entry
}

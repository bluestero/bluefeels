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
NEEDS+=([kitty-config]=kitty [kitty-nautilus]=kitty)
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
title_kitty() { echo "The kitty terminal itself, kept on its latest official release (Ubuntu's apt one lags behind)"; }
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

# ------------------------------------------------------ Shell & apps ---
# The prompt (starship), btop and yazi (came from unikit, tasks/14). Their presets are in
# fk configs (config_<id>).
COMPONENTS+=(starship keys zsh login-shell bashrc-tidy btop yazi yazi-keys)
group_keys() { echo Shell; }; group_zsh() { echo Shell; }; group_login_shell() { echo Shell; }
group_bashrc_tidy() { echo Shell; }; requires_zsh() { echo apt; }; requires_login_shell() { echo linux; }
NEEDS+=([login-shell]=zsh [bashrc-tidy]=bash)
group_starship() { echo Shell; }; group_btop() { echo "Terminal apps"; }
group_yazi() { echo "Terminal apps"; }; group_yazi_keys() { echo "Terminal apps"; }
requires_btop() { echo apt; }; requires_yazi() { echo linux; }; requires_yazi_keys() { echo linux; }
NEEDS+=([yazi-keys]=yazi)
GROUP_ABOUT[Shell]="Your shell: the starship prompt, Tab and history keys, zsh (and as your default), your old ~/.bashrc tidied."
GROUP_ABOUT["Terminal apps"]="btop (system monitor) and yazi (file manager; y opens it), coloured like kitty."
# ------------------------------------------------------------ starship ---
ss="$HOME/.config/starship.toml"; ss_src="$fk/starship/starship.toml"
label_starship() { echo "Starship prompt"; }
config_starship() { echo "file|starship|starship|$ss|$ss_src|link|starship.toml|the prompt"; }
# your patch merged over the preset (shell/init.sh does the same at start); prints an error
ss_merged="$HOME/.local/state/unikit/starship.toml"; ss_patch="$HOME/.config/unikit/patches/starship.toml"
ss_merge() {
  if [[ -f $ss_patch && -e $ss ]]; then python3 -I "$fk/starship/toml_patch.py" "$ss" "$ss_patch" "$ss_merged" 2>&1 | sed "s|^$HOME|~|; s|^|✗ starship: your patch has an error: |"
  else rm -f "$ss_merged"; fi
}
ss_sync() { "$fk/bin/k-bg" __sync_prompt >/dev/null 2>&1; return 0; }   # its accent copy is what starship reads
config_after_starship() { ss_merge >/dev/null; ss_sync; }   # (an error shows when you edit the patch)
config_saved_starship() {
  local err; err=$(ss_merge); ss_sync
  if [[ -n $err ]]; then head -1 <<<"$err"
  else echo "✓ starship: your patch saved (new terminals pick it up; with k-bg, this one too)"; fi
}
title_starship() { echo "Prompt showing git branch, k8s cluster, AWS profile and PROD warnings"; }
detail_starship() { echo "prompt config (git + GitHub account when it isn't your default, Python virtualenv, k8s, AWS profile + expiry, PROD markers); starship itself, latest from GitHub (sha256-checked), in ~/.local/bin if it isn't installed"; }
state_starship() { NOTE=""; if linked "$ss" "$ss_src"; then STATE=installed; else STATE=missing; fi
  type -P starship >/dev/null || { NOTE="starship itself isn't installed"; [[ $STATE == installed ]] && STATE=partial; }; }
install_starship() {
  get_tool starship "the prompt itself" "about 5 MB" fetch_starship
  linked "$ss" "$ss_src" && { ok "already linked"; return; }
  ask "Switch to bluefeels' starship prompt?" && link_file "$ss" "$ss_src" || skip; }
fetch_starship() { local a; case "$(dl_arch)" in amd64) a=x86_64 ;; arm64) a=aarch64 ;; esac
  gh_tool starship/starship "starship-$a-unknown-linux-musl.tar.gz" starship; }
uninstall_starship() { unlink_file "$ss" "$ss_src"; drop_tool starship; }
touches_starship() { echo "$ss"; }

# ---------------------------------------------------------------- keys ---
inputrc_src="$fk/shell/inputrc"
label_keys() { echo "Tab & history keys"; }
config_keys() { echo "file|readline|bash|$HOME/.inputrc|$inputrc_src|link|inputrc|keys at the bash prompt (~/.inputrc)"; }
title_keys() { echo "Smarter Tab completion; ↑/↓ searches history by what you typed"; }
detail_keys() { echo "~/.inputrc for bash (case-insensitive Tab, Up/Down search by what's typed)"; }
state_keys() { NOTE=""; if linked "$HOME/.inputrc" "$inputrc_src"; then STATE=installed; else STATE=missing; fi; }
install_keys() { linked "$HOME/.inputrc" "$inputrc_src" && { ok "already linked"; return; }
  ask "Link ~/.inputrc to shell/inputrc?" && link_file "$HOME/.inputrc" "$inputrc_src" || skip; }
uninstall_keys() { unlink_file "$HOME/.inputrc" "$inputrc_src"; }
touches_keys() { echo "$HOME/.inputrc"; }

# ----------------------------------------------------------------- zsh ---
zsh_pkgs=(zsh zsh-autosuggestions)
# Debian's /etc/zsh/zshrc runs compinit too; zsh/zshrc does it once, cached.
zshenv_body="skip_global_compinit=1"
label_zsh() { echo "Zsh"; }
title_zsh() { echo "Install zsh with suggestions as you type"; }
detail_zsh() { echo "zsh + faded suggestions; history, keys and the Tab menu (zsh/zshrc)"; }
touches_zsh() { echo "$HOME/.zshenv"; }
state_zsh() {
  local n=0 missing
  missing=$(missing_pkgs "${zsh_pkgs[@]}")
  [[ -z "$missing" ]] && (( n++ ))
  has_block "$HOME/.zshenv" "$zshenv_body" && (( n++ ))
  NOTE=""
  if (( n == 2 )); then STATE=installed
  elif (( n )); then STATE=partial; NOTE="${missing:+packages missing: $missing}"
  else STATE=missing; fi
}
install_zsh() {
  local missing; missing=$(missing_pkgs "${zsh_pkgs[@]}")
  if [[ -n "$missing" ]]; then
    if ask "Install $missing(apt, needs sudo)?"; then
      apt_install "${zsh_pkgs[@]}" && ok "installed" || { fail "apt failed (see $log_file)"; return 1; }
    else skip; return 0; fi
  fi
  if has_block "$HOME/.zshenv" "$zshenv_body"; then ok "zsh config already set up"
  elif ask "Set up ~/.zshenv (one managed block)?"; then
    set_block "$HOME/.zshenv" "$zshenv_body"
    ok "done. Try it now with: ${C}zsh${R}"
  else skip; return 0; fi
  has_block "$HOME/.zshrc" "$zsh_hook_body" || warn "zsh loads unikit once zsh-hook is set up too: tk install zsh-hook"
}
uninstall_zsh() {
  if [[ "$(login_shell)" == */zsh ]]; then
    warn "zsh is your login shell; switching back to bash first"
    uninstall_login_shell || return 1
  fi
  drop_block "$HOME/.zshenv"
  ok "removed the toolkit from ~/.zshenv"
  local have=""; pkg_installed zsh && have=1
  if [[ -n "$have" ]] && ask "Also remove the zsh packages (apt, needs sudo)?" n; then
    as_root apt-get remove -y "${zsh_pkgs[@]}" >>"$log_file" 2>&1 && ok "packages removed" || fail "apt failed (see $log_file)"
  fi
}

# --------------------------------------------------------- login-shell ---
login_shell() { getent passwd "$USER" | cut -d: -f7; }
label_login_shell() { echo "Zsh as default"; }
title_login_shell() { echo "Open new terminals in zsh (log out once afterwards)"; }
detail_login_shell() { echo "make zsh your default shell (new terminals; log out once for GNOME)"; }
state_login_shell() { NOTE=""
  type -P zsh >/dev/null || { STATE=n/a; NOTE="needs zsh first"; return; }
  if [[ "$(login_shell)" == */zsh ]]; then STATE=installed; else STATE=missing; NOTE="now: $(login_shell)"; fi; }
install_login_shell() {
  local z; z=$(type -P zsh) || { skip "zsh isn't installed"; return; }
  [[ "$(login_shell)" == "$z" ]] && { ok "already zsh"; return; }
  if ask "Make zsh your login shell (chsh asks for your password)?"; then
    remember_setting login-shell "$(login_shell)"
    chsh -s "$z" && ok "done. Log out and back in so GNOME and kitty pick it up" || fail "chsh failed"
  else skip; fi
}
uninstall_login_shell() {   # back to the shell you had before (bash if unknown)
  local prev; prev=$(recall_setting login-shell)
  [[ -n "$prev" && "$prev" != */zsh && -x "$prev" ]] || prev=/bin/bash
  [[ "$(login_shell)" == "$prev" ]] && { ok "already $prev"; forget_setting login-shell; return 0; }
  chsh -s "$prev" && { forget_setting login-shell; ok "login shell is ${prev##*/} again (log out and back in)"; } || { fail "chsh failed"; return 1; }
}

# --------------------------------------------------------- bashrc-tidy ---
# Your old ~/.bashrc tidied (bash/bashrc_plan.py): what shell/common.sh, zsh/zshrc and the
# layers now give both shells comes out, clashing leftovers go; unikit's own line (its bash
# part) stays. The uninstall puts your lines back (bash/bashrc_restore.py).
label_bashrc_tidy() { echo "~/.bashrc tidy-up"; }
title_bashrc_tidy() { echo "Your old ~/.bashrc aliases and settings come from bluefeels in both shells; leftovers that clash go"; }
detail_bashrc_tidy() { echo "~/.bashrc: copies of shell/common.sh (aliases, PATH, nvm) and old hooks taken out; unikit's line kept"; }
bash_plan() {
  BASH_PLAN=$(mktemp)
  python3 -I "$fk/bash/bashrc_plan.py" "$rc" "$init_line" >"$BASH_PLAN"
}
state_bashrc_tidy() {
  NOTE=""
  [[ -f "$rc" ]] || { STATE=missing; NOTE="no ~/.bashrc"; return; }
  bash_plan
  if cmp -s "$rc" "$BASH_PLAN"; then STATE=installed
  else STATE=missing; NOTE="leftovers to clean up in ~/.bashrc"; fi
  rm -f "$BASH_PLAN"
}
install_bashrc_tidy() {
  local b missing v
  [[ -f "$rc" ]] || touch "$rc"
  bash_plan
  if cmp -s "$rc" "$BASH_PLAN"; then rm -f "$BASH_PLAN"; ok "already done"; return; fi
  say "      ${D}$(diff "$rc" "$BASH_PLAN" | grep -c '^<') lines move out of ~/.bashrc (into bluefeels' shell/common.sh and the layers), $(diff "$rc" "$BASH_PLAN" | grep -c '^>') added${R}"
  logf "--- ~/.bashrc diff ---"
  diff -u "$rc" "$BASH_PLAN" --label "~/.bashrc" --label "~/.bashrc (new)" >>"$log_file"
  (( details )) && diff -u "$rc" "$BASH_PLAN" --label "~/.bashrc" --label "~/.bashrc (new)" | sed 's/^/    /'
  missing=""
  for v in $(grep -oE '^export OKTA_AWSCLI_[A-Z_]+' "$rc" | sed 's/^export //'); do
    cat "$repo"/layers/*/shell/init.sh 2>/dev/null | grep -q "^export $v=" || missing+="$v "
  done
  [[ -n "$missing" ]] && warn "not in a layer's shell/init.sh yet, so they'd be lost: $missing"
  grep -qE '^[[:space:]]*alias okcli=' "$rc" && warn "an active 'alias okcli=' stays in ~/.bashrc; it would shadow okcli"
  if ask "Update ~/.bashrc?"; then
    b=$(backup "$rc")
    cat "$BASH_PLAN" >"$rc"
    if bash -n "$rc"; then ok "done (backup: ${b/#$HOME/\~})"
    else cp -p "$b" "$rc"; fail "syntax error in the result, so the original was put back"; fi
  else skip "--details shows the diff"; fi
  rm -f "$BASH_PLAN"
}
# Undo: the lines taken out of your original ~/.bashrc go back where they were, and
# anything you edited since is kept; unikit's line stays (its bash part).
uninstall_bashrc_tidy() {
  local b orig base merged n
  orig=$(original_of "$rc")
  merged=$(mktemp); base=$(mktemp)
  if [[ -n "$orig" ]] && ! grep -qE "$init_re" "$orig" &&
     python3 -I "$fk/bash/bashrc_plan.py" "$orig" "$init_line" | grep -vE "$init_re" >"$base" &&
     python3 -I "$fk/bash/bashrc_restore.py" <(grep -vE "$init_re" "$rc") "$orig" "$base" >"$merged"; then
    n=$(diff "$rc" "$merged" | grep -c '^>')
    logf "--- ~/.bashrc restore diff ---"; diff -u "$rc" "$merged" --label "~/.bashrc" --label "~/.bashrc (restored)" >>"$log_file"
    if (( n )) && ask "Put back the $n line(s) taken out of ~/.bashrc? (your edits since are kept)"; then
      b=$(backup "$rc")
      if grep -qE "$init_re" "$rc"; then { cat "$merged"; printf '\n%s\n' "$init_line"; } >"$rc"; else cat "$merged" >"$rc"; fi
      if bash -n "$rc"; then ok "put back your $n line(s) (backup: ${b/#$HOME/\~})"
      else cp -p "$b" "$rc"; fail "syntax error after putting them back, so ~/.bashrc is unchanged; your original: ${orig/#$HOME/\~}"; fi
      rm -f "$merged" "$base"; return
    fi
  elif [[ -n "$orig" ]]; then
    warn "couldn't work out what to put back; your pre-toolkit ~/.bashrc: ${orig/#$HOME/\~}"
  fi
  rm -f "$merged" "$base"
  ok "nothing put back"
}

# ---------------------------------------------------------------- btop ---
# btop with the toolkit's settings (no black panel, rounded boxes). Its colours are
# generated from the kitty theme in use (k-theme writes ~/.config/btop/themes/kitty.theme).
bt="$HOME/.config/btop/btop.conf"; bt_src="$fk/btop/btop.conf"
# btop can't include a second file and writes its own config when you change a setting in
# its menu, so it gets a file of its own: the preset with your patch laid over it
# (fk configs). bt_made keeps the checksum of what the toolkit last wrote.
bt_patch="$HOME/.config/unikit/patches/btop.conf"; bt_made="$log_dir/originals/configs/btop.made"
bt_merge() {   # the preset, your patch's "key = value" lines in place of its own (new ones at the end)
  awk 'function k(l) { sub(/[ \t]*=.*/, "", l); return l }
    FILENAME == ARGV[1] { if ($0 ~ /^[A-Za-z_]+[ \t]*=/) { if (!(k($0) in p)) o[++n] = k($0); p[k($0)] = $0 }; next }
    $0 ~ /^[A-Za-z_]+[ \t]*=/ && (k($0) in p) { print p[k($0)]; done[k($0)] = 1; next }
    { print }
    END { for (i = 1; i <= n; i++) if (!(o[i] in done)) print p[o[i]] }' \
    "$([[ -f $bt_patch ]] && echo "$bt_patch" || echo /dev/null)" "${1:-$bt_src}"
}
bt_kv() { grep -E '^[A-Za-z_]+[[:space:]]*=' "$@" | sed -E 's/[[:space:]]*=[[:space:]]*/ = /' | sort; }   # the settings alone
bt_ours() { [[ -f $bt && ! -L $bt && "$(bt_kv "$bt")" == "$(bt_merge | bt_kv)" ]]; }   # the preset (and patch) as written
bt_build() { mkdir -p "${bt%/*}" "${bt_made%/*}"; rm -f "$bt"; bt_merge >"$bt" && sha256sum "$bt" | cut -d' ' -f1 >"$bt_made"; }
kth="$fk/bin/k-theme"
label_btop() { echo "btop"; }
config_btop() { echo "file|btop|btop|$bt|$bt_src|merge|btop.conf|system monitor"; }
# the merge kind's own (lib/configs.sh): write the file, is it ours, our checksum, your changes
merge_build_btop() { bt_build; }
merge_ours_btop() { bt_ours; }
merge_made_btop() { echo "$bt_made"; }
merge_keep_btop() { comm -23 <(bt_kv "$bt") <(bt_merge | bt_kv); }
config_saved_btop() { bt_build; echo "✓ btop: your patch saved (btop reads it when it starts)"; }
title_btop() { echo "btop system monitor, set up to follow your kitty colour theme"; }
detail_btop() { echo "btop (apt) if missing; ~/.config/btop/btop.conf: bluefeels/btop/btop.conf with your patch over it; kitty.theme written by k-theme"; }
state_btop() { NOTE=""
  local n=0
  type -P btop >/dev/null && (( n++ ))
  { linked "$bt" "$bt_src" || bt_ours; } && (( n++ ))
  if (( n == 2 )); then STATE=installed; elif (( n )); then STATE=partial; else STATE=missing; fi; }
install_btop() {
  if ! type -P btop >/dev/null; then
    if ask "Install btop? (apt, needs sudo)"; then
      apt_install btop && ok "installed" || { fail "apt failed (see $log_file)"; return 1; }
    else skip; return 0; fi
  fi
  if bt_ours; then ok "btop settings already set"
  elif linked "$bt" "$bt_src"; then   # older installs: a link, so btop's menu wrote into the repo
    if ask "Give btop a settings file of its own? (now its menu writes into the toolkit's copy)"; then
      dry || bt_build && ok "done ${D}(your own changes: fk configs → btop → Edit my patch)${R}"
    else skip; fi
  else
    ask "Use the toolkit's btop settings? (your own are kept as a backup)" || { skip; return 0; }
    dry || { [[ -f $bt && ! -L $bt ]] && backup "$bt" >/dev/null; bt_build; } && ok "set ${D}(your own changes: fk configs → btop → Edit my patch)${R}"
  fi
  dry || "$kth" btop >>"$log_file" 2>&1 && ok "colours follow k-theme ${D}(theme: $("$kth" current 2>/dev/null))${R}"
}
touches_btop() { echo "$bt"; }
uninstall_btop() {
  rm -f "$HOME/.config/btop/themes/kitty.theme"
  unlink_file "$bt" "$bt_src"
  if bt_ours; then   # the toolkit's file (one btop has changed since is yours, and stays)
    rm -f "$bt" "$bt_made"; local b; b=$(latest_backup "$bt")
    if [[ -n $b ]]; then mv "$b" "$bt"; ok "removed, put back ${b/#$HOME/\~}"; else ok "removed"; fi
  fi
  if type -P btop >/dev/null && ask "Also remove the btop package? (apt, needs sudo)" n; then
    as_root apt-get remove -y btop >>"$log_file" 2>&1 && ok "package removed" || fail "apt failed (see $log_file)"
  fi
}

# ---------------------------------------------------------------- yazi ---
# Terminal file manager. The release below goes in ~/.local/bin (no sudo). The
# release has no checksums file, so the sha256 of each build is pinned here
# (GitHub's own digest of the asset); bump both together.
YAZI_VERSION=26.9.1
YAZI_SHA_x86_64=9b9c39decccf8cb0ff53a7d637d38f8a79d93bbd0099f4ea9c619ef6bb392f5d
YAZI_SHA_aarch64=dd569daecaae914185f295634109295ccd25c1b42b02eb89a74f651970024f2e
fetch_yazi() {
  local arch f url tmp sum want
  case "$(uname -m)" in
    x86_64|amd64)  arch=x86_64;  want=$YAZI_SHA_x86_64 ;;
    aarch64|arm64) arch=aarch64; want=$YAZI_SHA_aarch64 ;;
    *) warn "no yazi download for $(uname -m)"; return 1 ;;
  esac
  type -P unzip >/dev/null || { warn "unzip is needed to unpack yazi"; return 1; }
  f="yazi-${arch}-unknown-linux-musl.zip"
  url="https://github.com/sxyazi/yazi/releases/download/v$YAZI_VERSION/$f"
  tmp=$(mktemp -d)
  curl -fsSL --retry 2 -o "$tmp/$f" "$url" 2>>"$log_file" || { warn "couldn't download yazi (offline?)"; rm -rf "$tmp"; return 1; }
  sum=$(sha256sum "$tmp/$f" | cut -d' ' -f1)
  [[ "$sum" == "$want" ]] || { warn "yazi download didn't match its checksum, so it wasn't installed"; rm -rf "$tmp"; return 1; }
  unzip -qo -j "$tmp/$f" '*/yazi' '*/ya' -d "$tmp/out" 2>>"$log_file" || { warn "no yazi in the download"; rm -rf "$tmp"; return 1; }
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$tmp/out/yazi" "$HOME/.local/bin/yazi"
  install -m 755 "$tmp/out/ya" "$HOME/.local/bin/ya"
  rm -rf "$tmp"
  logf "yazi $YAZI_VERSION installed to ~/.local/bin"
}


# Terminal file manager (yazi) plus the `y` command (shell/y.sh) that leaves
# your shell in the folder you quit in. Colours come from the terminal's own
# palette, so it already follows the kitty theme.
yazi_mine="$HOME/.local/bin/yazi"
yazi_ver() { "${1:-yazi}" --version 2>/dev/null | awk '/Version:/ { print $2; exit }'; }
label_yazi() { echo "yazi"; }
title_yazi() { echo "yazi file manager; y opens it and cd's to where you quit"; }
detail_yazi() { echo "yazi $YAZI_VERSION from GitHub (sha256-checked) in ~/.local/bin; the y command comes with the toolkit's shell setup"; }
state_yazi() {
  local v; v=$(yazi_ver); NOTE=""
  if [[ -z "$v" ]]; then STATE=missing
  elif [[ -x "$yazi_mine" ]] && ver_lt "$(yazi_ver "$yazi_mine")" "$YAZI_VERSION"; then STATE=partial; NOTE="update: $(yazi_ver "$yazi_mine") → $YAZI_VERSION"
  else STATE=installed; NOTE="$v"; fi
}
install_yazi() {
  local v; v=$(yazi_ver "$yazi_mine")
  if [[ -n "$v" ]] && ! ver_lt "$v" "$YAZI_VERSION"; then ok "yazi $v"; return; fi
  if [[ -z "$v" ]] && type -P yazi >/dev/null; then ok "yazi $(yazi_ver) is already installed elsewhere"; return; fi
  if ask "Download yazi $YAZI_VERSION into ~/.local/bin? (about 10 MB, no sudo)"; then
    dry && return
    fetch_yazi && ok "yazi $(yazi_ver "$yazi_mine") ${D}(type y; q quits, Q quits without cd)${R}" || fail "not installed (see the log)"
  else skip; fi
}
uninstall_yazi() {
  [[ -e "$yazi_mine" ]] || { ok "not installed"; return 0; }
  rm -f "$yazi_mine" "$HOME/.local/bin/ya"
  ok "removed ${D}(your ~/.config/yazi stays)${R}"
}

# Optional: two keys for yazi, as a marked block in ~/.config/yazi/keymap.toml (added to
# the file if there is one, the file made if not; uninstall takes out only the block).
yk_src="$fk/yazi/keymap.toml"
yk_file="$HOME/.config/yazi/keymap.toml"
label_yazi_keys() { echo "yazi keys"; }
config_yazi_keys() { echo "file|yazi keys|yazi|$yk_file|$yk_src|block||> and ctrl+backspace in yazi"; }
title_yazi_keys() { echo "yazi: > picks a folder inside this one; ctrl+backspace deletes a word"; }
detail_yazi_keys() { echo "a marked block from bluefeels/yazi/keymap.toml in ~/.config/yazi/keymap.toml (the file is made if it's missing); needs fzf"; }
# yazi's keymap can't have both prepend_keymap = [...] and [[...prepend_keymap]] for one layer:
# true when the file already has the first form, outside our block
yk_clash() { [[ -f "$yk_file" ]] && awk -v s="$BLOCK_START" -v e="$BLOCK_END" '$0==s{f=1;next} $0==e{f=0;next} !f' "$yk_file" | grep -qE '^[[:space:]]*prepend_keymap[[:space:]]*='; }
state_yazi_keys() { NOTE=""
  type -P yazi >/dev/null || { STATE=n/a; NOTE="yazi isn't installed"; return; }
  if has_block "$yk_file" "$(<"$yk_src")"; then STATE=installed
  elif grep -qxF "$BLOCK_START" "$yk_file" 2>/dev/null; then STATE=partial; NOTE="out of date"
  else STATE=missing; fi; }
install_yazi_keys() {
  has_block "$yk_file" "$(<"$yk_src")" && { ok "already there"; return; }
  if yk_clash; then
    warn "${yk_file/#$HOME/\~} already has prepend_keymap = [ ... ] lines, which can't sit next to the toolkit's keys."
    info "    Add the entries from $yk_src to your own list instead."; skip; return
  fi
  if ask "Add the keys to ${yk_file/#$HOME/\~}? (> picks a folder inside this one; ctrl+backspace deletes a word; the rest of the file stays yours)"; then
    dry && return
    mkdir -p "$(dirname "$yk_file")" && set_block "$yk_file" "$(<"$yk_src")" && ok "done ${D}(open yazi and try >)${R}"
  else skip; fi
}
uninstall_yazi_keys() {
  grep -qxF "$BLOCK_START" "$yk_file" 2>/dev/null || { ok "not there"; return 0; }
  drop_block "$yk_file"; ok "removed from ${yk_file/#$HOME/\~}"
}

# --------------------------------------------------------------- Desktop ---
# GNOME extensions and shortcuts (came from unikit, tasks/14): Window Calls, Alt+Tab after
# Show Desktop, Docker's tray dots hidden, Super+1..9 app keys, the rofi launcher.
COMPONENTS+=(bluefeels-window-calls alt-tab-desktop hide-docker-tray app-keys rofi)
group_bluefeels_window_calls() { echo Desktop; }; group_alt_tab_desktop() { echo Desktop; }
group_hide_docker_tray() { echo Desktop; }; group_app_keys() { echo Desktop; }; group_rofi() { echo Desktop; }
requires_bluefeels_window_calls() { echo gnome; }; requires_alt_tab_desktop() { echo gnome; }
requires_hide_docker_tray() { echo gnome; }; requires_app_keys() { echo gnome; }; requires_rofi() { echo gnome apt; }
GROUP_ABOUT[Desktop]="GNOME extensions and shortcuts: windows, Super+number app keys, the rofi launcher (Alt+Space, Super+S, Super+X)."
# The launcher entry (gives rofi's window an icon in a dock or panel); shared by rofi and the docks
launcher_icon_dir="$HOME/.local/share/icons/hicolor/512x512/apps"; launcher_icon="$launcher_icon_dir/k-launch.png"
# a layer can ask to keep it by defining wants_launcher_entry
launcher_entry_wanted() { kb_has rofi-launcher || { declare -F wants_launcher_entry >/dev/null && wants_launcher_entry; }; }
remove_launcher_entry() {
  launcher_entry_wanted && return 0
  rm -f "$HOME/.local/share/applications/k-launch.desktop" "$HOME/.local/share/applications/rofi.desktop" "$launcher_icon" "$HOME/.local/share/icons/hicolor/scalable/apps/k-launch.svg"
}
launcher_entry_set() { [[ -f "$launcher_icon" ]] && grep -qxF "Exec=$fk/rofi/bin/k-launch apps" "$HOME/.local/share/applications/k-launch.desktop" 2>/dev/null &&
  grep -qxF "Icon=k-launch" "$HOME/.local/share/applications/k-launch.desktop" &&
  [[ -f "$HOME/.local/share/applications/rofi.desktop" ]]; }
install_launcher_entry() {
  mkdir -p "$launcher_icon_dir" "$HOME/.local/share/applications"
  convert "$fk/rofi/rofi-icon.png" -resize 512x512 "$launcher_icon" 2>>"$log_file" ||
    install -m 644 "$fk/rofi/rofi-icon.png" "$launcher_icon"
  printf '%s\n' "[Desktop Entry]" "Type=Application" "Name=Launcher" "Comment=App launcher (Alt+Space)" \
    "Exec=$fk/rofi/bin/k-launch apps" "Icon=k-launch" "Terminal=false" "Categories=Utility;" "StartupWMClass=Rofi" \
    >"$HOME/.local/share/applications/k-launch.desktop"
  # GNOME's panel matches rofi's window to the system rofi.desktop (a gear icon); this copy wins over it
  sed "s|^Icon=.*|Icon=k-launch|" /usr/share/applications/rofi.desktop >"$HOME/.local/share/applications/rofi.desktop"
}


# --------------------------------------------- bluefeels-window-calls ---
# GNOME extension that lets scripts list, focus and close windows over D-Bus.
# app-keys and kitty-focus use it (Ctrl+Alt+T); another layer may bring a part for the same
# extension (bluetools, for ws): the same touches_, and shared_keep in the uninstall.
bfwc_uuid="window-calls@domandoman.xyz"
bfwc_enabled() { gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -q "'$bfwc_uuid'"; }
bfwc_present() { [[ -d "$HOME/.local/share/gnome-shell/extensions/$bfwc_uuid" ]]; }
bfwc_live() { gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/Windows \
  --method org.gnome.Shell.Extensions.Windows.List >/dev/null 2>&1; }
label_bluefeels_window_calls() { echo "Window Calls"; }
title_bluefeels_window_calls() { echo "Let scripts list, focus and close windows (GNOME extension; log out once)"; }
touches_bluefeels_window_calls() { echo "$HOME/.local/share/gnome-shell/extensions/$bfwc_uuid"; }
detail_bluefeels_window_calls() { echo "GNOME extension $bfwc_uuid from extensions.gnome.org into ~/.local/share/gnome-shell/extensions"; }
state_bluefeels_window_calls() {
  NOTE=""
  type -P gnome-shell >/dev/null || { STATE=unsupported; NOTE="needs GNOME"; return; }
  if bfwc_present && bfwc_enabled; then
    if bfwc_live; then STATE=installed; else STATE=partial; NOTE="log out and back in to load it"; fi
  elif bfwc_present; then STATE=partial; NOTE="installed, not enabled"
  else STATE=missing; fi
}
install_bluefeels_window_calls() {
  local ver url tmp
  if bfwc_present && bfwc_enabled; then
    bfwc_live && ok "already active" || ok "installed; log out and back in once to load it"
    return
  fi
  if ! bfwc_present; then
    ask "Download Window Calls from extensions.gnome.org and install it?" || { skip; return; }
    ver=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
    url=$(curl -fsS "https://extensions.gnome.org/extension-info/?uuid=$bfwc_uuid&shell_version=$ver" |
      python3 -Ic 'import json,sys; print(json.load(sys.stdin)["download_url"])' 2>/dev/null)
    [[ -n "$url" ]] || { fail "no Window Calls release for GNOME $ver"; return; }
    tmp=$(mktemp --suffix=.zip)
    if curl -fsSL -o "$tmp" "https://extensions.gnome.org$url" && gnome-extensions install --force "$tmp" >>"$log_file" 2>&1; then
      ok "installed"; logf "  from https://extensions.gnome.org$url"
    else rm -f "$tmp"; fail "download or install failed (see the log)"; return; fi
    rm -f "$tmp"
  fi
  # `gnome-extensions enable` can't see it until GNOME reloads, so add it to the list directly
  # (and off the disabled list, where an uninstall leaves it).
  dry || ext_list add "$bfwc_uuid"
  ok "enabled"
  warn "log out and back in once (Wayland loads new extensions only at login)"
}
uninstall_bluefeels_window_calls() {
  bfwc_present || { ok "not installed"; return; }
  shared_keep bluefeels-window-calls && return
  gnome-extensions disable "$bfwc_uuid" >/dev/null 2>&1
  python3 -I - "$bfwc_uuid" <<'PY'
import ast, subprocess, sys
cur = subprocess.run(["gsettings", "get", "org.gnome.shell", "enabled-extensions"], capture_output=True, text=True).stdout.strip()
lst = ast.literal_eval(cur.removeprefix("@as ")) if cur else []
if sys.argv[1] in lst:
    subprocess.run(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str([x for x in lst if x != sys.argv[1]])], check=True)
PY
  if gnome-extensions uninstall "$bfwc_uuid" >/dev/null 2>&1 || rm -rf "$HOME/.local/share/gnome-shell/extensions/$bfwc_uuid"; then
    ok "removed"
  fi
}

# ------------------------------------------------------ alt-tab-desktop ---
# After Super+D (show desktop), Alt+Tab goes back to the window you minimized,
# not the one before it. Small GNOME extension kept in bluefeels/gnome/ and linked in.
atd_uuid="alt-tab-desktop@bluefeels"
atd_dir="$HOME/.local/share/gnome-shell/extensions/$atd_uuid"; atd_src="$fk/gnome/$atd_uuid"
atd_enabled() { gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -q "'$atd_uuid'"; }
label_alt_tab_desktop() { echo "Alt+Tab after Show Desktop"; }
title_alt_tab_desktop() { echo "After Super+D, Alt+Tab returns to the window you minimized (GNOME extension; log out once)"; }
detail_alt_tab_desktop() { echo "~/.local/share/gnome-shell/extensions/$atd_uuid -> bluefeels/gnome/$atd_uuid, added to enabled extensions"; }
state_alt_tab_desktop() { NOTE=""
  type -P gnome-shell >/dev/null || { STATE=unsupported; NOTE="needs GNOME"; return; }
  if linked "$atd_dir" "$atd_src" && atd_enabled; then STATE=installed
  elif linked "$atd_dir" "$atd_src" || atd_enabled; then STATE=partial
  else STATE=missing; fi; }
install_alt_tab_desktop() {
  if linked "$atd_dir" "$atd_src" && atd_enabled; then ok "already installed"; return; fi
  ask "Make Alt+Tab return to the window you minimized with Super+D?" || { skip; return; }
  mkdir -p "$(dirname "$atd_dir")"
  linked "$atd_dir" "$atd_src" || link_file "$atd_dir" "$atd_src" || return 1
  ext_list add "$atd_uuid" && ok "enabled"
  warn "log out and back in once (Wayland loads new extensions only at login)"
}
uninstall_alt_tab_desktop() {
  ext_list del "$atd_uuid"
  unlink_file "$atd_dir" "$atd_src"
}

# ------------------------------------------------------ hide-docker-tray ---
# Docker Desktop's tray item has no icon and an empty menu: three dots that do nothing on click.
# Small GNOME extension (bluefeels/gnome/hide-docker-tray@bluefeels), linked in, that keeps it hidden.
hdt_uuid="hide-docker-tray@bluefeels"
hdt_dir="$HOME/.local/share/gnome-shell/extensions/$hdt_uuid"; hdt_src="$fk/gnome/$hdt_uuid"
hdt_enabled() { gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -q "'$hdt_uuid'"; }
label_hide_docker_tray() { echo "Hide Docker's tray dots"; }
title_hide_docker_tray() { echo "hides Docker Desktop's dead three-dots tray icon (GNOME extension; log out once)"; }
detail_hide_docker_tray() { echo "~/.local/share/gnome-shell/extensions/$hdt_uuid -> bluefeels/gnome/$hdt_uuid, added to enabled extensions"; }
state_hide_docker_tray() { NOTE=""
  type -P gnome-shell >/dev/null || { STATE=unsupported; NOTE="needs GNOME"; return; }
  if linked "$hdt_dir" "$hdt_src" && hdt_enabled; then STATE=installed
  elif linked "$hdt_dir" "$hdt_src" || hdt_enabled; then STATE=partial
  else STATE=missing; fi; }
install_hide_docker_tray() {
  if linked "$hdt_dir" "$hdt_src" && hdt_enabled; then ok "already installed"; return; fi
  ask "Hide Docker Desktop's dead three-dots tray icon?" || { skip; return; }
  mkdir -p "$(dirname "$hdt_dir")"
  linked "$hdt_dir" "$hdt_src" || link_file "$hdt_dir" "$hdt_src" || return 1
  ext_list add "$hdt_uuid" && ok "enabled"
  warn "log out and back in once (Wayland loads new extensions only at login)"
}
uninstall_hide_docker_tray() {
  ext_list del "$hdt_uuid"
  unlink_file "$hdt_dir" "$hdt_src"
}

# ---------------------------------------------------------------- rofi ---
# Rofi as the app launcher: Alt+Space apps (Tab for ssh, windows, run), Alt+Shift+Space ssh.
# Rofi 1.7 is an X11 program; -normal-window (set by bluefeels/rofi/bin/k-launch) lets it take the keyboard on GNOME's Wayland.
rofi_conf="$HOME/.config/rofi/config.rasi"; rofi_src="$fk/rofi/config.rasi"
label_rofi() { echo "Rofi launcher"; }
config_rofi() { echo "file|rofi|rofi|$rofi_conf|$rofi_src|link|rofi.rasi|launcher style"; }
title_rofi() { echo "Alt+Space opens an app launcher (Alt+Shift+Space ssh, Super+X power menu, Super+S speaker/mic/wifi/bluetooth), styled like kitty"; }
detail_rofi() { echo "rofi (apt) if missing; ~/.config/rofi/config.rasi -> bluefeels/rofi/config.rasi; four GNOME shortcuts (Alt+Space, Alt+Shift+Space, Super+X, Super+S); launcher icon (bluefeels/rofi/rofi-icon.png) in the app list and dock"; }
# rofi's config @imports files (colours, your patch); a missing one makes rofi open with an error box
doctor_rofi() {
  local imp miss=""
  [[ -r ~/.config/rofi/config.rasi ]] || return 0
  while IFS= read -r imp; do
    imp=${imp/#\~/$HOME}; [[ $imp == /* ]] || imp=$HOME/.config/rofi/$imp
    [[ -e $imp ]] || miss+="${imp/#$HOME/\~} "
  done < <(sed -n 's/^[[:space:]]*@import[[:space:]]*"\(.*\)".*/\1/p' ~/.config/rofi/config.rasi)
  if [[ -z $miss ]]; then echo "✓ config files all there"
  else echo "! config needs ${miss% }, which is missing — $(kit_of rofi) install rofi"; fi
}
state_rofi() { NOTE=""
  type -P gsettings >/dev/null || { STATE=unsupported; NOTE="needs GNOME"; return; }
  local n=0
  type -P rofi >/dev/null && (( n++ ))
  linked "$rofi_conf" "$rofi_src" && (( n++ ))
  rofi_keys_on && (( n++ ))
  launcher_entry_set && (( n++ ))
  [[ -e $HOME/.config/unikit/patches/rofi.rasi ]] && (( n++ ))   # config.rasi @imports it
  if (( n == 5 )); then STATE=installed; elif (( n )); then STATE=partial; else STATE=missing; fi; }
k_launch="$fk/rofi/bin/k-launch"
rofi_keys_on() { kb_runs rofi-launcher "$k_launch apps" && kb_runs rofi-ssh "$k_launch ssh" &&
  kb_runs rofi-power "$k_launch power" && kb_runs rofi-devices "$k_launch settings"; }
install_rofi() {
  if ! type -P rofi >/dev/null; then
    if ask "Install rofi? (apt, needs sudo)"; then
      apt_install rofi && ok "installed" || { fail "apt failed (see $log_file)"; return 1; }
    else skip; return 0; fi
  fi
  if linked "$rofi_conf" "$rofi_src"; then ok "rofi style already linked"
  else ask "Use bluefeels' rofi style? (your own is kept as a backup)" && link_file "$rofi_conf" "$rofi_src" || { skip; return 0; }; fi
  # config.rasi @imports your patch and rofi errors when it is missing, so it must exist
  local rp="$HOME/.config/unikit/patches/rofi.rasi"
  [[ -e $rp ]] || dry || { mkdir -p "${rp%/*}" && printf "// Your patch for rofi: read after the toolkit's preset, so what you set here wins.\n" >"$rp"; }
  dry || "$fk/bin/k-rofi" >>"$log_file" 2>&1 && ok "colours follow k-theme and k-bg"
  if launcher_entry_set; then ok "launcher icon already installed"
  else dry || install_launcher_entry && ok "launcher icon installed (log out and back in if the dock still shows none)"; fi
  if rofi_keys_on; then ok "shortcuts already set"
  elif ask "Set Alt+Space (apps), Alt+Shift+Space (ssh), Super+X (power menu) and Super+S (speaker, mic, wifi, bluetooth)?"; then
    kb_set rofi-launcher "Rofi launcher" "$k_launch apps" "<Alt>space"
    kb_set rofi-ssh "Rofi ssh" "$k_launch ssh" "<Alt><Shift>space"
    kb_set rofi-power "Rofi power" "$k_launch power" "<Super>x"
    kb_set rofi-devices "Rofi speaker, mic, wifi, bluetooth" "$k_launch settings" "<Super>s"
    ok "Alt+Space = apps, Alt+Shift+Space = ssh, Super+X = power menu, Super+S = speaker/mic/wifi/bluetooth"
  else skip; fi
}
touches_rofi() { echo "$rofi_conf"; }
uninstall_rofi() {
  kb_has rofi-launcher && kb_del rofi-launcher
  kb_has rofi-ssh && kb_del rofi-ssh
  kb_has rofi-power && kb_del rofi-power
  kb_has rofi-devices && kb_del rofi-devices
  unlink_file "$rofi_conf" "$rofi_src"
  rm -f "${rofi_conf%/*}/colors.rasi"
  remove_launcher_entry
  if type -P rofi >/dev/null && ask "Also remove the rofi package? (apt, needs sudo)" n; then
    as_root apt-get remove -y rofi >>"$log_file" 2>&1 && ok "package removed" || fail "apt failed (see $log_file)"
  fi
}

# ------------------------------------------------------------ app-keys ---
# Super+1..9 = the Nth pinned app in the dock: launch it, bring it to the front, or (when it
# is already in front) minimize it. gnome/app-keys/k-appkey does the work, one short process per key press;
# it uses Window Calls to find and minimize windows. GNOME's own Super+1..9 is switched off
# while this is on (the two would clash) and comes back with the uninstall.
ak_n=(1 2 3 4 5 6 7 8 9)
ak_cmd="$fk/gnome/app-keys/k-appkey"
ak_keys_on() { local i; for i in "${ak_n[@]}"; do kb_runs "app-key-$i" "$ak_cmd $i" || return 1; done; }
ak_native_off() { [[ "$(gsettings get org.gnome.shell.keybindings switch-to-application-1)" == "@as []" ]]; }
label_app_keys() { echo "Super+number app keys"; }
title_app_keys() { echo "Super+1..9 launches, raises or minimizes the Nth dock app (needs Window Calls; replaces GNOME's own)"; }
detail_app_keys() { echo "nine GNOME shortcuts (Super+1..9) running bluefeels/gnome/app-keys/k-appkey; GNOME's switch-to-application keys turned off (put back by the uninstall)"; }
state_app_keys() { NOTE=""
  type -P gsettings >/dev/null || { STATE=unsupported; NOTE="needs GNOME"; return; }
  if ak_keys_on && ak_native_off; then STATE=installed
  elif ak_keys_on || ak_native_off; then STATE=partial
  else STATE=missing; fi; }
install_app_keys() {
  local i
  if ak_keys_on && ak_native_off; then ok "already set"; return; fi
  ask "Make Super+1..9 launch, raise or minimize the Nth dock app?" n || { skip; return; }
  bfwc_live || warn "Window Calls isn't active yet: until it is, Super+number only launches / raises (install it, then log out once)"
  chmod +x "$ak_cmd"
  remember_setting app-keys-native "$(gsettings get org.gnome.shell.keybindings switch-to-application-1)"
  for i in "${ak_n[@]}"; do gsettings set org.gnome.shell.keybindings "switch-to-application-$i" "[]"; done
  for i in "${ak_n[@]}"; do kb_set "app-key-$i" "App key $i" "$ak_cmd $i" "<Super>$i"; done
  ok "Super+1..9 set (the keys work right away)"
}
uninstall_app_keys() {
  local i
  for i in "${ak_n[@]}"; do kb_has "app-key-$i" && kb_del "app-key-$i"; done
  if [[ -n "$(recall_setting app-keys-native)" ]]; then
    for i in "${ak_n[@]}"; do gsettings reset org.gnome.shell.keybindings "switch-to-application-$i"; done
    forget_setting app-keys-native
    ok "GNOME's own Super+1..9 back"
  fi
}

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
d2d_patched() { grep -qE "(bluefeels|work-toolkit) patch" "$d2d_dir/dock.js" 2>/dev/null; }   # (work-toolkit: its old name)
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

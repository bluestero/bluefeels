# bluefeels's shell setup. The toolkit's shell/init.sh sources it (bash and zsh), layers by
# name (bluefeels before bluetools), then its own tools. $_work_root is the toolkit's folder.
_fk="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)"
# zsh's own setup (history, keys, Tab menu, suggestions), then the aliases, PATH and env
# both shells get.
[ -n "${ZSH_VERSION:-}" ] && [ -r "$_fk/zsh/zshrc" ] && . "$_fk/zsh/zshrc"
[ -r "$_fk/shell/common.sh" ] && . "$_fk/shell/common.sh"
# The two GNOME extensions were named <name>@work-toolkit until 2026-11: once, their links and
# GNOME's list of enabled ones take the @bluefeels names (loaded at the next login).
for _x in alt-tab-desktop hide-docker-tray; do
  _xo="$HOME/.local/share/gnome-shell/extensions/$_x@work-toolkit"
  [ -L "$_xo" ] || continue
  rm -f "$_xo"; ln -sfn "$_fk/gnome/$_x@bluefeels" "${_xo%@*}@bluefeels"
  _xl=$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null) &&
    case "$_xl" in *"'$_x@work-toolkit'"*) gsettings set org.gnome.shell enabled-extensions "$(printf '%s' "$_xl" | sed "s/'$_x@work-toolkit'/'$_x@bluefeels'/")" ;; esac
done
unset _x _xo _xl
# Your starship patch (fk configs: edit my patch) laid over the preset: starship can't read
# two files, so they're merged into one, made again when either changes. First: k-bg
# (below) colours this file when it's there.
_ss_out="$HOME/.local/state/unikit/starship.toml"
_ss_patch="$HOME/.config/unikit/patches/starship.toml"
if [ -f "$_ss_patch" ] && [ -f "$HOME/.config/starship.toml" ] && command -v python3 >/dev/null 2>&1; then
  if [ ! -f "$_ss_out" ] || [ "$_ss_patch" -nt "$_ss_out" ] || [ "$HOME/.config/starship.toml" -nt "$_ss_out" ]; then
    python3 -I "$_fk/starship/toml_patch.py" "$HOME/.config/starship.toml" "$_ss_patch" "$_ss_out" 2>/dev/null ||
      echo "starship: your patch has an error (fk configs shows it); the prompt keeps the last one that worked" >&2
  fi
  [ -f "$_ss_out" ] && export STARSHIP_CONFIG="$_ss_out"
else
  rm -f "$_ss_out"
fi
unset _ss_out _ss_patch
# btop's own settings file (the preset with your patch): made again after either changes,
# unless btop has changed it since (fk configs then offers to keep that as your patch).
_bt="$HOME/.config/btop/btop.conf"
if [ -f "$HOME/.local/state/unikit/originals/configs/btop.made" ] && [ -f "$_bt" ] && [ ! -L "$_bt" ] &&
   { [ "$_fk/btop/btop.conf" -nt "$_bt" ] || [ "$HOME/.config/unikit/patches/btop.conf" -nt "$_bt" ]; }; then
  bash "$_work_root/lib/configs.sh" __refresh btop >/dev/null 2>&1
fi
unset _bt
# k-bg keeps a copy of starship.toml with the background's accent colours in it;
# starship rereads it at every prompt, so a new background shows straight away.
_kbg_star="${XDG_STATE_HOME:-$HOME/.local/state}/k-bg/starship.toml"
# Its source: your starship.toml, or the toolkit's merge of it with your patch (shell/init.sh).
_kbg_src="$HOME/.local/state/unikit/starship.toml"
[ -f "$_kbg_src" ] || _kbg_src="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
if [ -f "$_kbg_star" ]; then
  [ "$_kbg_src" -nt "$_kbg_star" ] &&
    "$_fk/bin/k-bg" __sync_prompt 2>/dev/null
  export STARSHIP_CONFIG="$_kbg_star"
fi
unset _kbg_star _kbg_src
for _f in k-icon k-bg k-theme y; do   # tab completion; y opens yazi
  [ -r "$_fk/shell/$_f.sh" ] && . "$_fk/shell/$_f.sh"
done
# The prompt. Layers that load after this one add their prompt hooks to starship's own list.
if command -v starship >/dev/null 2>&1; then
  if [ -n "${ZSH_VERSION:-}" ]; then eval "$(starship init zsh)"; else eval "$(starship init bash)"; fi
fi
unset -f k-config 2>/dev/null   # older toolkit versions defined it as a function
unset _fk _f

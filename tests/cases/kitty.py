"""bluefeels' kitty parts in a scratch copy of unikit (this layer included) with a scratch HOME:
kitty accents read as missing without a background.conf, and their uninstall doesn't make one."""
import os
import shutil
import subprocess

from fixture import REPO


def copy(sb):
    dst = sb.root + "/repo"
    shutil.copytree(REPO, dst, ignore=shutil.ignore_patterns(".git", "layers.lock", "tests", "tasks", "airpr", "*.zip"))
    return dst


def sh(sb, repo, script):
    """Runs bash with the installer's libraries loaded; returns its output."""
    pre = f'repo={repo} mode=yes details=0; . "$repo/lib/setup.sh"; . "$repo/lib/components.sh"\n'
    p = subprocess.run(["bash", "-c", pre + script], env=sb.env, cwd=sb.home, capture_output=True, text=True,
                       timeout=60, stdin=subprocess.DEVNULL)
    return p.stdout + p.stderr


def install(sb, repo, *parts):
    p = subprocess.run([repo + "/install.sh", "--yes", *parts], env=sb.env, cwd=sb.home, capture_output=True,
                       text=True, timeout=60, stdin=subprocess.DEVNULL)
    assert p.returncode == 0, p.stdout + p.stderr
    return p.stdout


def test_kitty_accents_need_a_background_conf(sb):
    repo = copy(sb)
    sb.fake("kitty", "exit 0")
    install(sb, repo, "--kit=fk", "kitty-config")
    out = sh(sb, repo, 'component_state kitty-accents; echo "$STATE"; uninstall_kitty_accents')
    assert out.splitlines()[0] == "missing", out          # k-bg reads a missing file as accents on
    assert not os.path.exists(sb.path("~/.config/kitty/background.conf")), "the uninstall must not make one"

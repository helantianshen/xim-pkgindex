#!/usr/bin/env python3
"""The version-entry revision check (.github/scripts/check-revision.lua).

Each case commits a base recipe to a scratch git repository, commits one
change on top of it, and runs the checker between the two commits -- the
same comparison CI makes between a pull request's base and head.

The rule under test: an entry that exists on the base may change its resource
(url, mirror urls, sha256, per-arch map, res) only together with a higher
`revision`; a revision never decreases, is a non-negative integer when
present, sits on the version entry, and is absent from `ref` aliases.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

import pytest

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / ".github/scripts/check-revision.lua"


def _lua():
    for name in ("lua5.4", "lua5.3", "lua"):
        path = shutil.which(name)
        if path and subprocess.run(
                [path, "-e", "os.exit(math.type ~= nil and 0 or 1)"]).returncode == 0:
            return path
    return None


LUA = _lua()
needs_lua = pytest.mark.skipif(LUA is None, reason="no Lua 5.3+ interpreter")

BASE = '''package = {
    spec = "2",
    name = "foo",
    xpm = {
        linux = {
            deps = { "xim:glibc" },
            ["latest"] = { ref = "1.1.0" },
            ["1.0.0"] = {
                url = "https://example.org/foo-1.0.0.tar.gz",
                sha256 = "aaaa",
            },
            ["1.1.0"] = {
                url = {
                    GLOBAL = "https://example.org/foo-1.1.0.tar.gz",
                    CN = "https://mirror.example.cn/foo-1.1.0.tar.gz",
                },
                sha256 = "bbbb",
            },
            ["2.0.0"] = {
                x86_64 = { url = "https://example.org/foo-2.0.0-x86_64.tar.gz", sha256 = "cccc" },
                aarch64 = { url = "https://example.org/foo-2.0.0-aarch64.tar.gz", sha256 = "dddd" },
            },
            ["3.0.0"] = "XLINGS_RES",
            ["4.0.0"] = {
                url = "https://example.org/foo-4.0.0.tar.gz",
                sha256 = "eeee",
                revision = 2,
            },
        },
    },
}

import("xim.libxpkg.pkginfo")

function install()
    return true
end
'''


def _git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True,
                          capture_output=True, text=True).stdout.strip()


def check(head_text, base_text=BASE, path="pkgs/f/foo.lua"):
    """Commit base_text, then head_text, and run the checker between them.
    base_text None: the recipe is new in the head commit."""
    with tempfile.TemporaryDirectory() as temp:
        repo = Path(temp)
        _git(repo, "init", "-q")
        _git(repo, "config", "user.email", "test@example.org")
        _git(repo, "config", "user.name", "test")
        _git(repo, "config", "commit.gpgsign", "false")
        recipe = repo / path
        recipe.parent.mkdir(parents=True)
        (repo / "README").write_text("index\n")
        if base_text is not None:
            recipe.write_text(base_text)
        _git(repo, "add", "-A")
        _git(repo, "commit", "-q", "-m", "base")
        base = _git(repo, "rev-parse", "HEAD")
        recipe.write_text(head_text)
        _git(repo, "add", "-A")
        _git(repo, "commit", "-q", "--allow-empty", "-m", "head")
        head = _git(repo, "rev-parse", "HEAD")
        result = subprocess.run([LUA, str(CHECKER), "--base", base, "--head", head, str(repo)],
                                capture_output=True, text=True)
        return result.returncode, result.stdout + result.stderr


def edit(old, new, text=BASE):
    assert text.count(old) == 1, old
    return text.replace(old, new)


@needs_lua
@pytest.mark.static
class TestRevisionCheck:
    def test_unchanged_recipe_passes(self):
        code, out = check(BASE + "\n-- a comment\n")
        assert code == 0, out
        assert "5 published entries compared" in out, out

    def test_sha256_change_without_revision_fails_naming_the_entry(self):
        code, out = check(edit('sha256 = "aaaa"', 'sha256 = "ffff"'))
        assert code == 1, out
        assert 'pkgs/f/foo.lua xpm.linux["1.0.0"]' in out, out
        assert "raise `revision` to 1" in out, out

    def test_sha256_change_with_revision_passes(self):
        code, out = check(edit('url = "https://example.org/foo-1.0.0.tar.gz",\n                sha256 = "aaaa",',
                               'url = "https://example.org/foo-1.0.0-r1.tar.gz",\n'
                               '                sha256 = "ffff",\n                revision = 1,'))
        assert code == 0, out

    def test_mirror_url_change_without_revision_fails(self):
        code, out = check(edit("https://mirror.example.cn/foo-1.1.0.tar.gz",
                               "https://mirror.example.cn/other/foo-1.1.0.tar.gz"))
        assert code == 1, out
        assert 'xpm.linux["1.1.0"]' in out, out

    def test_per_arch_sha256_change_needs_revision(self):
        changed = edit('sha256 = "dddd"', 'sha256 = "9999"')
        code, out = check(changed)
        assert code == 1 and 'xpm.linux["2.0.0"]' in out, out
        code, out = check(edit('sha256 = "9999" },', 'sha256 = "9999" },\n                revision = 1,',
                               changed))
        assert code == 0, out

    def test_string_entry_to_table_needs_revision(self):
        table = '{ res = true, sha256 = { x86_64 = "1234" } }'
        code, out = check(edit('["3.0.0"] = "XLINGS_RES"', '["3.0.0"] = ' + table))
        assert code == 1 and 'xpm.linux["3.0.0"]' in out, out
        code, out = check(edit('["3.0.0"] = "XLINGS_RES"',
                               '["3.0.0"] = { res = true, sha256 = { x86_64 = "1234" }, revision = 1 }'))
        assert code == 0, out

    @pytest.mark.parametrize("value", ['"1"', "-1", "1.0", "true"])
    def test_malformed_revision_fails(self, value):
        code, out = check(edit('sha256 = "aaaa",', f'sha256 = "aaaa",\n                revision = {value},'))
        assert code == 1, out
        assert "is not a non-negative integer" in out, out

    def test_malformed_revision_on_a_new_entry_fails(self):
        code, out = check(edit('["3.0.0"] = "XLINGS_RES",',
                               '["3.0.0"] = "XLINGS_RES",\n'
                               '            ["5.0.0"] = { url = "https://example.org/5", sha256 = "5555", revision = "2" },'))
        assert code == 1 and 'xpm.linux["5.0.0"]' in out, out

    def test_new_entry_without_revision_passes(self):
        code, out = check(edit('["3.0.0"] = "XLINGS_RES",',
                               '["3.0.0"] = "XLINGS_RES",\n'
                               '            ["5.0.0"] = { url = "https://example.org/5", sha256 = "5555" },'))
        assert code == 0, out

    def test_revision_decrease_fails(self):
        code, out = check(edit("revision = 2,", "revision = 1,"))
        assert code == 1 and "revision decreased from 2 to 1" in out, out

    def test_revision_removed_counts_as_a_decrease(self):
        code, out = check(edit("                revision = 2,\n", ""))
        assert code == 1 and "revision decreased from 2 to 0" in out, out

    def test_revision_raised_without_resource_change_passes(self):
        # A hook change that alters the installed files: allowed, and the
        # only way to ship one.
        code, out = check(edit("revision = 2,", "revision = 3,"))
        assert code == 0, out

    def test_revision_on_an_alias_fails(self):
        code, out = check(edit('["latest"] = { ref = "1.1.0" }',
                               '["latest"] = { ref = "1.1.0", revision = 1 }'))
        assert code == 1 and "carries no revision" in out, out

    def test_revision_inside_a_per_arch_map_fails(self):
        code, out = check(edit('sha256 = "cccc" }', 'sha256 = "cccc", revision = 1 }'))
        assert code == 1 and "belongs on the version entry" in out, out

    def test_field_order_and_comments_are_not_a_change(self):
        reordered = edit('url = "https://example.org/foo-1.0.0.tar.gz",\n                sha256 = "aaaa",',
                         '-- reordered\n                sha256 = "aaaa",\n'
                         '                url = "https://example.org/foo-1.0.0.tar.gz",')
        code, out = check(reordered)
        assert code == 0, out

    def test_hook_change_is_not_detected(self):
        # Out of scope by design; review has to catch it.
        code, out = check(edit("    return true\n", "    os.exec('true')\n    return true\n"))
        assert code == 0, out

    def test_removed_entry_is_noted_not_failed(self):
        code, out = check(edit('            ["3.0.0"] = "XLINGS_RES",\n', ""))
        assert code == 0, out
        assert 'xpm.linux["3.0.0"]: removed; not compared' in out, out

    def test_new_recipe_is_validated_not_compared(self):
        # A recipe the base does not have: nothing to compare, still validated.
        code, out = check(BASE, base_text=None)
        assert code == 0 and "0 published entries compared" in out, out
        code, out = check(edit("revision = 2,", 'revision = "2",'), base_text=None)
        assert code == 1 and "is not a non-negative integer" in out, out

    def test_recipe_that_does_not_load_fails(self):
        code, out = check(BASE + "\nthis is not lua\n")
        assert code == 1 and "cannot load recipe" in out, out

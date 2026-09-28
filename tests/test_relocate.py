"""libs/relocate.lua: a repacked payload's placeholders follow its install directory.

The repack tool (.agents/tools/repack/repack.py) records in RELOCATE.json which
files keep a build-prefix placeholder that only the install step can resolve;
relocate.apply() rewrites them. Binary files must keep their length (ELF
offsets), and every entry that cannot be applied must fail the install rather
than leave a payload pointing at the build machine.
"""
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
LIB = REPO / "libs" / "relocate.lua"
HARNESS = REPO / "tests" / "lua" / "relocate_harness.lua"
# conda pads its build prefix to 255 bytes so any real install path fits
PH = ("/home/conda/feedstock_root/build_artifacts/x_1/_h_env" + "_placehold" * 30)[:255]

pytestmark = pytest.mark.static


def lua():
    exe = shutil.which("lua5.4") or shutil.which("lua")
    if not exe:
        pytest.fail("Lua 5.4 is required for the relocate tests")
    return exe


def run(*args):
    return subprocess.run([lua(), str(HARNESS), str(LIB), *args],
                          capture_output=True, text=True, check=True).stdout.strip()


def manifest(tmp_path, entries):
    body = ",".join(
        f'{{path={p!r}, mode={m!r}, placeholder={ph!r}}}' for p, m, ph in entries)
    f = tmp_path / "manifest.lua"
    f.write_text(f"return {{schema=1, entries={{{body}}}}}")
    return f


def test_rewrite_cases():
    assert run("rewrite") == "OK"


def test_apply_binary_and_text(tmp_path):
    root = tmp_path / "pkg"
    (root / "lib").mkdir(parents=True)
    so = root / "lib" / "libx.so"
    so.write_bytes(b"\x7fELF\0" + PH.encode() + b"/lib/x\0rest")
    txt = root / "lib" / "cache"
    txt.write_text(f'"{PH}/lib/mod.so"\n')
    m = manifest(tmp_path, [("lib/libx.so", "binary", PH), ("lib/cache", "text", PH)])
    assert run("apply", str(root), str(m)) == "APPLIED 2"
    data = so.read_bytes()
    assert len(data) == len(b"\x7fELF\0" + PH.encode() + b"/lib/x\0rest")
    assert (str(root) + "/lib/x").encode() in data and PH.encode() not in data
    assert txt.read_text() == f'"{root}/lib/mod.so"\n'


@pytest.mark.parametrize("entry, message", [
    (("lib/missing.so", "binary", PH), "not in the payload"),
    (("../escape", "text", PH), "outside the payload"),
    (("lib/libx.so", "binary", "/other/placeholder"), "does not contain"),
])
def test_apply_fails_closed(tmp_path, entry, message):
    root = tmp_path / "pkg"
    (root / "lib").mkdir(parents=True)
    (root / "lib" / "libx.so").write_bytes(b"\0" + PH.encode() + b"\0")
    out = run("apply", str(root), str(manifest(tmp_path, [entry])))
    assert out.startswith("ERROR") and message in out


def test_apply_requires_manifest(tmp_path):
    out = run("apply", str(tmp_path))
    assert out.startswith("ERROR") and "schema-1 manifest" in out

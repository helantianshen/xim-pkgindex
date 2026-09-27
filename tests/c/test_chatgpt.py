"""ChatGPT 包的资源边界和启动行为验证"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile

import pytest

from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)
from tests.lib.xpkg_parser import parse_xpkg


ROOT = Path(__file__).resolve().parents[2]
RECIPE = ROOT / "pkgs/c/chatgpt.lua"


@pytest.mark.static
def test_metadata():
    meta = parse_xpkg(str(RECIPE))
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_valid_type(meta)
    assert set(meta.platforms) == {"linux", "macosx"}


@pytest.mark.static
def test_resolved_resources():
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        pytest.skip("Lua is required to evaluate the resource matrix")
    code = r'''
import = function() end
dofile(arg[1])
assert(package.xpm.windows == nil)
for platform, entries in pairs(package.xpm) do
    assert(entries[entries.latest.ref])
    for version, resources in pairs(entries) do
        if version ~= "deps" and version ~= "latest" then
            assert(resources.aarch64)
            assert((platform == "linux") == (resources.x86_64 ~= nil))
            for arch, asset in pairs(resources) do
                assert(asset.url:match("^https://persistent%.oaistatic%.com/"))
                assert(asset.url:find(version, 1, true))
                assert(#asset.sha256 == 64 and asset.sha256:match("^[0-9a-f]+$"))
            end
        end
    end
end
'''
    subprocess.run([lua, "-", str(RECIPE)], input=code, text=True, check=True)


@pytest.mark.isolation
def test_isolation():
    filename = str(RECIPE)
    assert_no_exec_xvm(filename)
    assert_no_bashrc_modification(filename)
    assert_no_direct_path_modification(filename)
    assert_uses_new_api(filename)
    text = RECIPE.read_text()
    assert all(module.startswith("xim.libxpkg.") for module in re.findall(r'import\("([^"]+)"\)', text))
    assert not re.search(r"\b(?:sudo|apt install|dnf install|pacman -S|--no-sandbox)\b", text)


@pytest.mark.index
def test_index_registration():
    assert_xim_add_succeeds(str(RECIPE))


@pytest.mark.static
@pytest.mark.parametrize("version", ["26.924.22138", "wrong-version"])
def test_deb_install_roundtrip(tmp_path, version):
    lua = shutil.which("lua") or shutil.which("lua5.4")
    sevenzip = shutil.which("7zz") or shutil.which("7z")
    if not lua or not sevenzip or not shutil.which("ar"):
        pytest.skip("Lua, 7-Zip and ar are required for the archive roundtrip")
    stage = tmp_path / "input"
    app = stage / "usr/lib/chatgpt"
    (app / "resources").mkdir(parents=True)
    (app / "ChatGPT").write_text("#!/bin/sh\nexit 0\n")
    (app / "ChatGPT").chmod(0o755)
    (app / "resources/app.asar").write_bytes(b"fixture")
    (app / "resources/asar-link").symlink_to("app.asar")
    (app / "resources/linux-package-metadata.json").write_text(json.dumps({"version": version}))
    (stage / "usr/bin").mkdir()
    (stage / "usr/bin/chatgpt").symlink_to("../lib/chatgpt/codex-launcher")
    with tarfile.open(tmp_path / "data.tar.xz", "w:xz") as archive:
        archive.add(stage / "usr", arcname="./usr")
    (tmp_path / "debian-binary").write_text("2.0\n")
    (tmp_path / "control").write_text("Package: chatgpt\nVersion: " + version + "\nArchitecture: amd64\n")
    with tarfile.open(tmp_path / "control.tar.xz", "w:xz") as archive:
        archive.add(tmp_path / "control", arcname="./control")
    subprocess.run(["ar", "rc", "fixture.deb", "debian-binary", "control.tar.xz", "data.tar.xz"], cwd=tmp_path, check=True)
    dep = tmp_path / "dependency"
    dep.mkdir()
    (dep / "7zz").symlink_to(sevenzip)
    target = tmp_path / "installed's folder"
    harness = r'''
local recipe, archive, target, dep = arg[1], arg[2], arg[3], arg[4]
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function run(s) assert(os.execute(s)) end
os.mkdir = function(p) run("mkdir -p " .. q(p)) end
os.mv = function(a,b) run("mv " .. q(a) .. " " .. q(b)) end
os.tryrm = function(p) run("rm -rf " .. q(p)) end
os.isfile = function(p) return os.execute("test -f " .. q(p)) == true end
pkginfo = {
    install_dir = function() return target end,
    install_file = function() return archive end,
    version = function() return "26.924.22138" end,
    dep_install_dir = function() return dep end,
}
system = { exec = run }
json = { loadfile = function(p)
    local f = assert(io.open(p)); local s = f:read("*a"); f:close()
    return { version = s:match('"version"%s*:%s*"([^"]+)"') }
end }
import = function() end
dofile(recipe)
assert(install())
'''
    result = subprocess.run([lua, "-", str(RECIPE), str(tmp_path / "fixture.deb"), str(target), str(dep)],
                            input=harness, capture_output=True, text=True)
    if version == "wrong-version":
        assert result.returncode != 0
        assert "archive version mismatch" in result.stderr
        assert not (target / "app/ChatGPT").exists()
    else:
        assert result.returncode == 0, result.stderr
        assert not (target / ".unpack").exists()
        assert (target / "app/resources/app.asar").read_bytes() == b"fixture"
        assert os.access(target / "app/ChatGPT", os.X_OK)
        assert (target / "app/resources/asar-link").is_symlink()
        assert (target / "app/resources/asar-link").read_bytes() == b"fixture"


@pytest.mark.static
@pytest.mark.parametrize("macos", [False, True])
def test_direct_xvm_registration(tmp_path, macos):
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        pytest.skip("Lua is required")
    root = tmp_path / "version's directory with spaces"
    bindir = root / ("ChatGPT.app/Contents/MacOS" if macos else "app")
    bindir.mkdir(parents=True)
    (bindir / "ChatGPT").touch()
    code = r'''
import = function() end
os.isfile = function(p) local f=io.open(p); if f then f:close(); return true end; return false end
pkginfo = { install_dir = function() return arg[2] end }
xvm = { add = function(name, node)
    assert(name == "chatgpt")
    assert(node.bindir == arg[3])
    assert(node.alias == "ChatGPT")
    assert(node.envs.CODEX_SPARKLE_ENABLED == "false")
end }
dofile(arg[1])
assert(config())
'''
    subprocess.run([lua, "-", str(RECIPE), str(root), str(bindir)], input=code, text=True, check=True)

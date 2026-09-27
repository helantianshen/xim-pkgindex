"""桌面运行库配方的公共元数据与隔离检查"""
from pathlib import Path
import shutil
import subprocess

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)


def check_recipe(name):
    recipe = Path("pkgs") / name[0] / (name + ".lua")
    meta = parse_xpkg(str(recipe))
    for check in (assert_required_fields, assert_valid_spec, assert_valid_type):
        check(meta)
    for check in (assert_no_typos, assert_no_exec_xvm,
                  assert_no_bashrc_modification, assert_no_direct_path_modification,
                  assert_uses_new_api):
        check(str(recipe))
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if lua:
        subprocess.run([lua, "-", str(recipe)], input='''
import = function() end
dofile(arg[1])
local linux = package.xpm.linux
assert(linux[linux.latest.ref])
for _, dep in ipairs(linux.deps) do
    local name = assert(dep:match("^xim:([^@]+)"))
    local f = assert(io.open("pkgs/" .. name:sub(1,1) .. "/" .. name .. ".lua"))
    f:close()
end
for arch, asset in pairs(linux[linux.latest.ref]) do
    assert(asset.url:match("^https://"))
    assert(#asset.sha256 == 64 and asset.sha256:match("^[0-9a-f]+$"))
end
''', text=True, check=True)


def check_index(name):
    assert_xim_add_succeeds(f"pkgs/{name[0]}/{name}.lua")

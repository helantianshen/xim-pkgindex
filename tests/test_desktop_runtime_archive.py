"""归档前缀迁移必须保留二进制布局，文本则使用真实安装路径"""
from pathlib import Path
import shutil
import subprocess

import pytest


@pytest.mark.static
def test_conda_prefix_relocation():
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        pytest.skip("Lua is required")
    script = r'''
import = function() end
local archive = dofile(arg[1])
local old = "/build/placeholder.with-patterns"
local prefix = "/tmp/user's app"
local source = "ELF\0" .. old .. "/lib:" .. old .. "/plugins\0trailer"
local result = archive.relocate(source, old, prefix, true)
assert(#result == #source)
assert(result:find(prefix .. "/lib:" .. prefix .. "/plugins\0", 1, true))
assert(result:sub(-7) == "trailer")
assert(not result:find(old, 1, true))
assert(archive.relocate("prefix=" .. old, old, prefix, false) == "prefix=" .. prefix)
assert(not pcall(archive.relocate, source, old, string.rep("x", #old + 1), true))
'''
    subprocess.run([lua, "-", str(Path("libs/runtime_archive.lua"))],
                   input=script, text=True, check=True)

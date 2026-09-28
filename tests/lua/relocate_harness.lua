-- Drive libs/relocate.lua in plain Lua.
--
--     lua5.4 relocate_harness.lua <relocate.lua> rewrite
--     lua5.4 relocate_harness.lua <relocate.lua> apply <install_dir> <manifest.lua>
--
-- `rewrite` runs the pure function against fixed cases and prints OK.
-- `apply` loads a manifest expressed as a Lua table (json.loadfile is stubbed
-- to return it) and runs relocate.apply over INSTALL_DIR, printing
-- `APPLIED <n>` or `ERROR <message>`.

local lib, mode, install_dir, manifest = ...

function import(name)
    local short = name:match("[^.]+$")
    if short == "json" then
        _G.json = { loadfile = function() return manifest and dofile(manifest) or nil end }
    end
end

local relocate = dofile(lib)

if mode == "rewrite" then
    local ph = "/build/_h_env_placehold_placehold"
    local new = "/tmp/user's app"
    local src = "ELF\0" .. ph .. "/lib:" .. ph .. "/share\0mid\0" .. ph .. "\0tail"
    local out = relocate.rewrite(src, ph, new, true)
    assert(#out == #src, "binary rewrite changed the length")
    assert(out:find(new .. "/lib:" .. new .. "/share\0", 1, true), "both occurrences in one string")
    assert(out:find("\0mid\0", 1, true), "neighbouring strings keep their offsets")
    assert(out:sub(-5) == "\0tail")
    assert(not out:find(ph, 1, true))
    assert(relocate.rewrite("prefix=" .. ph, ph, new, false) == "prefix=" .. new)
    assert(not pcall(relocate.rewrite, src, ph, string.rep("x", #ph + 1), true),
           "a prefix longer than the placeholder must be refused")
    print("OK")
elseif mode == "apply" then
    local ok, res = pcall(relocate.apply, install_dir)
    print(ok and ("APPLIED " .. res) or ("ERROR " .. tostring(res)))
end

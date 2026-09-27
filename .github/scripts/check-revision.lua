#!/usr/bin/env lua
--
-- A published version entry changes what it installs only together with a
-- higher `revision` (docs/V2/xpackage-spec.md, "`revision`").
--
-- WHAT IS CHECKED
-- ---------------
-- Every recipe that the change adds or modifies under pkgs/ is loaded twice
-- in the recipe sandbox (recipe-sandbox.lua): as it is on the base ref and as
-- it is in the work tree (or on --head). For each version entry the base
-- already has, in every `xpm` platform section:
--
--   * its resource -- `url` (with its mirror table), `sha256` (single or
--     per-arch), `res`, `arch_alias`, a per-arch resource map, or the bare
--     string value (`"XLINGS_RES"`, a url) -- is compared with the head's;
--   * if the resource differs, the head's revision must be HIGHER than the
--     base's. A client that implements revision reinstalls a payload whose
--     recorded revision differs from the recipe's; one whose revision did not
--     move keeps the old bytes and never learns that the entry now means
--     something else;
--   * the revision must never decrease.
--
-- For every version entry in a changed recipe, new ones included, `revision`
-- must be a non-negative integer when present, must sit on the version entry
-- itself (not inside a per-arch map, where no client reads it), and must not
-- appear on a `ref` alias, which carries none.
--
-- The resource is everything in the entry except `revision`, `ref` and
-- `deps`, so a field this check does not know by name counts as part of what
-- is downloaded rather than being ignored. A platform-level or root `source`
-- is not attributed to the entries that inherit it: bytes that change behind
-- an inherited url change the entry's own sha256, and that is compared.
--
-- WHAT IS NOT CHECKED
-- -------------------
-- Hook changes. An install() that now writes different files under an
-- unchanged resource changes what the entry installs just as a new asset
-- does, and needs a higher revision just the same; whether a hook change
-- alters the installed files is a judgement this check cannot make, so it is
-- made in review.
--
-- An entry that is removed, or that is an alias on either side, is not
-- compared.
--
-- USAGE
-- -----
-- CI runs it through check-revision.sh, which finds the interpreter and the
-- base ref. Directly:
--
--     lua check-revision.lua --base <ref> [--head <ref>] [<repo-root>]
--
-- Exit 0 = every compared entry is consistent; 1 = a violation or a recipe
-- that cannot be loaded; 2 = usage error or an unusable base ref.
--

local SCRIPT_DIR = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local sandbox = dofile(SCRIPT_DIR .. "/recipe-sandbox.lua")
local sorted_keys = sandbox.sorted_keys

-- `math.type` separates 1 from 1.0, which is the distinction the client
-- makes: libxpkg reads a revision with lua_isinteger, so `revision = 1.0`
-- installs as revision 0.
if not math.type then
    io.stderr:write("check-revision.lua needs Lua 5.3+ (math.type)\n")
    os.exit(2)
end

-- Fields of a platform section that are not version entries.
local PLATFORM_FIELDS = {
    deps = true, exports = true, source = true, url_template = true,
    arch_alias = true, res_versioned = true, ref = true,
}
-- Fields of `xpm` that are not platform sections.
local XPM_FIELDS = { source = true }
-- Fields of a version entry that are not part of what it downloads.
local NON_RESOURCE = { revision = true, ref = true, deps = true }

-- ── git ────────────────────────────────────────────────────────────────
local function sh_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Output of a git command, and whether it exited 0.
local function git(root, args)
    local p = io.popen("git -C " .. sh_quote(root) .. " " .. args .. " 2>/dev/null")
    if not p then return "", false end
    local out = p:read("a") or ""
    local ok = p:close()
    return out, ok == true
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

-- ── values ─────────────────────────────────────────────────────────────
-- A canonical text form of a value: table keys sorted, strings quoted, 1 and
-- 1.0 kept apart. Two entries have the same resource exactly when their
-- canonical forms are equal.
local function canon(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" then
        return (math.type(v) == "integer") and tostring(v) or string.format("%.17g(float)", v)
    end
    if t == "boolean" then return tostring(v) end
    if t == "table" then
        if v == sandbox.stub then return "<stub>" end
        if depth > 32 then return "<too deep>" end
        local parts = {}
        for _, k in ipairs(sorted_keys(v)) do
            parts[#parts + 1] = "[" .. canon(k, depth + 1) .. "]="
                .. canon(rawget(v, k), depth + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "<" .. t .. ">"
end

local function show(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)   -- 5.3+: a float prints as `1.0`, an integer as `1`
end

local function is_alias(entry)
    return type(entry) == "table" and rawget(entry, "ref") ~= nil
end

local function resource_of(entry)
    if type(entry) ~= "table" then return canon(entry) end
    local r = {}
    for k, v in pairs(entry) do
        if not NON_RESOURCE[k] then r[k] = v end
    end
    return canon(r)
end

-- The revision a client reads (non-negative integer, else 0), and the
-- problems with how it is stated.
local function revision_of(entry)
    if type(entry) ~= "table" then return 0, {} end
    local problems = {}
    local r = rawget(entry, "revision")
    local value = 0
    if r ~= nil then
        if math.type(r) == "integer" and r >= 0 then
            value = r
        else
            problems[#problems + 1] = string.format(
                "`revision = %s` is not a non-negative integer; a client reads it as 0",
                show(r))
        end
        if is_alias(entry) then
            problems[#problems + 1] =
                "a `ref` alias carries no revision; state it on the entry the alias names"
        end
    end
    for k, v in pairs(entry) do
        if type(v) == "table" and v ~= sandbox.stub and rawget(v, "revision") ~= nil then
            problems[#problems + 1] = string.format(
                "`revision` inside `%s` is read by no client; it belongs on the version entry",
                tostring(k))
        end
    end
    return value, problems
end

-- platform -> version -> entry, for every version entry of a loaded package.
local function entries_of(pkg)
    local out = {}
    local xpm = type(pkg) == "table" and rawget(pkg, "xpm") or nil
    if type(xpm) ~= "table" then return out end
    for _, plat in ipairs(sorted_keys(xpm)) do
        local pdata = rawget(xpm, plat)
        if type(pdata) == "table" and not XPM_FIELDS[plat] then
            local section = {}
            for _, key in ipairs(sorted_keys(pdata)) do
                if type(key) == "string" and not PLATFORM_FIELDS[key] then
                    section[key] = rawget(pdata, key)
                end
            end
            out[tostring(plat)] = section
        end
    end
    return out
end

-- ── the check ──────────────────────────────────────────────────────────
local function usage()
    io.stderr:write("usage: check-revision.lua --base <ref> [--head <ref>] [<repo-root>]\n")
    os.exit(2)
end

local base_ref, head_ref, root = nil, nil, "."
local i = 1
while arg[i] do
    local a = arg[i]
    if a == "--base" then base_ref = arg[i + 1]; i = i + 2
    elseif a == "--head" then head_ref = arg[i + 1]; i = i + 2
    elseif a:sub(1, 2) == "--" then usage()
    else root = a; i = i + 1 end
end
if not base_ref or base_ref == "" then usage() end
root = root:gsub("/+$", "")
if root == "" then root = "/" end

local _, base_ok = git(root, "rev-parse --verify --quiet " .. sh_quote(base_ref .. "^{commit}"))
if not base_ok then
    io.stderr:write(string.format("check-revision: cannot resolve the base ref '%s'\n", base_ref))
    os.exit(2)
end

local diff_args = "diff --name-only --no-renames --diff-filter=AM " .. sh_quote(base_ref)
if head_ref then diff_args = diff_args .. " " .. sh_quote(head_ref) end
local names, diff_ok = git(root, diff_args .. " -- pkgs/")
if not diff_ok then
    io.stderr:write("check-revision: git diff failed\n")
    os.exit(2)
end

local changed = {}
for line in names:gmatch("[^\n]+") do
    if line:match("%.lua$") then changed[#changed + 1] = line end
end
table.sort(changed)

local errors, notes = {}, {}
local compared, validated = 0, 0

local function err(file, msg)
    errors[#errors + 1] = string.format("::error file=%s::%s", file, msg)
end

for _, file in ipairs(changed) do
    local head_text
    if head_ref then
        local out, ok = git(root, "show " .. sh_quote(head_ref .. ":" .. file))
        head_text = ok and out or nil
    else
        head_text = read_file(root .. "/" .. file)
    end
    local head_pkg, head_err
    if head_text then
        head_pkg, head_err = sandbox.load_recipe_text(head_text, file)
    else
        head_err = "cannot read the file"
    end
    if not head_pkg then
        err(file, "cannot load recipe: " .. tostring(head_err))
    else
        local base_pkg = nil
        local base_text, on_base = git(root, "show " .. sh_quote(base_ref .. ":" .. file))
        if on_base then
            local base_err
            base_pkg, base_err = sandbox.load_recipe_text(base_text, file .. "@base")
            if not base_pkg then
                notes[#notes + 1] = string.format(
                    "%s: the base version does not load (%s); its entries were not compared",
                    file, tostring(base_err))
            end
        end

        local head_entries = entries_of(head_pkg)
        local base_entries = entries_of(base_pkg)

        for _, plat in ipairs(sorted_keys(head_entries)) do
            local section = head_entries[plat]
            for _, ver in ipairs(sorted_keys(section)) do
                local entry = section[ver]
                local where = string.format("%s xpm.%s[%q]", file, plat, ver)
                validated = validated + 1
                local head_rev, problems = revision_of(entry)
                for _, p in ipairs(problems) do err(file, where .. ": " .. p) end

                local old = base_entries[plat] and base_entries[plat][ver]
                if old ~= nil and not is_alias(old) and not is_alias(entry) then
                    compared = compared + 1
                    local base_rev = revision_of(old)
                    if head_rev < base_rev then
                        err(file, string.format(
                            "%s: revision decreased from %d to %d. A revision only ever "
                            .. "increases; a client holding revision %d would take the "
                            .. "entry for a different payload and reinstall it.",
                            where, base_rev, head_rev, base_rev))
                    elseif resource_of(old) ~= resource_of(entry) and head_rev <= base_rev then
                        err(file, string.format(
                            "%s: the resource of a published version changed while its "
                            .. "revision stayed %d. A published url and sha256 are "
                            .. "immutable; publish the new payload under a new asset name "
                            .. "and raise `revision` to %d, so that clients holding "
                            .. "revision %d reinstall it (docs/V2/xpackage-spec.md).",
                            where, base_rev, base_rev + 1, base_rev))
                    end
                end
            end
        end

        for _, plat in ipairs(sorted_keys(base_entries)) do
            for _, ver in ipairs(sorted_keys(base_entries[plat])) do
                if not (head_entries[plat] and head_entries[plat][ver] ~= nil) then
                    notes[#notes + 1] = string.format(
                        "%s xpm.%s[%q]: removed; not compared", file, plat, ver)
                end
            end
        end
    end
end

for _, n in ipairs(notes) do io.write("note: " .. n .. "\n") end
for _, e in ipairs(errors) do io.write(e .. "\n") end

if #errors > 0 then
    io.write(string.format(
        "revision check: FAIL (%d problem(s); %d published entr%s compared, "
        .. "%d entr%s validated, %d changed recipe(s) against %s)\n",
        #errors, compared, compared == 1 and "y" or "ies",
        validated, validated == 1 and "y" or "ies", #changed, base_ref))
    os.exit(1)
end
-- The counts are part of the result: a check that compared nothing prints
-- the same PASS as one that compared everything, and only the numbers tell
-- the two apart.
io.write(string.format(
    "revision check: PASS (%d published entr%s compared, %d entr%s validated, "
    .. "%d changed recipe(s) against %s)\n",
    compared, compared == 1 and "y" or "ies",
    validated, validated == 1 and "y" or "ies", #changed, base_ref))
os.exit(0)

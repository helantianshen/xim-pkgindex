import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.json")
import("xim.pkgindex.sysroot")

local runtime_archive = {}

local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- conda 的二进制前缀按 NUL 字符串补齐，保持 ELF 段偏移和文件长度不变
function runtime_archive.relocate(data, old, prefix, binary)
    local pattern = old:gsub("([^%w])", "%%%1")
    if not binary then return (data:gsub(pattern, function() return prefix end)) end
    assert(#prefix <= #old, "Runtime install prefix exceeds upstream placeholder")
    return (data:gsub("([^%z]+)%z", function(chunk)
        local result, count = chunk:gsub(pattern, function() return prefix end)
        return result .. string.rep("\0", count * (#old - #prefix)) .. "\0"
    end))
end

-- 归档由资源声明校验，解包过程不执行发行版或 conda 安装脚本
function runtime_archive.install(required)
    local dir = pkginfo.install_dir()
    local archive = pkginfo.install_file()
    local work = dir .. "/.unpack"
    local stage = work .. "/payload"
    local z = quote(pkginfo.dep_install_dir("xim:7zip") .. "/7zz")
    os.tryrm(work)
    os.mkdir(stage)
    local function extract(file, format, target)
        system.exec(z .. " x -y -t" .. format .. " " .. quote(file) .. " -o" .. quote(target))
    end
    local stem = archive:match("([^/]+)%.conda$")
    if stem then
        extract(archive, "zip", work)
        for _, prefix in ipairs({"pkg-", "info-"}) do
            local tar = work .. "/" .. prefix .. stem .. ".tar"
            extract(tar .. ".zst", "zstd", work)
            extract(tar, "tar", stage)
        end
    elseif archive:match("%.tar%.bz2$") then
        extract(archive, "bzip2", work)
        extract(work .. "/" .. archive:match("([^/]+)%.bz2$"), "tar", stage)
    elseif archive:match("%.deb$") then
        system.exec(z .. " x -y -tAr " .. quote(archive) .. " data.tar.xz -o" .. quote(work))
        extract(work .. "/data.tar.xz", "xz", work)
        extract(work .. "/data.tar", "tar", stage)
        local triplet = archive:match("_arm64%.deb$") and "aarch64-linux-gnu" or "x86_64-linux-gnu"
        os.mv(stage .. "/usr/lib/" .. triplet, stage .. "/lib")
        if os.isdir(stage .. "/usr/share") then os.mv(stage .. "/usr/share", stage .. "/share") end
    else
        error("Unsupported runtime archive: " .. archive)
    end
    for _, file in ipairs(required) do
        assert(os.isfile(stage .. "/" .. file), "Missing runtime payload: " .. file)
    end
    local paths = stage .. "/info/paths.json"
    if os.isfile(paths) then
        for _, entry in ipairs(json.loadfile(paths).paths) do
            if entry.prefix_placeholder then
                local file = stage .. "/" .. entry._path
                assert(not entry._path:find("..", 1, true) and entry._path:sub(1,1) ~= "/")
                local input = assert(io.open(file, "rb"))
                local data = input:read("*a")
                input:close()
                local output = assert(io.open(file, "wb"))
                output:write(runtime_archive.relocate(data, entry.prefix_placeholder, dir, entry.file_mode == "binary"))
                output:close()
            end
        end
    end
    for _, name in ipairs({"lib", "libexec", "include", "share", "info", "etc", "bin"}) do
        if os.isdir(stage .. "/" .. name) then
            os.tryrm(dir .. "/" .. name)
            os.mv(stage .. "/" .. name, dir .. "/" .. name)
        end
    end
    os.tryrm(work)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

return runtime_archive

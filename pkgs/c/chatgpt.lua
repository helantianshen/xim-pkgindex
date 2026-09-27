local base = "https://persistent.oaistatic.com/codex-app-prod/"

local function deb(version, arch, sha256)
    return {
        url = base .. "linux/deb/pool/main/c/chatgpt/chatgpt_" .. version .. "_" .. arch .. ".deb",
        sha256 = sha256,
    }
end

local function mac(version, sha256)
    return { aarch64 = {
        url = base .. "ChatGPT-darwin-arm64-" .. version .. ".zip",
        sha256 = sha256,
    } }
end

package = {
    spec = "2",
    name = "chatgpt",
    description = "Official ChatGPT desktop app with xlings-managed versions",
    homepage = "https://learn.chatgpt.com/docs/app",
    docs = "https://learn.chatgpt.com/docs/linux/linux-app",
    licenses = {"LicenseRef-OpenAI-Proprietary"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"app", "ai", "tools"},
    keywords = {"chatgpt", "openai", "desktop"},
    programs = {"chatgpt"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip@26.02"},
            ["latest"] = { ref = "26.924.22138" },
            ["26.924.22138"] = {
                x86_64 = deb("26.924.22138", "amd64", "ce3bb1aa82ccdfe3037ada2fd8d187796ea4a0d5ed031d0e4ec8adce8b7014e7"),
                aarch64 = deb("26.924.22138", "arm64", "6570f078c5ea25461ce103b2e31fa7dd6c5e717136fa9237c701d22db62b5e3f"),
            },
            ["26.917.71314"] = {
                x86_64 = deb("26.917.71314", "amd64", "851ec28b65bde2ff1da9f37dcdf5b6e20a915c7568f8b2ce993c00428f018ae5"),
                aarch64 = deb("26.917.71314", "arm64", "2114883623dae34a4bc7a67faad3e6652dd9bfdc7a28f57c36ed03e350be1cf1"),
            },
        },
        macosx = {
            ["latest"] = { ref = "26.924.22138" },
            ["26.924.22138"] = mac("26.924.22138", "7cf9569b116a32af61a6ab4e9979466774b6dc8e9dbcf70264596a1ae2dfd57d"),
            ["26.917.71314"] = mac("26.917.71314", "e3f436f729295bdb72b9acc9115bbf767a1fda7d081f2f83de84f70b93fdca9c"),
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.json")

local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

function install()
    local dir = pkginfo.install_dir()
    local archive = pkginfo.install_file()
    local parent = assert(archive:match("^(.*)/[^/]+$"))
    local version = pkginfo.version()
    os.mkdir(dir)

    if archive:match("%.deb$") then
        local unpack = dir .. "/.unpack"
        local sevenzip = pkginfo.dep_install_dir("xim:7zip") .. "/7zz"
        os.tryrm(unpack)
        os.mkdir(unpack)
        system.exec(quote(sevenzip) .. " x -tAr -y " .. quote(archive) .. " data.tar.xz -o" .. quote(unpack))
        system.exec(quote(sevenzip) .. " x -txz -y " .. quote(unpack .. "/data.tar.xz") .. " -o" .. quote(unpack))
        system.exec(quote(sevenzip) .. " x -ttar -y " .. quote(unpack .. "/data.tar") .. " -o" .. quote(unpack) .. " './usr/lib/chatgpt/*'")
        local app = unpack .. "/usr/lib/chatgpt"
        local metadata = json.loadfile(app .. "/resources/linux-package-metadata.json")
        assert(metadata.version == version, "ChatGPT archive version mismatch")
        assert(os.isfile(app .. "/ChatGPT"), "ChatGPT executable is missing")
        assert(os.isfile(app .. "/resources/app.asar"), "ChatGPT app.asar is missing")
        os.tryrm(dir .. "/app")
        os.mv(app, dir .. "/app")
        os.tryrm(unpack)
    elseif archive:match("%.zip$") then
        local app = parent .. "/ChatGPT.app"
        system.exec("test \"$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' " ..
            quote(app .. "/Contents/Info.plist") .. ")\" = " .. quote(version))
        system.exec("/usr/bin/codesign --verify --deep --strict " .. quote(app))
        os.tryrm(dir .. "/ChatGPT.app")
        os.mv(app, dir .. "/ChatGPT.app")
    else
        error("Unsupported ChatGPT archive")
    end

    return os.isfile(dir .. "/app/ChatGPT") or os.isfile(dir .. "/ChatGPT.app/Contents/MacOS/ChatGPT")
end

function config()
    local dir = pkginfo.install_dir()
    local bindir = dir .. "/app"
    if os.isfile(dir .. "/ChatGPT.app/Contents/MacOS/ChatGPT") then
        bindir = dir .. "/ChatGPT.app/Contents/MacOS"
    end
    -- 更新开关只传给当前应用及其子进程
    xvm.add("chatgpt", {
        bindir = bindir,
        alias = "ChatGPT",
        envs = { CODEX_SPARKLE_ENABLED = "false" },
    })
    return true
end

function uninstall()
    xvm.remove("chatgpt")
    return true
end

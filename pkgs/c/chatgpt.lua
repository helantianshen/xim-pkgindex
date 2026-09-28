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
            -- Linux arm64 debs exist upstream, but glibc and gcc-runtime have
            -- no arm64 payload yet, so only x86_64 is offered here.
            --
            -- Put first on every ELF's RUNPATH by elfpatch: the bundled
            -- libvips the native image module links against.
            exports = { runtime = { libdirs = {
                "app",
                "app/resources/cua_node/lib/node_modules/@img/sharp-libvips-linux-x64/lib",
            } } },
            -- Grouped by how the app reaches them. 7zip unpacks the deb in
            -- install(); everything else is the app's runtime closure.
            deps = {
                "xim:7zip@26.02",
                -- DT_NEEDED of ChatGPT and its native modules (readelf -d)
                "xim:glibc", "xim:gcc-runtime", "xim:glib", "xim:dbus", "xim:expat",
                "xim:nss", "xim:nspr", "xim:atk", "xim:at-spi2-atk", "xim:at-spi2-core",
                "xim:libcups", "xim:cairo", "xim:pango", "xim:gdk-pixbuf", "xim:gtk3",
                "xim:libxcb", "xim:libxkbcommon", "xim:libX11", "xim:libXext",
                "xim:libXcomposite", "xim:libXdamage", "xim:libXfixes", "xim:libXrandr",
                "xim:alsa-lib", "xim:mesa", "xim:libudev", "xim:libusb", "xim:openssl",
                "xim:tpm2-tss",
                -- dlopen'd by Chromium/Electron: the keyring-backed credential
                -- store (without it: a plain-text store) and notifications
                "xim:libsecret", "xim:libnotify",
                -- Chromium's optional Qt UI shims (KDE, --ui-toolkit=qt)
                "xim:qt5", "xim:qt-base",
                -- GL/EGL/Vulkan discovery for the GPU process
                "xim:graphics",
            },
            ["latest"] = { ref = "26.924.22138" },
            ["26.924.22138"] = {
                x86_64 = deb("26.924.22138", "amd64", "ce3bb1aa82ccdfe3037ada2fd8d187796ea4a0d5ed031d0e4ec8adce8b7014e7"),
            },
            ["26.917.71314"] = {
                x86_64 = deb("26.917.71314", "amd64", "851ec28b65bde2ff1da9f37dcdf5b6e20a915c7568f8b2ce993c00428f018ae5"),
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
import("xim.libxpkg.log")
import("xim.pkgindex.graphics")

local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function apparmor_profile(dir)
    return dir .. "/share/apparmor/xlings-chatgpt"
end

-- 1 when unprivileged user namespaces need an AppArmor grant on this host
local function userns_restricted()
    local f = io.open("/proc/sys/kernel/apparmor_restrict_unprivileged_userns")
    if not f then return false end
    local v = f:read("*l")
    f:close()
    return v == "1"
end

function install()
    local dir = pkginfo.install_dir()
    local archive = pkginfo.install_file()
    local parent = assert(archive:match("^(.*)/[^/]+$"))
    local version = pkginfo.version()
    os.mkdir(dir)

    if archive:match("%.deb$") then
        local unpack = dir .. "/.unpack"
        local z = quote(pkginfo.dep_install_dir("xim:7zip") .. "/7zz")
        os.tryrm(unpack)
        os.mkdir(unpack)
        -- ar -> xz -> tar as one stream: the 1.5 GiB data.tar never lands on
        -- disk, and only the application directory is written out.
        system.exec(z .. " e -so -tAr " .. quote(archive) .. " data.tar.xz | "
            .. z .. " x -si -txz -so | "
            .. z .. " x -si -ttar -y -o" .. quote(unpack) .. " './usr/lib/chatgpt/*' >/dev/null")
        local app = unpack .. "/usr/lib/chatgpt"
        local metadata = json.loadfile(app .. "/resources/linux-package-metadata.json")
        assert(metadata.version == version, "ChatGPT archive version mismatch")
        assert(os.isfile(app .. "/ChatGPT"), "ChatGPT executable is missing")
        assert(os.isfile(app .. "/resources/app.asar"), "ChatGPT app.asar is missing")
        os.tryrm(dir .. "/app")
        os.mv(app, dir .. "/app")
        os.tryrm(unpack)
        -- The deb's postinst loads an AppArmor profile that grants user
        -- namespaces to /usr/lib/chatgpt/ChatGPT, which Chromium's sandbox
        -- needs on hosts that restrict them (Ubuntu 23.10+). The same profile
        -- for this path, for the user to load; config() says how.
        os.mkdir(dir .. "/share/apparmor")
        local f = assert(io.open(apparmor_profile(dir), "w"))
        f:write("abi <abi/4.0>,\ninclude <tunables/global>\n\n",
                "profile xlings-chatgpt-", version, " \"", dir, "/app/ChatGPT\" flags=(unconfined) {\n",
                "  userns,\n}\n")
        f:close()
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
    local envs = { CODEX_SPARKLE_ENABLED = "false" }
    if os.isfile(dir .. "/ChatGPT.app/Contents/MacOS/ChatGPT") then
        bindir = dir .. "/ChatGPT.app/Contents/MacOS"
    else
        -- XDG_DATA_DIRS among these reaches <subos>/share, where gtk3
        -- places its compiled GSettings schemas
        envs = graphics.consumer_envs()
        envs.CODEX_SPARKLE_ENABLED = "false"
        if userns_restricted() then
            local profile = apparmor_profile(dir)
            log.warn("ChatGPT: this host restricts unprivileged user namespaces, which "
                .. "Chromium's sandbox needs. To allow them for this version, as root: "
                .. "install -m 0644 %s /etc/apparmor.d/xlings-chatgpt-%s && "
                .. "apparmor_parser -r /etc/apparmor.d/xlings-chatgpt-%s",
                profile, pkginfo.version(), pkginfo.version())
        end
    end
    -- The updater switch reaches this app and its children only
    xvm.add("chatgpt", {
        bindir = bindir,
        alias = "ChatGPT",
        envs = envs,
    })
    return true
end

function uninstall()
    xvm.remove("chatgpt")
    return true
end

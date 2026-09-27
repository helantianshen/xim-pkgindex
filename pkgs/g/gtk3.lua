-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "gtk3",
    description = "gtk3 runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/gtk3",
    licenses = {"LGPL-2.0-or-later"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:at-spi2-atk", "xim:atk", "xim:cairo", "xim:fontconfig", "xim:fribidi", "xim:gdk-pixbuf", "xim:glib", "xim:glibc", "xim:harfbuzz", "xim:libX11", "xim:libXcomposite", "xim:libXcursor", "xim:libXdamage", "xim:libXext", "xim:libXfixes", "xim:libXi", "xim:libXinerama", "xim:libXrandr", "xim:libcups", "xim:libepoxy", "xim:libxkbcommon", "xim:pango", "xim:wayland"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "3.24.43" },
            ["3.24.43"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/gtk3-3.24.43-h0359ba6_0.conda",
                    sha256 = "493d416b436bf9902d246ae333f0e1ecfb7d8193f0acd0e5f30bb2405f06558b",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/gtk3-3.24.43-h16d2767_0.conda",
                    sha256 = "ede9c5f46c598ac935162796e5159e3a43a3d7cc315e9654dc434e22581d9da5",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libgailutil-3.so.0", "lib/libgdk-3.so.0", "lib/libgtk-3.so.0"})
end

function config()
    local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
    local schemas = pkginfo.install_dir() .. "/share/glib-2.0/schemas"
    local compiler = pkginfo.dep_install_dir("xim:glib") .. "/bin/glib-compile-schemas"
    system.exec(quote(compiler) .. " --strict " .. quote(schemas))
    assert(os.isfile(schemas .. "/gschemas.compiled"), "GTK schemas were not compiled")
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

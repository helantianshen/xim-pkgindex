-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "at-spi2-core",
    description = "at-spi2-core runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/at-spi2-core",
    licenses = {"LGPL-2.1-or-later"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:dbus", "xim:glib", "xim:glibc", "xim:libX11", "xim:libXi", "xim:libXtst"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "2.40.3" },
            ["2.40.3"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/at-spi2-core-2.40.3-h0630a04_0.tar.bz2",
                    sha256 = "c4f9b66bd94c40d8f1ce1fad2d8b46534bdefda0c86e3337b28f6c25779f258d",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/at-spi2-core-2.40.3-h1f2db35_0.tar.bz2",
                    sha256 = "cd48de9674a20133e70a643476accc1a63360c921ab49477638364877937a40d",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libatspi.so.0"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

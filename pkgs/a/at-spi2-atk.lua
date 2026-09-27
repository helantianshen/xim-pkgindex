-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "at-spi2-atk",
    description = "at-spi2-atk runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/at-spi2-atk",
    licenses = {"LGPL-2.1"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:at-spi2-core", "xim:atk", "xim:dbus", "xim:glib", "xim:glibc"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "2.38.0" },
            ["2.38.0"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/at-spi2-atk-2.38.0-h0630a04_3.tar.bz2",
                    sha256 = "26ab9386e80bf196e51ebe005da77d57decf6d989b4f34d96130560bc133479c",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/at-spi2-atk-2.38.0-h1f2db35_3.tar.bz2",
                    sha256 = "c2c2c998d49c061e390537f929e77ce6b023ef22b51a0f55692d6df7327f3358",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libatk-bridge-2.0.so.0", "lib/gtk-2.0/modules/libatk-bridge.so"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

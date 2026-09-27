-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "libXcomposite",
    description = "libXcomposite runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/xorg-libxcomposite",
    licenses = {"MIT"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glibc", "xim:libX11"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "0.4.6" },
            ["0.4.6"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/xorg-libxcomposite-0.4.6-hb9d3cd8_2.conda",
                    sha256 = "753f73e990c33366a91fd42cc17a3d19bb9444b9ca5ff983605fa9e953baf57f",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/xorg-libxcomposite-0.4.6-h86ecc28_2.conda",
                    sha256 = "0cb82160412adb6d83f03cf50e807a8e944682d556b2215992a6fbe9ced18bc0",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libXcomposite.so.1"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

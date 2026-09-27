-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "libusb",
    description = "libusb runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/libusb",
    licenses = {"LGPL-2.1-or-later"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glibc", "xim:libudev1"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "1.0.29" },
            ["1.0.29"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/libusb-1.0.29-h73b1eb8_0.conda",
                    sha256 = "89c84f5b26028a9d0f5c4014330703e7dff73ba0c98f90103e9cef6b43a5323c",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/libusb-1.0.29-h06eaf92_0.conda",
                    sha256 = "a60aae6b529cd7caa7842f9781ef95b93014e618f71fb005e404af434d76a33f",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libusb-1.0.so.0"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "libcap",
    description = "libcap runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/libcap",
    licenses = {"BSD-3-Clause"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glibc"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "2.71" },
            ["2.71"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/libcap-2.71-h39aace5_0.conda",
                    sha256 = "2bbefac94f4ab8ff7c64dc843238b6c8edcc9ff1f2b5a0a48407a904dc7ccfb2",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/libcap-2.71-h51d75a7_0.conda",
                    sha256 = "2b66e66e6a0768e833e7edc764649679881ec0a6b37d9bf254b1ceb3b8b434ef",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libcap.so.2", "lib/libpsx.so.2"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

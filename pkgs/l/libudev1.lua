-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "libudev1",
    description = "libudev1 runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/libudev1",
    licenses = {"LGPL-2.1-or-later"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glibc", "xim:libcap"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "257.4" },
            ["257.4"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/libudev1-257.4-hbe16f8c_1.conda",
                    sha256 = "56e55a7e7380a980b418c282cb0240b3ac55ab9308800823ff031a9529e2f013",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/libudev1-257.4-h7b9e449_1.conda",
                    sha256 = "3eff7ed43eb78a1f11d51e99ee3a49ed7da508ee1077ea9dbbaa49f9e30b9000",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libudev.so.1"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

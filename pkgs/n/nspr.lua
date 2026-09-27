-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "nspr",
    description = "nspr runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/nspr",
    licenses = {"MPL-2.0"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glibc"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "4.40" },
            ["4.40"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/nspr-4.40-h29cc59b_0.conda",
                    sha256 = "7cf473259ef9945ce19ecc898a2dd146cd32dc86099d87b86f79c5e5b0ef55f0",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/nspr-4.40-h3ad9384_0.conda",
                    sha256 = "bff5602852f1662852e809d5d1cd0a79055bbcfa37906911e2574ca40681b10e",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libnspr4.so", "lib/libplc4.so", "lib/libplds4.so"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

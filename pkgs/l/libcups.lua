-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "libcups",
    description = "libcups runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/libcups",
    licenses = {"Apache-2.0"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glibc", "xim:krb5", "xim:zlib"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "2.3.3" },
            ["2.3.3"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/libcups-2.3.3-h7a8fb5f_6.conda",
                    sha256 = "205c4f19550f3647832ec44e35e6d93c8c206782bdd620c1d7cf66237580ff9c",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/libcups-2.3.3-h4f2b762_6.conda",
                    sha256 = "41b04f995c9f63af8c4065a35931e46cbc2fdd6b9bf7e4c19f90d53cbb2bc8e5",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libcups.so.2", "lib/libcupsimage.so.2"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

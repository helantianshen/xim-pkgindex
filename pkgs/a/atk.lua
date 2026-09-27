-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "atk",
    description = "atk runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/atk-1.0",
    licenses = {"LGPL-2.0-or-later"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glib", "xim:glibc"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "2.38.0" },
            ["2.38.0"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/atk-1.0-2.38.0-h04ea711_2.conda",
                    sha256 = "df682395d05050cd1222740a42a551281210726a67447e5258968dd55854302e",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/atk-1.0-2.38.0-hedc4a1f_2.conda",
                    sha256 = "69f70048a1a915be7b8ad5d2cbb7bf020baa989b5506e45a676ef4ef5106c4f0",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libatk-1.0.so.0"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

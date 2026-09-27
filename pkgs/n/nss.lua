-- conda-forge 固定构建的独立运行库，资源 SHA256 与两架构 ELF 依赖均已核对
package = {
    spec = "2",
    name = "nss",
    description = "nss runtime libraries for desktop applications",
    homepage = "https://anaconda.org/conda-forge/nss",
    licenses = {"MPL-2.0"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glibc", "xim:nspr", "xim:sqlite"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "3.118" },
            ["3.118"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/nss-3.118-h445c969_0.conda",
                    sha256 = "44dd98ffeac859d84a6dcba79a2096193a42fc10b29b28a5115687a680dd6aea",
                },
                aarch64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-aarch64/nss-3.118-h544fa81_0.conda",
                    sha256 = "48942696889367ffd448f8dccfc080fb7e130b9938a4a3b6b20ef8e6af856463",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.libxpkg.pkginfo")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libfreebl3.so", "lib/libfreeblpriv3.so", "lib/libnss3.so", "lib/libnssckbi.so", "lib/libnssdbm3.so", "lib/libnsssysinit.so", "lib/libnssutil3.so", "lib/libsmime3.so", "lib/libsoftokn3.so", "lib/libssl3.so"})
end

function config()
    xvm.add(package.name, { type = "group" })
    -- NSPR 通过 SONAME 动态加载 NSS 模块，SubOS 库入口覆盖该加载路径
    sysroot.declare_libs(pkginfo.install_dir(), "lib", package.name .. "@" .. pkginfo.version(), pkginfo.version())
    return true
end

function uninstall()
    for _, name in ipairs(sysroot.entries(pkginfo.install_dir() .. "/lib")) do
        if name:find("%.so$") or name:find("%.so%.") then xvm.remove(name) end
    end
    xvm.remove(package.name)
    return true
end

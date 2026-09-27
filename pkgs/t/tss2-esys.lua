-- Debian 固定构建的独立 TPM 运行库，安装时仅提取库和许可文件
package = {
    spec = "2",
    name = "tss2-esys",
    description = "tss2-esys runtime libraries for desktop applications",
    homepage = "https://github.com/tpm2-software/tpm2-tss",
    licenses = {"BSD-2-Clause"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glibc", "xim:tss2-mu", "xim:tss2-sys", "xim:openssl"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "4.1.3" },
            ["4.1.3"] = {
                x86_64 = {
                    url = "https://deb.debian.org/debian/pool/main/t/tpm2-tss/libtss2-esys-3.0.2-0t64_4.1.3-7_amd64.deb",
                    sha256 = "98aedd109f1636f1632b0b1ff5558d28d6bd242a976fa83f64ab89928737fafa",
                },
                aarch64 = {
                    url = "https://deb.debian.org/debian/pool/main/t/tpm2-tss/libtss2-esys-3.0.2-0t64_4.1.3-7_arm64.deb",
                    sha256 = "c9f066b2d6c4f8d5600f5011a4b38edb465c1204e7a88c2d1a787f3d24756f73",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libtss2-esys.so.0"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

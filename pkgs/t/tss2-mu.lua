-- Debian 固定构建的独立 TPM 运行库，安装时仅提取库和许可文件
package = {
    spec = "2",
    name = "tss2-mu",
    description = "tss2-mu runtime libraries for desktop applications",
    homepage = "https://github.com/tpm2-software/tpm2-tss",
    licenses = {"BSD-2-Clause"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glibc"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "4.1.3" },
            ["4.1.3"] = {
                x86_64 = {
                    url = "https://deb.debian.org/debian/pool/main/t/tpm2-tss/libtss2-mu-4.0.1-0t64_4.1.3-7_amd64.deb",
                    sha256 = "83b74e945d9b34baa3f40c6d17649b8a538f76b335c2bb2ea2398e47806653c6",
                },
                aarch64 = {
                    url = "https://deb.debian.org/debian/pool/main/t/tpm2-tss/libtss2-mu-4.0.1-0t64_4.1.3-7_arm64.deb",
                    sha256 = "4770af1f999afae91798b4836b9188316d5dedba5d4fe21ce6688f761bec8b41",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libtss2-mu.so.0"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

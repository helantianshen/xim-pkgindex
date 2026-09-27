-- Debian 固定构建的独立 TPM 运行库，安装时仅提取库和许可文件
package = {
    spec = "2",
    name = "tss2-sys",
    description = "tss2-sys runtime libraries for desktop applications",
    homepage = "https://github.com/tpm2-software/tpm2-tss",
    licenses = {"BSD-2-Clause"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "desktop"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {"xim:7zip", "xim:glibc", "xim:tss2-mu"},
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "4.1.3" },
            ["4.1.3"] = {
                x86_64 = {
                    url = "https://deb.debian.org/debian/pool/main/t/tpm2-tss/libtss2-sys1t64_4.1.3-7_amd64.deb",
                    sha256 = "cc7134ebf00e0c2552a4cbcb8cacfef40d9e076624927895bf9ad023e2b73fe1",
                },
                aarch64 = {
                    url = "https://deb.debian.org/debian/pool/main/t/tpm2-tss/libtss2-sys1t64_4.1.3-7_arm64.deb",
                    sha256 = "3564bc3545cdba7db5ed391e7ba52b5f494676105154a0ec89e092277cf84098",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libtss2-sys.so.1"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

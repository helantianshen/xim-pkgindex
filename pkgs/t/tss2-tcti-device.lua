-- Debian 固定构建的独立 TPM 运行库，安装时仅提取库和许可文件
package = {
    spec = "2",
    name = "tss2-tcti-device",
    description = "tss2-tcti-device runtime libraries for desktop applications",
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
                    url = "https://deb.debian.org/debian/pool/main/t/tpm2-tss/libtss2-tcti-device0t64_4.1.3-7_amd64.deb",
                    sha256 = "24861e35389617f8a8eb685cba8b5fdfc6ac769301cfbdef245287b7f129763a",
                },
                aarch64 = {
                    url = "https://deb.debian.org/debian/pool/main/t/tpm2-tss/libtss2-tcti-device0t64_4.1.3-7_arm64.deb",
                    sha256 = "d7a41070ae4b84c66695d08886c356fcba67bd32898e3fd8e06c6854f0803897",
                },
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.pkgindex.runtime_archive")

function install()
    return runtime_archive.install({"lib/libtss2-tcti-device.so.0"})
end

function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

package = {
    spec = "2",

    homepage = "https://gnupg.org/software/libgcrypt/",
    name = "libgcrypt",
    description = "The GnuPG general-purpose cryptographic library (libgcrypt)",

    licenses = {"LGPL-2.1-or-later"},
    repo = "https://dev.gnupg.org/source/libgcrypt.git",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"security", "lib"},
    keywords = {"gnupg", "gcrypt", "crypto", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- DT_NEEDED outside the payload (readelf -d): libgpg-error.
            deps = { "xim:glibc", "xim:libgpg-error" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.12.2" },
            ["1.12.2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libgcrypt/releases/download/1.12.2/libgcrypt-1.12.2-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libgcrypt/releases/download/1.12.2/libgcrypt-1.12.2-linux-x86_64.tar.gz",
                    },
                    sha256 = "220b2692cc7edadcc732af6c963f384f47b386142eae42e3fec7c3c0ea3f814a",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libgcrypt/releases/download/1.12.2/libgcrypt-1.12.2-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libgcrypt/releases/download/1.12.2/libgcrypt-1.12.2-linux-aarch64.tar.gz",
                    },
                    sha256 = "5ec1beaaf31747fdce89020d6a6606bfd12ec1b5cc526e5ffc8dfc338088bc7e",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     libgcrypt-lib-1.12.2-h7cc23a3_2.conda
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: only the .pc files carried one; rewritten to prefix=/usr.
--
-- Runtime library only: conda-forge's libgcrypt-lib split carries no headers.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(package.name .. "-" .. pkginfo.version(), dir)
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return os.isfile(dir .. "/lib/libgcrypt.so.20")
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name, { type = "group" })
    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers_tree(dir, "include", "usr/include", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

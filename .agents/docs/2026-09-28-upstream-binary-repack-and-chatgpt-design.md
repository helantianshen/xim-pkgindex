# 第三方二进制（conda-forge / Debian）重打包规范化 + ChatGPT 桌面栈落地方案

**日期**: 2026-09-28
**状态**: 已在 PR #889 实现，待 review
**起点**: PR #889（`feat(chatgpt)`，原 head `a7641af`）的 review
**范围**: `libs/runtime_archive.lua` 的去留与命名；conda-forge / Debian 来源 payload 的统一生产流程；
PR #889 中运行库 provider、qt5、pango、chatgpt 的最终形态。

---

## 0. 结论

| 问题 | 结论 |
|---|---|
| `runtime_archive.lua` 与 conda 强相关吗？ | **一半是。** 85 行里做了三件事：①解开容器格式（`.conda` / `.tar.bz2` / `.deb`），②整理目录布局（deb 的 `usr/lib/<triplet>` → `lib`），③按 conda 的 `info/paths.json` 把 build-prefix placeholder 改成安装目录。只有③真正依赖 conda；①②是“外来包格式”的通用问题，deb 分支与 conda 无关。 |
| 很多地方要用吗？ | **要用，而且已经在用，只是之前没有统一实现。** main 上已有 15 个 recipe 来自 conda-forge 重打包（krb5、keyutils、zstd、xz、icu、libedit、libmd、xcb-util 系列、mesa-lavapipe、pocl、shaderc），本 PR 再加 14 个 payload。安装期改写 placeholder 的先例是 `pocl.lua`，它在 recipe 里写了一份等价算法。生产那 15 个 payload 的工具以前从未提交进仓库。 |
| 命名是否见名知意？ | **不是。** `runtime` 在生态里已经有 `exports.runtime`、`_RUNTIME`、runtime revision gate 三个含义；`archive` 描述的是容器，不是职责。按职责拆开后：安装期部分 → **`libs/relocate.lua`**，离线部分 → **`.agents/tools/repack/repack.py`**。 |
| 最终方案 | 外来格式一律离线处理：`repack.py` 生成标准 payload（附 `PROVENANCE.md`，必要时附 `RELOCATE.json`），经 `graphics/publish.sh` 发布到 xlings-res GLOBAL+CN 并逐字节校验；recipe 只消费标准 tarball。**recipe 本身和它的简短注释就是这个包的 spec**，不另建每包的 spec 文件；只有通用基础设施（repack 工具、relocate 库）才有独立的说明。安装期只剩一件事：`relocate.apply()` 按 payload 自带的清单改写 placeholder。`runtime_archive.lua` 删除。 |

---

## 1. 现状盘点

### 1.1 conda-forge 来源的既有 recipe（main）

| 形态 | recipe |
|---|---|
| 重打包 → xlings-res，库模板（`seal` + `declare_*`） | krb5、keyutils、zstd、xz、icu、libedit、libmd、xcb-util、xcb-util-image、xcb-util-keysyms、xcb-util-renderutil、xcb-util-wm、xcb-util-cursor |
| 重打包 → xlings-res，整个闭包私有、不声明 deps | mesa-lavapipe、pocl（shaderc 也用到 conda 产物） |

共同约定（见 recipe 注释和 #762 的提交说明）：tarball 顶层是 `<name>-<version>/`；`PROVENANCE.md` 逐项记录来源；`.pc` 离线改写成 `prefix=/usr`；每个包在注释里写 PLACEHOLDER AUDIT。

### 1.2 安装期 placeholder 改写的先例

`pkgs/p/pocl.lua` 的 `_rewrite_prefix_in_binary` 加上一张 `CONDA_PLACEHOLDERS` 表。`libs/relocate.lua` 实现了同一个算法（补 NUL、保持文件长度），并且把 placeholder 从 recipe 常量挪进 payload 的清单。pocl 以后可以迁过来（§9）。

### 1.3 自动 elfpatch 的实际行为（决定 provider 模板）

依据 libxpkg `elfpatch.lua` 的 `_apply` 与 `closure_lib_paths`：

- **触发**：runtime deps 里恰好有一个包导出 `exports.runtime.loader`（实践中就是 `xim:glibc`）。
- **RUNPATH** = 自身 `exports.runtime.libdirs`（没有就用 `lib64`/`lib`）+ 每个 runtime dep 的 libdirs + subos `lib` 兜底。
- 所以 pango 加上 `xim:glibc` 后才会被 patch；chatgpt 自身的 `exports.runtime.libdirs`（libvips 目录）会排在它每个 ELF 的 RUNPATH 最前面，是生效的。
- **build deps 不在 `resolved_deps` 里**（xlings `installer.cpp` 只为 `node.runtime_deps` 填写），所以 `pkginfo.dep_install_dir("xim:7zip")` 要求 7zip 留在 runtime deps。7zip 的 payload 没有 `lib`/`lib64`，不会往 RUNPATH 里加东西；closure check 的 “declares '7zip' but nothing … provides” 只是一条提示，qt.lua 也是这样。

---

## 2. 设计决策

- **D1 来源**：开源库 payload 一律发布到 xlings-res GLOBAL+CN。recipe 不直接指向 conda.anaconda.org / deb.debian.org。
- **D2 外来格式离线处理**：解包、目录整理、取舍、许可证收集都在 `repack.py` 里完成；hook 里不再出现 conda/deb。
- **D3 recipe 即 spec**：来源 artefact、placeholder 结论、刻意不打包的内容写在 recipe 头注释里；可复现的完整命令在 payload 的 `PROVENANCE.md` 里（xlings-res 仓库 README 也有一份）。不另建每包 spec 文件。
- **D4 placeholder 四类**，由工具审计，未分类的一律报失败（exit 1）：

  | 类 | 例子 | 处理 |
  |---|---|---|
  | pkg-config | `*.pc` | 自动：`prefix=/usr`，其余 `${prefix}`；安装期 `relocate_pkgconfig` 收尾 |
  | payload 内部数据 `--relocate` | gtk3 模块目录与 locale | 留在原处，写入 `RELOCATE.json`，安装期 `relocate.apply()` |
  | 宿主拥有 `--host` | libcups 的 `/etc/cups` 和 cupsd socket，libudev 的 hwdb，libgpg-error 的 `/etc` | 离线按 FHS 映射改写：`<ph>/etc → /etc`，`<ph>/var → /var`，`<ph>/… → /usr/…`（二进制补 NUL） |
  | 无害 `--inert` | （本批没有） | 保留，在 recipe 里写原因 |

  conda-build（`_h_env_placehold`）和 rattler-build（`host_env_placehold`）两种填充格式都能识别。
- **D5 库模板统一**（§4.3）：`os.mv` → `relocate.apply`（仅 gtk3）→ `selfcontain.seal` → `relocate_pkgconfig`；`config()` 声明 libs / headers / pkgconfig。
- **D6 payload 不可变**：改写 payload 的动作（编译 GSettings schema）放在 `install()`。
- **D7 env 不写死路径**：消费方只依赖 `${XLINGS_DYNAMIC_SUBOS_DIR}` 形式的 env（`graphics.consumer_envs()`）。
- **D8 架构**：provider 同时发布 x86_64 和 aarch64 payload（照 krb5/zstd 的先例）；终端应用 chatgpt 只声明整条闭包都已具备的架构（Linux x86_64 + macOS arm64）。

---

## 3. 流水线

```
upstream artefact（conda-forge；Debian 一律用 snapshot.debian.org 的永久 URL）
   ▼
.agents/tools/repack/repack.py --name --version --arch --src URL#SHA256 … [--relocate/--host/--inert/--keep/--drop/--require]
   ├─ 下载、校验 sha256（缓存在 ~/.cache/xlings-repack）
   ├─ 解包；deb: usr/lib/<triplet> → lib，usr/share → share，copyright → licenses/
   ├─ 默认不打包：bin/ sbin/ libexec/、.a/.la、cmake/GIR/aclocal/gettext、man/doc/info、conda 元数据
   ├─ placeholder 审计（D4）
   ├─ PROVENANCE.md（来源表、规范化命令、审计结论）、RELOCATE.json
   └─ 确定性 tarball（--sort=name --mtime=@0 gzip -n）+ .sha256；同一输入两次运行 sha256 相同
   ▼
.agents/tools/graphics/publish.sh dist/   （本次泛化：任意 -linux-<arch>，连同 .sha256 sidecar）
   ├─ github.com/xlings-res/<name>（GLOBAL）+ gitcode.com/xlings-res/<name>（CN，gtc）
   └─ 两边下载回来与本地逐字节比对，输出 RECIPE-DATA.txt（url + sha256）
   ▼
pkgs/<x>/<name>.lua（§4.3 模板）
```

---

## 4. 组件

### 4.1 `.agents/tools/repack/repack.py`

用法与各类 placeholder 的处理见 `.agents/tools/repack/README.md`。退出码遵循 `.agents/tools/README.md`：0 已产出；1 输入有问题（sha256 不符、未分类 placeholder、多个来源冲突、缺 `--require`）；3 无法运行（缺工具、下载失败）。ELF 不在这里修改，RUNPATH 由安装期 `selfcontain.seal` 按解析结果写入。

### 4.2 `libs/relocate.lua`

```lua
import("xim.pkgindex.relocate")
relocate.apply(pkginfo.install_dir())                    -- 读 <dir>/RELOCATE.json
relocate.rewrite(data, placeholder, new_prefix, binary)  -- 纯函数
```

清单格式：`{ "schema": 1, "entries": [ { "path", "mode": "binary"|"text", "placeholder" } ] }`。每条记录自带 placeholder，因为一个 payload 可能合并了多个 build。以下情况都 fail closed：清单缺失、路径越界、文件缺失、记录的 placeholder 在文件里一次都找不到、二进制文件长度变化、安装路径比 placeholder 长。测试见 `tests/test_relocate.py` + `tests/lua/relocate_harness.lua`。

### 4.3 provider 模板

```lua
function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(package.name .. "-" .. pkginfo.version(), dir)
    relocate.apply(dir)                  -- 只有 payload 带 RELOCATE.json 时（gtk3）
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return os.isfile(dir .. "/lib/<main soname>")
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
```

`deps` 上方用一行注释写明 payload 的外部 DT_NEEDED（readelf -d 实测）。所有声明函数在目录不存在时都是 no-op，所以只有运行库的 payload（tpm2-tss、libnotify、libudev、libgcrypt）也能用同一模板。

---

## 5. 逐包落地（本 PR）

| 包 | 来源 | 版本 | placeholder | 备注 |
|---|---|---|---|---|
| gtk3 | conda-forge | 3.24.43（沿用 PR 选定；conda 最新是 3.24.52） | relocate ×13 | schema 在 install 编译，声明到 `<subos>/share/glib-2.0/schemas`；`xim:glib@>=2.88`（需要 `bin/glib-compile-schemas`） |
| atk / at-spi2-core / at-spi2-atk | conda-forge | 2.38.0 / 2.40.3 / 2.38.0 | pc | at-spi2-core 不打包总线启动器及其 D-Bus service 文件，a11y 总线由桌面会话提供 |
| nss / nspr | conda-forge | 3.118 / 4.40 | pc | NSS 按名字 dlopen 模块，靠 `declare_libs` 放进 subos 库视图 |
| libcups | conda-forge | 2.3.3 | host | 读宿主 `/etc/cups`，连接宿主 cupsd；`lib/cups/` 下的服务端 helper 不打包 |
| libcap / libusb / libXcomposite | conda-forge | 2.71 / 1.0.29 / 0.4.6 | pc | |
| **libudev**（原 libudev1） | conda-forge libudev1 | 257.4 | host | 包名按库名；hwdb 指向宿主 |
| **tpm2-tss**（原 tss2-* ×4） | Debian 13 `4.1.3-1.2`，snapshot | 4.1.3 | 无 | 4 个 deb 合并成一个 payload；原 PR 用的 sid `4.1.3-7` 在 pool 里不是永久地址 |
| **libsecret**（新） | conda-forge | 0.21.7 | pc | Chromium 用 dlopen 访问系统密钥环 |
| **libgcrypt**（新） | conda-forge libgcrypt-lib | 1.12.2 | pc | libsecret 的依赖；只有运行库 |
| **libgpg-error**（新） | conda-forge | 1.61 | host | rattler-build 格式的 placeholder |
| **libnotify**（新） | Debian 13 `0.8.6-1`，snapshot | 0.8.6 | 无 | Electron 用 dlopen 加载 |
| qt5 | 官方 Qt 仓库（qtsdk，四个镜像，CN 可用） | 5.15.2 | — | 不变，仅 x86_64 |
| pango | 现有 xlings-res | 1.52.1 | — | 见 §7 |

---

## 6. chatgpt

1. **资源**：官方 URL 加逐架构 sha256，不变。是否镜像 CN 由维护者决定（§10）。
2. **架构**：删除 Linux aarch64 版本条目；macOS arm64 保留。
3. **deps**：按用途分组并加注释；`libudev1` → `libudev`，`tss2-*` → `tpm2-tss`；新增 `libsecret`、`libnotify`；7zip 留在 runtime deps（§1.3）。
4. **exports**：`app` + x64 的 sharp-libvips 目录（去掉用不到的 arm64 目录）。
5. **envs**：去掉 `GSETTINGS_SCHEMA_DIR`；schema 通过 `XDG_DATA_DIRS=<subos>/share` 找到。
6. **解包**：`7zz e -so -tAr … | 7zz x -si -txz -so | 7zz x -si -ttar …` 一条管道完成，1.5 GiB 的 `data.tar` 不再落盘。
7. **AppArmor**：官方 postinst 装的 profile（已从 deb 中取出确认）是 `profile chatgpt "/usr/lib/chatgpt/ChatGPT" flags=(unconfined) { userns, }`，按路径绑定。`install()` 为当前版本生成同样内容、路径指向本版本的 `share/apparmor/xlings-chatgpt`；`config()` 在 `/proc/sys/kernel/apparmor_restrict_unprivileged_userns` 为 1 时，用 `log.warn` 给出一行以 root 执行的加载命令。xlings 自己不做 root 操作，也不用 `--no-sandbox`。
8. **宿主边界**：`xdg-open`、a11y 总线、密钥环 / 通知守护进程、cupsd 由宿主桌面提供（写进 `.agents/docs/chatgpt.md`）。

---

## 7. pango

加 `xim:glibc` 之后，自动 elfpatch 才会对 pango 生效，payload 的 ELF 会被改写，这就是“安装出来的文件变了”，所以 `revision = 1` 符合 spec。deps 和 revision 旁边补了注释说明原因。后续 issue（不在本 PR）：`libXxf86vm`、`libxshmfence` 同样导出了 libdirs 却没有 `xim:glibc` 依赖；还要审计既不导出 libdirs、也不依赖 glibc 的库包。

---

## 8. 验证

见 PR 描述中的记录：repack 两次运行 sha256 一致；GLOBAL/CN 逐字节比对；`tests/test_relocate.py` 与各 provider 的 static/index 测试；隔离 `XLINGS_HOME` 中安装 chatgpt 完整闭包；dep-closure-check；用 xlings loader `--list` 检查 ChatGPT 主程序及原生模块，确认没有回退到宿主库；以及 CI。

---

## 9. 与 PR 拆分建议的关系

按维护者的决定，本方案全部落在 PR #889 里，不再拆成 6 个 PR。后续单独处理的有：pocl 迁移到 `relocate.apply`（需要 revision + 1 并重新发布 payload）、`graphics/repack-upstream-deb.sh` 并入 repack、§7 的审计。

---

## 10. 待决问题

1. ChatGPT 这类专有许可的官方安装包，要不要像 claude 那样镜像到 xlings-res CN？（本 PR 未镜像）
2. 同一个目录只能有一个 `gschemas.compiled`：以后出现第二个 GSettings schema 提供者时，需要在 subos 层统一编译。
3. `graphics.consumer_envs()` 在用户没有设置 `XDG_DATA_DIRS` 时，只会给出 `<subos>/share`，不包含宿主的 `/usr/share`（图标、主题、mime）。这是先前就有的行为，对所有 graphics 消费方都一样，建议单独开 issue。

---

## 11. 对首版 review（`pr-889-review.md`）的修正

- **P1-3 降级**：provider 都依赖 `xim:glibc`，自动 elfpatch 会把 deps 的 libdirs 写进 RUNPATH，跨 payload 解析本来就有保障。现在统一调用 `seal` 是为了和其余 recipe 一致。
- **P1-5 撤回**：`closure_lib_paths` 会把包自身的 `exports.runtime.libdirs` 放在 RUNPATH 最前面，chatgpt 的那几行是生效的。

# ChatGPT 桌面版

该包使用 OpenAI 官方固定版本资源，由 xlings 保存独立程序目录并切换启动入口。
提供 Linux x86_64 和 macOS ARM64；不提供 Windows、macOS Intel。
官方也有 Linux ARM64 deb，但 `glibc`、`gcc-runtime` 等基础包还没有 ARM64 payload，
所以配方暂不声明 Linux ARM64，等基础资源到位后再加。包状态为 `dev`。

当前收录 `26.924.22138` 和 `26.917.71314`，`latest` 指向前者。

## 使用

```sh
xlings install chatgpt@26.924.22138 --yes
xlings use chatgpt 26.924.22138
xlings list
chatgpt
```

其他索引的本地测试包需要使用搜索结果中的命名空间，例如 `local:chatgpt`。
切换前完全退出应用；运行中的实例不会随 xvm 切换，也可能接收后续启动的请求。
已安装版本通过 `xlings list` 查询；应用参数直接传给官方程序，不拦截或改写。

## 安装边界

- Linux 提取官方 deb 中的完整 `usr/lib/chatgpt`，不调用 dpkg、apt、dnf 或 pacman，不执行包内安装脚本，不配置系统软件源
- deb 是程序内容的分发容器；用户态运行库通过 xlings 的 deps 提供，不要求宿主安装 Debian 包管理器
- deb 的 ar、xz、tar 三层均由声明的 xlings `7zip` 依赖解包
- macOS 使用官方 appcast 中的完整 ZIP，保留 `.app` 结构并在安装时检查版本和代码签名；不修改签名、不清除隔离属性、不覆盖 `/Applications`
- 通过 xvm 将 `chatgpt` 直接注册为 `ChatGPT` 二进制的别名；本包不修改全局 PATH、默认浏览器、URL 协议处理器或系统桌面入口
- 卸载删除该版本程序和 xvm 注册；不删除账号、配置、项目或会话数据

## Linux 发行版

官方预览版列出的环境为 Ubuntu 24.04/26.04、Debian 13、Fedora 43/44 和当前 Arch。
CachyOS 等 Arch 衍生发行版单独记录验证结果，不能视为官方支持承诺。
Alpine/musl 不在支持范围内。

Linux 运行库需要通过包的 `deps` 声明，由 xlings 安装和提供。
不提供要求用户自行补装发行版库的 `--check-deps` 命令。
配方声明 glibc、GCC、GTK 3、NSS/NSPR、AT-SPI、CUPS、ALSA、X11、Mesa、Qt 5/6、USB、TPM，
以及 Chromium 通过 dlopen 使用的 libsecret（系统密钥环存凭据，缺失时退化为明文存储）和 libnotify。
新增的运行库 payload 由 `.agents/tools/repack/repack.py` 从 conda-forge / Debian（snapshot.debian.org）
的固定构建重打包，发布到 xlings-res 的 GitHub 与 GitCode 两个镜像；安装期不解析 conda 或 deb 格式。
需要跟随安装目录的构建前缀（gtk3 的模块目录）记录在 payload 的 `RELOCATE.json`，
安装时由 `libs/relocate.lua` 改写；属于宿主的路径（CUPS 的 `/etc/cups` 和 socket、udev hwdb）
在重打包时就映射到宿主路径。
Qt 5 采用官方 Qt 5.15.2 qtbase 和配套 ICU 56，复用现有 qtsdk 下载与校验；不包含 Qt Quick 或 ODBC/PostgreSQL 驱动。
原生模块使用的内置 libvips 仍来自 ChatGPT 自身资源：它的目录写在 `exports.runtime.libdirs`，
elfpatch 会把它放在包内每个 ELF 的 RUNPATH 最前面。
gtk3 在安装时把 GSettings schema 编译进 payload，再声明到 `<subos>/share/glib-2.0/schemas`；
`graphics.consumer_envs()` 给出的 `XDG_DATA_DIRS` 已包含 `<subos>/share`，因此不再设置 `GSETTINGS_SCHEMA_DIR`。
Pango 补充 glibc 依赖以启用 elfpatch，并提高配方 revision。

新增运行库都同时发布了 x86_64 和 ARM64 payload；Linux ARM64 仍缺 glibc 加载器、GCC 及部分图形基础库，
Qt 5 当前只有已验证的 x86_64 官方 SDK。
不能把资源存在、安装成功或静态检查通过当作桌面运行验收。
内核、显示服务、设备驱动和桌面会话仍属于宿主边界，不通过关闭 sandbox 绕过安全策略。

## Chromium 沙箱与 AppArmor

官方 deb 的 postinst 会安装 `/etc/apparmor.d/chatgpt`，允许 `/usr/lib/chatgpt/ChatGPT`
创建用户命名空间，Chromium 沙箱需要这个权限。该 profile 按路径绑定，覆盖不到 xlings 的安装目录。
安装时会为当前版本生成同样内容、路径指向本版本的 profile：
`<版本目录>/share/apparmor/xlings-chatgpt`。在限制非特权用户命名空间的宿主上
（`cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns` 输出 1，Ubuntu 23.10 起默认如此），
需要由用户以 root 加载一次：

```sh
# 以 root 执行；v 为已安装版本，路径按实际 XLINGS_HOME 调整
v=26.924.22138
install -m 0644 ~/.xlings/data/xpkgs/xim-x-chatgpt/$v/share/apparmor/xlings-chatgpt /etc/apparmor.d/xlings-chatgpt-$v
apparmor_parser -r /etc/apparmor.d/xlings-chatgpt-$v
```

xlings 不执行任何 root 操作，也不使用 `--no-sandbox`。安装钩子的输出在成功时不会显示给用户，
所以这一步只能写在文档里，不能靠安装时提示。

## 宿主边界

打开链接用的 `xdg-open`（官方依赖 `xdg-utils`）、桌面会话的无障碍总线、密钥环守护进程、
通知守护进程和 cupsd 都由宿主桌面提供；本包只提供它们的客户端库。

## 更新和版本数据

xvm 为该应用进程设置 `CODEX_SPARKLE_ENABLED=false`，关闭所收录版本的内置更新器。
此开关来自已检查的应用实现，不是稳定公开 API；每次收录新版本都必须重新确认其语义。
直接启动内部二进制或双击 `.app` 会绕过 xvm，因此不受该开关约束。
安装时校验资源 SHA256 和包内版本；不添加逐次启动时的宿主元数据解析。

多个程序版本默认继续使用应用自己的数据位置；程序隔离不等于账号和数据隔离。
本包不迁移或回滚用户数据，旧版本读取新版本写入的数据仍可能不兼容。
旧版能否继续连接 OpenAI 服务也不由 xlings 保证。

## 资源维护

- Linux 固定 URL 来自官方 Debian 仓库，逐架构校验 SHA256
- macOS 固定 URL 来自官方 appcast，完整下载后计算 SHA256，并保留官方签名
- `latest` 仅引用明确版本，不能把持续变化的下载链接绑定到固定版本
- 不自动复制到第三方镜像；官方资源使用专有许可
- 不启用当前面向 GitHub Releases 的自动升级扫描

## 验证记录

首轮实测覆盖隔离 `XLINGS_HOME` 中的 CachyOS x86_64 两版本安装、切换和卸载。
首轮 CI 覆盖 Linux x86_64、macOS ARM64 的 latest 安装和卸载。
改为 xvm 直接启动后的验证以对应提交的 CI 和测试结果为准。
本轮在隔离 home 实装新增依赖，使用 xlings 加载器检查主程序、Qt shim 和当前架构的 glibc 原生模块。
`pytest tests/c/test_chatgpt.py -m verify` 可复验已安装版本的库解析；检查禁止宿主库兜底，跳过归档内不属于当前 glibc 平台的预构建模块。
GUI 登录、Linux ARM64 运行和跨发行版桌面兼容性仍未完成验收。

## 官方资料

- [Linux 安装说明](https://learn.chatgpt.com/docs/linux/linux-app)
- [macOS 更新清单](https://persistent.oaistatic.com/codex-app-prod/appcast.xml)
- [应用更新策略](https://learn.chatgpt.com/docs/enterprise/manage-app-updates)

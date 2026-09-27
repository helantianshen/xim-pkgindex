# ChatGPT 桌面版

该包使用 OpenAI 官方固定版本资源，由 xlings 保存独立程序目录并切换启动入口。
支持 Linux x86_64、ARM64 和 macOS ARM64；不提供 Windows 或 macOS Intel 资源。
包状态为 `dev`，平台声明表示有对应资源，不代表所有桌面环境已完成验收。

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
- deb 是程序内容的分发容器；是否能运行取决于宿主 glibc、桌面库和安全策略，而不是宿主是否使用 dpkg
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
当前配方仅声明了解包依赖 `xim:7zip`，运行库闭环尚未完成，PR 保持 Draft。
不能把资源存在、安装成功或静态检查通过当作桌面运行验收。
内核、显示服务、设备驱动和桌面会话仍属于宿主边界，不通过关闭 sandbox 绕过安全策略。

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
GUI 启动、登录、Linux ARM64 运行和跨发行版桌面兼容性仍未完成验收。

## 官方资料

- [Linux 安装说明](https://learn.chatgpt.com/docs/linux/linux-app)
- [macOS 更新清单](https://persistent.oaistatic.com/codex-app-prod/appcast.xml)
- [应用更新策略](https://learn.chatgpt.com/docs/enterprise/manage-app-updates)

# reverse-skill-nix

为 [reverse-skill](https://github.com/zhaoxuya520/reverse-skill) 准备的配套 Nix 工具环境，目标平台为 **x86_64-linux / NixOS**。

`reverse-skill` 提供逆向工程、安全分析等任务的技能说明、路由和工作流；本项目负责为这些技能准备实际调用的软件、运行库和启动入口，并通过 Nix 固定工具版本与依赖。技能内容通过 `reverse-skill/` Git 子模块引用，工具清单在 `nix/tools.nix` 中维护。

本项目重点解决 NixOS 上工具安装、动态库、Java/Python 运行时和桌面集成问题。进入对应开发环境后，再按 `reverse-skill/README_AI.md` 使用技能；加载环境本身不会自动激活技能、注册 MCP 或运行分析任务。

## 使用

克隆时一并获取技能子模块：

```bash
git clone --recurse-submodules https://github.com/dahai9/reverse-skill-nix.git
cd reverse-skill-nix
nix develop
```

已有本地仓库时，在项目根目录执行：

```bash
git submodule update --init --recursive
nix develop
```

首次使用需要联网下载 nixpkgs 和工具，依赖版本由 `flake.lock` 锁定。完整环境含 JEB、Ghidra、浏览器、Android SDK、angr、SecLists，首次下载和磁盘占用较大。

也可以加载单个分组，每组都包含 core：

| 命令 | 工具 |
|---|---|
| `nix develop .#core` | JDK、Node/npm/npx、pnpm、Python 3.12、uv、Go、Rust、通用命令 |
| `nix develop .#android` | JEB、jadx、apktool、adb、apksigner、zipalign、Frida、Objection |
| `nix develop .#binary` | IDA Pro、radare2/rabin2/radiff2、Ghidra、GDB、编译与 ELF 工具、Capstone/Unicorn/LIEF |
| `nix develop .#web` | agent-browser、Playwright 和浏览器、mitmproxy、BurpSuite、Wireshark/tshark、tcpdump、Docker 客户端 |
| `nix develop .#pentest` | nmap、nuclei、sqlmap、ffuf、hashcat、SecLists |
| `nix develop .#analysis` | binwalk、YARA、bkcrack、pwntools、angr |
| `nix develop .#reports` | Graphviz、PlantUML、Mermaid CLI、Pandoc、Python 文档处理库 |
| `nix develop` 或 `nix develop .#full` | 上述全部工具 |

单次执行：

```bash
nix develop .#android -c jadx --version
nix develop .#analysis -c python3 -c 'import pwn, angr, yara'
nix develop .#web -c python3 -m playwright --version
```

退出 shell 即退出环境。环境不会自动启动 Docker、代理、MCP 服务或修改 AI 客户端配置。Docker 客户端需要宿主机已有可用 daemon；抓包、USB 设备和 GPU 使用宿主机的权限与驱动配置。

## 环境约定

- Android SDK 固定使用 Build Tools 35.0.0，包含 adb、apksigner 和 zipalign，不下载模拟器、系统镜像或 NDK。`ANDROID_HOME`、`ANDROID_SDK_ROOT` 和 Build Tools PATH 自动设置。
- 配置允许非自由软件并接受 Android SDK 许可证，使用前应确认符合自己的许可要求。
- Python 统一使用 3.12 和 Nix 打包的依赖。额外 Python 项目可用 `uv venv` 创建独立环境；不向 Nix 的只读 Python 环境执行全局 pip 安装。
- Playwright 使用 Nix 提供的浏览器，agent-browser 使用 Nix Chromium。额外安装的 npm Playwright 若版本不同，不能保证共用这些浏览器。
- `REVERSE_SKILL_ROOT` 基于项目根目录设置，请在根目录进入环境。
- IDA Pro 9.4 已作为项目包加入二进制和完整环境，其 IDAPython 固定使用 Python 3.12。

## 需要单独接入的能力

以下能力不属于这个 flake 的自动安装范围：

| 能力 | 接入方式 |
|---|---|
| Binary Ninja | 自备授权与安装包；本环境不捆绑 |
| Ghidra/Burp MCP | 按需安装对应插件并配置客户端；主程序可用不代表 MCP 已连接 |
| jshookmcp、Reqable MCP | 本环境提供 Node/npx；按实际使用的客户端单独注册，Reqable 桌面程序另装 |
| anything-analyzer、OpenReverse、ProxyCat、PentestSwarm | 独立项目，按需固定版本、安装并配置；本环境提供 Node/pnpm、Python/uv、Go、Docker 客户端 |
| xquik-mcp | 远程服务，单独注册并完成 OAuth |
| PowerShell | 主要使用仓库的 Linux/Bash 入口；不为 Windows 专用脚本安装兼容环境 |

`reverse-skill` 自带 Linux bootstrap 使用 apt，不适用于本项目；新增工具应修改 Nix 清单。没有自动运行该仓库的初始化、扫描或安装脚本。

## Codex MCP：APK 与原生库分析

提供两个固定版本的社区连接：`mrexodia/ida-pro-mcp`（commit `f82e6e2`）和 `zinja-coder/jadx-mcp-server`（commit `a8e5b7d`），JADX GUI 插件固定为 6.5.0。源码和插件下载均校验哈希。此外注册 JEB 5.38 自带的官方 HTTP MCP，不安装第三方 JEB 桥接插件。

JADX 使用官方 1.5.6 JVM 发行包，由 `nix/jadx.nix` 提供 Java 17 启动器，避开 nixpkgs 包附带的可选 Quark 依赖链；不捆绑 Quark 插件能力。可用 `nix run .#jadx` 打开 GUI。

JADX 插件构建时将 Javalin 的监听调用改为 `127.0.0.1`，避免其默认监听所有网卡。修改仅涉及监听地址，若上游调用结构变化，构建会失败而不会静默跳过补丁。

```bash
nix build .#ida-pro-mcp .#jadx-mcp
nix run .#install-reverse-mcp
codex mcp list
```

安装命令会向 `${IDAUSR:-$HOME/.idapro}/plugins/` 放置 IDA 插件链接，通过 JADX 插件管理器安装 JAR，并使用 `codex mcp add` 在 `${CODEX_HOME:-$HOME/.codex}/config.toml` 注册 `idapro`、`jadx` 和 `jeb`。已有不同的同名 IDA 插件及 Codex 配置先备份；这一步需要用户目录写权限和可用的 `codex` 命令。进入开发环境不会自动执行安装。

- **JADX**：`nix develop .#android -c jadx-gui`，打开 APK 并确认 AI MCP 插件已启动。Codex 的 stdio 桥连接本机 `127.0.0.1:8650`，可以读取类、方法、Manifest、交叉引用和执行重命名。
- **IDA**：重启 IDA 并打开要分析的原生库；插件默认提供本机 `127.0.0.1:13337` 服务，必要时在 `Edit → Plugins → MCP` 启动。Codex 通过 stdio 代理自动发现 IDA 实例。本封装只提供 GUI 插件与代理，不安装额外的 idalib Python SDK 或启动后台 supervisor。
- **JEB**：运行 `nix run .#jeb`，在 GUI 中启动内置 MCP 或使用 VIBRE 助手入口。默认地址是 `http://localhost:8425/mcp`，仅注册地址不会代为启动服务。5.38 随包文档和 JAR 已包含此功能；[官方 MCP 文档](https://www.pnfsoftware.com/jeb/manual/mcp/) 的较新版本工具列表不代表 5.38 全部支持。
- 安装后新开 Codex 会话加载工具。注册成功只说明配置已写入，实际分析仍要求对应 GUI 打开样本并启动插件。
- adb、Frida 和 apktool 保持 CLI 使用；未安装 Ghidra、Burp 或设备控制类第三方 MCP。

单独启动桥接程序可用 `nix run .#ida-pro-mcp -- --help` 和 `nix run .#jadx-mcp -- --help`。安装器在 `${XDG_DATA_HOME:-$HOME/.local/share}/reverse-tools/mcp/nix-roots/` 创建 GC roots，防止注册的 Nix store 路径被垃圾回收；更新包后重新运行安装命令以刷新路径。

## JEB

JEB 5.38.0.202603112011 已加入 Android 和完整环境。可以单独构建或运行：

```bash
nix build .#jeb
nix run .#jeb -- --version
nix run .#jeb
nix run .#jeb-cli -- -h
```

进入 `nix develop .#android` 后也可直接运行 `jeb`、`jeb-cli`。`jeb --version` 显示封装版本，不启动 Java 或验证许可证。

GUI 启动时自动注册 `${XDG_DATA_HOME:-$HOME/.local/share}/applications/JEB.desktop`，匹配窗口的 `JEB` 应用标识，让 Wayland dock 显示安装包内的 JEB 图标。已有非本项目生成的同名桌面入口会保留。也可在开发环境中执行 `jeb-install-desktop` 单独注册；桌面入口从固定的 Nix store 路径启动，无需桌面会话中有 `jeb` 命令。

安装包从 [GitHub Release](https://github.com/dahai9/reverse-tools-assets/releases/tag/jeb-5.38.0) 下载，SHA-256 固定在 `nix/jeb.nix`。JEB 独立使用 Java 17，GUI 所需的 Linux SWT jar、WebKitGTK 4.1 和动态库由封装提供。启动器设置 WebKit 的动态库搜索路径及 GIO 网络模块，同时提供支持 SVG 的 GdkPixbuf 加载器缓存、Adwaita/hicolor 图标主题和 MIME 数据目录，无需系统安装 Debian 的 WebKit 包。

首次启动会把安装目录复制到 `${XDG_DATA_HOME:-$HOME/.local/share}/reverse-tools/jeb/5.38.0.202603112011/`，用于保存配置和插件，额外占用一份解压后的磁盘空间。启动器直接调用 GUI 或控制台 Java 入口，不运行原脚本中的自动更新器；更新安装包应修改版本、URL 和哈希。

默认 JVM 最大堆内存为 8 GiB，可以通过 `JEB_JAVA_OPTS="-Xmx4G"` 覆盖。包内许可证标识为 `jeb-demo`、40 天试用，封装不修改许可证或授权检查；实际可用功能取决于有效授权。

## IDA Pro

`nix/ida-pro/` 复制自 `~/zaneyos/pkgs/ida-pro/` 的包定义与来源清单，项目运行和构建不依赖该外部目录，也不修改原系统安装。

```bash
nix build .#ida-pro
nix run .#ida
nix run .#idat -- <IDA命令行参数>
nix develop .#binary
```

进入二进制或完整环境后可以直接调用 `ida`、`idat`。安装包和附件沿用原定义中的固定 URL 与 SHA-256，复用 nixpkgs 的 Qt 依赖和 ELF 修补逻辑；启动器通过 `idapyswitch` 指定 Python 3.12。

默认保留原包 `withPatches = true` 的行为，加载 `linux_patched.zip` 中的库和许可证文件；`nix build .#ida-pro-unpatched` 可构建不覆盖这些库及许可证的版本。附件中的 `ida-keygen` 和 IDAPIN 源码也按原定义保留，构建、验证和启动过程中不会自动执行 `ida-keygen`。Lumina、HexVault 与许可证服务器未加入开发环境或自动启动。

## 维护与验证

```bash
nix flake check --no-build
nix build .#checks.x86_64-linux.jeb-browser --no-link
nix build .#checks.x86_64-linux.mcp-bridges --no-link
nix build .#checks.x86_64-linux.jadx-mcp-plugin --no-link
nix develop .#full -c bash -c 'java -version; python3 --version; node --version; jadx --version; frida --version; r2 -v'
nix fmt
```

更新依赖时执行 `nix flake update`，审阅 `flake.lock` 后重新验证。`--no-build` 仅验证求值；实际进入开发环境会下载或构建工具。

`jeb-browser` 回归测试在虚拟显示器中验证 GTK 主题图标解码和 SVG MIME 类型识别，再使用 JEB 自带的 SWT 创建 WebKit 浏览器并加载本地 HTML，不访问外网。仅测试进程关闭 WebKit 的嵌套沙箱，以兼容 Nix 构建沙箱；正常 `jeb` 启动器保留 WebKit 的默认沙箱设置。

`mcp-bridges` 检查 IDA stdio 代理的初始化，以及 JADX 桥接程序的初始化和工具列表。`jadx-mcp-plugin` 实际启动插件 HTTP 服务并验证回环监听和健康接口。此处对 FastMCP 及其存储依赖保留导入检查，以本项目的 stdio 集成检查替代可选云服务测试套件。这些检查不启动分析 GUI，也不代表设备连接、IDA/JEB 后端或实际 APK 分析已经验证。

`flake.lock` 已固定 nixpkgs 26.05。完整工具环境的实际下载与启动需要按各自使用场景验证。

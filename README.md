# Denuvo环境一键配置工具

一个基于 WPF 的 Windows 桌面工具，用来为现有 `VBS.cmd` 脚本提供更友好的图形界面。

这个程序会把原始脚本内嵌到 `.exe` 中，并通过图形界面触发脚本执行。点击 `关闭保护` 或 `还原改动` 后，程序会以管理员权限运行，并在需要时立即重启系统。

## 功能

- 提供中文 / 英文界面切换
- 图形化执行原始 `VBS.cmd` 脚本
- 支持一键关闭保护
- 支持一键还原改动
- 在界面中显示实时日志输出
- 构建为单文件 Windows 可执行程序

## 注意事项

- 本工具会修改系统安全相关设置
- 运行时可能关闭 `VBS`、`Memory Integrity`、`Credential Guard`、`System Guard`、`Windows Hello` 保护以及 `Windows Hypervisor`
- 运行后可能要求立即重启
- 请仅在你明确知道这些操作含义的前提下使用

## 运行环境

- Windows
- .NET 8 SDK
- 需要管理员权限

## 本地构建

在项目根目录执行：

```cmd
build-exe.cmd
```

构建完成后，输出文件位于：

```text
dist\Denuvo环境一键配置工具.exe
```

## 终端测试运行

如果你在 WSL / bash 下测试：

```bash
"./dist/Denuvo环境一键配置工具.exe"
```

如果你在 Windows `cmd` 下测试：

```cmd
dist\Denuvo环境一键配置工具.exe
```

## 项目结构

```text
.
├─ src/
│  ├─ VbsManager.cs
│  ├─ VbsManagerApp.csproj
│  └─ app.manifest
├─ VBS.cmd
├─ build-exe.cmd
├─ .gitignore
└─ README.md
```

## 说明

- `VBS.cmd` 是原始脚本逻辑
- `src/VbsManager.cs` 是图形界面主程序
- `src/VbsManagerApp.csproj` 是项目配置
- `build-exe.cmd` 用于一键发布单文件 `.exe`
- `dist/` 为构建输出目录，默认已被 `.gitignore` 忽略

## GitHub 提交建议

当前仓库已经配置了 `.gitignore`，不会提交这些不必要的文件：

- `dist/`
- `bin/`
- `obj/`
- `src/bin/`
- `src/obj/`
- IDE 本地配置文件
- 临时缓存和调试符号文件

如果你要分发编译后的程序，建议使用 GitHub Releases，而不是直接把 `dist/` 提交到仓库中。

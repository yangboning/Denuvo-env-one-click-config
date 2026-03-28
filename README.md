# 这份 VBS.cmd 本身看起来不像后门        但它明显是在为高风险内核级程序创造运行条件      真正更值得怀疑的，往往不是这个脚本，而是“打算在它运行后加载的那个驱动/程序”

# Denuvo环境一键配置工具（请先看注意事项）
一个基于 WPF 的 Windows 桌面工具，用来为现有 `VBS.cmd` 脚本提供更友好的图形界面。VBS.cmd来源于 https://fitgirl-repacks.site/。软件的功能也是来源于这个网站的技术：https://fitgirl-repacks.site/hypervisor-guide/

这个程序会把原始脚本内嵌到 `.exe` 中，并通过图形界面触发脚本执行。点击 `关闭保护` 或 `还原改动` 后，程序会以管理员权限运行，并在需要时立即重启系统。

## 功能

- 提供中文 / 英文界面切换
  <img width="1286" height="940" alt="image" src="https://github.com/user-attachments/assets/d0e9aabd-4f1f-4b31-8a6b-902fe7977a02" />
  
- 图形化执行原始 `VBS.cmd` 脚本
- 支持一键关闭保护，在单击关闭保护后会弹出确认按钮，点击是之后，系统会自动重启，点击否则取消没有任何动作。
  <img width="1285" height="942" alt="image" src="https://github.com/user-attachments/assets/c5aed36c-2ace-4564-a1c9-93827d3d6d20" />
  
  在点击关闭保护后的那次重启时，会出现这张图片：
  <img width="900" height="600" alt="image" src="https://github.com/user-attachments/assets/80153ebb-1e3b-43b6-ae36-de308da15af3" />
  <img width="818" height="478" alt="image" src="https://github.com/user-attachments/assets/0c706107-dc04-450e-9c9a-1ff2bb8eb916" />
  用户需要手动按键盘上的 7 ，来关闭驱动程序签名强制功能，然后正常登录就可以。

  Windows 11 中禁用驱动程序签名强制是临时的，每一次用户自己手动重启电脑也会恢复，可以参考这个帖子https://zhuanlan.zhihu.com/p/657203490

- 支持一键还原改动，单击还原改动后，用户同样收到确认弹窗，点击是之后，系统正常自动重启。
  
- 构建为单文件 Windows 可执行程序

## 注意事项

- 在使用本工具前，你的操作系统最好是win 10/ Win 11的专业版（这样可以最大程度地减少由于虚拟化引起的 bug），因为专业版的系统给用户对于系统底层策略的权限更高用户可以自己编辑一些权限和策略，而家庭版的系统相较于专业版就有很多限制。
- 请确保你的计算机支持 CPU 虚拟化，并且处于开启状态，计算机 CPU 虚拟化的开启状态可以在任务管理器里面查看，如图：
  <img width="1518" height="1073" alt="image" src="https://github.com/user-attachments/assets/8d59810c-cb90-46f2-a6b1-cb62638c97e4" />

- 本工具会修改系统安全相关设置
- 运行时可能关闭 `VBS`、`Memory Integrity`、`Credential Guard`、`System Guard`、`Windows Hello` 保护以及 `Windows Hypervisor`
- 运行后立即重启才能生效
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


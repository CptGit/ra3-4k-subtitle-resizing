# Red Alert 3：4K 字幕大小补丁

[简体中文](README.md) | [English](README.en.md)

将战场对白字幕的字号从14调整为7，改善4K分辨率下字幕过大、频繁换行的问题。适用于《红色警戒3》英文版1.12，已在3840×2160下测试。较低分辨率下的字幕也会随之缩小。

## 构建

需要Windows PowerShell和RA3 MOD SDK。SDK的`tools`目录应包含`BinaryAssetBuilder.exe`、`MakeBig.exe`及其依赖。

在命令提示符中运行，分别传入游戏根目录和SDK根目录：

```bat
build.cmd "X:\Games\Red Alert 3" "X:\Tools\RA3_MODSDK"
```

构建产物：

```text
build/
├─ SubtitlePreload_1.0.big
└─ RA3_english_1.12.SkuDef
```

编译日志和中间文件也保存在`build/`中。

## 安装

退出游戏，备份游戏根目录中的`RA3_english_1.12.SkuDef`，然后复制构建产物：

| 构建产物 | 安装位置 |
|---|---|
| `SubtitlePreload_1.0.big` | 游戏的`Data`目录 |
| `RA3_english_1.12.SkuDef` | 游戏根目录，替换同名文件 |

安装后按原来的方式启动1.12。

如果原SkuDef已经为其他补丁做过修改，请保留原文件，在加载`Core12.big`之前加入以下一行，而不是直接覆盖：

```text
add-big Data\SubtitlePreload_1.0.big
```

本项目提供英文版启动配置。其他语言版本请在对应的1.12 SkuDef中加入同一行，不要用英文配置覆盖。

卸载时恢复原SkuDef，或移除新增的加载行，再删除`Data\SubtitlePreload_1.0.big`。

## 源码结构

```text
src/
├─ SageXml/
│  └─ UI/
│     └─ SettingsCommon.xml
└─ RA3_english_1.12.SkuDef
build.cmd
build.ps1
tests.ps1
```

`SettingsCommon.xml`保留SDK中的完整内容，唯一修改是`UISubtitleDisplay`的字体大小：

```diff
- <Font Name="Lucida Sans" Size="14"/>
+ <Font Name="Lucida Sans" Size="7"/>
```

SkuDef在原版1.12配置中增加补丁包的加载行。

## 构建过程

`build.cmd`传递路径参数并运行`build.ps1`。后者依次执行：

1. 从XML中提取`UISubtitleDisplay`，调用SDK编译。
2. 读取`Core12.big`中的高、中、低三套static数据流。
3. 替换字幕资产，保留其他资产及资源引用。
4. 调用SDK的MakeBig生成补丁包，并复制源码中的SkuDef到输出目录。

脚本中的BIG读取、RefPack解压和数据插入函数用于处理这些资源流。构建输出都位于项目的`build/`目录，游戏输入文件以只读方式使用。

## 验证与兼容性

运行构建检查：

```powershell
.\tests.ps1 -GameDirectory "X:\Games\Red Alert 3" -SdkDirectory "X:\Tools\RA3_MODSDK"
```

检查涵盖XML的一字段差异、SDK编译结果、启动配置、资源文件数量和原始`Core12.big`的完整性。

补丁调整的是固定字号，不改变引擎的缩放算法。其他MOD、游戏版本和联机平台的兼容性需另行确认。

<div align="center">
  <img src="entry/src/main/resources/base/media/icon_round.png" width="192" />
  <h1>铃音</h1>
</div>

基于 **HarmonyOS NEXT** 的本地音乐播放器。

|     |     |
| --- | --- |
| 平台 | HarmonyOS 6.0.2 (API 22) |
| 设备 | 手机 |
| 许可 | MIT |

readme是AI写的，看不懂的不要问我^v^

###### 来群里聊天吧（求求了！），如果有bug、可以砸群u头上
###### ~~（发石也可以）~~
###### qq群：1062329769 / 1080024537

## 功能

- **音频播放** — 播放/暂停、上一曲/下一曲、进度拖动、音量调节（触感反馈）
- **播放模式** — 单曲循环、列表循环、列表停止、随机播放
- **后台播放** — 支持锁屏控制、通知栏控制（AVSession）
- **收藏系统** — 标记喜欢的歌曲，持久化存储
- **格式支持** — 主流格式 (`.mp3` `.flac` `.ogg` `.wav` `.m4a` `.aac` `.amr` `.ape`) + **DSD** (`.dff` `.dsf` `.dst`)
- **元数据解析** — 基于 FFmpeg 提取标题、艺术家、专辑、编曲者、流派等信息
- **专辑封面** — 自动提取内嵌封面，无封面时使用默认 CD 图标
- **文件浏览** — 按全部歌曲 / 文件夹 / 艺术家/编曲者 / 专辑 / 专辑艺术家 / 流派 / 收藏 分类浏览
- **歌单支持** — 解析 `.m3u` 歌单文件
- **动态主题** — 根据专辑封面亮度自动调整界面背景色

## 技术栈

| 层 | 技术 |
| --- | --- |
| UI | ArkUI (ArkTS) + WebView (HTML5/CSS/JS) |
| 播放 | AVPlayer (系统播放器) / FFmpeg Player（还没做好） |
| 解析 | FFmpeg (C++ NAPI) — libavformat / libavcodec |
| 通信 | emitter 事件总线 + JavaScript Proxy 桥接 |
| 构建 | Hvigor + CMake (C++14) |
| 测试 | Hypium （Hypium是什么？？？） |

## 项目结构

```
ArkMusic/
├── AppScope/                    # 应用级配置
├── entry/                       # 主模块 (HAP)
│   └── src/main/
│       ├── cpp/                 # C++ 原生代码 (FFmpeg NAPI)
│       ├── ets/                 # ArkTS 源码
│       │   ├── entryability/    # 应用入口
│       │   ├── pages/           # 页面 (启动页/WebView首页)
│       │   └── package/         # 核心模块 (播放器/文件管理/元数据/配置)
│       ├── libs/                # 预编译 FFmpeg 动态库
│       └── resources/
│           └── rawfile/
│               └── webview_gui/  # HTML5 前端界面
├── hvigor/                      # 构建配置
├── build-profile.json5          # 签名 & 编译配置
└── hvigorfile.ts                # 构建入口
```

## 构建运行

需要 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 及 HarmonyOS SDK。

```bash
# 打开项目 → Build → Build Hap(s)/App(s)
# 或命令行:
hvigor assembleDebug
```

部署到真机即可运行。（不支持x86模拟器）

## 权限

| 权限 | 用途 |
| --- | --- |
| `INTERNET` | WebView 加载前端页面 |
| `KEEP_BACKGROUND_RUNNING` | 后台播放 |
| `VIBRATE` | 音量调节触感反馈 |

## 许可

MIT © nekofox POT

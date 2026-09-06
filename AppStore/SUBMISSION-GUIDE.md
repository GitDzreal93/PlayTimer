# PlayTimer App Store 提审指南

最后更新：2026-09-06（对应代码库当前状态）

## 一、技术就绪状态（已完成 ✅）

- [x] App 图标：1024×1024 PNG 无 alpha（`Sources/App/Resources/Assets.xcassets`）
- [x] 4 个 target 构建 + 自动签名通过（Team FUU4946D45）
- [x] 真机安装/启动验证通过
- [x] PIN 安全：PBKDF2-SHA256 21万轮 + 5次失败指数退避锁定
- [x] DeviceActivity 计时窗口锚定会话开始时间（修复午夜清零）
- [x] MonitorExtension 失败兜底写入 error 状态
- [x] 版本号 1.0 (1)，最低 iOS 16.0，iPad 专用

## 二、你还需要手动做的事（按顺序）

### 1. 注册 App Store Connect
- [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → 我的 App → 新建 App
- 平台：iOS；名称：PlayTimer（如被占用备选：PlayTimer 玩耍计时器 / PlayTime Timer）
- 主要语言：简体中文
- Bundle ID：`com.wenlei.PlayTimer`（Apple Developer 后台确认已注册）
- SKU：`playtimer-2026-001`（自定义）

### 2. 上传隐私政策 URL
- `PRIVACY-POLICY-zh.md` 需要托管到公网 URL。免费方案：
  - GitHub Pages：建一个仓库 → 放入此文件（改名 index.md 或 index.html）→ Settings → Pages → 开启
  - 或 Notion 公开页面分享链接
- 填到 App Store Connect → App 隐私 → 隐私政策 URL

### 3. 填写隐私营养标签
App Store Connect → App 隐私 → 开始填写，选择：

| 问题 | 答案 |
|---|---|
| 收集数据吗？ | **否，不收集任何数据** |
| 用于追踪的 SDK | 无 |
| 与第三方共享 | 无 |

（应用无网络请求、无 SDK，这是最简单 truthful 申报）

### 4. 截图（iPad 需要）
需要 **iPad 13" 显示器尺寸**（2064×2752 或 2048×2732）截图至少 1 张，建议 3-5 张：
1. 主界面（授权引导/PIN 创建）
2. 应用合集管理页
3. 开始确认页（显示合集+时长）
4. 玩耍进行中倒计时
5. 休息界面（深色）

**截图方法**：真机运行 App 到对应页面 → 侧键+音量上键截屏 → AirDrop 到 Mac → 如尺寸不符用 `sips -z 2732 2048` 调整（竖屏为 2048×2732）。

### 5. App 描述文案（可直接用）

**名称**：PlayTimer
**副标题**（30字内）：儿童屏幕时间管理·家长掌控
**关键词**（100字符内）：屏幕时间,儿童模式,计时器,休息提醒,家长控制,护眼,限额
**描述**：
> PlayTimer 帮助家长管理孩子的 iPad 使用时间。
>
> 【怎么工作】
> 1. 家长授权屏幕时间并设置 PIN
> 2. 选择本轮允许使用的 App（或整机计时）
> 3. 孩子玩耍，应用计量实际使用
> 4. 时间到自动进入休息，其余应用被屏蔽
> 5. 休息结束后需家长验证才能开始新一轮
>
> 【特性】
> · 多套应用合集，像歌单一样切换（学习/游戏）
> · 5 分钟预警通知，孩子有心理准备
> · Face ID / Touch ID 家长验证
> · 数据全部留在设备上，不联网不上传

**分类**：主要=生活方式（Lifestyle）或 效率（Productivity）；次要=教育
**年龄分级**：4+（无暴力/无网络内容/无赌博）→ 回答问卷全选"无"
**价格**：免费（或自定）

### 6. Family Controls 特别注意事项 ⚠️
本 App 使用 DeviceActivity/ManagedSettings API，审核需要：
- **审核备注（Review Notes）必须写清楚**（App Store Connect → App 信息 → 审核备注）：

> 此应用面向家长管理儿童 iPad 屏幕时间。测试步骤：
> 1. 首次启动需要授权"屏幕时间"（Family Controls 权限，系统弹窗）
> 2. 设置 4-6 位家长 PIN
> 3. 工具栏开启"测试模式"（1分钟一轮，无需等25分钟）
> 4. 选择一个应用合集（可用 FamilyActivityPicker 选系统应用）
> 5. 开始儿童模式 → 切到被计时的应用使用约 1 分钟
> 6. 到时后设备会盾屏（其他应用被屏蔽）→ 回到应用家长验证可结束
>
> 注：屏幕时间 API 需真机测试，模拟器上部分功能不可用。

- 演示视频（可选但强烈建议）：录一段 30-60 秒完整流程屏幕录像，上传到审核备注支持的链接
- **Apple 对 Family Controls 类审核较慢**（常 2-7 天），且可能要求补充说明儿童隐私保护措施（已在隐私政策中覆盖）

### 7. 归档上传
```bash
# 项目根目录执行
xcodegen generate
open PlayTimer.xcodeproj
# Xcode: Product → Archive → Distribute App → App Store Connect
```
或者命令行：
```bash
xcodebuild -project PlayTimer.xcodeproj -scheme PlayTimer -destination 'generic/platform=iOS' -archivePath build/PlayTimer.xcarchive archive
xcodebuild -exportArchive -archivePath build/PlayTimer.xcarchive -exportOptionsPlist <(cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>FUU4946D45</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
EOF
) -exportPath build/export
# 然后用 Transporter 或 xcrun altool 上传
```

## 三、发布前建议人工真机过一遍的清单

- [ ] 完整跑一轮测试模式（1分钟）：开始→玩耍→盾屏→休息→家长验证→结束
- [ ] PIN 连续输错 5 次 → 确认出现"失败次数过多"锁定提示
- [ ] 通知权限拒绝后再开始会话 → 确认 App 不崩溃（只是没通知）
- [ ] 中途重启 iPad → 重新打开 App → 会话状态还在
- [ ] 休息结束不开家长验证，盾牌持续保留（核心安全属性）

## 四、已知限制（不影响提审，记录备查）

- 深夜场景：会话若跨越午夜，DeviceActivity 窗口已锚定开始时间，但极端情况（窗口结束仍在玩）依赖家长手动结束
- 屏蔽基于 `applicationCategories = .all()`，系统设置等白名单外应用也被屏蔽属预期
- 无本地化文件（UI 中文硬编码），面向中国区市场没问题；若上美区需英文化

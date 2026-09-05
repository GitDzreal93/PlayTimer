# PlayTimer 真机测试清单

这份清单是为了把 PlayTimer 跑到你的 iPad 真机上。当前工程已经配置为 iPad-only，并且已经写入本机检测到的 Apple Development Team：`FUU4946D45`。

## 现在已经准备好的部分

- Xcode 工程由 `project.yml` 生成。
- 主 App 和 3 个扩展 target 都使用同一个 Team ID。
- App Group 已统一为 `group.com.wenlei.PlayTimer`。
- Bundle IDs：
  - `com.wenlei.PlayTimer`
  - `com.wenlei.PlayTimer.monitor`
  - `com.wenlei.PlayTimer.shield-configuration`
  - `com.wenlei.PlayTimer.shield-action`
- Entitlements 已包含 App Groups 和 Family Controls。

## 第一次真机运行步骤

1. 用线连接 iPad 到 Mac。
2. 解锁 iPad。
3. iPad 上如果弹出“信任此电脑”，点“信任”，并输入 iPad 密码。
4. 打开 Xcode。
5. Xcode 顶部菜单打开 `Settings...`，进入 `Accounts`。
6. 点左下角 `+`，登录你的 Apple Developer 账号。
7. 选中账号后，确认 Team 列表里能看到 `FUU4946D45`。
8. 打开本工程：`PlayTimer.xcodeproj`。
9. 顶部运行设备选择你的 iPad，不要选模拟器。
10. 左侧点蓝色项目图标 `PlayTimer`，进入 `Signing & Capabilities`。
11. 对下面 4 个 target 都确认 Team 是同一个：
    - `PlayTimer`
    - `PlayTimerMonitorExtension`
    - `PlayTimerShieldConfigurationExtension`
    - `PlayTimerShieldActionExtension`
12. 如果 Xcode 显示 “Registering bundle identifier” 或 “Creating provisioning profile”，等它完成。
13. 点运行按钮。

## 如果遇到报错

### No Account for Team

含义：Mac 上有开发证书，但 Xcode 没有登录这个 Apple Developer 账号，或者账号凭证过期。

处理：

1. 打开 Xcode `Settings...`。
2. 进入 `Accounts`。
3. 登录或重新登录 Apple Developer 账号。
4. 回到工程重新运行。

### No profiles for bundle id were found

含义：Xcode 还没有为这个 bundle id 创建开发证书配置文件。

处理：

1. 确认 Xcode 已登录开发者账号。
2. 确认 4 个 target 都选择同一个 Team。
3. 保持 `Automatically manage signing` 开启。
4. 再运行一次，让 Xcode 自动创建 profiles。

### Family Controls capability is unavailable

含义：Apple Developer 后台没有给这个 App ID 开启 Family Controls 权限，或者账号没有这个能力。

处理：

1. 进入 Apple Developer 后台的 Certificates, Identifiers & Profiles。
2. 找到主 App 和 3 个扩展的 App IDs。
3. 确认 Family Controls / App Groups 能力可用并已开启。
4. 如果后台不允许开启 Family Controls，需要在 Apple Developer 账号里申请该能力。

### iPad 显示 unavailable

含义：Mac 能看到设备名，但暂时不能部署。

处理：

1. 解锁 iPad。
2. 插线后点“信任此电脑”。
3. 在 Xcode `Window > Devices and Simulators` 里等设备准备完成。
4. 如果还是不行，拔插数据线，重启 Xcode。

## 真机验证路径

1. 安装后打开 PlayTimer。
2. 授权 Screen Time。
3. 创建 4-6 位家长 PIN。
4. 打开测试模式。
5. 建一个 App 合集，比如“英语学习”，选择 1-2 个 App。
6. 开始儿童模式，确认开始页里显示正确合集和 `1 分钟`。
7. 第一次出现通知权限弹窗时，点允许。
8. 切到允许的 App 使用，等 1 分钟阈值触发。
9. 验证到点后其他 App 被 Shield，并能收到休息开始通知。
10. 休息结束后，用家长 PIN 或 Face ID / Touch ID 开始下一轮。

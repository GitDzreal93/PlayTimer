# PlayTimer 隐私政策

最后更新：2026年9月6日

本政策说明 PlayTimer（"本应用"）如何处理信息。本应用由开发者独立开发，**不收集、不传输、不共享任何个人信息**。

## 本应用访问的数据

| 数据 | 用途 | 是否离开设备 |
|---|---|---|
| 屏幕时间授权（Family Controls） | 计量选中应用的实际使用时长，达到阈值后触发休息 | 否 |
| 应用选择（FamilyActivityPicker） | 仅记录您选中的应用标识（token），用于计时和屏蔽 | 否 |
| 家长 PIN（加盐 PBKDF2 哈希） | 验证家长身份，仅存储哈希值，不存储明文 | 否 |
| 通知权限 | 发送开始/预警/休息提醒 | 否 |

## 存储位置

所有数据（会话状态、设置、应用合集、PIN 哈希）均存储在设备本地的 App Group 容器和 Keychain 中，受 iOS 数据保护加密。

## 不做的事

- 不联网（无任何网络请求）
- 不含广告、不含分析/统计 SDK、不含第三方追踪
- 不与 App Store 之外的任何一方共享数据

## 儿童隐私

本应用面向家长管理儿童设备使用。儿童无法访问家长设置；应用不收集儿童的任何个人身份信息。符合 Apple《儿童类别准则》与相关数据最小化要求。

## 联系

如有疑问，请通过 App Store 开发者页面提供的联系方式与我们联系。

---

## English Summary

PlayTimer collects no personal data. All information (screen time authorization, app selections, parent PIN hash, session state) stays on-device in the App Group container and Keychain. The app makes no network requests, includes no ads, analytics, or third-party SDKs, and shares nothing with anyone.

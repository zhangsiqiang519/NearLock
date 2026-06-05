# macOS 保护总开关与手动立即锁屏

## Goal

给 macOS 端补两个手动控制能力，让用户随时掌控锁屏行为：
1. **保护总开关**：一个常驻的"启用/停用自动锁屏"开关。停用后彻底不自动锁屏，
   与现有"定时暂停 10/30/60 分钟后自动恢复"互补——总开关是无限期的手动状态。
2. **立即锁屏**：一个按钮，不等 RSSI 检测，手动点击立刻息屏锁屏。

## Requirements

1. SettingsStore 新增持久化字段 `protectionEnabled`（默认 true），UserDefaults 存储。
2. ProximityMonitor 在 `protectionEnabled == false` 时短路，不触发自动锁屏
   （与 `isPaused` 并列的另一道闸）。
3. MenuContentView 顶部新增保护开关（Toggle）：开=启用保护，关=停用保护。
4. MenuContentView 新增"立即锁屏"按钮，点击调用 `ScreenLocker.lockNow()` 并记日志。
5. 菜单栏图标与状态文案反映总开关：停用时显示明显不同的图标/文案。
6. 开关与立即锁屏操作都写入事件日志。

## Acceptance Criteria

- [ ] 关闭保护开关后，即使绑定设备 RSSI 持续低于阈值也不锁屏
- [ ] 重新打开保护开关后，自动锁屏恢复正常
- [ ] `protectionEnabled` 状态 App 重启后保持
- [ ] 点击"立即锁屏"立刻触发息屏（与自动触发走同一 ScreenLocker）
- [ ] 保护停用时菜单栏图标/状态文案与启用时有可区分的显示
- [ ] 开关切换、立即锁屏均产生事件日志条目
- [ ] macOS 工程构建通过（xcodebuild）

## Definition of Done

- macOS `xcodebuild` 构建通过
- 总开关与定时暂停两套机制逻辑不冲突（任一为"不保护"即不锁）
- README 同步说明新增的开关与立即锁屏

## Technical Approach

- **数据层**：`SettingsStore` 加 `@Published var protectionEnabled: Bool { didSet 写 UserDefaults }`，
  init 读取（缺省 true）。
- **触发闸**：`ProximityMonitor.tick()` 在判定触发前增加 `guard settings.protectionEnabled else { return }`，
  与现有 `settings.isPaused` 短路并列。两者关系：**只要"暂停中"或"保护停用"任一成立，就不自动锁屏**。
- **UI**：
  - 顶部 `Toggle("自动锁屏保护", isOn: $settings.protectionEnabled)`。
  - "立即锁屏"按钮（`.borderedProminent`），点击 `ScreenLocker.lockNow()` + `eventLog.log`。
  - `statusText` / 菜单栏 `menuBarIcon` 增加 `protectionEnabled == false` 分支
    （如图标用 `lock.slash`，文案"保护已关闭"）。
- **状态优先级**（菜单栏图标与文案）：保护关闭 > 暂停中 > 未绑定 > 保护中。

## Decision (ADR-lite)

**Context**: 用户要"锁屏和不锁屏"的手动能力。现有只有自动检测锁屏 + 定时暂停。
**Decision**: 解读为"常驻保护总开关(不锁屏)" + "立即锁屏按钮(主动锁屏)"两个互补功能。
总开关与定时暂停并存：暂停是限时的，开关是无限期的，二者都能阻止自动锁屏。
**Consequences**: 用户有了无限期停用入口，不必反复用定时暂停续期；立即锁屏满足"现在就走"的主动场景。
新增字段不影响既有持久化（默认 true 向后兼容）。

## Out of Scope

- 全局快捷键触发立即锁屏（MVP 仅面板按钮）
- 锁屏方式切换（仍用既定的 pmset 息屏）
- 多套保护策略/定时计划

## Technical Notes

- 复用既有 `ScreenLocker.lockNow()`，立即锁屏与自动锁屏行为一致。
- 立即锁屏不受冷却(`cooldown`)限制——那是自动触发的防抖，手动点击应即时生效。
- 涉及文件：`Store/SettingsStore.swift`、`Lock/ProximityMonitor.swift`、
  `Views/MenuContentView.swift`、`NearLockApp.swift`（菜单栏图标）。

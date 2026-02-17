# CombatEngine.spoon

Hammerspoon 战斗引擎插件 (V1.2)。旨在为游戏提供高效、模块化的自动化战斗支持。

## 功能特性

- **模块化架构**: 采用 Spoon 插件格式，易于集成和管理。
- **极速异步引擎**: 最小化输入延迟，支持复杂的技能优先级逻辑。
- **自动切换**: 支持多职业/多方案快速切换（双击触发）。
- **智能排队**: 基于冷却时间（CD）和施法时长（Duration）的智能技能释放顺序。
- **安全锁机制**: 内置 `synthetic_lock` 防止脚本模拟按键引起的死锁或重复触发。
- **摇杆模拟**: 支持右键拖拽模拟虚拟摇杆操作。

## 安装

1. 下载 `CombatEngine.spoon` 目录。
2. 将其放置在你的 `~/.hammerspoon/Spoons/` 目录下。
3. 在你的 `init.lua` 中加载：

```lua
hs.loadSpoon("CombatEngine")
spoon.CombatEngine:init()
spoon.CombatEngine:start()
```

## 配置

你可以在主 `init.lua` 中自定义配置：

```lua
spoon.CombatEngine.config.debug = false
spoon.CombatEngine.config.gameBundleID = "com.netease.immortal"

-- 也可以覆盖默认方案
local mySchemes = { ... }
spoon.CombatEngine:start(mySchemes)
```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

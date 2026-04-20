# Departured（已弃用/归档）

本目录用于保存项目历史遗留实现的参考代码（非编译目标）。在开发过程中有时会保留旧实现以便参考、回退或迁移，但这些文件不应直接参与当前构建或生产部署。

当前包含的文件：
- `MySqlDatabaseService.swift`：直接使用 `MySQLNIO` 与 MariaDB 通信的低层实现样例（含连接管理、重连、健康检查和 SQL 插入逻辑）。该实现已被项目的 Fluent ORM / FluentMySQLDriver 替代，因此标注为已弃用。
- `SensorDHT22.swift`：使用 Fluent 的 `Model` 定义的传感器表模型。项目中已有统一的模型和迁移（查看 `Sources/App/Models` 与 `Sources/App/Migrations`），该文件作为旧版本保留以供参考。

推荐的处理策略（已执行）：
1. 档案化（保留在本目录）：保留原始代码以便参考与迁移，但不要把文件移动到 `Sources/...` 下或作为构建目标的一部分。这样可以避免与当前代码冲突，也保留历史实现。该仓库中 `Departured` 目录即为此用途。
2. 添加文档说明（已完成）：本文件解释了为什么保留这些文件，以及后续建议的替代实现位置（例如使用 `Fluent` 模型与迁移，参见 `Sources/App/Models` 与 `Sources/App/Migrations`）。
3. 如需彻底删除或恢复：
   - 若要删除：在确认没有历史参考需求后，删除这些文件并在 PR 中记录原因与链接到替代实现。
   - 若要恢复为活动代码：将需要的文件移到 `Sources/App/` 下，移除或更新过时的 API/依赖，并添加或更新迁移以确保数据库模式一致。

迁移建议（如果你要把某个实现整合回主线）：
- 优先将持久化逻辑迁移到 Fluent（Model + Migration + Repository/Service 层）。
- 将低层的 MySQLNIO 实现封装为可选的 `LegacyMySQLService`，提供与当前服务接口相同的方法（例如 `saveMessage(...)`），并在实现迁移完成后逐步弃用。
- 为迁移过程添加单元测试，确保新实现与旧实现在关键行为（例如数据字段、时间戳格式）上保持一致。

如果你希望，我可以：
- 根据需要把这些文件移动到 `Docs/Archive` 或以 `*.deprecated.swift` 重命名以更清晰地标注状态；
- 自动生成一个简单的迁移计划（文件到 Fluent 模型/迁移）；
- 或者删除这些文件并打开一个变更 PR（请确认）。

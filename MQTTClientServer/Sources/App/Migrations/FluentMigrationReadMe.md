
下面是一套 **Vapor Fluent 4** 里可直接复制改名的 **`AsyncMigration`** 模板。Fluent 的 Schema API **没有**官方的「改表名」方法（见 [fluent-kit#408](https://github.com/vapor/fluent-kit/issues/408)），所以 **改表名用 `database.raw(...).run()`**；PostgreSQL / SQLite / MySQL 对 `ALTER TABLE … RENAME` 写法基本一致，MySQL 也可用 `RENAME TABLE`。

---

### 1. 空壳（AsyncMigration）

```swift
import Fluent

struct M1234567890_DoSomething: AsyncMigration {
    func prepare(on database: Database) async throws {
        // ...
    }

    func revert(on database: Database) async throws {
        // ...
    }
}
```

> 把 `M1234567890_` 换成你的时间戳前缀；在 `configure.swift` 里 `app.migrations.add(M1234567890_DoSomething())`。

---

### 2. 建表（常见：UUID 主键 + 时间戳）

```swift
import Fluent

struct M1234567890_CreateUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
```

---

### 3. 删表

```swift
import Fluent

struct M1234567890_DropUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users").delete()
    }

    func revert(on database: Database) async throws {
        // 若无法安全重建，revert 可留空或抛错说明
    }
}
```

---

### 4. 加字段

```swift
import Fluent

struct M1234567890_AddDisplayNameToUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("display_name", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("display_name")
            .update()
    }
}
```

---

### 5. 改字段类型（`updateField`）

```swift
import Fluent

struct M1234567890_ChangeAgeToDouble: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .updateField("age", .double)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .updateField("age", .int)
            .update()
    }
}
```

---

### 6. 删字段

```swift
import Fluent

struct M1234567890_RemoveLegacyField: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("legacy_flag")
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .field("legacy_flag", .bool, .required)
            .update()
    }
}
```

---

### 7. 外键（在已有表上加约束）

```swift
import Fluent

struct M1234567890_AddUserIdFK: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("posts")
            .foreignKey("user_id", references: "users", "id", onDelete: .cascade)
            .update()
    }

    func revert(on database: Database) async throws {
        // 需要你知道约束名，或用数据库里查到的名字：
        try await database.schema("posts")
            .deleteConstraint(name: "posts_user_id_foreign") // 示例名，按实际改
            .update()
    }
}
```

---

### 8. **改表名**（必须用 Raw SQL）

PostgreSQL / SQLite / MySQL 都支持下面这种（表名请按你库里的实际命名改；若有大小写/保留字，需按方言加引号）。

```swift
import Fluent

struct M1234567890_RenameUsersToAccounts: AsyncMigration {
    private let oldTable = "users"
    private let newTable = "accounts"

    func prepare(on database: Database) async throws {
        try await database.raw("ALTER TABLE \(unsafeRaw: oldTable) RENAME TO \(unsafeRaw: newTable)")
            .run()
    }

    func revert(on database: Database) async throws {
        try await database.raw("ALTER TABLE \(unsafeRaw: newTable) RENAME TO \(unsafeRaw: oldTable)")
            .run()
    }
}
```

若你当前 Fluent/SQLKit 版本没有 `unsafeRaw:` 插值，可改成字面量（迁移里表名是常量，这样最简单）：

```swift
try await database.raw("ALTER TABLE users RENAME TO accounts").run()
```

**注意：** 改表名后，对应 `Model` 上的 `static let schema = "..."` 要改成新表名；若有别的表的外键指向旧表名，可能还要单独处理约束（视数据库而定）。

---

### 9. MySQL 备选：`RENAME TABLE`

```swift
try await database.raw("RENAME TABLE users TO accounts").run()
// revert: RENAME TABLE accounts TO users
```

---

### 10. 枚举类型 + 字段（异步）

```swift
import Fluent

struct M1234567890_AddPlanetTypeEnum: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.enum("planet_type")
            .case("smallRocky")
            .case("gasGiant")
            .create()

        let planetType = try await database.enum("planet_type").read()

        try await database.schema("planets")
            .field("type", planetType, .required)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("planets")
            .deleteField("type")
            .update()

        try await database.enum("planet_type").delete()
    }
}
```

---

### 在 `configure.swift` 注册示例

```swift
import Vapor
import Fluent

// ...
app.migrations.add(M1234567890_CreateUsers())
app.migrations.add(M1234567890_RenameUsersToAccounts())
```

---

**小结：** 除「改表名」和部分高级变更外，优先用 **`database.schema(...).create() / .update() / .delete()`**；**改表名**用 **`AsyncMigration` + `database.raw(...).run()`**，并同步更新 Model 的 `schema` 与外键关系。若你贴出 Fluent / `fluent-kit` 版本号，我可以把 `raw` 插值写法改成与你项目完全一致的 API。

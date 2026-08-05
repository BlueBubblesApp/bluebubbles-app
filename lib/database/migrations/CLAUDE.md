# database/migrations/ — ObjectBox Schema Migrations

Contains migration scripts that run when the database version is incremented.

## Files

| File | Purpose |
|------|---------|
| `message_handle_relationship_migration.dart` | Migrates legacy message→handle relationships to the new N:M `ToMany` schema |
| `chat_latest_message_migration.dart` | Backfills `Chat.dbLatestMessage` / `dbOnlyLatestMessageDate` |

## How Migrations Work
1. `database.dart` stores `Database.version`
2. On startup, if the stored version is less than the current version, migration scripts run in a `switch` loop:
   ```dart
   switch (nextVersion) {
     case N: MyMigration.migrate(); break;
   }
   ```
3. Version is bumped to current after all migrations complete

## Adding a Migration
1. Create `my_migration.dart` in this directory
2. Register it in the version switch in `lib/database/database.dart`
3. Bump `Database.version`
4. Run `dart run build_runner build` if `@Entity` annotations changed

## Rules
- Migrations are one-shot and irreversible — always test with a real device DB before shipping
- Never edit `lib/generated/objectbox.g.dart` directly
- Add `@Property(uid: ...)` to new entity fields to avoid schema conflicts

## Related
- Database init: `lib/database/database.dart`
- Entity definitions: `../io/CLAUDE.md`

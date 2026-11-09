# services/network/api/ — HTTP API Sub-Services

One file per server API domain. Each class implements `BaseApi` and is exposed on `HttpService` as `HttpSvc.<name>` (see the method table in `../CLAUDE.md`).

## Files
| File | Class | Property on `HttpSvc` |
|------|-------|------------------------|
| `base_api.dart` | `BaseApi` (abstract interface) | — |
| `server_api.dart` | `ServerApi` | `server` |
| `fcm_api.dart` | `FcmApi` | `fcm` |
| `attachment_api.dart` | `AttachmentApi` | `attachment` |
| `chat_api.dart` | `ChatApi` | `chat` |
| `message_api.dart` | `MessageApi` | `message` |
| `handle_api.dart` | `HandleApi` | `handle` |
| `contact_api.dart` | `ContactApi` | `contact` |
| `backup_api.dart` | `BackupApi` | `backup` |
| `facetime_api.dart` | `FaceTimeApi` | `faceTime` |
| `icloud_api.dart` | `iCloudApi` | `icloud` |
| `firebase_api.dart` | `FirebaseApi` | `firebase` |
| `genmoji_api.dart` | `GenmojiApi` | `genmoji` (v2 only — `_svc.apiRootV2`) |

## `BaseApi`
`base_api.dart` defines the minimal interface (`dio`, `origin`, `apiRoot`, `apiRootV2`, `headers`, `buildQueryParams()`, `runApiGuarded()`, `returnSuccessOrError()`) that `HttpService` implements. Every sub-service is constructed with a `BaseApi` reference (`HttpService` itself) rather than importing it directly — this avoids a circular import between `HttpService` and the sub-services it owns.

## Adding a new endpoint
1. Add the method to the relevant sub-service file here, calling `_svc.dio`, `_svc.apiRoot`, `_svc.buildQueryParams()`, `_svc.runApiGuarded()` as needed.
2. For a new domain, create `<domain>_api.dart` implementing against `BaseApi`, then wire it up as a named property on `HttpService`.
3. Never add request methods directly to `HttpService` — see `../CLAUDE.md` and `.claude/rules/api.md`.

## Related

`MessageApi.query` accepts the optional v2 `dateField` selector (`created`, `delivered`, `read`,
`updated`, `edited`, `retracted`) for its `after`/`before` bounds. Omit it for legacy server requests.

- Full method-level reference table: `../CLAUDE.md`
- HTTP conventions (`runApiGuarded`, `buildQueryParams`, error handling): `.claude/rules/api.md`

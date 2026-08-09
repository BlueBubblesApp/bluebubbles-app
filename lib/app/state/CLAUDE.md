# lib/app/state/ — Reactive State Wrappers

These are the bridge between ObjectBox DB entities and the UI.

## Files
- `chat_state.dart` — `ChatState`: reactive wrapper for a `Chat` entity
- `message_state.dart` — `MessageState`: reactive wrapper for a `Message` entity
- `attachment_state.dart` — `AttachmentState`: reactive wrapper for an `Attachment` entity
- `handle_state.dart` — `HandleState`: reactive wrapper for a `Handle` entity, owned by `HandleService`
- `chat_state_scope.dart`, `message_state_scope.dart`, `attachment_state_scope.dart` — `InheritedWidget` scopes exposing the corresponding state via `<X>StateScope.of(context)`

## Purpose
ObjectBox entities are heavy (lazy-loaded relations, DB context required). Re-querying the DB on every UI event would be expensive. Instead, `ChatState`/`MessageState`/`AttachmentState` mirror the UI-relevant fields as `Rx*` observables so widgets can rebuild only the sub-tree that cares about a specific field.

## Key Rules
- **Never write to a state object from UI code.** Only `*Internal()` methods may mutate observables.
- `*Internal()` methods are called exclusively by:
  - `ChatsService` (for `ChatState`)
  - `MessagesService` (for `MessageState`)
  - `MessagesService`, `OutgoingMessageHandler`, and `IncomingMessageHandler` (for `AttachmentState`)
- Each `Rx*` field is independent — a badge update does not trigger a title rebuild.

## ChatState Observable Fields
| Field | Type | Driven by |
|-------|------|-----------|
| `isPinned` | `RxBool` | pin/unpin |
| `hasUnreadMessage` | `RxBool` | mark read/unread |
| `isArchived` | `RxBool` | archive |
| `muteType` / `muteArgs` | `RxnString` | mute settings |
| `title` / `displayName` / `subtitle` | `RxnString` | contact name changes |
| `latestMessage` | `Rxn<Message>` | new message received |
| `textFieldText` / `textFieldAttachments` | reactive | draft persistence |
| `isActive` / `isAlive` | `RxBool` | lifecycle (conversation open) |

## MessageState Observable Fields
Key observables: `guid`, `text`, `dateDelivered`, `dateRead`, `dateEdited`, `error`, `hasReactions`, `associatedMessages`, `isSending`, `isSent`, `hasError`, `isReaction`.

Also owns `attachmentStates: Map<String, AttachmentState>` keyed by attachment GUID.

## AttachmentState Observable Fields
| Field | Type | Driven by |
|-------|------|-----------|
| `guid` | `RxnString` | temp→real GUID swap |
| `mimeType` / `transferName` / `totalBytes` | `Rxn*` | attachment metadata updates |
| `width` / `height` | `RxnInt` | image property load |
| `isDownloaded` | `RxBool` | download complete / file confirmed on disk |
| `transferState` | `Rx<AttachmentTransferState>` | upload/download lifecycle (see enum) |
| `uploadProgress` | `RxnDouble` | 0.0–1.0 during upload; null otherwise |
| `downloadProgress` | `RxnDouble` | 0.0–1.0 during download; null otherwise |
| `isSending` | `RxBool` | derived: temp GUID + uploading state |
| `hasError` | `RxBool` | derived: transferState == error |

### AttachmentTransferState enum
`idle` → `uploading` → *(complete)*  
`idle` → `queued` → `downloading` → `processing` → `complete`  
Any state → `error`

## Updating State (correct pattern)
```dart
// In ChatsService, after DB write:
chatState.updateHasUnreadInternal(true);

// In MessagesService, after DB write:
messageState.updateDateReadInternal(DateTime.now());

// Via MessagesService for attachment state (preferred):
msvc.notifyAttachmentUploadStarted(message, attachment);
msvc.notifyAttachmentUploadProgress(msgGuid, attGuid, 0.5);
msvc.notifyAttachmentDownloadStarted(msgGuid, attGuid, downloadController);
msvc.notifyAttachmentDownloadComplete(msgGuid, attGuid);
msvc.notifyAttachmentTransferError(msgGuid, attGuid);
msvc.renameAttachmentState(msgGuid, oldAttGuid, newAttGuid);
```

## Bulk Update
`updateFromChat(Chat)` and `updateFromMessage(Message)` update all fields at once from a freshly fetched DB object.  `updateFromMessage` also calls `_syncAttachmentStates` to reconcile the attachment map.

## Redaction
Both `ChatState` and `MessageState` support `redactFields()` / `unredactFields()` — called by the service layer when the setting changes.

## Where ChatState lives
`ChatsService` owns a `Map<String, ChatState>` keyed by chat GUID. Access via `ChatsSvc.getChatState(guid)`.

## Where MessageState lives
`MessagesService` owns a `Map<String, MessageState>` keyed by message GUID.

## Where AttachmentState lives
Each `AttachmentState` is owned by its parent `MessageState` inside `MessageState.attachmentStates` (keyed by attachment GUID).  Access via:
```dart
final state = controller.messageState?.getAttachmentState(attachmentGuid);
// or via service:
final state = msvc.getAttachmentState(messageGuid, attachmentGuid);
```

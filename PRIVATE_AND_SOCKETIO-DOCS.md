# BlueBubbles Private API and Socket.IO Reference

This document summarizes the app’s Private API features and its Socket.IO event usage.
It is derived from the current client implementation in the settings UI, message send flow, socket service, and action handler.

## Private API overview

The app can operate in two main modes when sending certain actions:

- `apple-script` fallback mode
- `private-api` mode when the server supports the Private API and the feature is enabled

The send flow switches automatically based on the user’s settings and message type.

### Relevant settings

These settings are stored by the client and control Private API behavior:

- `enablePrivateAPI`
- `privateSendTypingIndicators`
- `privateMarkChatAsRead`
- `privateManualMarkAsRead`
- `privateSubjectLine`
- `privateAPISend`
- `privateAPIAttachmentSend`
- `editLastSentMessageOnUpArrow`
- `enableQuickTapback`

## Private API features exposed in the UI

The app describes the following capabilities when Private API support is available on the server:

- Send and receive typing indicators
- Send tapbacks, effects, and mentions
- Send messages with subject lines
- Send replies on supported macOS versions
- Edit and unsend messages on supported macOS versions
- Receive Digital Touch messages
- Mark chats read on the Mac server
- Mark chats unread on supported macOS versions
- Rename group chats
- Add and remove people from group chats
- Change the group chat photo on supported macOS versions
- Check whether a recipient is registered with iMessage
- View Focus statuses on supported macOS versions
- Use Find My Friends on supported macOS versions
- Be notified of incoming FaceTime calls
- Answer FaceTime calls on supported macOS versions, marked experimental

## Private API send behavior

When Private API is enabled, the client may send extra fields with message requests.

### Text messages

`POST /api/v1/message/text` may include:

- `method`: `private-api` or `apple-script`
- `effectId`
- `subject`
- `selectedMessageGuid`
- `partIndex`
- `ddScan` on supported versions

### Attachments

`POST /api/v1/message/attachment` may include:

- `method`: `private-api` or `apple-script`
- `effectId`
- `subject`
- `selectedMessageGuid`
- `partIndex`
- `isAudioMessage`

### Multipart messages

`POST /api/v1/message/multipart` may include:

- `effectId`
- `subject`
- `selectedMessageGuid`
- `partIndex`
- `ddScan` on supported versions
- `parts`: each part includes text and mention metadata

### Tapbacks

`POST /api/v1/message/react` is used for reactions / tapbacks.

### Unsending and editing

- `POST /api/v1/message/{guid}/unsend`
- `POST /api/v1/message/{guid}/edit`

## Chat-level Private API behavior

The app uses Private API support for some chat actions as well:

- Mark read / unread on the server
- Typing indicators
- Group chat rename and membership updates
- Chat photo changes

## Socket.IO transport

The app keeps a persistent Socket.IO connection to the server for live updates.

### Connection details

- Server is derived from the configured server origin
- Connection query includes `guid=<guidAuthKey>`
- Transports enabled: `websocket` and `polling`
- Extra headers from the HTTP client are attached to the socket connection
- Reconnection is enabled
- On repeated connection errors, the client can fetch a refreshed server URL and restart the socket

### Socket state lifecycle

The client tracks:

- `connected`
- `disconnected`
- `connecting`
- `error`

If connection errors persist, the client retries and may fetch a new server URL before reconnecting.

## Socket.IO event list

### Server lifecycle events

- `connect`
- `reconnect`
- `reconnect_attempt`
- `reconnecting`
- `connecting`
- `disconnect`
- `connect_error`
- `connect_timeout`
- `error`

### App events

The client listens for these server events:

| Event | Purpose |
| --- | --- |
| `new-message` | Deliver a new message payload |
| `updated-message` | Deliver an updated message payload |
| `typing-indicator` | Show or hide typing state for a chat |
| `chat-read-status-changed` | Notify that a chat was read or unread |
| `imessage-aliases-removed` | Notify that one or more aliases were removed |
| `ft-call-status-changed` | Notify FaceTime call status changes |
| `incoming-facetime` | Legacy incoming FaceTime event |
| `group-name-change` | Notify a group chat rename |
| `participant-added` | Notify a participant add event |
| `participant-removed` | Notify a participant removal event |
| `participant-left` | Notify that a participant left |
| `new-findmy-location` | Update Find My friend location in the Find My UI when the Find My page is active |

Platform scope notes:

- `group-name-change`, `participant-added`, `participant-removed`, `participant-left`, and `incoming-facetime` are registered on web/desktop only.
- Core events such as `new-message`, `updated-message`, `typing-indicator`, `chat-read-status-changed`, `imessage-aliases-removed`, and `ft-call-status-changed` are registered cross-platform.

### Event handling notes

- Group membership and name events refresh the affected chat.
- `typing-indicator` toggles typing UI state for the target chat.
- `chat-read-status-changed` updates unread state locally.
- `new-message` and `updated-message` are queued and then reconciled with temp GUIDs.
- `incoming-facetime` is parsed as JSON on desktop and web.
- `new-findmy-location` is consumed by the Find My page listener to update friend markers in-place.
- On Android, overlapping message/lifecycle events may also arrive through the method channel (FCM path), and are ignored when an active socket session is already handling them.

## Socket payload notes

Message events are expected to be wrapped payloads (parsed through `ServerPayload`) and then mapped into internal models.

Some chat metadata events (for example participant/name updates) are handled from direct event payloads.

Typical patterns:

- Message events include a `tempGuid` when they correspond to a locally sent message
- Read status events include `chatGuid` and `read`
- Typing events include `guid` and `display`
- Alias removal events include `aliases`

## Socket acknowledgements

The client has a generic socket send helper that emits an event and waits for an acknowledgement.

- If the acknowledgement payload is encrypted, it is decrypted using the GUID auth key
- The decrypted payload is parsed before resolving the promise
- This helper is also used for typing emits such as `started-typing` and `stopped-typing` when Private API typing indicators are enabled

## Practical summary

- HTTP APIs handle fetch/query/send operations.
- Socket.IO handles live receive-side updates.
- Private API settings mainly control richer send actions, read receipts, typing indicators, group management, and call-related integration.

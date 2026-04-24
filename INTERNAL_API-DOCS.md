# BlueBubbles Internal API Reference

This document summarizes the HTTP API used by the app to talk to the BlueBubbles server.
It is derived from the current client implementation in `lib/services/network/http_service.dart`.

## Base URL and auth

- Base URL: `https://<server-origin>/api/v1`
- Most requests include the GUID auth token as a query parameter: `guid=<guidAuthKey>`
- Requests are built from the configured server address, or an origin override when the app is pointed at a local server.
- Successful responses are usually wrapped as `{ "data": ... }`.
- Download endpoints return bytes and use an extended timeout.

## Common query patterns

The client commonly uses these query parameters:

- `with`: include related objects or extra fields
- `sort`: sort direction, usually `ASC` or `DESC`
- `before` / `after`: pagination bounds using timestamps or IDs depending on the endpoint
- `offset` / `limit`: paging controls
- `guid`: required auth token
- `original`: download the original attachment when supported
- `extraProperties=avatar`: request contact avatars

## Server and health

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/ping` | Check server reachability |
| POST | `/mac/lock` | Lock the Mac |
| POST | `/mac/imessage/restart` | Restart iMessage |
| GET | `/server/info` | Fetch server metadata such as server version and OS version |
| GET | `/server/restart/soft` | Restart server services |
| GET | `/server/restart/hard` | Restart the whole server app |
| GET | `/server/update/check` | Check whether a server update is available |
| POST | `/server/update/install` | Install the available server update |
| GET | `/server/statistics/totals` | Get totals for handles, messages, chats, and attachments |
| GET | `/server/statistics/media` | Get media totals |
| GET | `/server/statistics/media/chat` | Get media totals grouped by chat |
| GET | `/server/logs?count=...` | Fetch server logs |

## FCM

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/fcm/device` | Register a new FCM device with `name` and `identifier` |
| GET | `/fcm/client` | Fetch current FCM client data |

## Attachments and downloads

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/attachment/{guid}` | Fetch attachment metadata |
| GET | `/attachment/{guid}/download` | Download the attachment bytes |
| GET | `/attachment/{guid}/download?original=true` | Download the original attachment when available |
| GET | `/attachment/{guid}/live` | Download live photo data |
| GET | `/attachment/{guid}/blurhash` | Fetch attachment blurhash bytes |
| GET | `/attachment/count` | Count attachments in the server database |

### Download behavior

- Attachment downloads use `responseType: bytes`.
- Receive timeout is multiplied for large downloads.
- Progress callbacks are exposed for attachment, live photo, blurhash, and generic URL downloads.

## Chats

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/chat/query` | Query chats |
| GET | `/chat/{guid}/message` | Get messages for a specific chat |
| POST | `/chat/{guid}/participant/{method}` | Add or remove a participant |
| POST | `/chat/{guid}/leave` | Leave a chat |
| PUT | `/chat/{guid}` | Rename/update a chat |
| POST | `/chat/new` | Create a new chat |
| GET | `/chat/count` | Count chats |
| GET | `/chat/{guid}` | Fetch a single chat |
| POST | `/chat/{guid}/read` | Mark a chat read |
| POST | `/chat/{guid}/unread` | Mark a chat unread |
| GET | `/chat/{guid}/icon` | Fetch the chat icon |
| POST | `/chat/{guid}/icon` | Set the chat icon |
| DELETE | `/chat/{guid}/icon` | Remove the chat icon |
| DELETE | `/chat/{guid}` | Delete the chat |

### Chat query notes

`POST /chat/query` accepts a JSON body with:

- `with`: related data to include, such as `participants`, `lastmessage`, `sms`, or `archived`
- `offset`, `limit`: paging controls
- `sort`: sort direction

`POST /chat/new` sends:

- `addresses`: recipient list
- `message`: optional initial message
- `service`: chat service
- `method`: `private-api` when enabled, otherwise `apple-script`

## Messages

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/message/count` | Count messages |
| GET | `/message/count/updated` | Count updated messages |
| GET | `/message/count/me` | Count messages from me |
| POST | `/message/query` | Query the message database |
| GET | `/message/{guid}` | Fetch a single message |
| GET | `/message/{guid}/embedded-media` | Download embedded media for digital touch or handwritten messages |
| POST | `/message/text` | Send a text message |
| POST | `/message/attachment` | Send a message with an attachment |
| POST | `/message/multipart` | Send a multipart message with mentions and rich text parts |
| POST | `/message/react` | Send a tapback / reaction |
| POST | `/message/{guid}/unsend` | Unsend a message |
| POST | `/message/{guid}/edit` | Edit a message |
| POST | `/message/{guid}/notify` | Trigger a notification for a message |
| DELETE | `/chat/{guid}/{messageGuid}` | Delete a message from a chat |

### Message query notes

`POST /message/query` accepts a JSON body with:

- `with`: relations to include, such as `chat`, `chats`, `attachment`, `attachments`, `handle`, `chats.participants`, `chat.participants`, or `attributedBody`
- `where`: custom filter expressions
- `sort`: usually `DESC`
- `before`, `after`: pagination bounds
- `chatGuid`: restrict to one chat
- `offset`, `limit`: paging controls
- `convertAttachments`: when `true`, attachments are normalized in the response

### Send message notes

The text-send endpoint accepts:

- `chatGuid`
- `tempGuid`
- `message`
- `method`: usually `apple-script` or `private-api`
- optional private API-only fields such as `effectId`, `subject`, `selectedMessageGuid`, `partIndex`, and `ddScan`

`ddScan` is only added by the client when Private API send is enabled and supported by the detected macOS/server version.

Attachment send accepts multipart form data with:

- file field: `attachment`
- `chatGuid`
- `tempGuid`
- `name`
- `method`
- optional private API fields: `effectId`, `subject`, `selectedMessageGuid`, `partIndex`, `isAudioMessage`

Multipart send accepts an array of parts with text and mention metadata.

Unlike text/attachment send, multipart send payloads do not include a `method` field in the current client implementation.

## Handles and contacts

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/handle/count` | Count handles |
| POST | `/handle/query` | Query handles |
| GET | `/handle/{guid}` | Fetch a single handle |
| GET | `/handle/{address}/focus` | Fetch a handle’s Focus state |
| GET | `/handle/availability/imessage?address=...` | Check whether a recipient is registered with iMessage |
| GET | `/handle/availability/facetime?address=...` | Check whether a recipient is available on FaceTime |
| GET | `/contact` | Fetch all iCloud contacts |
| POST | `/contact/query` | Look up contacts by address list |
| POST | `/contact` | Create contacts on the server |

### Contact notes

- `GET /contact` supports `extraProperties=avatar` to include avatar data.
- `POST /contact/query` accepts `{ "addresses": [...] }`.
- `POST /contact` accepts a list of contact objects.

## Backup and settings

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/backup/theme` | Fetch backup theme JSON |
| POST | `/backup/theme` | Save backup theme JSON |
| DELETE | `/backup/theme` | Delete backup theme JSON |
| GET | `/backup/settings` | Fetch backup settings |
| POST | `/backup/settings` | Save backup settings |
| DELETE | `/backup/settings` | Delete backup settings |

## FaceTime

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/facetime/answer/{callUuid}` | Answer a FaceTime call |
| POST | `/facetime/leave/{callUuid}` | Leave / decline a FaceTime call |

## Scheduled messages

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/message/schedule` | List scheduled messages |
| POST | `/message/schedule` | Create a scheduled message |
| PUT | `/message/schedule/{id}` | Update a scheduled message |
| DELETE | `/message/schedule/{id}` | Delete a scheduled message |

## iCloud and Find My

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/icloud/findmy/devices` | Fetch Find My devices |
| POST | `/icloud/findmy/devices/refresh` | Refresh Find My devices |
| GET | `/icloud/findmy/friends` | Fetch Find My friends |
| POST | `/icloud/findmy/friends/refresh` | Refresh Find My friends |
| GET | `/icloud/account` | Fetch iCloud account info |
| GET | `/icloud/contact` | Fetch the account contact card |
| POST | `/icloud/account/alias` | Update the account alias |

## Generic download helper

The client also exposes a generic download helper for arbitrary URLs. It is used for remote files that are not part of the BlueBubbles API.

## Notes for implementers

- Most requests use the shared `guid` auth token in the query string.
- The app retries certain 502 responses when the origin contains `trycloudflare`.
- For endpoints that return attachments or media, the client expects bytes rather than JSON.
- The response payload is usually consumed from `response.data['data']`.

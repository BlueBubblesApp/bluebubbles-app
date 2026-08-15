# Voice Commands (Google Assistant / Gemini)

"Hey Google, send a BlueBubbles message to Mom."

Android only. The feature is scoped to **conversations that already exist** — an
unmatched recipient is reported as an error rather than guessed at, because a
spoken name doesn't determine the address *or* the service (iMessage vs. SMS) a
new chat would have to be created on.

---

## Why App Actions, and what about Gemini

Google Assistant is being removed from Android phones starting September 2026,
with Gemini taking over. Its successor API for app integration —
[AppFunctions](https://developer.android.com/ai/appfunctions) — is still a
private preview limited to trusted testers, so it isn't something this app can
ship against yet.

What *is* generally available, and what Gemini honors during the transition, is
**App Actions**: built-in intents (BIIs) declared as capabilities in
`res/xml/shortcuts.xml`. That's what this implementation uses. Both assistants
read the same declaration, which is why there's one implementation rather than
two.

Only the Android entry point is assistant-specific. `VoiceCommandService.handleRequest`
takes a plain `VoiceCommandRequest`, so moving to AppFunctions later means
building one of those from a new callsite — the resolution, disambiguation, and
send logic doesn't change.

---

## The two fulfillment paths

Assistants can reach the app in two different ways, and both are handled.

### 1. Deep link (the general case)

`res/xml/shortcuts.xml` declares `actions.intent.SEND_MESSAGE` and
`actions.intent.CREATE_MESSAGE`. Each expands a `<url-template>` into a URI:

```
bluebubbles://voice/send-message?recipient=Mom&text=I%27m%20on%20my%20way
```

`MainActivity` claims the `bluebubbles` scheme with host `voice` in
`AndroidManifest.xml`, so this opens the app like any other deep link and lands
in `IntentsService.handleIntent`.

**Why a deep link and not an explicit intent.** Intent attributes in
`shortcuts.xml` are parsed as *literal strings* — they do not expand
`${applicationId}` or `@string/` references. A hardcoded
`android:targetPackage` would therefore only be correct for one product flavor,
breaking `alpha`, `beta`, and the dev flavors. The URI scheme lives in the
manifest, which every flavor shares.

Each capability also declares a second, parameterless `<intent>`. That's the
required fallback for a vague query, and it just opens the app.

### 2. Shortcut grounding (a named recipient the assistant recognises)

`PushShareTargetsHandler` donates the most recent conversations as dynamic
shortcuts (`ChatsService.shareTargetCount` of them). Each is bound to both
capabilities via `addCapabilityBinding(..., "message.recipient.name", [name])`,
which gives the assistant an inventory of real conversation names to ground
speech against — materially better recognition for names like "Mom" than
free-text transcription.

When a query grounds to one of these, the assistant launches **the shortcut's
own intent**, which already carries `chatGuid`. That path skips name matching
entirely.

These are the same shortcuts that back the system share sheet's direct-share
row; they serve both purposes.

---

## Dart flow

```
IntentsService.handleIntent
  └─ VoiceCommandRequest.parse(data, extras)      ← null for non-voice intents
       └─ VoiceCommandService.handleRequest
            ├─ StartupTasks.waitForUI()
            ├─ resolve chat  (guid → direct | name/address → rank & match)
            ├─ confirm       (skipped when `voiceCommandAutoSend` is on)
            └─ OutgoingMsgHandler.queue(OutgoingMessage(...))
```

`VoiceCommandRequest.parse` reads each parameter from the deep-link query
*and* from intent extras, so it covers either fulfillment path. A bare
`chatGuid` deliberately does **not** count as a voice command — that's an
ordinary notification or launcher-shortcut tap, and it keeps its existing
"just open the chat" behaviour.

### Outcomes

| Situation | What happens |
|---|---|
| Recipient + message text | Confirmation dialog, then send (or send straight away with `voiceCommandAutoSend`) |
| Recipient only | Opens the conversation so the user can dictate the body |
| Confirmation declined | Opens the conversation with the dictated text prefilled — the dictation is never thrown away |
| Several equally-good matches | `showBBListSelector` disambiguation, labelled with the service when titles collide |
| No match | Error dialog naming what was heard |
| No chats synced yet | Error dialog explaining that |
| No recipient at all (fallback intent) | Silently leaves the user on the chat list — not an error |

---

## Matching

`VoiceCommandService.rankChats` scores every non-deleted chat and returns
**everything tied for the best score**. Returning the tied set rather than one
winner is the point: a tie means the app genuinely can't tell which conversation
was meant, and quietly picking one risks sending to the wrong person.

Names are normalized first — lower-cased, punctuation stripped (Unicode letters
preserved, so accented names survive), whitespace collapsed, and the filler
words assistants keep in a transcription dropped ("send a message to **my** mom",
"the family **chat**").

Scoring tiers, strongest first:

| Score | Match |
|---|---|
| 100 | Exact name, or an exact address on a 1:1 chat |
| 85 | One name starts the other ("mom" ↔ "mom smith") |
| 70 | Every spoken word is a word of the candidate, any order |
| 55 | Substring |
| 45 | Every spoken word prefixes a word of the candidate |

Below 45 is treated as no match at all. The 55 and 45 tiers require a query of
at least 3 characters — "jo" prefixes half an address book, and every one of
those hits would tie.

**Groups are matched on their own name, not their participants.** A group with a
display name is scored against that name. A *nameless* group's title is just its
participant list ("Mom, Dad & 2 others"), so "Mom" would substring-match every
group she's in; those hits — and address matches against a group participant —
are capped at 50 so a dedicated 1:1 chat with that person always wins.

---

## Settings

`Settings → Advanced → Voice Commands` explains the feature and exposes one
toggle:

- **Send Without Confirming** (`voiceCommandAutoSend`, default off) — send
  immediately when the command already includes the body. Off by default because
  speech-to-text gets things wrong and an unconfirmed send can't be undone.

### Security note on the deep link

`bluebubbles://voice/...` is a `BROWSABLE` filter on an exported activity, which
is what makes assistant fulfillment work — and also means any app or web page on
the device can fire the same URI. With the default confirmation prompt that's
harmless: the user sees exactly what would be sent and to whom. Turning
**Send Without Confirming** on removes that gate, so a crafted link could send a
message with no interaction. That's the trade-off the setting buys, and the
reason it ships off.

---

## Testing

The deep link can be driven directly, without an assistant:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "bluebubbles://voice/send-message?recipient=Mom&text=testing" \
  com.bluebubbles.messaging
```

Recipient only:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "bluebubbles://voice/send-message?recipient=Mom" \
  com.bluebubbles.messaging
```

Inspect the donated shortcuts and their capability bindings:

```bash
adb shell dumpsys shortcut | grep -A 20 com.bluebubbles.messaging
```

End-to-end assistant behaviour needs a real device signed in to a Google
account, with the app installed from a build whose `shortcuts.xml` the assistant
has indexed — capability discovery is not immediate after install.

---

## Files

| File | Role |
|---|---|
| `android/app/src/main/res/xml/shortcuts.xml` | Capability declarations |
| `android/app/src/main/AndroidManifest.xml` | `bluebubbles://voice` scheme on `MainActivity` |
| `android/.../services/system/PushShareTargetsHandler.kt` | Shortcut donation + capability binding |
| `lib/services/backend/java_dart_interop/voice_command_service.dart` | Parsing, matching, confirmation, send |
| `lib/services/backend/java_dart_interop/intents_service.dart` | Routes voice intents to the service |
| `lib/app/layouts/settings/pages/advanced/voice_commands_panel.dart` | Settings panel |

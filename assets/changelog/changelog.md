# What's new?

Below are the last few BlueBubbles App release changelogs

## 1.11.4

### Changes

- Fixes issue sending attachments if the BlueBubbles server was v1.5.3/v1.5.4, and the Private API was not enabled.
- Audio player will now stop after it completes (rather than repeat)
- Fixes issue where timestamp dividers would not appear on the Samsung theme
- Fixes issue where audio would not pause when leaving a chat or closing the app

## 1.11.3

### The Big Stuff

- QOL improvements and bug fixes from the major rewrite
- Private API Attachment sending
   - Send attachment with effect
   - Send attachment as a reply
   - Voice notes now show up as voice notes for the recipient
- A few other minor new features

### The Nitty Gritty

#### New Features

- Automatically re-upload contacts to server when contacts changes are detected
- Added ability to connect with custom headers
- Added ability to enable read receipts / typing indicators for specific chats without enabling globally
- Connection status now has two categories - REST API connection & socket connection
- Show message sent status and date if tapped on (Material / Samsung)
- Long press camera button starts video recording (iOS)
- Private API Attachment sending
   - Send attachment with effect
   - Send attachment as a reply
   - Voice notes now show up as voice notes for the recipient

#### Bug Fixes

- Fixed issues with matching contacts if phone number starts with "0" for contact
- Fixed message size in message popup when in tablet mode
- Fixed delete chat not working on iOS
- Fixed scheduled message save button not appearing until clicking into the text field
- Fixed connection error messages on setup
- Fixed attachments not showing on first load (Desktop)
- Fixed sharing to app not getting the image when both text and image shared at once
- Fixed issue where app would not clear notifications / mark read on iDevices when actively in the chat
- Fixed issues with filtering unknown senders
- Fixed retrying failed attachment send makes it disappear
- Fixed accessing message details popup would sometimes result in a gray screen
- Fixed popping manually sync messages dialog would pop the underlying page
- Fixed color of navigation bar buttons
- Fixed sending a message to existing chat via chat creator would not send (tablet mode)

#### Improvements

- Added custom renderbox to chat list on samsung theme to fix weird issues with divider lines
- Mark all as read will now fetch chats from database to accurately mark everything as read
- Scheduled message interval field will not clear itself when a bad input is entered (Desktop)
- Improved algorithm for getting initials of contacts
- Reply thread viewer will always take up the whole screen now when in tablet mode
- Added "waiting for iMessage..." indicator when sending attachment
- Updated emoji regex for unicode 15
- Improved audio player design & timestamp display
- Improved design of a few screens in the setup menu
- System titlebar can now be removed properly (Linux)
- Auto submit address in chat creator if the user did not, but is sending a message
- Group events are now parsed more correctly
- Incremental sync now uses local IP override (incremental sync can complete even if proxy is inaccessible)
- Render subjects on interactive messages or attachment messages if they dont have plaintext
- iOS emojis are used in chat titles for the chat details page
- Material theme chat list got some love to look closer to Google Messages
- Audio recordings made from the app should now sound *much* better
- Force square aspect ratio when rendering QR code
- Account for left system padding (e.g. punch hole camera) when rendering message popup

#### Re-added Features

- Confetti effect re-added (Flutter 3.7 crash is fixed)

#### For Developers

- Updated to Flutter 3.7.3
- Parts of backend updated to successfully parse new server payload type (support for encryption)

## 1.11.2

### Changes

- Fixes issue where contact info would not show when searching
- Ability to set a default email for a given handle
- Mentions are now bold (previously was the primary theme color)
- When a 502 Gateway error is hit (for Cloudflare), the request is auto-retried
- The refresh button for the FindMy devices page will actually refresh locations now
- Improved URL preview design
- Better reply generation on swipe to show timestamp
- Fixes issue where media/files were not able to be saved to the device
- Fixes the connection indicator
- Fixes issue where the re-sync handles button would run against servers < v1.5.2

## 1.11.1

### The Big Stuff

- QOL improvements and bug fixes from the major rewrite
- Upgrade to Flutter 3.7
- New method to fully fix contacts issues

### The Nitty Gritty

#### New Features
- New switch design
- Confirmation dialog when deleting chat
- New function to properly reset / fix contacts glitches
- Open chat details when tapping group name in header (Material / Samsung)
- Cancel attachment send
- New camera button on iOS skin

#### Bug Fixes
- Fixed iOS pinned chats not reacting well to divider width changes when in tablet mode
- Fixed tab/enter emoji insertion in text field
- Fixed bugs with current chat highlight on chat list when in tablet mode
- Fixed shape and color of group overflow avatar
- Fixed refresh action overlapping with back button on findmy (Samsung)
- Fixed not being able to save edits to a scheduled message in some cases
- Fixed colors in send effect picker
- Fixed some bugs when going into the message view from search
- Fixed weirdness with deleting chats
- Fixed importing VCF not working
- Fixed rare lateinitializationerror for DB store
- Fixed attachment showing "Unknown" rather than the sender when viewing fullscreen
- Fixed URL preview getting cut off if preview image is too large
- Fixed bug where attachments wouldn't populate in view after opening chat via a notification
- Fixed attachment send timing out during the send
- Fixed rendering bugs when going in and out of tablet mode (rotating phone, disabling tablet mode, etc)

#### Improvements
- Allow for tab / shift+tab to move cursor between text fields
- Made connection indicator global
- Disabled swipe left / right on findmy page
- Detect right click on send button
- Added enter to send when editing a message
- Disabled fingerprint auth on Android 9 and under (to prevent crashes)
- Improved consistency of settings tiles
- Improved typing indicator going away animation
- Improved send animation (Material / Samsung)
- Removed video overlay on replied to widget
- Improved display of unread message counter when over 100

#### Removed Features (Temporarily)
- Confetti effect removed due to a crash on Flutter 3.7

#### For Developers
- Updated targetSdkVersion & compileSdkVersion to 33 (Android 13)
- Updated Java & Dart dependencies
- Updated to Flutter 3.7 / Dart 2.19

## 1.11.0

- Full rewrite of the **entire** app
  - Backend completely redone to reduce potential for bugs and increase maintainability
  - Frontend completely redone to improve performance drastically and make the app prettier & more fun to use 
  - Some stats:
    - 100,000+ lines of code modified
    - 500+ files changed
    - 100+ issues closed
    - 6 months / hundreds of hours in the making
- iMessage parity
  - Display mentions in **bold**
  - Display unsent messages
  - Display edited messages, along with their past edits
  - Display messages with attachments or other rich content in the correct order
  - Allow reacting to individual parts of a message
  - Improved URL previews
  - Display more information for iMessage apps (e.g. Shazam, Apple Pay, YouTube, OpenTable, etc)
  - Unsend sent messages (Ventura Private API)
  - Edit sent messages (Ventura Private API)
  - Send handwritten messages
- View FindMy Devices
- Scheduled messages
- Notification for incoming FaceTimes
- Option to use localhost address for low latency when on server WiFi network
- Choose an app font from nearly 1,400 custom fonts
- Way, way, way too many other changes to count. Bug fixes, performance improvements, new features - you name it, the app got it.

### Removed Features

* Swipe actions on conversation tiles in iOS theme - use long-press for same functionality instead
* Auto-play message effects - not reliable and seamless enough for prime-time
* Reduced number of options in redacted mode

### What's Next?

* 3 letters - take a guess ;) - how else could we follow up an update as big as this one?

## 1.10.1

### Fixes & Optimizations

* Upgraded flutter to v3.3.0.
   - This update should fix the keyboard lag issue some users were experiencing.
* Fixes issue uploading attachments on BlueBubbles Web.
* Fixes issue where a temporary chat mute would not apply properly.
* Fixes issue loading texts from macOS Ventura.
   - This fixes the "Unknown Group Event" issue with macOS Ventura.
* Fixes issue where new messages wouldn't show in an open chat until re-entering the chat.
* App can no longer be flipped upside-down, unless enabled in the Settings.
* Fixes issue where message previews for reactions would always show "You", rather than the real sender.
* Fixes big emoji issue where font size would be extremely large, on some devices.
* Fixes grey advanced theming page when the music theme was enabled.

## 1.10 (Bordeaux)

### The Big Stuff

- Full rewrite of theming system to make the app as pretty as possible
- Bug fixes
- Performance improvements

### The Nitty Gritty

#### New Features
- Theming system rewrite
  - UI Components are now more consistent towards their respective skins
  - Theme colors now apply in much more places throughout the UI
  - Many more options to modify theme colors
  - Simplified customization parameters
  - Buffed Material You - it now reaches much deeper into the UI to truly transform the app towards your system theme
  - Over 85 new default themes - there's something for everyone now!
  - Added visual feedback when tapping items in settings
  - Added transparency settings on Windows Desktop
  - Dialog design has been unified across the entire app
  - Revamped conversation details design
  - Revamped fullscreen media viewer design
  - Gradient backgrounds are now supported on default themes as well
  - Old themes will be completely deactivated, but they are still viewable from the advanced theming menu
- Added wearable actions to notifications (Pebble / Fitbit / etc smartwatches)
- Added support for modifying API Timeout duration
- macOS Ventura support
- Custom emoji font on Web
- Desktop
  - Made notification actions reorderable by dragging

#### Bug Fixes
- Fixed off-center UI components in various places
- Fixed broken audio sending
- Fixed broken audio player
- Fixed app requiring Firebase on setup
  - Firebase remains required when using Ngrok / Cloudflare
- Fixed zoomed in contact photos on notifications and share sheet
- Fixed app crashing after attaching large files
- Fixed "removed" reactions not actually getting removed from the UI
- Fixed stickers not loading in
- Fixed Giphy not working on Web
- Fixed taking photos / videos from camera button in the app would sometimes be unresponsive
- Fixed some issues removing people from chats
   - This may not reflect in the UI immediately still, but a restart of the app will reflect it
- Desktop
  - Fixed link previews
  - Fixed issues with window bounds going off screen
  - Fixed / improved wonky UI elements
  - Removed ability to disable tablet mode
  - Fixed error on convo tile right click
  - Fixed globalkey errors with details popup
  - Fixed appdata migration

#### Improvements
- Asynchronous incremental sync (better performance when loading the app from background)
- Share shortcuts are now set as conversations to interact better with Android system
- Improved contact photo matching (Desktop / Web)
- Don't auto-save interactive message attachments
- Force cloudflare URLs to https
- Request storage permissions when "save sync log" is enabled
- Improved customize theme error snackbar info
- Added detection for large files (> 100mb)
- Laid the groundwork for attributedBody support (mentions) for next update
- Improved Android 12+ splash screen
- Improved performance of loading chat messages

#### For Developers
- Updated targetSdkVersion & compileSdkVersion to 32 (Android 12L)
- Updated gradle plugin
- Updated Java & Dart dependencies

## 1.9.1

### Bug Fixes

* Fixes issues creating new chats
* Fixes issue with scroll-to-bottom when scrolled up in a chat, and trying sending a message
* Fixes invisible icon during setup
* Fixes issues opening external links (i.e. twitter or youtube)
* Fixes missing avatars for chats with no participants
    - A chat having no participants is technically a bug, however, we still want to maintain a good UI

## 1.9.0

### Notes

* Reminder to **not** upgrade to macOS Ventura until further notice

### The Big Stuff

- Material You / Material 3 / Android 12 stretchy scroll theming support
- Conversation bubble notifications (Android 12 and up)
- Full REST API migration, which means better error handling, reliability, and overall UX!
    - This has also given us faster reactions (private API only)
- Chat peek (long press chat)
- Tons of nice bug fixes & improvements (replying via notification is fixed!)
- Migration to Flutter 3.0 - more performance improvements
- Desktop & Web
   - Better contacts support
   - Image paste
   - Better notifications
   - Better scrolling

### The Nitty Gritty

#### New Features

- Material You theming
- Material 3 UI design
- Android 12's stretchy over-scroll indicator
- Conversation bubble notifications
- Sync iMessage group chat icons
- Download original attachment from server (heic, caf, etc) if converted by server
- Added toggle for sent / delivered / received indicators on chat list
- Added option to refresh contacts list manually
- Chat peek when chat long pressed
- Save initial sync log for later analysis
- Rewrite of initial sync code - at least twice as fast and more reliable!
- Added button to report bug (redirect to GitHub issues)
- Added filename and MIME type info to attachment metadata
- Marking as read on one BlueBubbles client now marks as read on all BlueBubbles clients (Private API only)
- Check for server updates on app start
- Desktop
   - Contact photo support
   - Image paste
   - Customizable notification actions
   - Contact photos and avatars in notifications
   - Allow text selection when in the message details popup (Web too)
   - Remember window size and position when relaunching app
   - Added new option to dramatically improve mouse wheel scrolling
   - Option to change mouse wheel scrolling multiplier
   - Ability to send location

#### Bug Fixes

- Fixed replying via notification not working
- Fixed message sending getting bricked if a sent message errors
- Fixed issues where enter to send would not work well with a physical keyboard on Android
- Fixed some issues with downloading videos
- Fixed migration error
- Fixed error when setting up share targets with null icon
- Fixed show/hide dividers option not showing for Samsung skin
- Fixed back button not present on Material and Samsung, and in new chat creator
- Fixed status bar icon brightness
- Fixed clear transcript dialog not popping after clicking confirm
- Fixed theme not updating on system theme (when switching dark -> light)
- Fixed failed to send & connection loss notifications not working on Android 12
- Fixed chat creation dialog on Big Sur+
- Fixed loading theme backups not working
- Fixed reaction sending to the wrong chat if the chat is switched quickly
- Fixed gray screen after changing chat name
- Fixed new chats not loading the name or icon after being created
- Fixed restart iMessage showing as in-progress indefinitely
- Fixed up/down arrow keys not moving through text in the text field
- Fixed IP addresses with http at the front being flagged as "invalid"
- Fixed total chat calculation on initial sync
- Fixed custom avatars not being hidden in redacted mode
- Fixed messages sent with subject text and only emojis as the main body not showing the subject text
- Fixed private API featured message not sending as private API when sent with an attachment
- Fixed group name change sometimes causing a chat to jump to the bottom of the entire list
- Fixed settings menus getting grayed out when spamming them (in tablet mode)
- Fixed gray screen when automatically opening the last used chat on Web
- Fixed group icon change events not showing correctly
- Fixed chats sometimes not loading on Web without a refresh
- Fixed networking and platform-specific related exceptions on Web
- Fixed minor UI bug in notification settings screen
- Desktop
   - Fixed redacted mode not hiding contact names
   - Fixed brick on desktop when server URL changes and new messages are fetched
   - Fixed laggy sliders
   - Contact photos update correctly when they are loaded

#### Improvements

- Full REST API transition
- Improved battery optimization logic
- Improved resolution of avatars in pinned chats, notifications, and share targets
- Improved initial sync code
- Improved Samsung skin coloring and scrolling on chat list
- Show confirmation when attachment is saved locally
- Ask for confirmation before overwriting file on Desktop
- Regenerate thumbnail when re-downloading attachment
- Reworked video preview tap actions
- Rounded corners of 3dot dropdown in iOS and Samsung skin
- Reworked message tail to match iMessage better
- Updated iOS emoji font to iOS 15.4
- Added hover highlight to conversation tiles
- Improved hit-box on reaction widgets
- Reaction widgets are now hidden on El Capitan servers
- Auto open keyboard settings apply when closing error popups
- Scroll chat window to the bottom when sending a message
- Add delay to recording a voice memo after sending a message (to prevent accidental activations)
- Changed URL preview overflow to show as much text as possible, rather than clipping with ellipsis
- Removed portrait mode restriction for tablets in the setup view
- Added support for physical keyboards on Android to cycle through the Discord-style emoji insertion with up/down arrow keys
- Added GitHub Sponsors link to Info page
- Removed attachment chunk size setting (not needed anymore)
- Added signed-in iCloud account to the server metadata
- Upgraded to Flutter 3.0
- Show more attachments per row in conversation details if space is available

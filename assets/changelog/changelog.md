# What's new?

Below are the last few BlueBubbles App release changelogs

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

## v1.8.0

**Note**: For this update, we recommend updating your server to v1.0.0: https://github.com/BlueBubblesApp/bluebubbles-server/releases.

Please be advised that the next client update will require a minimum server version of 0.3.0 or greater!

### The Big Stuff

- Database migration from SQLite to ObjectBox
   - **If you run into any migration errors or black error screens, please let us know via Discord or email! If a close and re-open doesn't fix the error, please fully reset and re-sync the app with your server. If you are missing messages, please use the Manual Sync Messages feature in the chat details page!**
- Material theme UI improvements, and new Samsung skin
   - Samsung skin is in Beta, it may or may not be laggy for you
- Private API Send - send regular messages with the Private API (try it out, the speeds are crazy!) (requires server 0.4.0+, best experience on server 1.0.0)
- Important fixes to message sending and notifications
- Lots and lots and lots of quality of life features, fixes, and improvements
   - You should see improved speed, stability, fluidity, etc
- All-new Desktop app, stable release! Supports Windows & Linux.

### The Nitty Gritty

#### New Features

- Private API Send
- New Material theme UI
- New Samsung skin (Beta)
- Colon emoji insertion like Discord
- Added ability to selectively enable & disable typing indicators and read receipts
- Added ability to resize avatars
- Added box overlay to QR Scanner
- Added support for .tiff and .tif images
- Added green theming to SMS Relay/Text Forwarding chats (again, this is *not* Android SMS support!)
- The text box will now show `iMessage` or `Text Forwarding` to correspond with the type of chat
- The create chat view will now show `iMessage` or `Text Forwarding` to correspond with the type of chat
- Press and hold will now quick react if double-tap for details and quick react are both turned on
- .heic -> .jpg conversion will now be cached, so the lag when opening a chat filled with .heics should only happen once
- Added confirmation dialog before clearing local transcript
- Added easter egg to the initial setup screen (try and find it :P)
- Added show/hide password toggle on manual server password entry
- Added option to choose file path when manually downloading a file
- Added ability to pick address from contacts when adding someone to a group chat
- Added ability to set the order of pinned chats
- Open contact form when name is tapped in Material or Samsung theme
- Added ability to change pin column count on Desktop
- Effects automatically play when received / sent
- Added ability to reorder pinned chats
- **Desktop / Web Features**
   - Added option to disable close to tray
   - Added option to start on boot
   - Added GIF picker
   - Added keyboard shortcuts (see settings > about > keyboard shortcuts for the full list)
   - Support reconfiguring with server using manual entry
   - Added debug option to fetch contacts to debug contacts issues
   - Added download progress to files on web

#### Bug Fixes

- Fixed message lock issue when using Private API send
- Fixed issues with message duplication on new server rewrite
- Fixed issues with notification dots and active chat
- Fixed tapping/clicking outside the chat transcript dialog wouldn't dismiss it
- Fixed issues with contacts not loading when entering via a notification
- Fixed highlighting issues in right click context menu
- Fixed laser rendering in tablet mode
- Fixed big emoji messages don't show effect previews
- Fixed some emojis from smart reply not showing as big emoji
- Fixed system theme not actually switching with the system theme
- Fixed DM notifications appearing with a double name on Samsungs
- Fixed "black screen of death" for a random error with local_authentication
- Fixed issues with stickers crashing the app
- Fixed issues with stickers flashing when sending new texts
- Fixed some issues with stickers not showing - note that GIF stickers are still not supported at this time
- Fixed direction of arrow key scrolling on the message view (Web)
- Fixed adding multiple GIFs to send, and then removing one, would remove all of them
- Fixed message font color not updating after switching themes (Web)
- Fixed files shared from file explorer would not show image previews
- Fixed notification getting cleared when opening a new chat on top of an old chat that had a notification active
- Fixed homescreen shortcuts occasionally losing their contact picture
- Fixed issue where the app would try to render an error message as an image when an attachment failed to download from the server
- Fixed width calculation issues for big emoji when rendering reply lines
- Fixed mark chats read would keep manually mark chats read as "true", when it should be moved back to "false"
- Fixed API timeout errors not being shown to the user
- Fixed a crash that could occur when receiving a new notification
- Fixed messages sometimes showing out of order due to being ordered by ROWID
- Fixed Apple Pay detection
- Fixed IP address not being allowed in manual entry
- Fixed manual entry not allowing setups without firebase set up
- Fixed issues with parsing server versions with an `-alpha` suffix
- Fixed crashes on Android 7 and lower:
   - Replying to a notification in the shade
   - Downloading an attachment
- Fixed issues with downloading non-media in details popup
- Fixed padding on context menu for link previews
- Fixed logs download path on desktop
- Fixed issues with some big emoji showing as small
- Fixed focus loss issues on desktop & web when moving cursor off of the text field
- Fixed details menu not disappearing when items from the more menu are tapped
- Fixed incremental sync occurring instead of a full sync when resetting the app
- Fixed custom avatars and custom colors getting reset
- Fixed issues with chat highlighting on Desktop & Web
- Fixed issues with clearing notifications from the shade
- Fixed text color when playing an effect with colorful bubbles
- Fixed audio player widget on desktop / web
- Fixed gray tile when contact card does not have a name
- Fixed rendering bug when viewing reply threads on web from the message details popup

#### Improvements

- Added some padding under the selected attachments list
- Improved selected text highlight color
- Disable right click for effect on Desktop/Web when no text is in the text field
- Removed sync messages setup screen on Web
- Improved the alignment of stickers on messages
- Improved some theming on the setup screens
- Improved timestamp and client-side naming of settings & theming backups
- Improved some strings here and there
- Improved performance when images load in
- Improved speed of loading chats
- Improved speed of syncing
- Improved smoothness of keyboard animation
- Animation smoothness improvements
- Scrolling smoothness improvements
- Improved speed of opening chat details, compose chat, the message view, and the chat list
- Improved fullscreen photo view UI
- Updated dependencies and updated target SDK to Android 12 for build
- Lowered API request timeout duration from 30sec to 15sec
- Improved support for Cloudflare - now you shouldn't need to cycle WiFi for a new Cloudflare address to connect
- Made split view divider bar thinner
- Added mouse cursor indicator to split view divider bar
- Improved theming on message stats popup
- Removed sent / read / delivered indicators on group chats (since they will only ever show as sent)
- Only use tablet mode when there is sufficient width, not just when the available width > available height
- Hide immersive mode toggle on Desktop and Web
- Allow sliding the divider further to the left on Desktop and Web
- Fill the whole screen when opening an attachment fullscreen when in tablet mode, rather than just the right side
- Improved the details menu popup to be less cluttered and have better alignment and sizing
- Added disclaimer to immersive mode (may cause keyboard jank)
- Improved some text to alleviate confusion
- Improved the speed of initial sync greatly
- Optimized iOS emoji font rendering
- Removed reply option when message has not finished sending
- Removed custom titlebar on gnome Linux
- Shift + Enter will create newline on Linux
- Improved background isolate Java & Dart code
- Invisible ink notifications are now hidden
- Switched to REST API for attachment downloads - improved reliability and speed
- Improved user experience when thumbnails cannot be loaded for a video
- Load high resolution contact photos for pinned chats
- Lots and lots of code cleanup and small optimizations
- Flutter Engine & Framework updates
  - Framework: v2.10.2
  - Engine: v2.16.1

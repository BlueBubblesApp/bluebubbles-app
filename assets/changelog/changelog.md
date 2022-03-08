# What's new?

Below are the last few BlueBubbles App release changelogs

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

## v1.7.1

## Changes

* Adds warning message to let people know to update their server to at minimum, 0.3.0, by February 1st, 2022.
* Fixes some issues with Text Forwarding
* Fixes some issues with not loading chat titles properly
* Better descriptions for certain config options

## v1.7.0

**NOTE**: If you want to try out the new Private API features (or Big Sur Private API), server version v0.3.0 and Private API helper version v0.0.3 are _required_!

## Changes

### The Big Stuff

- Private API support for Big Sur+ (*Intel only Macs*)
- Big Sur+ chat creation (DMs only for right now, we hope to add group chat support via the Private API soon)
- View replies (requires Big Sur and up)
- View message effects
- New Private API features!
   - Rename group chats
   - Add & remove participants from group chats
   - Send effects
   - Send subject lines
   - Send replies (requires Big Sur and up)
- iOS Emojis
- Text Forwarding support (this is *not* Android SMS support, just SMS support for those who have iPhone Text Forwarding / SMS Relay enabled)
- Minor bug fixes & improvements

### The Nitty Gritty

#### New Features

- **Private API Features**
   - Rename group chats
   - Add & remove participants from group chats
   - Send effects
   - Send subject lines
   - Send replies (requires Big Sur and up)
- **UI Features / iMessage Feature Parity**
   - View message effects
   - View replies (requires Big Sur and up)
   - DM chat creation for Big Sur+
   - iOS Emojis
   - Text Forwarding / SMS Relay support
   - Add immersive mode option (make bottom navigation bar transparent and show app contents behind it)
   - Added ability to change font weight (bold / light) of text in theme settings
- Added ability to delete attachments to free up space without resetting the whole app
- Added support for copying the server address when tapping it
- Support underlining multiple phones / emails / links in a single message
- Support translating reaction text ('somebody liked "a message"') if it was sent from a device in another language
- Add incognito keyboard option on Android (when enabled, the keyboard will not store any data as you type)
- Added support for automatically saving pictures to gallery and files to downloads folder
- Added support for generating a chat transcript, either as a plaintext or PDF document
- Completely redesigned setup screen UI

#### Bug Fixes

- Fixed padding for images sent with a message
- Fixed attach recent photo text misalignment
- Fixed off-center icons
- Fixed video preview in attachment picker
- Removed the ability to set .heic images as a custom avatar (it would crash the app)
- Fixed chat creator defaulting to the message text field rather than the participant text field
- Fixed clicking on a selected attachment selects it a second time
- Fixed attachment viewer wouldn't show images past the most recent 25
- Fixed text field text would carry over to a different chat when opening that chat through a notification popup
- Removed empty box when there are no smart replies
- Fixed overlay not disappearing in material mode video player
- Fixed issues with sent / delivered / read receipts not updating
- Fixed reply from notification shade not working
- Fixed reaction alignment for digital touch messages
- Fixed changing color on theme picker dark mode would reset the tab bar selected item to light mode
- **Android fixes**
   - Fixed duplicate notification issue
   - Fixed contact avatars not showing for notifications sometimes
   - Fixed a lot of bugs with unread blue dot
   - Fixed link parsing incorrect with some characters (this will still remain an issue on web and desktop because Google MLKit is unsupported there)
   - Swipe back gesture in tablet mode will now exit the app
   - Fixed .heic images not loading
- **Web fixes**
   - Fixed reactions not displaying in message preview
   - Fixed connection & sync empty header display in settings

#### Improvements

- Moved server statistics to its own dialog to reduce clutter
- Added dismiss button to QR code generation
- Under-the-hood improvements when fetching notifications to fix avatars not loading
- Reduced attach recent photo threshold
- Removed extra notification categories in android settings
- Made server connection dialog continue when pressing enter on the password field
- Improved notification reliability
- Improved speed of launching chat details page
- Hide more database related items on Web, since database is unsupported there
- Hide keyboard when app is not in foreground (mainly to not show the keyboard input method notification)
- Show server details as the first page in tablet mode settings
- When in phone landscape mode, the chat header will shrink to allow more content to show
- When in dark mode, the theme settings will now automatically start in the dark mode tab

## v1.6.0

**NOTE**: Please update your BlueBubbles Server to v0.2.0 for extended capabilities! If you want to try out BlueBubbles Web/Desktop, v0.2.0 is _required_!

## Changes

### The Big Stuff

* Introducing BlueBubbles for Web (BlueBubbles Server v0.2.0 required)!
  - https://bluebubbles.app/web
  - https://bluebubbles.app/web/beta (if you'd like to try out beta features)
  - BlueBubbles Desktop (new) is still in beta. If you'd like to try it out, join our Discord server!
* Fixes empty notification summary (again)
* Delivery/Read indicators for chats
  - Pinned will show an icon, unpinned will show text above the last message date
* Fixes issues with the incorrect last message displaying in the chat list

### The Nitty Gritty

#### New Features
* Adds address, phone number, and email detection within a message
* You can now generate a QR Code on your Android Device to screenshot & save
  - The QRCode will only be valid until your server URL changes (never if Dynamic DNS)
* Additional information is now shown in the Connection & Server Management settings page
* Ability to check for Server updates directly from your Android/Web client
* Icons in the iOS theme are now more iOS-y
* Ability to export contacts to your BlueBubbles server so that other clients (Web & Desktop) can use them

#### Bug Fixes
* Fixes layout issues with Smart Replies
* Fixes duplicate message issue when sending a message with a link (separated by a new line)
* Fixes issues sharing .txt files to BlueBubbles
* Tons of other small fixes and cross-platform enhancements

## v1.5.0

## Changes

### The Big Stuff
* New notification options
* New theming options
  - Ability to dynamically theme the app based on the current song's album cover
  - Ability to copy and save those dynamic themes
* Tablet mode
* Unknown senders tab option
  - Senders with no associated contact info will be separated
* Other new features, UI, and UX improvements

### The Nitty Gritty

#### New Features

- **New Notification Options**
  - Added the option to schedule a reminder for a message by long-pressing the message
  - Added new notification settings page
  - Added the ability to change the notification sound
  - Added the option to disable notifying reactions
  - Added the ability to set global text detection (only notify when a text contains certain words or phrases)
  - Added the ability to mute certain individuals in a chat
  - Added the ability to mute a chat temporarily
  - Added the ability to set text detection on a specific chat - only notify when a text from the specified chat contains certain words or phrases
- **New Theming Options**
   - Added the ability to get background and primary color from album art (requires full notification access)
   - Added the ability to set an animated gradient background for the chat list (gradient is created between background and primary color)
- **Other New Features**
   - Added a better logging mechanism to make it easier to send bug reports to the developers
   - Added ability to add a camera button above the chat creator button like Signal
   - Added "Unknown Senders" tab

#### Bug Fixes

- **UI bugs**
   - Fixed custom bubble color getting reset for new messages
   - Fixed 24hr time not working properly
   - Improved smart reply padding in Material theme
- **UX bugs**
   - Fixed some bugs with the fullscreen photo viewer

#### Improvements

- **UI Improvements**
   - Move pinned chat typing indicator to the avatar so the latest message bubble can always be seen
   - Completely revamped icons for iOS theme to match iOS-style
   - Improved URL preview
   - Removed Camera preview from share menu to reduce lag. Replaced by 2 buttons, camera and video
- **UX Improvements**   
   - Added pagination to incremental sync (messages should load faster)
   - Increased chat page size to reduce visible "lag" when resuming the app from the background

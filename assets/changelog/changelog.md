# What's new?

Below are the last few BlueBubbles App release changelogs

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

## v1.4.1
### Enhancements

* Increases message preview to 2 lines (max)
* Send animation is now smoother & easier to maintain/modify

### Bug Fixes

* Fixes URL preview issues
  - Issue where the favicon would not show
  - Issue where the preview image would show briefly, then disappear
* Fixes notification issues
  - Issue where notifications would not be received, especially after a long sleep period
  - (Hopeful) Issue where the notification summary would persist, even when there were no child notifications
* Fixes Image preview issues
  - Issue where you'd sometimes see a box behind an image preview
  - Issue where an image would show as invalid, even if it's valid
  - Issue where .webp and other unsupported image formats (on the Mac) would disappear after sending

## v1.4.0

### New Features

* Ability to set custom chat icons/logos (local-only)
  - This does not effect other members of the chat
* Ability to swipe away (down) full screen image/attachment viewer
* Ability to export/import settings (and themes) to/from phone storage

### Bug Fixes

* Fixes some issues with DDNS providers (and probably some Ngrok/LocalTunnel connections)
* Fixes issue with webp/tiff images loading improperly
* Fixes issue where the summary notification would persist even if there were no notifications left

## v1.3.0

### The Big Stuff

- Redesigned pinned chats for iOS theme
- Huge settings UI overhaul
- Notification improvements
- Performance and reliability improvements
- Lots of small new features and UI / UX improvements

### The Nitty Gritty

#### New Features

- **Redesigned Pinned Chats**
  - iOS theme now has iOS 14 style "big pins"
  - Overhauled the group avatar icons - they are now arranged in a circle with a customizable max count
  - Group avatar icons now prefer to show avatars with pictures
- **New Options / Settings**
  - Added support for setting the mute/unmute default behavior for videos (media settings)
  - Added support for 24hr time format (misc settings)
  - Added support for double tapping a message to send a quick tapback (conversation settings, and Private API must be enabled)
  - Added support for setting the default number to call
  - Added support for locking the app via pin or biometrics (misc settings)
  - Added support for showing contact avatars in direct chats (conversation settings)
  - Added support for redacting big emojis (redacted mode settings)
  - Added support for setting the swipe direction in the fullscreen attachment viewer (media settings)
  - Added support for customizing swipe actions for the conversation tiles (chat list settings)
  - Added "Restart Private API" button (_requires server v0.1.20_) (connection & server settings, and Private API must be enabled)
- **New Redacted Mode Features**
  - Added redacted mode support to the chat creator
  - Added redacted mode to the server management details (connection URL & others)
- **New Media and Message-Related Features**
  - Added support for pull-to-refresh in the attachment picker menu to load new attachments
  - Added the "info" and "redownload from server" options to the fullscreen video player
  - Added an "open in browser" button in the message details popup for links
  - Added the ability to share text via the message details popup
  - Added the ability to choose multiple files in the share menu
  - Added the ability to choose other apps to load files from via the share menu
- **New Notification-Related Features**
  - Added 30sec timeout and error notification when a message fails to send due to connection loss
  - Notifications are now grouped under a single item
- **Other New Features**
  - Allow any type of URL in the manual configuration setup to support ngrok tcp connections
  - Added support for Android Auto
  - Adaptive Icon support
  - Typing indicators can now show inside the chat list (requires Private API to be enabled)
  - If your last sent message errored, your message preview in the chat list will show that
  - Recipient names/addresses will now always show in the message details popup

#### Bug Fixes

- **System Interaction Bugs**
  - Fixed duplicate apps in app switcher
  - Remove notification in the notification panel when marking a single chat or all chats as read
  - Fixed muted chats still sending notifications in some cases
  - Fixed issue where replying to a notification would crash the app on Android 8 and under
  - Fixed sharing not working when the app is fully closed
  - Fixed sharing to a direct chat would not work if the chat was currently open
  - Fixed conversation shortcuts when long pressing the app icon not working correctly
  - TIFF Images now get handled using the regular file opener widget
- **UI bugs**
  - Fixed ">" indicator not showing for long group names on the message header
  - Fixed animation not working when receiving a chat
  - Hide reaction details when in redacted mode
  - Fixed text box placeholder label
  - Fixed switching from Material theme to iOS theme would make the chat list disappear
  - Fixed overlaps in the message details popup
  - Fixed "unsupported" showing instead of the contact number in the chat creator
  - Fixed license page theming in dark mode
  - Fixed issue where some messages would show up as a link preview
  - Fixed layout issues with "Scroll To Bottom" button
  - Fixed issue where send button would not switch between the send/mic icon in Material theme
- **UX bugs**
  - Fixed some bugs with the audio player
  - Fixed some bugs with chats becoming randomly unpinned
  - Fixed some bugs with the reset app workflow
  - Fixed back button closing app instead of removing selections when in multi-select mode
  - Fixed dupe messages when retrying to send a failed message
  - Fixed "Restart iMessage" button not working
  - Fixed issues with initializing the camera after taking a picture
  - Fixed issue with syncing business chats (they are ignored now)
  - Fixed many issues with URL parsing
  - Fixed camera being used after closing the share sheet in some cases

#### Improvements

- **UI Improvements**
  - Completely redesigned all settings screens
  - Improved padding on setup page indicator
  - Remove "Socket Disconnected" message when the app is in the background
  - Improved unread message indicator in the message view
  - Improved audio player design
  - Use Android-style spinners everywhere when in Material theme
  - Improved details popup layout
  - Added loading indicator when getting chats on startup
  - Added loading indicator to new chat creator when fetching existing chats
  - Improved the image placeholder widgets
  - Added new splash screens
- **UX Improvements**
  - Only show re-download from server if the message has successfully sent
  - The details menu will close after copying message text
  - Added haptic feedback when sending a reaction
  - Improved share menu performance
  - Variable animation speeds for progress circles
  - Warning message now shows when trying to start a new chat when the server is running on Big Sur and up
  - New snackbar style
  - Improved the hitbox for the remove attachment button in the share preview
  - Improved the animation when opening the share menu
  - Added Battery Optimization page to the setup

#### Optimizations

- Migrated the entire app to Nullsafety and Flutter 2.0 - what does this mean for you? Much better stability and lots of under-the-hood optimizations!
- Migrated to new Socket IO plugin
- Migrated to using the GetX package
- **Media & Message-Related Optimizations**
  - Improved smart reply functionality
  - Improved handling of SSL errors for link previews
  - Improved handling of .heic images
  - Improved handling of saving media to the device
  - Improved handling of compressing attachments for better performance & reliability
  - Video thumbnails are now cached to the device
  - Improved logic for getting image dimensions
  - Improved image display widget to be more reliable
- **System Interaction Optimizations**
  - Vastly improved notifications logic to make them more consistent and more reliable
  - Prevent sharing items to the app when setup is incomplete
  - Better support for sharing text & audio attachments
- **Other Optimizations**
  - Avatar quality is now determined by low-memory mode
  - Improved contact matching for weirdly formatted phone numbers
  - Improved under-the-hood logic for chats
  - Improved under-the-hood logic for messages

## v1.2.0

- UX: Adds `%` symbol to the attachment preview quality slider
- UX: Attachment preview quality slider now increments in steps of 5 instead of 10
- UX: Message details popup menu is now re-organized a bit for better user-experience
- UX: Adds better support for .heic images (at partial quality)
- UX: Sets the priority of notifications to `high` in effort to fix notification issues
- New Feature: Ability to start a new conversation within message details popup
- New Feature: Ability to forward a message within message details popup
- New Feature: Ability to rename a conversation (locally on Android only)
- New Feature: Ability to mute/unmute videos from the preview
- New Feature: Redacted mode is now honored in the conversation details page
- New Feature: Settings toggle to enable/disable filtered chats (leave this disabled if you don't have issues)
- Bug Fix: Fixes issue where not all chats would load into your chat list (only top 10)
- Bug Fix: Removes copy options for messages without text (or images)
- Bug Fix: Fixes issue where the recipient's avatar would show for your reactions

## v1.1.1

- Bug Fix: Fixes grey screen when creating a new chat

## v1.1.0

- New Feature: Adds back button to image viewer
- New Feature: Adds contact addresses under their name in the message details page
- New Feature: Adds haptic feedback to camera preview
- New Feature: Ability to mark all chats as read via the 3 dot menu
- New Feature: Message details popup now fades in for a smoother animation
- New Feature: Attachment downloader now animates progress instead of "jumping" progress
- UX: Increases chat page size to 12 for material skin to avoid visual stutters during chat loading
- Bug Fix: Fixes issue where avatar colors were editable even when the option was disabled
- Bug Fix: Fixes issue where you wouldn't be able to delete a message if it wasn't sent
- Bug Fix: Fixes grey box issues in reactions popup
- Bug Fix: Fixes issue where your own reaction wouldn't show an avatar
- Bug Fix: Fixes grey box issues for incoming video attachments
- Bug Fix: Manual mark chat as read button now only shows when auto-mark chat as read is off
- Bug Fix: Fixes attachment details page not having bottom margin/spacing, thus interfering with the navigation bar
- Bug Fix: Fixes attachment downloading issues in the details page

## v1.0.0

This version encompasses all release candidates for the unreleased v0.1.16. I have rolled up and summarized all the changes since v0.1.15 below:

- Official v1.0.0 release!
- New Feature: Smart Replies
- New Feature: Material Theme
- New Feature: Hide Keyboard on Scroll
- New Feature: Open Keyboard on Scroll to Bottom
- New Feature: Swipe to Close Keyboard
- New Feature: Move chat creator button to header
- New Feature: Improved URL previews (faster & cached)
- New Feature: Re-download Attachment (long-press)
- New Feature: Ability to restart iMessage on your Mac
- New Feature: Private API Features are now toggle-able
- New Feature: Delivered Timestamps
- New Feature: Last message texts are now ellipsed
- New Feature: Existing chats now show before contact addresses in share screen
- New Feature: Double-tap to show message details
- New Feature: Chat message search
- New Feature: Redacted Mode
- New Feature: More granular timestamps
- New Feature: Attachment Preview Quality Slider
- New Feature: Colorblind Mode
- New Feature: Ability to restart the BlueBubbles Server, remotely
- New Feature: Show connection indicator in chat
- Bug Fix: Fixes issue where the contact address would not auto-fill the fields when creating a new contact
- Bug Fix: Fixes placeholder text not updating
- Bug Fix: Fixes message subject color
- Bug Fix: Fixes issue with background refreshing happening too much (for contacts & chats)
- Bug Fix: Settings panel header doesn't change on theme change
- Bug Fix: Fixes issues around when read receipts are shown
- Bug Fix: Fixes issues around sharing (direct share & more)
- Bug Fix: Fixes issues around share screen performance
- Bug Fix: Fixes issues with sharing content from other keyboards (Samsung Keyboard, Bitmoji Keyboard, & more)
- Bug Fix: Fixes issue with parsing new Apple Maps locations
- Bug Fix: Improves reliability of QR Scanning
- Bug Fix: Fixes issue loading some emojis as big-emojis
- Bug Fix: Fixes issue with showing duplicate contacts for a chat
- Bug Fix: Fixes issue with message tails not being "fluid"
- Bug Fix: Fixes issue showing invalid attachments
- Bug Fix: Fixes some issues around international phone numbers
- Bug Fix: Fixes issue where a video could not be replayed until you re-entered the chat
- Bug Fix: Fixes issue where the camera preview would not be able to be flipped correctly
- Other: Optimizations to chat syncing
- Other: Optimizations to chat loading
- Other: Optimizations to contact loading
- Other: A ton more...

## v0.1.15

- Adds Option: Send Delay
- Fixes to formatting international numbers
- Adds Option: Show Recipient/Group Name as Text Field Placeholder
- Adds Feature: Custom Avatar Colors
- Fixes issue with loading YouTube previews
- Adds Feature: Sync all messages since a point in time
- Fixes issue with empty chats when Contacts permission is disabled
- Adds Feature: Share Targets
- Fixes issue with preloading chats in the chat selector
- Fixes issue where previous messages will re-animate when sending a new message
- Fixes issue loading chat previews when in share screen
- Fixes issue where chat creator would create a chat if it already existed
- Tons of optimizations and small tweaks
- Tons of other small bug fixes and improvements

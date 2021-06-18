# What's new?

Below are the last few BlueBubbles App release changelogs

## v1.1.0

* New Feature: Adds back button to image viewer
* New Feature: Adds contact addresses under their name in the message details page
* New Feature: Adds haptic feedback to camera preview
* New Feature: Ability to mark all chats as read via the 3 dot menu
* New Feature: Message details popup now fades in for a smoother animation
* New Feature: Attachment downloader now animates progress instead of "jumping" progress
* UX: Increases chat page size to 12 for material skin to avoid visual stutters during chat loading
* Bug Fix: Fixes issue where avatar colors were editable even when the option was disabled
* Bug Fix: Fixes issue where you wouldn't be able to delete a message if it wasn't sent
* Bug Fix: Fixes grey box issues in reactions popup
* Bug Fix: Fixes issue where your own reaction wouldn't show an avatar
* Bug Fix: Fixes grey box issues for incoming video attachments
* Bug Fix: Manual mark chat as read button now only shows when auto-mark chat as read is off
* Bug Fix: Fixes attachment details page not having bottom margin/spacing, thus interfering with the navigation bar
* Bug Fix: Fixes attachment downloading issues in the details page

## v1.0.0

This version encompasses all release candidates for the unreleased v0.1.16. I have rolled up and summarized all the changes since v0.1.15 below:

* Official v1.0.0 release!
* New Feature: Smart Replies
* New Feature: Material Theme
* New Feature: Hide Keyboard on Scroll
* New Feature: Open Keyboard on Scroll to Bottom
* New Feature: Swipe to Close Keyboard
* New Feature: Move chat creator button to header
* New Feature: Improved URL previews (faster & cached)
* New Feature: Re-download Attachment (long-press)
* New Feature: Ability to restart iMessage on your Mac
* New Feature: Private API Features are now toggle-able
* New Feature: Delivered Timestamps
* New Feature: Last message texts are now ellipsed
* New Feature: Existing chats now show before contact addresses in share screen
* New Feature: Double-tap to show message details
* New Feature: Chat message search
* New Feature: Redacted Mode
* New Feature: More granular timestamps
* New Feature: Attachment Preview Quality Slider
* New Feature: Colorblind Mode
* New Feature: Ability to restart the BlueBubbles Server, remotely
* New Feature: Show connection indicator in chat
* Bug Fix: Fixes issue where the contact address would not auto-fill the fields when creating a new contact
* Bug Fix: Fixes placeholder text not updating
* Bug Fix: Fixes message subject color
* Bug Fix: Fixes issue with background refreshing happening too much (for contacts & chats)
* Bug Fix: Settings panel header doesn't change on theme change
* Bug Fix: Fixes issues around when read receipts are shown
* Bug Fix: Fixes issues around sharing (direct share & more)
* Bug Fix: Fixes issues around share screen performance
* Bug Fix: Fixes issues with sharing content from other keyboards (Samsung Keyboard, Bitmoji Keyboard, & more)
* Bug Fix: Fixes issue with parsing new Apple Maps locations
* Bug Fix: Improves reliability of QR Scanning
* Bug Fix: Fixes issue loading some emojis as big-emojis
* Bug Fix: Fixes issue with showing duplicate contacts for a chat
* Bug Fix: Fixes issue with message tails not being "fluid"
* Bug Fix: Fixes issue showing invalid attachments
* Bug Fix: Fixes some issues around international phone numbers
* Bug Fix: Fixes issue where a video could not be replayed until you re-entered the chat
* Bug Fix: Fixes issue where the camera preview would not be able to be flipped correctly
* Other: Optimizations to chat syncing
* Other: Optimizations to chat loading
* Other: Optimizations to contact loading
* Other: A ton more...

## v0.1.15

* Adds Option: Send Delay
* Fixes to formatting international numbers
* Adds Option: Show Recipient/Group Name as Text Field Placeholder
* Adds Feature: Custom Avatar Colors
* Fixes issue with loading YouTube previews
* Adds Feature: Sync all messages since a point in time
* Fixes issue with empty chats when Contacts permission is disabled
* Adds Feature: Share Targets
* Fixes issue with preloading chats in the chat selector
* Fixes issue where previous messages will re-animate when sending a new message
* Fixes issue loading chat previews when in share screen
* Fixes issue where chat creator would create a chat if it already existed
* Tons of optimizations and small tweaks
* Tons of other small bug fixes and improvements

## v0.1.13

- Performance improvements when
  - Loading older messages
  - Scrolling up in the conversation list
  - Sending messages
  - Loading URL previews
  - Downloading attachments
  - Opening share panel
- Adds ability to pick image from gallery when tapping "Pick File"
- Adds tap to restart server
- Fixes contact card widget
- Fixes attachment downloader when chat is open
- Fixes crash when passwords containing "%" and "&" were used on the server
- Fixes attachment fullscreen viewer showing wrong image
- Adds better support for group events
  - You should now see "<Person 1> added <Person 2>" instead of "<Person 1> added someone to the conversation"
- Fixes image loading page
- Limits scroll speed multiplier to 1
- Adds ability to clear a chat's transcript
- Fixes audio message issues
- Fixes avatars for addresses that don't have handles
- Adds better subject support
- Better .caf support
- Fixes issue where cameras would stay open after share menu closes
- Device name is now set based on device (can be seen in server)
- Makes navigation bar color match the current background color
- Socket Error notification changes
  - Adds socket error notification channel so that you can choose to disable the notification
  - Adds ability to click the notification to take you directly to the server management page of the app to restart the server
- Fixes issues with settings panel not properly reflecting the current settings
- Fixes issue where removing an attachment would not fully remove it, thus re-entering the chat would cause the attachment to reappear
- Added ability to take a picture in fullscreen
- Back button in share menu now closes the share menu
- Fixes issue with chats not pre-loading in the chat creator/share menu
- Adds additional setup information to the setup workflow
- Fixes sharing location
- Location widget is now clickable
- Fixes empty map issue
- Added proper error message for ROWID error
- Fixes issues with backing out of full screen camera
- Fixes issue to infinite loading image after cancelling a camera shot
- Adds ability to take video
- Adds dense tile option (Settings > Theme & Style)
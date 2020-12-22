# What's new?

Below are the last few BlueBubbles App release changelogs

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

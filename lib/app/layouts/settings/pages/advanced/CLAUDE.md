# settings/pages/advanced/ — Advanced Settings Panels

Integration-level settings panels for power users and developers.

## Files

| File | Purpose |
|------|---------|
| `firebase_panel.dart` | Firebase project config (API key, project ID, sender ID) for FCM push delivery |
| `private_api_panel.dart` | Private API feature toggles: typing status, read receipts, send-as-SMS fallback, force SMS |
| `redacted_mode_panel.dart` | Redacted Mode settings: hide message content, avatars, names in screenshots |
| `notification_providers_panel.dart` | Configure alternative notification delivery providers (UnifiedPush endpoints) |
| `tasker_panel.dart` | Tasker (Android automation) integration settings and variable export |
| `unified_push.dart` | UnifiedPush distributor selection and configuration |
| `voice_commands_panel.dart` | Google Assistant / Gemini voice command explainer + confirm-before-send toggle (Android only) |

## Related
- Voice commands: `lib/services/backend/java_dart_interop/voice_command_service.dart`, `docs/VOICE_COMMANDS.md`
- Push services: `lib/services/network/firebase/CLAUDE.md` and `lib/services/ui/unifiedpush.dart`
- Settings router: `../CLAUDE.md`

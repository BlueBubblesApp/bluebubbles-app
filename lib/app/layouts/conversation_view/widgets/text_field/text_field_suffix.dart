import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/effects/send_effect_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/audio_player.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/send_button.dart';
import 'package:bluebubbles/app/wrappers/cupertino_icon_wrapper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/ui/chat/send_data.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:path/path.dart';
import 'package:record/record.dart';
import 'package:universal_io/io.dart';

class TextFieldSuffix extends StatefulWidget {
  const TextFieldSuffix({
    super.key,
    required this.subjectTextController,
    required this.textController,
    required this.controller,
    required this.recorderController,
    required this.sendMessage,
    this.isChatCreator = false,
    this.alwaysShowSend = false,
    this.hasInitialAttachments = false,
  });

  final TextEditingController? subjectTextController;
  final TextEditingController textController;
  final ConversationViewController? controller;
  final RecorderController? recorderController;
  final Future<void> Function({String? effect}) sendMessage;
  final bool isChatCreator;

  /// When true the send button is always shown, regardless of whether there
  /// is text or attachments. Used in the chat creator when an existing chat
  /// has been resolved so the user can open the conversation without typing.
  final bool alwaysShowSend;

  /// Mirrors `initialAttachments.isNotEmpty` from the parent TextFieldComponent.
  /// Used in isChatCreator mode to show the send button when attachments are
  /// pre-loaded (e.g. shared from another app) but no text has been typed yet.
  final bool hasInitialAttachments;

  @override
  State<StatefulWidget> createState() => _TextFieldSuffixState();
}

class _TextFieldSuffixState extends State<TextFieldSuffix> with ThemeHelpers {
  final AudioRecorder audioRecorder = AudioRecorder();

  // Cache these values at init to avoid repeated platform checks
  late final bool _isWeb = kIsWeb;
  late final bool _isDesktop = kIsDesktop;

  bool get isChatCreator => widget.isChatCreator;
  bool get alwaysShowSend => widget.alwaysShowSend;

  /// Absolute path the in-progress recording is being written to.
  ///
  /// The recorder is pointed at a path we pick rather than letting it choose its own temp file,
  /// so the memo can still be recovered when `stop()` fails to hand a path back.
  String? _recordingPath;

  /// Android captures to WAV instead of going through `audio_waveforms`' AAC encoder.
  ///
  /// That encoder drives MediaCodec asynchronously and only completes `stop()` once the codec
  /// reports end-of-stream, which on most devices it never does: the future never resolves, the
  /// memo is silently dropped, and the controller stays stuck in its recording state so the next
  /// tap does nothing at all (#3023). Its WAV encoder finalizes the file inline on the platform
  /// thread, so `stop()` always returns. The capture is converted to m4a before it's attached.
  bool get _usesWavCapture => !_isWeb && !_isDesktop && Platform.isAndroid;

  void deleteAudioRecording(String path) {
    File(path).delete();
  }

  /// A stable per-chat destination for the recording, so a leftover file from a discarded memo
  /// gets overwritten instead of piling up in the temp directory.
  File _recordingDestination(String ext) {
    final guid = widget.controller!.chat.guid.characters.where((c) => c.isAlphabetOnly || c.isNumericOnly).join();
    final file = File(join(FilesystemSvc.appDocDir.path, "temp", "recorder", "$guid.$ext"));
    file.createSync(recursive: true);
    return file;
  }

  Future<void> _toggleRecording() async {
    final controller = widget.controller;
    if (controller == null) return;
    controller.showRecording.toggle();

    if (controller.showRecording.value) {
      await _startRecording();
    } else {
      await _stopRecording();
    }
  }

  Future<void> _startRecording() async {
    final controller = widget.controller!;
    try {
      final destination = _recordingDestination(_usesWavCapture ? "wav" : "m4a");
      _recordingPath = destination.path;

      if (_isDesktop) {
        await audioRecorder.start(const RecordConfig(bitRate: 320000), path: destination.path);
        return;
      }

      await widget.recorderController!.record(
        path: destination.path,
        recorderSettings: RecorderSettings(
          androidEncoderSettings: AndroidEncoderSettings(
            androidEncoder: _usesWavCapture ? AndroidEncoder.wav : AndroidEncoder.aacLc,
          ),
          // WAV is uncompressed, so capture at a voice-appropriate rate -- converting to AAC
          // afterwards can't undo an oversized capture.
          sampleRate: _usesWavCapture ? 22050 : 44100,
          bitRate: 320000,
        ),
      );
      // If the recorder still isn't in a recording state after the call,
      // treat it as a failure and reset the UI.
      if (!widget.recorderController!.isRecording) {
        controller.showRecording.value = false;
        showSnackbar("Error", "Failed to start recording. Please check microphone permissions.");
      }
    } catch (e, stack) {
      controller.showRecording.value = false;
      showSnackbar("Error", "Failed to start recording. Please check microphone permissions.");
      Logger.error("Error starting recording", error: e, trace: stack);
    }
  }

  Future<void> _stopRecording() async {
    String? reportedPath;
    try {
      reportedPath = _isDesktop
          ? await audioRecorder.stop()
          // A recorder that never completes must not wedge the text field with no way back.
          : await widget.recorderController!.stop().timeout(const Duration(seconds: 10));
    } catch (e, stack) {
      Logger.error("Error stopping recording", error: e, trace: stack);
    }

    // The recorder only reports its path back on a clean stop, so fall back to the path it was
    // handed rather than throwing the memo away.
    final captured = _recordingOnDisk(reportedPath) ?? _recordingOnDisk(_recordingPath);
    _recordingPath = null;
    if (captured == null) {
      showSnackbar("Error", "Failed to save voice memo. Please try again.");
      return;
    }

    final recording = _usesWavCapture ? await AttachmentsSvc.convertAudioToM4a(captured) : captured;

    final file = PlatformFile(
      name: basename(recording.path),
      path: recording.path,
      bytes: await recording.readAsBytes(),
      size: await recording.length(),
    );

    if (!mounted) return;
    await _showRecordingPreview(file);
  }

  /// Resolves [path] to a recording that actually reached disk with audio in it -- a WAV whose
  /// header was never finalized is 44 bytes of placeholder and nothing else.
  File? _recordingOnDisk(String? path) {
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() <= 44) return null;
    return file;
  }

  Future<void> _showRecordingPreview(PlatformFile file) async {
    await showBBDialog(
      context: context,
      barrierDismissible: false,
      title: "Send it?",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Review your audio snippet before sending it",
            style: context.theme.textTheme.bodyLarge,
          ),
          Container(height: 10.0),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.width * 0.6),
            child: AudioPlayer(
              key: Key("AudioMessage-${file.path}"),
              file: file,
              attachment: null,
            ),
          )
        ],
      ),
      actions: <BBDialogAction>[
        BBDialogAction(
          text: "Discard",
          isDestructive: true,
          onPressed: () {
            deleteAudioRecording(file.path!);
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        BBDialogAction(
          text: "Send",
          isDefault: true,
          onPressed: () async {
            await widget.controller!.send(SendData(
              attachments: [file],
              text: "",
              subject: "",
              isAudioMessage: true,
            ));
            deleteAudioRecording(file.path!);
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      valueListenables: [widget.textController, widget.subjectTextController].nonNulls.toList(),
      builder: (context, values, _) {
        // Extract text checks outside Obx - these are already reactive via MultiValueListenableBuilder
        final hasText = widget.textController.text.isNotEmpty;
        final hasSubject = widget.subjectTextController?.text.isNotEmpty ?? false;

        // For chat creator, we don't have a controller, so skip Obx.
        // Only show the send button when there is actually content to send;
        // otherwise the button is hidden entirely to avoid a no-op tap.
        if (isChatCreator) {
          // When a controller is present (existing chat resolved), use Obx to
          // reactively watch pickedAttachments and respect alwaysShowSend.
          if (widget.controller != null) {
            return Obx(() {
              final hasAttachments = widget.controller!.pickedAttachments.isNotEmpty;
              final canSend = alwaysShowSend || hasText || hasAttachments || widget.hasInitialAttachments;
              if (!canSend) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(3.0),
                child: SendButton(
                  sendMessage: widget.sendMessage,
                  onLongPress: () {},
                ),
              );
            });
          }
          // No controller — check static values only.
          final canSendInCreator = hasText || widget.hasInitialAttachments;
          if (!canSendInCreator) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.all(3.0),
            child: SendButton(
              sendMessage: widget.sendMessage,
              onLongPress: () {},
            ),
          );
        }

        return Obx(() {
          // Only reactive values in Obx scope - controller is guaranteed non-null here
          final hasAttachments = widget.controller!.pickedAttachments.isNotEmpty;
          final showRecording = widget.controller!.showRecording.value && widget.recorderController != null;
          final canSend = alwaysShowSend || hasText || hasSubject || hasAttachments;

          return Padding(
            padding: const EdgeInsets.all(3.0),
            child: AnimatedCrossFade(
              crossFadeState: canSend && !showRecording ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 150),
              firstChild: _RecordingButton(
                isWeb: _isWeb,
                isDesktop: _isDesktop,
                isChatCreator: isChatCreator,
                showRecording: showRecording,
                onPressed: _toggleRecording,
              ),
              secondChild: SendButton(
                sendMessage: widget.sendMessage,
                onLongPress: () {
                  if (widget.controller!.scheduledDate.value != null) return;
                  sendEffectAction(
                    context,
                    widget.controller!,
                    widget.textController.text.trim(),
                    widget.subjectTextController?.text.trim() ?? "",
                    widget.controller!.replyToMessage?.message.guid,
                    widget.controller!.replyToMessage?.partIndex,
                    widget.controller!.chat.guid,
                    widget.sendMessage,
                    widget.textController is MentionTextEditingController
                        ? (widget.textController as MentionTextEditingController).mentionables
                        : [],
                  );
                },
              ),
            ),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    audioRecorder.dispose();

    super.dispose();
  }
}

/// Extracted recording button to reduce Obx rebuild scope and prevent
/// unnecessary rebuilds of the complex recording UI
class _RecordingButton extends StatelessWidget {
  const _RecordingButton({
    required this.isWeb,
    required this.isDesktop,
    required this.isChatCreator,
    required this.showRecording,
    required this.onPressed,
  });

  final bool isWeb;
  final bool isDesktop;
  final bool isChatCreator;
  final bool showRecording;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isWeb) {
      return const SizedBox(height: 32, width: 32);
    }

    return Obx(() {
      final isIOS = SettingsSvc.settings.skin.value == Skins.iOS;

      return TextButton(
        style: TextButton.styleFrom(
          backgroundColor: !isIOS || (isIOS && !isChatCreator && !showRecording)
              ? null
              : !isChatCreator && !showRecording
                  ? context.theme.colorScheme.outline
                  : context.theme.colorScheme.primary.withValues(alpha: 0.4),
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(0),
          maximumSize: isDesktop ? const Size(40, 40) : const Size(32, 32),
          minimumSize: isDesktop ? const Size(40, 40) : const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: !isChatCreator && !showRecording
            ? CupertinoIconWrapper(
                icon: Icon(
                  isIOS ? CupertinoIcons.mic_fill : Icons.mic_none,
                  color: isIOS
                      ? context.theme.colorScheme.outline.withValues(alpha: 0.8)
                      : context.theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              )
            : CupertinoIconWrapper(
                icon: Icon(
                  isIOS ? CupertinoIcons.stop_fill : Icons.stop_circle,
                  color: isIOS ? context.theme.colorScheme.primary : context.theme.colorScheme.onSurfaceVariant,
                  size: 15,
                ),
              ),
        onPressed: onPressed,
      );
    });
  }
}

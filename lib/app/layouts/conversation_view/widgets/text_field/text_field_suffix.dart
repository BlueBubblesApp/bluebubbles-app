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
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:path/path.dart';
import 'package:record/record.dart';
import 'package:system_info2/system_info2.dart';
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
  late final bool _isLinuxArm64 =
      kIsDesktop && Platform.isLinux && SysInfo.kernelArchitecture == ProcessorArchitecture.arm64;

  bool get isChatCreator => widget.isChatCreator;
  bool get alwaysShowSend => widget.alwaysShowSend;

  void deleteAudioRecording(String path) {
    File(path).delete();
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
                isLinuxArm64: _isLinuxArm64,
                isChatCreator: isChatCreator,
                alwaysShowSend: alwaysShowSend,
                showRecording: showRecording,
                controller: widget.controller,
                recorderController: widget.recorderController,
                audioRecorder: audioRecorder,
                onDeleteRecording: deleteAudioRecording,
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
    required this.isLinuxArm64,
    required this.isChatCreator,
    required this.alwaysShowSend,
    required this.showRecording,
    required this.controller,
    required this.recorderController,
    required this.audioRecorder,
    required this.onDeleteRecording,
  });

  final bool isWeb;
  final bool isDesktop;
  final bool isLinuxArm64;
  final bool isChatCreator;
  final bool alwaysShowSend;
  final bool showRecording;
  final ConversationViewController? controller;
  final RecorderController? recorderController;
  final AudioRecorder audioRecorder;
  final Function(String) onDeleteRecording;

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
        child: isLinuxArm64
            ? const SizedBox(height: 40)
            : !isChatCreator && !showRecording
                ? CupertinoIconWrapper(
                    icon: Icon(
                      isIOS ? CupertinoIcons.mic_fill : Icons.mic_none,
                      color: isIOS
                          ? context.theme.colorScheme.outline.withValues(alpha: 0.5)
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
        onPressed: () async {
          if (controller == null) return;
          controller!.showRecording.toggle();

          if (controller!.showRecording.value) {
            // Start recording
            try {
              if (isDesktop) {
                File temp = File(join(
                  FilesystemSvc.appDocDir.path,
                  "temp",
                  "recorder",
                  "${controller!.chat.guid.characters.where((c) => c.isAlphabetOnly || c.isNumericOnly).join()}.m4a",
                ));
                temp.createSync(recursive: true);
                audioRecorder.start(const RecordConfig(bitRate: 320000), path: temp.path);
                return;
              }
              await recorderController!.record(
                sampleRate: 44100,
                bitRate: 320000,
              );
            } catch (e) {
              controller!.showRecording.value = false;
              final msg = e.toString().toLowerCase().contains('space') || e.toString().toLowerCase().contains('storage')
                  ? "Not enough storage space to record audio"
                  : "Failed to start recording";
              showSnackbar("Error", msg);
            }
          } else {
            // Stop recording and show dialog
            late final String? path;
            late final PlatformFile file;

            if (isDesktop) {
              path = await audioRecorder.stop();
              if (path == null) return;
              final _file = File(path);
              file = PlatformFile(
                name: basename(_file.path),
                path: _file.path,
                bytes: await _file.readAsBytes(),
                size: await _file.length(),
              );
            } else {
              path = await recorderController!.stop();
              if (path == null) return;
              final _file = File(path);
              file = PlatformFile(
                name: basename(_file.path),
                path: _file.path,
                bytes: await _file.readAsBytes(),
                size: await _file.length(),
              );
            }

            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                  title: Text("Send it?", style: context.theme.textTheme.titleLarge),
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
                          key: Key("AudioMessage-$path"),
                          file: file,
                          attachment: null,
                        ),
                      )
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: Text(
                        "Discard",
                        style: context.theme.textTheme.bodyLarge!.copyWith(
                          color: Get.context!.theme.colorScheme.primary,
                        ),
                      ),
                      onPressed: () {
                        onDeleteRecording(file.path!);
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                    ),
                    TextButton(
                      child: Text(
                        "Send",
                        style: context.theme.textTheme.bodyLarge!.copyWith(
                          color: Get.context!.theme.colorScheme.primary,
                        ),
                      ),
                      onPressed: () async {
                        await controller!.send(SendData(
                          attachments: [file],
                          text: "",
                          subject: "",
                          isAudioMessage: true,
                        ));
                        onDeleteRecording(file.path!);
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                    ),
                  ],
                );
              },
            );
          }
        },
      );
    });
  }
}

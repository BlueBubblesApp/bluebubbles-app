import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:bluebubbles/app/components/attachment_preview.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class PinnedTileTextBubble extends CustomStateful<ConversationTileController> {
  const PinnedTileTextBubble({
    super.key,
    required this.chat,
    required this.size,
    required super.parentController,
  });

  final Chat chat;
  final double size;

  @override
  State<StatefulWidget> createState() => PinnedTileTextBubbleState();
}

class PinnedTileTextBubbleState extends CustomState<PinnedTileTextBubble, void, ConversationTileController> {
  final bool leftSide = Random().nextBool();
  final List<Worker> _previewWorkers = [];
  String? _requestedDownloadGuid;

  Chat get chat => widget.chat;
  double get size => widget.size;
  // Groups always place the tail on the left (pointing toward the sender icon).
  bool get effectiveLeftSide => chat.isGroup ? true : leftSide;

  @override
  void initState() {
    super.initState();
    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    _previewWorkers.addAll([
      ever(controller.chatState.latestMessage, (_) => _maybeDownloadPreview()),
      ever(controller.chatState.hasUnreadMessage, (_) => _maybeDownloadPreview()),
      ever(SettingsSvc.settings.autoDownload, (_) {
        _requestedDownloadGuid = null;
        _maybeDownloadPreview();
      }),
      ever(SettingsSvc.settings.onlyWifiDownload, (_) {
        _requestedDownloadGuid = null;
        _maybeDownloadPreview();
      }),
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeDownloadPreview());
  }

  @override
  void dispose() {
    for (final worker in _previewWorkers) {
      worker.dispose();
    }
    super.dispose();
  }

  /// Download the latest unread image/video so the pin bubble can show a thumb
  /// without opening the thread.
  void _maybeDownloadPreview() {
    if (!mounted || kIsWeb) return;
    final chatState = controller.chatState;
    if (!chatState.hasUnreadMessage.value) return;
    final lastMessage = chatState.latestMessage.value;
    if (lastMessage == null || lastMessage.isFromMe == true || lastMessage.associatedMessageGuid != null) {
      return;
    }
    if (SettingsSvc.settings.highPerfMode.value) return;
    if (SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideAttachments.value) {
      return;
    }
    if (!SettingsSvc.settings.autoDownload.value) return;

    final attachments = AttachmentPreview.attachmentsFor(lastMessage, chatGuid: chat.guid);
    final preview = AttachmentPreview.firstPreviewableAttachment(attachments);
    if (preview == null) return;
    if (AttachmentsSvc.hasLocalFile(preview)) return;

    final guid = preview.guid;
    if (guid == null || guid.startsWith('temp') || guid == _requestedDownloadGuid) return;
    _requestedDownloadGuid = guid;

    unawaited(_downloadPreview(preview));
  }

  Future<void> _downloadPreview(Attachment attachment) async {
    if (!await AttachmentsSvc.canAutoDownload(requestStoragePermission: false)) {
      _requestedDownloadGuid = null;
      return;
    }
    if (!mounted) return;
    AttachmentDownloader.startDownload(
      attachment,
      onComplete: (_) {
        unawaited(_onPreviewDownloaded(attachment));
      },
      onError: () {
        _requestedDownloadGuid = null;
      },
    );
  }

  Future<void> _onPreviewDownloaded(Attachment attachment) async {
    if (attachment.mimeStart == 'video' && File(attachment.path).existsSync()) {
      await AttachmentsSvc.getVideoThumbnail(attachment.path);
    }
    if (mounted) setState(() {});
  }

  List<Color> getBubbleColors(Message? lastMessage) {
    // Default to the received-bubble color (same as text_bubble.dart for incoming messages).
    List<Color> bubbleColors = [
      context.theme.colorScheme.surfaceContainerHighest,
      context.theme.colorScheme.surfaceContainerHighest,
    ];
    if (lastMessage == null) return bubbleColors;
    if (!SettingsSvc.settings.colorfulAvatars.value &&
        SettingsSvc.settings.colorfulBubbles.value &&
        !lastMessage.isFromMe!) {
      if (lastMessage.handleRelation.target?.color == null) {
        bubbleColors = toColorGradient(lastMessage.handleRelation.target?.address);
      } else {
        bubbleColors = [
          HexColor(lastMessage.handleRelation.target!.color!),
          HexColor(lastMessage.handleRelation.target!.color!).lightenAmount(0.075),
        ];
      }
    }
    return bubbleColors;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chatState = controller.chatState;
      final lastMessage = chatState.latestMessage.value;
      final subtitle = chatState.subtitle.value ?? '';

      final unread = chatState.hasUnreadMessage.value;
      // Null-safe isFromMe: treat null as false (unknown sender → show the bubble)
      final isFromMe = lastMessage?.isFromMe == true;
      if (!unread || lastMessage?.associatedMessageGuid != null || isFromMe || isNullOrEmpty(subtitle)) {
        return const SizedBox.shrink();
      }

      final attachments = lastMessage == null
          ? const <Attachment>[]
          : AttachmentPreview.attachmentsFor(lastMessage, chatGuid: chat.guid);
      final previewAttachment = AttachmentPreview.firstPreviewableAttachment(attachments);
      final showPreview = previewAttachment != null &&
          !SettingsSvc.settings.highPerfMode.value &&
          AttachmentPreview.canShow(previewAttachment, generateVideoThumbnail: true);
      // Prefer a real "1 Photo" label over the stale "Attachment" fallback when
      // we had to re-query attachments that the cached latest message missed.
      final label = showPreview
          ? subtitle
          : _attachmentLabel(attachments, lastMessage) ?? subtitle;

      final background = getBubbleColors(lastMessage).first.withValues(alpha: 0.95);
      return Align(
        // Groups: bubble grows up from its Positioned anchor → top-left align.
        // DMs: center the bubble on the appropriate side.
        alignment:
            chat.isGroup ? Alignment.topLeft : (effectiveLeftSide ? Alignment.centerLeft : Alignment.centerRight),
        child: Padding(
          padding: EdgeInsets.only(
            left: effectiveLeftSide ? size * 0.04 : size * 0.01,
            right: effectiveLeftSide ? size * 0.01 : size * 0.04,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: size * 0.3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.125),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(size * 0.125),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: showPreview ? 2.0 : 3.0,
                          horizontal: showPreview ? 2.0 : 6.0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size * 0.125),
                          color: background,
                        ),
                        child: showPreview
                            ? _previewContent(previewAttachment)
                            : _subtitleText(label, lastMessage),
                      ),
                    ),
                  ),
                ),
              ),
              // Tail renders after the bubble so it paints above the shadow.
              Positioned(
                bottom: -size * 0.06,
                right: effectiveLeftSide ? null : size * 0.05,
                left: effectiveLeftSide ? size * 0.05 : null,
                child: Transform.scale(
                  // scaleY: -1 flips the tail to point downward (it's below the bubble).
                  // scaleX: -1 additionally mirrors horizontally for groups so the
                  // tail points left toward the sender icon.
                  scaleX: chat.isGroup ? -1 : 1,
                  scaleY: -1,
                  child: CustomPaint(
                    size: Size(size * 0.15, size * 0.075),
                    painter: TailPainter(leftSide: effectiveLeftSide, background: background),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// In-memory "1 Photo" text from [attachments] when the cached subtitle is
  /// the empty-relation fallback ("Attachment").
  String? _attachmentLabel(List<Attachment> attachments, Message? lastMessage) {
    if (attachments.isEmpty) return null;
    final msg = Message(
      text: lastMessage?.text,
      subject: lastMessage?.subject,
      hasAttachments: true,
    )..dbAttachments.addAll(attachments);
    return msg.getNotificationText();
  }

  Widget _previewContent(Attachment attachment) {
    final thumbSize = size * 0.45;
    const pad = 2.0;
    return AttachmentPreview(
      attachment: attachment,
      size: thumbSize,
      borderRadius: BorderRadius.circular(max(0, size * 0.125 - pad)),
      generateVideoThumbnail: true,
    );
  }

  Widget _subtitleText(String text, Message? lastMessage) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      maxLines: clampDouble((size ~/ 30).toDouble(), 1, 2).toInt(),
      textAlign: TextAlign.center,
      style: context.theme.textTheme.bodySmall!.copyWith(
        fontSize: (size / 12).clamp(
          context.theme.textTheme.bodySmall!.fontSize! * 0.85,
          double.infinity,
        ),
        color: SettingsSvc.settings.colorfulBubbles.value
            ? getBubbleColors(lastMessage).first.oppositeLightenOrDarken(75)
            : context.theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class TailPainter extends CustomPainter {
  TailPainter({
    Key? key,
    required this.leftSide,
    required this.background,
  });

  final bool leftSide;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = background;
    Path path = Path();

    if (leftSide) {
      path.moveTo(size.width * 0.9355556, size.height * 0.1489091);
      path.cubicTo(size.width, size.height * 0.3262727, size.width * 0.6313889, size.height * 0.5667273,
          size.width * 0.7722222, size.height * 0.8181818);
      path.cubicTo(size.width * 0.8054444, size.height * 0.8875455, size.width * 0.9209444, size.height, size.width,
          size.height);
      path.cubicTo(size.width * 0.7504167, size.height, size.width * 0.2523611, size.height, 0, size.height);
      path.cubicTo(size.width * 0.2253889, size.height * 0.9245455, size.width * 0.2102778, size.height * 0.6476364,
          size.width * 0.5255556, size.height * 0.3018182);
      path.cubicTo(size.width * 0.7247778, size.height * 0.0966364, size.width * 0.8862222, size.height * 0.0308182,
          size.width * 0.9355556, size.height * 0.1489091);
      path.close();
    } else {
      path.moveTo(size.width * 0.0644444, size.height * 0.1489091);
      path.cubicTo(0, size.height * 0.3262727, size.width * 0.3686111, size.height * 0.5667273, size.width * 0.2277778,
          size.height * 0.8181818);
      path.cubicTo(
          size.width * 0.1945556, size.height * 0.8875455, size.width * 0.0790556, size.height, 0, size.height);
      path.cubicTo(size.width * 0.2495833, size.height, size.width * 0.7476389, size.height, size.width, size.height);
      path.cubicTo(size.width * 0.7746111, size.height * 0.9245455, size.width * 0.7987222, size.height * 0.6476364,
          size.width * 0.4744444, size.height * 0.3018182);
      path.cubicTo(size.width * 0.2752222, size.height * 0.0966364, size.width * 0.1137778, size.height * 0.0308182,
          size.width * 0.0644444, size.height * 0.1489091);
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    final oldPainter = oldDelegate as TailPainter;
    return leftSide != oldPainter.leftSide || background != oldPainter.background;
  }
}

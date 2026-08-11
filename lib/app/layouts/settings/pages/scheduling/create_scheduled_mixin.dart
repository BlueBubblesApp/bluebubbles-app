import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;

mixin CreateScheduledMixin<T extends StatefulWidget> on State<T> {
  ScheduledMessage? get existingMessage;

  late final TextEditingController messageController = TextEditingController(text: existingMessage?.payload.message);
  final FocusNode messageNode = FocusNode();
  late final TextEditingController numberController =
      TextEditingController(text: existingMessage?.schedule.interval?.toString() ?? '1');

  late final RxString selectedChat = (existingMessage?.payload.chatGuid ?? '').obs;
  late final RxString schedule = (existingMessage?.schedule.type ?? "once").obs;
  late final RxString frequency = (existingMessage?.schedule.intervalType ?? "daily").obs;
  late final RxInt repeatInterval = (existingMessage?.schedule.interval ?? 1).obs;
  late final Rx<DateTime> date = (existingMessage?.scheduledFor ?? DateTime.now()).obs;
  late final RxBool isEmpty = (existingMessage?.payload.message.isNotEmpty ?? false).obs;

  String? get validationError {
    if (selectedChat.value.isEmpty) return "Please select a chat!";
    if (isEmpty.value) return "Please enter a message!";
    if (date.value.isBefore(DateTime.now())) return "Please pick a date in the future!";
    return null;
  }

  void initForm() {
    if (messageController.text.isEmpty && !isEmpty.value) {
      isEmpty.value = true;
    } else if (isEmpty.value) {
      isEmpty.value = false;
    }
    messageController.addListener(() {
      if (messageController.text.isEmpty && !isEmpty.value) {
        isEmpty.value = true;
      } else if (isEmpty.value) {
        isEmpty.value = false;
      }
    });
    numberController.addListener(() {
      final value = int.tryParse(numberController.text) ?? 1;
      if (repeatInterval.value != value) {
        repeatInterval.value = value;
      }
    });
  }

  Future<void> pickDateTime(BuildContext context) async {
    final picked = await showBBDateTimePicker(context: context, initialDate: date.value);
    if (picked == null) return;
    if (picked.isBefore(DateTime.now())) {
      showSnackbar("Error", "Pick a date in the future!");
      return;
    }
    date.value = picked;
  }

  Future<void> saveScheduledMessage(BuildContext context) async {
    if (date.value.isBefore(DateTime.now())) {
      showSnackbar("Error", "Pick a date in the future!");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
          title: Text(
            "Scheduling message...",
            style: context.theme.textTheme.titleLarge,
          ),
          content: SizedBox(
            height: 70,
            child: Center(
              child: CircularProgressIndicator(
                backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
              ),
            ),
          ),
        );
      },
    );

    final scheduleMap = schedule.value == "once"
        ? {"type": "once"}
        : {"type": "recurring", "interval": repeatInterval.value, "intervalType": frequency.value};

    Response response;
    if (existingMessage != null) {
      response = await HttpSvc.message.updateScheduled(
        existingMessage!.id,
        selectedChat.value,
        messageController.text,
        date.value.toUtc(),
        scheduleMap,
      );
    } else {
      response = await HttpSvc.message.createScheduled(
        selectedChat.value,
        messageController.text,
        date.value.toUtc(),
        scheduleMap,
      );
    }

    if (kIsDesktop) {
      Get.close(1);
    } else {
      Navigator.of(context).pop();
    }

    if (response.statusCode == 200 && response.data != null) {
      final data = existingMessage != null ? existingMessage!.toJson() : response.data['data'];
      if (existingMessage != null) {
        for (String k in response.data['data'].keys) {
          data[k] = response.data['data'][k];
        }
      }
      final message = ScheduledMessage.fromJson(data);
      Navigator.of(context).pop(message);
    } else {
      Logger.error("Scheduled message error: ${response.statusCode}");
      Logger.error(response.data);
      showSnackbar("Error", "Something went wrong!");
    }
  }

  InputDecoration buildMessageDecoration(BuildContext context, {required double borderRadius}) {
    return InputDecoration(
      contentPadding: const EdgeInsets.all(12.5),
      isDense: true,
      isCollapsed: true,
      hintText: "Message",
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: context.theme.colorScheme.outline),
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
      ),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: context.theme.colorScheme.outline),
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: context.theme.colorScheme.primary),
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
      ),
      fillColor: Colors.transparent,
      hintStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(color: context.theme.colorScheme.outline),
    );
  }

  Widget buildMessageTextField(BuildContext context, {required double borderRadius}) {
    return TextField(
      textCapitalization: TextCapitalization.sentences,
      focusNode: messageNode,
      autocorrect: true,
      controller: messageController,
      style: context.theme.extension<BubbleText>()!.bubbleText,
      keyboardType: TextInputType.multiline,
      maxLines: 14,
      minLines: 1,
      selectionControls:
          SettingsSvc.settings.skin.value == Skins.iOS ? cupertinoTextSelectionControls : materialTextSelectionControls,
      enableIMEPersonalizedLearning: !SettingsSvc.settings.incognitoKeyboard.value,
      textInputAction: TextInputAction.newline,
      cursorColor: context.theme.colorScheme.primary,
      cursorHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize! * 1.25,
      decoration: buildMessageDecoration(context, borderRadius: borderRadius),
      onTap: () => HapticFeedback.selectionClick(),
      onSubmitted: (_) => messageNode.unfocus(),
    );
  }
}

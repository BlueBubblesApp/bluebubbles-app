import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyncSettings extends StatelessWidget {
  final controller = Get.find<SetupViewController>();

  @override
  Widget build(BuildContext context) {
    return SetupPageTemplate(
      title: "Sync Messages",
      subtitle: "",
      customSubtitle: NumberOfMessagesText(parentController: controller),
      customMiddle: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: context.theme.colorScheme.properSurface,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Sync Options",
                style: context.theme.textTheme.titleLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                textAlign: TextAlign.center,
              ),
            ),
            NumberOfMessagesSlider(parentController: controller),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    "Skip empty chats",
                    style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface).copyWith(height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  StatefulSwitch(
                    parentController: controller,
                    initial: controller.skipEmptyChats,
                    update: (newVal) {
                      controller.skipEmptyChats = newVal;
                    },
                  ),
                ],
              ),
            ),
            if (!kIsWeb)
              const SizedBox(height: 10),
            if (!kIsWeb)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      "Save sync log to downloads",
                      style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface).copyWith(height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    StatefulSwitch(
                      parentController: controller,
                      initial: controller.saveToDownloads,
                      update: (newVal) {
                        controller.saveToDownloads = newVal;
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      customButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
          ),
        ),
        height: 40,
        child: ElevatedButton(
          style: ButtonStyle(
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
            backgroundColor: MaterialStateProperty.all(Colors.transparent),
            shadowColor: MaterialStateProperty.all(Colors.transparent),
            maximumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
            minimumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
          ),
          onPressed: () {
            final numberOfMessagesPerPage = controller.numberToDownload.clamp(1, double.infinity).toInt();
            final skipEmptyChats = controller.skipEmptyChats;
            final saveToDownloads = controller.saveToDownloads;
            setup.startSetup(numberOfMessagesPerPage, skipEmptyChats, saveToDownloads);

            controller.pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.cloud_download,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                  "Start Sync",
                  style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NumberOfMessagesText extends CustomStateful<SetupViewController> {
  NumberOfMessagesText({required super.parentController});

  @override
  State<StatefulWidget> createState() => _NumberOfMessagesTextState();
}

class _NumberOfMessagesTextState extends CustomState<NumberOfMessagesText, int, SetupViewController> {

  @override
  void updateWidget(int newVal) {
    controller.numberToDownload = newVal;
    super.updateWidget(newVal);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "We will now download the first ${controller.numberToDownload == 0 ? "message" : "${controller.numberToDownload.toString().split(".").first} messages"} for each of your chats.\nYou can see more messages by simply scrolling up in the chat.",
              style: context.theme.textTheme.bodyLarge!.apply(
                fontSizeDelta: 1.5,
                color: context.theme.colorScheme.outline,
              ).copyWith(height: 1),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Note: If the syncing gets stuck, try reducing the number of messages to sync to 1.",
              style: context.theme.textTheme.bodyLarge!.apply(
                color: context.theme.colorScheme.outline,
              ).copyWith(height: 1),
            ),
          ),
        ),
      ],
    );
  }
}

class NumberOfMessagesSlider extends CustomStateful<SetupViewController> {
  NumberOfMessagesSlider({required super.parentController});

  @override
  State<StatefulWidget> createState() => _NumberOfMessagesSliderState();
}

class _NumberOfMessagesSliderState extends CustomState<NumberOfMessagesSlider, int, SetupViewController> {
  double numberOfMessages = 25;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Number of Messages to Sync Per Chat: $numberOfMessages",
            style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface).copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Slider(
          value: numberOfMessages,
          onChanged: (double value) {
            controller.updateNumberToDownload(value.toInt());
            setState(() {
              numberOfMessages = value == 0 ? 1 : value;
            });
          },
          label: numberOfMessages == 0 ? "1" : numberOfMessages.toString(),
          divisions: 10,
          min: 0,
          max: 50,
        ),
      ],
    );
  }
}

class StatefulSwitch extends CustomStateful<SetupViewController> {
  StatefulSwitch({
    required super.parentController,
    required this.initial,
    required this.update
  });

  final bool initial;
  final Function(bool) update;

  @override
  State<StatefulWidget> createState() => _StatefulSwitchState();
}

class _StatefulSwitchState extends CustomState<StatefulSwitch, int, SetupViewController> {
  late bool value;

  @override
  void initState() {
    super.initState();
    value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      activeColor: context.theme.colorScheme.primary,
      activeTrackColor: context.theme.colorScheme.primaryContainer,
      inactiveTrackColor: context.theme.colorScheme.onSurfaceVariant,
      inactiveThumbColor: context.theme.colorScheme.onBackground,
      onChanged: (bool newVal) {
        widget.update.call(newVal);
        setState(() {
          value = newVal;
        });
      },
    );
  }
}

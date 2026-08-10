import 'package:bluebubbles/app/components/bb_slider.dart';
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

  SyncSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SetupPageTemplate(
      title: "Sync Messages",
      subtitle: "",
      customSubtitle: NumberOfMessagesText(parentController: controller),
      belowSubtitle: const SizedBox(height: 10),
      customMiddle: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: context.theme.colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 15, bottom: 5, left: 8, right: 8),
              child: Text(
                "Sync Options",
                style: context.theme.textTheme.titleLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
            NumberOfMessagesSlider(parentController: controller),
            const SizedBox(height: 10),
            TimeFilterDropdown(parentController: controller),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    "Skip empty chats",
                    style: context.theme.textTheme.bodyLarge!
                        .copyWith(color: context.theme.colorScheme.onSurfaceVariant)
                        .copyWith(height: 1.5),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        "Sync group chat icons",
                        style: context.theme.textTheme.bodyLarge!
                            .copyWith(color: context.theme.colorScheme.onSurfaceVariant)
                            .copyWith(height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      StatefulSwitch(
                        parentController: controller,
                        initial: controller.syncGroupChatIcons,
                        update: (newVal) {
                          controller.syncGroupChatIcons = newVal;
                        },
                      ),
                    ],
                  ),
                  Text(
                    "Note: Syncing group chat icons can significantly increase the time it takes to sync chats.",
                    style: context.theme.textTheme.bodySmall!.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  )
                ],
              ),
            ),
            if (!kIsWeb)
              Padding(
                padding: const EdgeInsets.only(left: 40.0, right: 40.0, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      "Save sync log to downloads",
                      style: context.theme.textTheme.bodyLarge!
                          .copyWith(color: context.theme.colorScheme.onSurfaceVariant)
                          .copyWith(height: 1.5),
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
      buttonWrapper: (btn) {
        return Padding(
          padding: const EdgeInsets.only(top: 15),
          child: btn,
        );
      },
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
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            shadowColor: WidgetStateProperty.all(Colors.transparent),
            maximumSize: WidgetStateProperty.all(Size(context.width * 2 / 3, 36)),
            minimumSize: WidgetStateProperty.all(Size(context.width * 2 / 3, 36)),
          ),
          onPressed: () async {
            final numberOfMessagesPerPage = controller.numberToDownload.clamp(1, double.infinity).toInt();
            final skipEmptyChats = controller.skipEmptyChats;
            final saveToDownloads = controller.saveToDownloads;
            final syncGroupChatIcons = controller.syncGroupChatIcons;
            final syncTimeFilter = controller.syncTimeFilter;

            // Init the full sync first so when we go to the next page,
            // the manager is already created.
            // Don't await or else the page won't change.
            setup.startSetup(
                numberOfMessagesPerPage, skipEmptyChats, saveToDownloads, syncGroupChatIcons, syncTimeFilter);

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
              Text("Start Sync",
                  style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class NumberOfMessagesText extends CustomStateful<SetupViewController> {
  const NumberOfMessagesText({super.key, required super.parentController});

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
              style: context.theme.textTheme.bodyLarge!
                  .apply(
                    fontSizeDelta: 1.5,
                    color: context.theme.colorScheme.outline,
                  )
                  .copyWith(height: 1),
            ),
          ),
        )
      ],
    );
  }
}

class NumberOfMessagesSlider extends CustomStateful<SetupViewController> {
  const NumberOfMessagesSlider({super.key, required super.parentController});

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
            style: context.theme.textTheme.bodyLarge!
                .copyWith(color: context.theme.colorScheme.onSurfaceVariant)
                .copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        BBSlider(
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
  const StatefulSwitch({super.key, required super.parentController, required this.initial, required this.update});

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
      onChanged: (bool newVal) {
        widget.update.call(newVal);
        setState(() {
          value = newVal;
        });
      },
    );
  }
}

class TimeFilterDropdown extends CustomStateful<SetupViewController> {
  const TimeFilterDropdown({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _TimeFilterDropdownState();
}

class _TimeFilterDropdownState extends CustomState<TimeFilterDropdown, int?, SetupViewController> {
  // Time filter options in milliseconds
  final Map<String, int?> timeOptions = {
    '1 week': 604800000, // 7 days
    '1 month': 2592000000, // 30 days
    '3 months': 7776000000, // 90 days
    '6 months': 15552000000, // 180 days (default)
    '1 year': 31536000000, // 365 days
    'All time': null, // No filter
  };

  late int? selectedValue;

  @override
  void initState() {
    super.initState();
    selectedValue = controller.syncTimeFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Text(
              "Sync Active Chats Within",
              style: context.theme.textTheme.bodyLarge!
                  .copyWith(color: context.theme.colorScheme.onSurfaceVariant)
                  .copyWith(height: 1.5),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<int?>(
            value: selectedValue,
            dropdownColor: context.theme.colorScheme.surfaceContainerHighest,
            items: timeOptions.entries.map((entry) {
              return DropdownMenuItem<int?>(
                value: entry.value,
                child: Text(
                  entry.key,
                  style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                ),
              );
            }).toList(),
            onChanged: (int? newValue) {
              controller.syncTimeFilter = newValue;
              setState(() {
                selectedValue = newValue;
              });
            },
          ),
        ],
      ),
    );
  }
}

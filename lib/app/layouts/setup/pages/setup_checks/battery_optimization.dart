import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

class BatteryOptimizationCheck extends StatefulWidget {
  const BatteryOptimizationCheck({super.key});

  @override
  State<BatteryOptimizationCheck> createState() => _BatteryOptimizationCheckState();
}

class _BatteryOptimizationCheckState extends State<BatteryOptimizationCheck> with WidgetsBindingObserver {
  /// Null until the first check resolves, so we don't flash "Enabled" on the way in
  bool? _disabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The exemption is granted in a system dialog, so returning to the foreground is the
    // only signal we get that the answer changed.
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final isDisabled = await isBatteryOptimizationDisabled();
    if (!mounted) return;
    setState(() => _disabled = isDisabled);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _disabled;
    return SetupPageTemplate(
      title: "Battery Optimization",
      subtitle:
          "We recommend disabling battery optimization for BlueBubbles to ensure you receive all your notifications.",
      // Full width so the status row stays left-aligned in both states — without it the
      // column shrinks to the status row alone once the button is gone, and the parent
      // centers it.
      belowSubtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  disabled == null
                      ? Icons.hourglass_empty
                      : disabled
                          ? Icons.check_circle
                          : Icons.error_outline,
                  color: disabled == null
                      ? context.theme.colorScheme.outline
                      : disabled
                          ? Colors.green
                          : context.theme.colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  disabled == null
                      ? "Battery Optimization: Checking…"
                      : "Battery Optimization: ${disabled ? "Disabled" : "Enabled"}",
                  style: context.theme.textTheme.bodyLarge!
                      .apply(
                        fontSizeDelta: 1.5,
                        color: disabled == null
                            ? context.theme.colorScheme.outline
                            : disabled
                                ? Colors.green
                                : context.theme.colorScheme.error,
                      )
                      .copyWith(height: 2),
                ),
              ],
            ),
          ),
          // Nothing to prompt for once we already have the exemption — Android has no API
          // to revoke it, so undoing this is a trip to system settings the user makes on
          // their own. The status above updates when they come back either way.
          if (disabled == false)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 13),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
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
                      maximumSize: WidgetStateProperty.all(const Size(200, 36)),
                      minimumSize: WidgetStateProperty.all(const Size(30, 30)),
                    ),
                    onPressed: () async {
                      final optimizationsDisabled = await disableBatteryOptimizations();
                      await _refreshStatus();
                      if (!optimizationsDisabled) {
                        showSnackbar("Error", "Battery optimizations were not disabled. Please try again.");
                      }
                    },
                    child: Shimmer.fromColors(
                      baseColor: Colors.white70,
                      highlightColor: Colors.white,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Go to settings",
                              style:
                                  context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

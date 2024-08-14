import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

class BatteryOptimizationCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SetupPageTemplate(
      title: "Battery Optimization",
      subtitle: "We recommend disabling battery optimization for BlueBubbles to ensure you receive all your notifications.",
      belowSubtitle: FutureBuilder<bool?>(
        future: DisableBatteryOptimization.isAllBatteryOptimizationDisabled,
        initialData: false,
        builder: (context, snapshot) {
          bool disabled = snapshot.data != null && snapshot.data == true;
          if (disabled) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Battery Optimization: ${disabled ? "Disabled" : "Enabled"}",
                  style: context.theme.textTheme.bodyLarge!.apply(
                    fontSizeDelta: 1.5,
                    color: disabled ? Colors.green : context.theme.colorScheme.error,
                  ).copyWith(height: 2)),
              ),
            );
          } else {
            return Padding(
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
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                      backgroundColor: MaterialStateProperty.all(Colors.transparent),
                      shadowColor: MaterialStateProperty.all(Colors.transparent),
                      maximumSize: MaterialStateProperty.all(const Size(200, 36)),
                      minimumSize: MaterialStateProperty.all(const Size(30, 30)),
                    ),
                    onPressed: () async {
                      final optimizationsDisabled = await disableBatteryOptimizations();
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
                          Text("Go to settings", style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

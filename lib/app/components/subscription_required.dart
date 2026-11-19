import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// The paid features, drawn as their tiles are: the same icon and color.
enum ProFeature {
  games("Games", "Playing games needs", Icons.sports_esports_rounded, Color(0xFFD4A72C)),
  stickers("Stickers", "Stickers need", Icons.sticky_note_2_rounded, Color(0xFF5856D6)),
  genmoji("Genmoji", "Genmoji need", Icons.add_reaction_rounded, Color(0xFFFF2D55));

  const ProFeature(this.label, this._needs, this.icon, this.color);

  final String label;
  final String _needs;
  final IconData icon;
  final Color color;

  String get message => "$_needs a BlueBubbles subscription on your server.";
}

/// What a locked feature offers next. The one rule the dialog and [SubscriptionRequiredPanel] share: Learn More once
/// the server, reachable, has said where to get a subscription; otherwise Retry, since offline there's nothing to buy
/// until the server says what it has, and online without a page a recheck is all there is.
enum SubscriptionAction { retry, learnMore }

/// Reads `SubscriptionSvc`'s Rx state: call inside an `Obx` to follow it.
SubscriptionAction get subscriptionAction =>
    !SubscriptionSvc.offline && SubscriptionSvc.purchaseUrl.value != null
        ? SubscriptionAction.learnMore
        : SubscriptionAction.retry;

/// Says [feature] needs a subscription on the server, with Learn More or Retry by [subscriptionAction]; while the
/// server can't be reached to ask, it says it's offline. For a paid feature's entry point when
/// `SubscriptionSvc.locked`: pass [onUnlocked] to open the feature when Retry finds the server back with it.
Future<void> showSubscriptionRequired(
  BuildContext context, {
  required ProFeature feature,
  VoidCallback? onUnlocked,
}) async {
  await showBBDialog(
    context: context,
    // The title is in the content, under the badge
    content: SubscriptionRequiredCard(feature: feature),
    actions: [
      BBDialogAction(text: "Close", onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
      switch (subscriptionAction) {
        SubscriptionAction.retry => BBDialogAction(
            text: "Retry",
            isDefault: true,
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop();
              if (await retrySubscriptionCheck()) {
                onUnlocked?.call();
              } else if (!SubscriptionSvc.offline && context.mounted) {
                // Back, and without the subscription: now that's what to say
                await showSubscriptionRequired(context, feature: feature, onUnlocked: onUnlocked);
              }
            },
          ),
        SubscriptionAction.learnMore => BBDialogAction(
            text: "Learn More",
            isDefault: true,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              openSubscriptionPage();
            },
          ),
      },
    ],
  );
}

/// A locked feature drawn in place of its content (a library grid or view): [SubscriptionRequiredCard] with the
/// [subscriptionAction] button under it, following `SubscriptionSvc` as it changes.
class SubscriptionRequiredPanel extends StatelessWidget {
  const SubscriptionRequiredPanel({super.key, required this.feature});

  final ProFeature feature;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SubscriptionRequiredCard(feature: feature),
        const SizedBox(height: 12),
        Obx(() {
          final action = subscriptionAction;
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            onPressed: action == SubscriptionAction.learnMore ? openSubscriptionPage : retrySubscriptionCheck,
            child: Text(action == SubscriptionAction.learnMore ? "Learn More" : "Retry"),
          );
        }),
      ],
    );
  }
}

/// The feature's badge with a lock, "Subscription Required" and why (or, while the server can't be reached, a cloud and
/// "Server Offline"): the dialog's content, and a locked panel's.
class SubscriptionRequiredCard extends StatelessWidget {
  const SubscriptionRequiredCard({super.key, required this.feature});

  final ProFeature feature;

  @override
  Widget build(BuildContext context) => Obx(() => _build(context, SubscriptionSvc.offline));

  Widget _build(BuildContext context, bool offline) {
    final scheme = context.theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        SizedBox.square(
          dimension: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(child: Icon(feature.icon, size: 34, color: feature.color)),
              ),
              Positioned(
                right: -6,
                bottom: -6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
                  child: Icon(offline ? Icons.cloud_off_rounded : Icons.lock_rounded,
                      size: 16, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          offline ? "Server Offline" : "Subscription Required",
          textAlign: TextAlign.center,
          style: context.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          offline
              ? "Your server can't be reached right now. ${feature.label} will be back when it is."
              : feature.message,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Checks the subscription again, and says so when the server still can't be reached. True when the feature is
/// unlocked now.
Future<bool> retrySubscriptionCheck() async {
  await SubscriptionSvc.refresh();
  if (SubscriptionSvc.offline) {
    showSnackbar("Server Offline", "Your server still can't be reached.", type: SnackbarType.error);
  }
  return !SubscriptionSvc.locked;
}

/// The server's page for getting a subscription, when it gave one. The address comes from the server, so only an
/// `https` page is opened: anything else could launch another app or a local file.
Future<void> openSubscriptionPage() async {
  final url = SubscriptionSvc.purchaseUrl.value;
  if (url == null) return;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    Logger.warn("Ignoring a subscription page that isn't https: $url", tag: "Subscription");
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/legend_grid.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Below this share, a participant's segment is collapsed into "Others" —
/// otherwise a large group renders as unreadable slivers.
const double _kMinSegmentShare = 0.03;

/// Shared participant→color mapping so every chart (balance bar, leaderboard,
/// volume chart, engagement donuts) colors the same person the same way.
Color participantColor(BuildContext context, int participantId, Map<int, ParticipantInfo> participants) {
  if (participantId == kMeParticipantId) return context.theme.colorScheme.primary;
  return _colorForAddress(context, participants[participantId]?.address);
}

/// Deterministic, theme-aware color seeded from a participant's address.
///
/// Unlike [toColorGradient] (used for avatars), which picks from a fixed set
/// of only 7 hues and collides often in groups, this hashes the address into
/// a full 360° hue so distinct participants very rarely land on the same
/// color. Saturation is kept high enough to stay distinguishable even on a
/// muted/desaturated theme, and lightness follows light/dark mode so it never
/// clashes against the current skin.
Color _colorForAddress(BuildContext context, String? address) {
  final hue = _hueFromAddress(address ?? "");
  final primarySaturation = HSLColor.fromColor(context.theme.colorScheme.primary).saturation;
  final saturation = primarySaturation.clamp(0.55, 0.85);
  final lightness = ThemeSvc.inDarkMode(context) ? 0.68 : 0.46;
  return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
}

double _hueFromAddress(String address) {
  if (address.isEmpty) return 210.0;
  int hash = 0;
  for (final unit in address.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return (hash % 360).toDouble();
}

/// N-segment horizontal share bar. Renders two segments for a 1:1 chat and one
/// per participant for a group — same widget either way, no branching at the
/// call site.
class ParticipantBar extends StatelessWidget {
  const ParticipantBar({
    super.key,
    required this.leaderboard,
    required this.participants,
  });

  final List<ParticipantCount> leaderboard;
  final Map<int, ParticipantInfo> participants;

  @override
  Widget build(BuildContext context) {
    final total = leaderboard.fold<int>(0, (a, b) => a + b.count);
    if (total == 0) return const SizedBox.shrink();

    // Local user always leads, regardless of rank, so "your share" sits in a
    // consistent position across every chat.
    final me = leaderboard.where((e) => e.participantId == kMeParticipantId);
    final others = leaderboard.where((e) => e.participantId != kMeParticipantId).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final ordered = [...me, ...others];

    final segments = <_Segment>[];
    ParticipantCount? collapsed;
    for (final entry in ordered) {
      final share = entry.count / total;
      if (entry.participantId != kMeParticipantId && share < _kMinSegmentShare) {
        collapsed = ParticipantCount(-2, (collapsed?.count ?? 0) + entry.count);
        continue;
      }
      segments.add(_Segment(entry, share, _colorFor(context, entry.participantId)));
    }
    if (collapsed != null && collapsed.count > 0) {
      segments.add(_Segment(collapsed, collapsed.count / total, context.theme.colorScheme.outlineVariant));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: SizedBox(
            height: 22.0,
            child: Row(
              children: segments.map((s) {
                return Expanded(
                  flex: (s.share * 1000).round().clamp(1, 1000),
                  child: Container(
                    color: s.color,
                    alignment: Alignment.center,
                    child: s.share >= 0.12
                        ? Text(
                            "${(s.share * 100).round()}%",
                            style: context.theme.textTheme.labelSmall?.copyWith(
                              color: s.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        LegendGrid(items: [
          for (final s in segments)
            (
              label: s.count.participantId == -2
                  ? "Others · ${(s.share * 100).round()}%"
                  : "${participants[s.count.participantId]?.displayName ?? "Unknown"} · ${(s.share * 100).round()}%",
              color: s.color,
            ),
        ]),
      ],
    );
  }

  Color _colorFor(BuildContext context, int participantId) => participantColor(context, participantId, participants);
}

class _Segment {
  final ParticipantCount count;
  final double share;
  final Color color;
  const _Segment(this.count, this.share, this.color);
}

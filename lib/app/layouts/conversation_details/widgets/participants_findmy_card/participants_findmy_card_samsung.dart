import 'package:bluebubbles/app/layouts/conversation_details/widgets/participants_findmy_card/participants_findmy_card_shared.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ParticipantsFindMyMapCardSamsung extends StatelessWidget {
  final ParticipantsFindMyCardViewModel vm;

  const ParticipantsFindMyMapCardSamsung({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Material(
          color: context.headerColor,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: vm.sheetOpen ? null : vm.openExpandedMap,
            child: Column(
              children: [
                buildFindMyMapPreview(context, vm),
                _ParticipantsFindMyFooterSamsung(vm: vm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantsFindMyFooterSamsung extends StatelessWidget {
  final ParticipantsFindMyCardViewModel vm;

  const _ParticipantsFindMyFooterSamsung({required this.vm});

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = context.theme.textTheme.bodyMedium?.copyWith(
      color: context.theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      height: vm.footerHeight + 4,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: context.tileColor,
      child: Row(
        children: [
          Icon(
            Icons.place_outlined,
            size: 20,
            color: context.theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vm.isGroup ? vm.groupTitle : (vm.locationTitle ?? 'Loading Location'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleMedium,
                ),
                if (vm.isLoadingParticipants)
                  Text(
                    'Loading location...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  )
                else if (vm.isGroup)
                  Text(
                    groupParticipantLabel(vm.visibleParticipants.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  )
                else
                  Text(
                    locationStateLabel(vm.visibleParticipants.first),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 22,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

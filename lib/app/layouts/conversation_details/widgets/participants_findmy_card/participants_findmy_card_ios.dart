import 'package:bluebubbles/app/layouts/conversation_details/widgets/participants_findmy_card/participants_findmy_card_shared.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ParticipantsFindMyMapCardIOS extends StatelessWidget {
  final ParticipantsFindMyCardViewModel vm;

  const ParticipantsFindMyMapCardIOS({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Material(
          color: context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: vm.sheetOpen ? null : vm.openExpandedMap,
            child: Column(
              children: [
                buildFindMyMapPreview(context, vm),
                _ParticipantsFindMyFooter(vm: vm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantsFindMyFooter extends StatelessWidget {
  final ParticipantsFindMyCardViewModel vm;

  const _ParticipantsFindMyFooter({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: vm.footerHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: context.tileColor,
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 18,
            color: context.theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vm.isGroup ? vm.groupTitle : (vm.locationTitle ?? 'Loading Location'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleSmall,
                ),
                if (vm.isLoadingParticipants)
                  Text(
                    'Loading…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall,
                  )
                else if (vm.isGroup)
                  Text(
                    groupParticipantLabel(vm.visibleParticipants.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall,
                  )
                else
                  Text(
                    locationStateLabel(vm.visibleParticipants.first),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

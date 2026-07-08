import 'package:bluebubbles/app/layouts/conversation_details/widgets/participants_findmy_card/participants_findmy_card_shared.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ParticipantsFindMyMapCardMaterial extends StatelessWidget {
  final ParticipantsFindMyCardViewModel vm;

  const ParticipantsFindMyMapCardMaterial({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Material(
          color: context.headerColor,
          child: InkWell(
            onTap: vm.sheetOpen ? null : vm.openExpandedMap,
            child: Column(
              children: [
                buildFindMyMapPreview(context, vm),
                _ParticipantsFindMyFooterMaterial(vm: vm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantsFindMyFooterMaterial extends StatelessWidget {
  final ParticipantsFindMyCardViewModel vm;

  const _ParticipantsFindMyFooterMaterial({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: vm.footerHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: context.tileColor,
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
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
                  style: context.theme.textTheme.titleSmall,
                ),
                if (vm.isLoadingParticipants)
                  Text(
                    'Loading location...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else if (vm.isGroup)
                  Text(
                    groupParticipantLabel(vm.visibleParticipants.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    locationStateLabel(vm.visibleParticipants.first),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Icon(
              Icons.open_in_full,
              size: 18,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

/// Developer Tools panel that scans local handles for a missing
/// [Handle.originalROWID] (the server-side ROWID used to link messages to
/// their sender) and offers a way to try and repair them by re-fetching the
/// handle from the server by address.
class HandleAuditPanel extends StatefulWidget {
  const HandleAuditPanel({super.key});

  @override
  State<HandleAuditPanel> createState() => _HandleAuditPanelState();
}

class _HandleAuditPanelState extends State<HandleAuditPanel> with ThemeHelpers {
  bool _loading = true;
  bool _remediating = false;
  int _totalHandles = 0;
  List<HandleAuditResult> _results = [];

  int get _missingCount => _results.length;

  double get _missingPercent => _totalHandles == 0 ? 0 : (_missingCount / _totalHandles) * 100;

  bool get _hasRemediableEntries =>
      _results.any((r) => r.status == HandleAuditStatus.pending || r.status == HandleAuditStatus.stillMissing ||
          r.status == HandleAuditStatus.notFoundOnServer || r.status == HandleAuditStatus.error);

  /// Keeps anything still needing attention above already-repaired entries,
  /// so a lone unresolved handle never ends up buried below a long list of
  /// resolved ones.
  void _sortResults() {
    _results.sort((a, b) {
      final aDone = a.status == HandleAuditStatus.repaired ? 1 : 0;
      final bDone = b.status == HandleAuditStatus.repaired ? 1 : 0;
      if (aDone != bDone) return aDone - bDone;
      return a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase());
    });
  }

  @override
  void initState() {
    super.initState();
    _runAudit();
  }

  Future<void> _runAudit() async {
    if (kIsWeb) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (mounted) setState(() => _loading = true);

    final total = await runAsync(() => Database.handles.count());
    final query = Database.handles.query(Handle_.originalROWID.isNull()).build();
    final missing = await runAsync(() => query.find());
    query.close();

    final results = missing
        .map((h) => HandleAuditResult(
              handleId: h.id!,
              address: h.address,
              service: h.service,
              // Handle.displayName can resolve to an empty string (e.g. an
              // unformatted, empty, or otherwise unresolvable address with no
              // matched contact) — never let a row render with nothing
              // identifying it.
              displayLabel: !isNullOrEmpty(h.displayName)
                  ? h.displayName
                  : (!isNullOrEmpty(h.address) ? h.address : "Handle #${h.id}"),
              hasContact: h.contactsV2.isNotEmpty,
              country: h.country,
            ))
        .toList();

    if (!mounted) return;
    setState(() {
      _totalHandles = total;
      _results = results;
      _loading = false;
      _sortResults();
    });
  }

  Future<void> _remediateAll() async {
    if (_remediating || !_hasRemediableEntries) return;
    setState(() => _remediating = true);

    int repaired = 0;
    int totalRelinked = 0;
    for (final result in _results) {
      if (result.status == HandleAuditStatus.repaired) continue;

      if (mounted) setState(() => result.status = HandleAuditStatus.remediating);

      try {
        // The server treats the address as the "guid" for this route.
        final response = await HttpSvc.handle.handle(result.address);
        final handleData = response.data?['data'];

        if (handleData is! Map) {
          if (mounted) setState(() => result.status = HandleAuditStatus.notFoundOnServer);
          continue;
        }

        final serverHandle = Handle.fromMap(handleData.cast<String, dynamic>());
        if (serverHandle.originalROWID == null) {
          // The server itself has no originalROWID for this address — nothing we can do locally.
          if (mounted) setState(() => result.status = HandleAuditStatus.stillMissing);
          continue;
        }

        final saved = await serverHandle.saveAsync(matchOnOriginalROWID: false);
        if (saved.originalROWID == null) {
          if (mounted) setState(() => result.status = HandleAuditStatus.stillMissing);
          continue;
        }

        // Mirror MessageHandleRelationshipMigration: now that this handle has a
        // real originalROWID again, re-attach any message whose handleId points
        // at it but whose handleRelation was left unset because the lookup
        // failed at save time.
        final relinked = await Message.relinkMessagesToHandle(
          handleId: saved.originalROWID!,
          localHandleId: saved.id!,
        );

        repaired++;
        totalRelinked += relinked;
        if (mounted) {
          setState(() {
            result.status = HandleAuditStatus.repaired;
            result.relinkedMessageCount = relinked;
          });
        }
      } catch (e, s) {
        // JSON API errors resolve as a `Response` carrying the real status code
        // (see ApiInterceptor.onError) rather than throwing a DioException.
        if (e is Response && e.statusCode == 404) {
          if (mounted) setState(() => result.status = HandleAuditStatus.notFoundOnServer);
        } else {
          Logger.error("Failed to remediate handle ${result.address}", error: e, trace: s);
          if (mounted) setState(() => result.status = HandleAuditStatus.error);
        }
      }
    }

    if (mounted) {
      setState(() {
        _remediating = false;
        _sortResults();
      });
    }
    showSnackbar(
      "Remediation Complete",
      "Repaired $repaired of ${_results.length} handle(s). Relinked $totalRelinked orphaned message(s).",
    );
  }

  Future<void> _confirmDeleteHandle(HandleAuditResult result) async {
    final bool? confirmed = await showBBDialog<bool>(
      context: context,
      title: "Delete Handle?",
      body: "This will permanently delete \"${result.displayLabel}\" (${result.address}) from this device. "
          "Any messages already linked to it will no longer show a sender for it. This cannot be undone.",
      actions: [
        BBDialogAction(
          text: "Cancel",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
        ),
        BBDialogAction(
          text: "Delete",
          isDestructive: true,
          color: Colors.redAccent,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );

    if (confirmed != true) return;

    try {
      Handle.delete(result.handleId);
      if (!mounted) return;
      setState(() {
        _results.remove(result);
        if (_totalHandles > 0) _totalHandles -= 1;
      });
      showSnackbar("Handle Deleted", "Removed \"${result.displayLabel}\" from this device.");
    } catch (e, s) {
      Logger.error("Failed to delete handle ${result.address}", error: e, trace: s);
      showSnackbar("Error", "Failed to delete handle: ${e.toString()}");
    }
  }

  Color _statusColor(HandleAuditStatus status) {
    switch (status) {
      case HandleAuditStatus.repaired:
        return Colors.green;
      case HandleAuditStatus.remediating:
        return Colors.blueAccent;
      case HandleAuditStatus.stillMissing:
      case HandleAuditStatus.notFoundOnServer:
        return Colors.orangeAccent;
      case HandleAuditStatus.error:
        return Colors.redAccent;
      case HandleAuditStatus.pending:
        return context.theme.colorScheme.outline;
    }
  }

  IconData _statusIcon(HandleAuditStatus status) {
    switch (status) {
      case HandleAuditStatus.repaired:
        return Icons.check_circle;
      case HandleAuditStatus.remediating:
        return Icons.sync;
      case HandleAuditStatus.stillMissing:
      case HandleAuditStatus.notFoundOnServer:
        return Icons.warning_amber_rounded;
      case HandleAuditStatus.error:
        return Icons.error;
      case HandleAuditStatus.pending:
        return Icons.help_outline;
    }
  }

  String _statusLabel(HandleAuditStatus status) {
    switch (status) {
      case HandleAuditStatus.repaired:
        return "Repaired";
      case HandleAuditStatus.remediating:
        return "Remediating...";
      case HandleAuditStatus.stillMissing:
        return "Missing on server";
      case HandleAuditStatus.notFoundOnServer:
        return "Not found";
      case HandleAuditStatus.error:
        return "Failed";
      case HandleAuditStatus.pending:
        return "Needs repair";
    }
  }

  Widget _buildSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _missingCount == 0
                ? "All $_totalHandles handle(s) have an originalROWID."
                : "$_missingCount of $_totalHandles handle(s) are missing an originalROWID "
                    "(${_missingPercent.toStringAsFixed(1)}%).",
            style: context.theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            "A missing originalROWID means new messages from that sender may fail to link to the "
            "correct handle, and could be filtered out of the conversation entirely.",
            style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      safeAreaTop: true,
      appBar: BBAppBar(
        titleText: "Handle Audit",
        leading: buildBackButton(context),
        backgroundColor: Colors.transparent,
        toolbarHeight: kIsDesktop ? 90 : 50,
        actions: [
          if (!_loading && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _hasRemediableEntries && !_remediating ? _remediateAll : null,
                child: _remediating ? buildProgressIndicator(context, size: 20) : const Text("Remediate All"),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(child: buildProgressIndicator(context))
          : CustomScrollView(
              physics: ThemeSwitcher.getScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildSummary()),
                if (_results.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          "No handles are missing an originalROWID.",
                          style: context.theme.textTheme.labelLarge,
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final result = _results[index];
                        final needsAttention = result.status != HandleAuditStatus.repaired;
                        final addressLabel = !isNullOrEmpty(result.address) ? result.address : "(no address on file)";

                        // Extra context, packed into one compact line so the
                        // list stays scannable even with many faulty handles.
                        final metaLine = [
                          result.service == 'iMessage' ? addressLabel : "$addressLabel (${result.service})",
                          "#${result.handleId}",
                          if (!isNullOrEmpty(result.country)) result.country!,
                          if (!result.hasContact) "No Contact",
                        ].join(' • ');

                        return Container(
                          // Unresolved rows get a subtle tint so a single flagged
                          // handle doesn't get lost/overlooked in an otherwise-empty list.
                          color: needsAttention ? _statusColor(result.status).withValues(alpha: 0.08) : null,
                          child: ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Icon(_statusIcon(result.status), color: _statusColor(result.status)),
                            title: Text(result.displayLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  metaLine,
                                  style: context.theme.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((result.relinkedMessageCount ?? 0) > 0)
                                  Text(
                                    "Relinked ${result.relinkedMessageCount} orphaned message(s)",
                                    style: context.theme.textTheme.bodySmall?.copyWith(color: Colors.green),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _statusLabel(result.status),
                                  style: context.theme.textTheme.bodySmall?.copyWith(
                                    color: _statusColor(result.status),
                                    fontWeight: needsAttention ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  tooltip: "Delete Handle",
                                  color: Colors.redAccent,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: result.status == HandleAuditStatus.remediating || _remediating
                                      ? null
                                      : () => _confirmDeleteHandle(result),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: _results.length,
                    ),
                  ),
                if (kIsDesktop) const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }
}

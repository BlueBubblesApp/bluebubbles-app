import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/backend/interfaces/storage_interface.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/isolates/isolate_event.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

/// Owns filter state, dispatches analysis runs, and is the sole consumer of
/// [IsolateEvent.storageAnalysisProgress] — applying the `runId` filter that
/// keeps a stale run's events from corrupting the currently-displayed progress.
class StorageAnalyzerController extends GetxController {
  // Filters — settable before the first analysis, per the requirement that
  // both parameters are visible and editable from the empty state.
  final Rxn<Chat> selectedChat = Rxn<Chat>();
  final Rx<StorageAgeFilter> ageFilter = StorageAgeFilter.all.obs;

  final Rxn<StorageAnalysisResult> result = Rxn<StorageAnalysisResult>();
  final Rx<StorageAnalysisProgress> progress = const StorageAnalysisProgress.idle().obs;
  final RxnString error = RxnString();

  /// Segment types the user has toggled on for deletion (Task 08). Cleared
  /// whenever a fresh analysis lands, since old selections may no longer
  /// correspond to what's on screen.
  final RxSet<StorageSegmentType> selectedSegments = <StorageSegmentType>{}.obs;

  String? _currentRunId;
  late final void Function(dynamic) _onProgress = _handleProgressEvent;

  @override
  void onInit() {
    super.onInit();
    GetIt.I<GlobalIsolate>().addEventListener(IsolateEvent.storageAnalysisProgress, _onProgress);
    // Re-run automatically once the user has already analyzed at least once —
    // before that, the empty state's explicit "Analyze" button is the only
    // trigger, per the plan's "both filters settable up front" requirement.
    //
    // `analyze()` is deferred to a microtask rather than called directly: this
    // listener fires synchronously from inside the filter Rx's own
    // `notifyChildren` call (GetX's Rx streams are sync broadcast streams),
    // so setting other Rx fields (`result`, `progress`) in there re-enters
    // notifyChildren mid-dispatch and trips GetX's "improper use of
    // GetX/Obx" reentrancy warning. A microtask breaks out of that call stack.
    everAll([selectedChat, ageFilter], (_) {
      if (result.value != null) Future.microtask(analyze);
    });
  }

  @override
  void onClose() {
    GetIt.I<GlobalIsolate>().removeEventListener(IsolateEvent.storageAnalysisProgress, _onProgress);
    super.onClose();
  }

  Future<void> analyze() async {
    final runId = const Uuid().v4();
    _currentRunId = runId;

    selectedSegments.clear();
    error.value = null;
    // Drop the previous result immediately — the progress branch takes
    // priority in the UI while `stage != null`, but clearing this too means
    // a failed refresh can't fall through and silently re-show stale numbers.
    result.value = null;
    progress.value = StorageAnalysisProgress(
      stage: StorageAnalysisStage.indexing,
      processed: 0,
      total: 0,
      bytesSoFar: 0,
    );

    try {
      final r = await StorageInterface.analyze(
        chatGuid: selectedChat.value?.guid,
        ageFilter: ageFilter.value,
        runId: runId,
      );
      // A newer run may have started (and completed, or errored) while this
      // one was in flight — a stale result must never clobber a fresher one.
      if (_currentRunId != runId) return;
      result.value = r;
    } catch (e) {
      if (_currentRunId != runId) return;
      error.value = e.toString();
    } finally {
      if (_currentRunId == runId) {
        progress.value = const StorageAnalysisProgress.idle();
      }
    }
  }

  void _handleProgressEvent(dynamic data) {
    final map = data as Map<String, dynamic>;
    if (map['runId'] != _currentRunId) return; // superseded run — drop it

    progress.value = StorageAnalysisProgress(
      stage: StorageAnalysisStage.values.byName(map['stage'] as String),
      processed: map['processed'] as int,
      total: map['total'] as int,
      bytesSoFar: map['bytes'] as int,
    );
  }

  void toggleSegment(StorageSegmentType type) {
    if (selectedSegments.contains(type)) {
      selectedSegments.remove(type);
    } else {
      selectedSegments.add(type);
    }
  }

  int get selectedBytes => result.value?.segments
          .where((s) => selectedSegments.contains(s.type))
          .fold<int>(0, (a, s) => a + s.bytes) ??
      0;
}

import "package:bluebubbles/app/layouts/findmy/findmy_refresh_progress.dart";
import "package:bluebubbles/database/models.dart";
import "package:flutter_test/flutter_test.dart";

FindMyFriend friend({String? rawAddress, String? hydratedAddress}) => FindMyFriend(
  latitude: null,
  longitude: null,
  longAddress: null,
  shortAddress: null,
  title: null,
  subtitle: null,
  handle: hydratedAddress == null ? null : Handle(address: hydratedAddress),
  handleAddress: rawAddress,
  lastUpdated: null,
  status: null,
  locatingInProgress: false,
  favoriteOrder: null,
);

void main() {
  test("counts only expected friends updated after the session begins", () {
    final progress = FindMyRefreshProgress.start().withRoster(["alice", "bob"]).withUsableEvent("alice");

    expect(progress.updated, 1);
    expect(progress.total, 2);
    expect(progress.pending, 1);
  });

  test("ignores duplicate, unknown, blank, and missing identifiers", () {
    final progress = FindMyRefreshProgress.start()
        .withRoster(["alice", "bob", "", null])
        .withUsableEvent("alice")
        .withUsableEvent("alice")
        .withUsableEvent("unknown")
        .withUsableEvent("")
        .withUsableEvent(null);

    expect(progress.updated, 1);
    expect(progress.total, 2);
    expect(progress.pending, 1);
    expect(progress.wasUpdated("alice"), isTrue);
    expect(progress.wasUpdated("unknown"), isFalse);
  });

  test("retains a usable event that arrives before the roster response", () {
    final progress = FindMyRefreshProgress.start().withUsableEvent("alice").withRoster(["alice", "bob"]);

    expect(progress.updated, 1);
    expect(progress.pending, 1);
  });

  test("spins each row until its own location arrives in this refresh", () {
    final progress = FindMyRefreshProgress.start()
        .withRoster(["updated", "locating", "cached"])
        .withUsableEvent("updated");

    // A stale fix that already arrived this refresh shows its distance, not a spinner.
    expect(findMyFriendRowSpinning(progress, stableId: "updated", locatingInProgress: false), isFalse);
    expect(findMyFriendRowSpinning(progress, stableId: "locating", locatingInProgress: true), isTrue);
    // A saved location from before this refresh still spins until a fresh answer.
    expect(findMyFriendRowSpinning(progress, stableId: "cached", locatingInProgress: false), isTrue);
    expect(findMyFriendRowSpinning(progress, stableId: null, locatingInProgress: false), isTrue);
  });

  test("stops spinning when the refresh window ends unless Apple is still locating", () {
    final finished = FindMyRefreshProgress.start().withRoster(["alice", "bob"]).withUsableEvent("alice").finish();

    expect(findMyFriendRowSpinning(finished, stableId: "bob", locatingInProgress: false), isFalse);
    expect(findMyFriendRowSpinning(finished, stableId: "bob", locatingInProgress: true), isTrue);
    expect(findMyFriendRowSpinning(FindMyRefreshProgress.idle(), stableId: "alice", locatingInProgress: false), isFalse);
  });

  test("keeps partial progress until the refresh window finishes", () {
    final active = FindMyRefreshProgress.start().withRoster(["alice", "bob"]).withUsableEvent("alice");
    expect(active.active, isTrue);
    expect(active.updated, 1);
    expect(active.pending, 1);

    final finished = active.finish();
    expect(finished.active, isFalse);
    expect(finished.updated, 1);
    expect(finished.pending, 1);
  });

  test("identifies a hydrated friend by its provider address", () {
    expect(findMyFriendRefreshIdFor(friend(rawAddress: "alice", hydratedAddress: "alice")), "alice");
    expect(findMyFriendRefreshIdFor(friend(hydratedAddress: "alice")), "alice");
    expect(findMyFriendRefreshIdFor(friend(rawAddress: "alice")), "alice");
    expect(findMyFriendRefreshIdFor(friend()), isNull);
    expect(findMyFriendRefreshId(rawHandleAddress: " ", hydratedHandleAddress: "alice"), "alice");
  });

  test("matches a hydrated-only roster entry with a raw-only event", () {
    final progress = FindMyRefreshProgress.start()
        .withRoster([findMyFriendRefreshIdFor(friend(hydratedAddress: "alice"))])
        .withUsableEvent(findMyFriendRefreshIdFor(friend(rawAddress: "alice")));

    expect(progress.updated, 1);
    expect(progress.pending, 0);
  });

  test("matches a raw-only roster entry with a hydrated-only event", () {
    final progress = FindMyRefreshProgress.start()
        .withRoster([findMyFriendRefreshIdFor(friend(rawAddress: "alice"))])
        .withUsableEvent(findMyFriendRefreshIdFor(friend(hydratedAddress: "alice")));

    expect(progress.updated, 1);
    expect(progress.pending, 0);
  });
}

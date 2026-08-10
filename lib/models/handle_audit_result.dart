/// Outcome of a remediation attempt for a single [HandleAuditResult].
enum HandleAuditStatus {
  /// Found missing `originalROWID` during the audit scan, not yet remediated.
  pending,

  /// Remediation is currently in-flight for this handle.
  remediating,

  /// Remediation found a server-side `originalROWID` and it was saved locally.
  repaired,

  /// The server returned a match for the address, but it also had no
  /// `originalROWID` value.
  stillMissing,

  /// The server had no handle matching this address at all.
  notFoundOnServer,

  /// The remediation request failed (network/API error).
  error,
}

/// A single handle flagged by the Developer Tools "Handle Auditing" scan for
/// having a `null` `Handle.originalROWID`.
class HandleAuditResult {
  final int handleId;
  final String address;
  final String service;

  /// Contact display name, falling back to formatted address, falling back
  /// to the raw address — mirrors [Handle.displayName].
  final String displayLabel;

  /// Whether this handle currently has a matched contact (`ContactV2`).
  final bool hasContact;

  /// `Handle.country`, when set — extra context for diagnosing why a
  /// specific handle ended up in this state.
  final String? country;

  HandleAuditStatus status;

  /// Number of previously-unlinked messages re-attached to this handle's
  /// `handleRelation` after a successful repair. Null until remediation runs.
  int? relinkedMessageCount;

  HandleAuditResult({
    required this.handleId,
    required this.address,
    required this.service,
    required this.displayLabel,
    required this.hasContact,
    this.country,
    this.status = HandleAuditStatus.pending,
    this.relinkedMessageCount,
  });
}

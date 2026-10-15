import 'dart:isolate';

bool isIsolateOverride = false;
String? isolateNameOverride;

/// Prefixes the log name (and so the log file) of this engine's isolates without changing [isIsolate]. Set for each
/// Android bubble's engine, whose root and spawned isolates would otherwise share names with the main engine's and
/// with other bubbles'.
String? logNamePrefix;

bool get isIsolate =>
    isIsolateOverride ||
    (isolateNameOverride ?? Isolate.current.debugName) != null &&
        (isolateNameOverride ?? Isolate.current.debugName) != 'main';

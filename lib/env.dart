import 'dart:isolate';

bool isIsolateOverride = false;
String? isolateNameOverride;

/// Prefixes the log name (and so the log file) of this engine's isolates without changing [isIsolate]. Set for
/// Android bubble engines, whose root and spawned isolates would otherwise share names with the main engine's.
/// Every bubble shares the one prefix, so its files have several writers (see RotatingFileOutput).
String? logNamePrefix;

bool get isIsolate =>
    isIsolateOverride ||
    (isolateNameOverride ?? Isolate.current.debugName) != null &&
        (isolateNameOverride ?? Isolate.current.debugName) != 'main';

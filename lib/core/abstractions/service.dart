import 'dart:async';

import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/core/enums/service.dart';
import 'package:bluebubbles/core/logging/named_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

abstract class Service extends GetxService {
  String get name;

  int get version;

  bool get required;

  bool headless;

  ServiceState state = ServiceState.inactive;

  List<ServiceState> completedStates = [];

  List<Service> get dependencies => [];

  late NamedLogger log;

  get isActive => ![ServiceState.disposing, ServiceState.disposed, ServiceState.inactive].contains(state);

  get hasInitialized => completedStates.contains(ServiceState.initialized) || completedStates.contains(ServiceState.initializing);
  get hasStarted => completedStates.contains(ServiceState.started) || completedStates.contains(ServiceState.starting);
  get hasStopped => completedStates.contains(ServiceState.stopped) || completedStates.contains(ServiceState.stopping);
  get hasDisposed => completedStates.contains(ServiceState.disposed) || completedStates.contains(ServiceState.disposing);

  Completer<void>? _initCompleter;
  Completer<void>? _startCompleter;
  Completer<void>? _stopCompleter;

  // If it hasn't been initialized yet, create an incomplete future.
  // Otherwise, create a completed future. This is so code an properly await
  // for the service to get to specific states.
  Completer<void> get initFuture {
    if (!hasInitialized) {
      _initCompleter = Completer<void>();
    }

    return _initCompleter ?? Completer.sync();
  }

  Completer<void> get startFuture {
    if (!hasStarted) {
      _startCompleter = Completer<void>();
    }

    return _startCompleter ?? Completer.sync();
  }

  Completer<void> get stopFuture {
    if (!hasStopped) {
      _stopCompleter = Completer<void>();
    }

    return _stopCompleter ?? Completer.sync();
  }

  Service({ this.headless = false }) {
    log = NamedLogger(name);
  }

  setState(ServiceState state) {
    completedStates.addIf(!completedStates.contains(state), state);
    log.info("Service ${state.name}");
  }

  Future<void> initAndStart() async {
    await init();
    await start();
  }

  Future<void> setupDependencies() async {
    for (Service service in dependencies) {
      // If the state is inactive, we need to initialize it
      if (service.state == ServiceState.inactive) {
        // Don't await, but we can use the future to wait for it to finish
        service.initAndStart();
      }

      // If the state is initialized or is initializing, we need to wait for it to finish
      if (service.hasInitialized) {
        await service.initFuture.future;
      }
    }
  }

  Future<void> initAllPlatforms() {
    return Future.value();
  }

  Future<void> initWeb() {
    return Future.value();
  }

  Future<void> initMobile() {
    return Future.value();
  }

  Future<void> initDesktop() {
    return Future.value();
  }

  Future<void> init() async {
    if (hasInitialized) {
      return log.warn("Service already initialized. to re-initialize, call dispose() first");
    }

    // Use the existing future (if something is already waiting for it)
    final future = initFuture;

    // Set the state to initializing
    setState(ServiceState.initializing);
    final stopwatch = Stopwatch()..start();

    await initAllPlatforms();

    // Handle initialization
    if (kIsWeb) {
      await initWeb();
    } else if (GetPlatform.isMobile) {
      await initMobile();
    } else if (GetPlatform.isDesktop) {
      await initDesktop();
    }

    await _handleMigration();

    // Mark the service as initialized
    log.debug("Service initialized in ${stopwatch.elapsedMilliseconds}ms");
    setState(ServiceState.initialized);
    future.complete();
    return future.future;
  }

  Future<void> startWeb() {
    return Future.value();
  }

  Future<void> startMobile() {
    return Future.value();
  }

  Future<void> startDesktop() {
    return Future.value();
  }

  Future<void> postStart() {
    return Future.value();
  }

  Future<void> start() async {
    if (hasStarted) {
      return log.warn("Service already started. to re-start, call stop() first");
    }

    // Use the existing future (if something is already waiting for it)
    final future = startFuture;

    // Set the state to initializing
    setState(ServiceState.starting);
    final stopwatch = Stopwatch()..start();

    // Handle startup
    if (kIsWeb) {
      await startWeb();
    } else if (GetPlatform.isMobile) {
      await startMobile();
    } else if (GetPlatform.isDesktop) {
      await startDesktop();
    }

    // Mark the service as started
    log.debug("Service started in ${stopwatch.elapsedMilliseconds}ms");
    setState(ServiceState.started);
    future.complete();
    return future.future;
  }

  Future<void> stopWeb() {
    return Future.value();
  }

  Future<void> stopMobile() {
    return Future.value();
  }

  Future<void> stopDesktop() {
    return Future.value();
  }

  Future<void> postStop() {
    return Future.value();
  }

  Future<dynamic> stop() async {
    if (hasStopped) {
      return log.warn("Service already stopped. to re-stop, call start() first");
    }

    // Use the existing future (if something is already waiting for it)
    final future = stopFuture;

    // Set the state to initializing
    setState(ServiceState.stopping);
    final stopwatch = Stopwatch()..start();

    // Handle stop code
    if (kIsWeb) {
      await stopWeb();
    } else if (GetPlatform.isMobile) {
      await stopMobile();
    } else if (GetPlatform.isDesktop) {
      await stopDesktop();
    }

    // Mark the service as stopped
    log.debug("Service stopped in ${stopwatch.elapsedMilliseconds}ms");
    setState(ServiceState.stopped);
    future.complete();
    return future.future;
  }

  Future<void> _handleMigration() async {
    final stopwatch = Stopwatch()..start();
    await migrate();
    log.debug("Migration completed in ${stopwatch.elapsedMilliseconds}ms");
  }

  Future<void> migrate() {
    return Future.value();
  }

  void dispose() {
    if (hasDisposed) {
      log.warn("Service already disposed. to re-dispose, call init() first");
      return;
    }

    setState(ServiceState.disposing);
    Stopwatch stopwatch = Stopwatch()..start();
    stop();
    log.info("Service disposed in ${stopwatch.elapsedMilliseconds}ms");
    setState(ServiceState.disposed);
  }

  @override
  onClose() {
    dispose();
    super.onClose();
  }
}
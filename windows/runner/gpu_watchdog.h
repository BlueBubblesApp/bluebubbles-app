#ifndef RUNNER_GPU_WATCHDOG_H_
#define RUNNER_GPU_WATCHDOG_H_

#include <windows.h>

// Flutter never recovers from a lost GPU device (sleep, TDR, driver update): the window stays white until
// the app restarts (flutter/flutter#124194). This restarts it. Release/profile only, never under a debugger.
void StartGpuWatchdog(HWND window);

// First thing in wWinMain: in a relaunched process, waits for the old one to exit.
void WaitForGpuRecoveryParent();

#endif  // RUNNER_GPU_WATCHDOG_H_

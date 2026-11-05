#ifndef RUNNER_TOAST_FORWARDER_H_
#define RUNNER_TOAST_FORWARDER_H_

#include <windows.h>

// WM_COPYDATA id for a toast activation forwarded to the running instance. The payload is UTF-16:
// the activation arguments, then each user input key and value, all NUL-separated.
constexpr ULONG_PTR kToastActivationCopyDataId = 0x42424e54;

// Windows sometimes starts a new process for a toast activation even though the app is running and
// has its activator registered. Unpackaged only. When that happens and another
// instance's window exists, receives the activation here, forwards it to that window and returns
// true so this process exits; otherwise returns false and startup continues normally.
bool ForwardToastActivationToRunningInstance(const wchar_t* window_class, const wchar_t* title);

#endif  // RUNNER_TOAST_FORWARDER_H_

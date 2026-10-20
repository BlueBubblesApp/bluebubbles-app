#ifndef RUNNER_STORE_UPDATE_H_
#define RUNNER_STORE_UPDATE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// Channel for Microsoft Store in-app updates. Only finds updates when running
// as the Store-signed package.
std::unique_ptr<flutter::MethodChannel<>> CreateStoreUpdateChannel(
    flutter::BinaryMessenger* messenger, HWND hwnd);

#endif  // RUNNER_STORE_UPDATE_H_

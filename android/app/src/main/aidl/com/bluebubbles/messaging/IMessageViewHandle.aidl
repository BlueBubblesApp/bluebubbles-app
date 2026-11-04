// IMessageViewHandle.aidl
package com.bluebubbles.messaging;

// Declare any non-default types here with import statements
import com.bluebubbles.messaging.MadridMessage;
import com.bluebubbles.messaging.ITaskCompleteCallback;

interface IMessageViewHandle {
    void updateMessage(in MadridMessage message, in ITaskCompleteCallback callback);

    void setSuppressNotifications(boolean suppress);

    void lock();
    void unlock();
}
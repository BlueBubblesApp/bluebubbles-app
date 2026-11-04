// IKeyboardHandle.aidl
package com.bluebubbles.messaging;

// Declare any non-default types here with import statements
import com.bluebubbles.messaging.MadridMessage;

oneway interface IKeyboardHandle {
    void addMessage(in MadridMessage message);
}
// MadridMessage.aidl
package com.bluebubbles.messaging;

// Declare any non-default types here with import statements

parcelable MadridMessage {
    String messageGuid;
    @nullable
    String ldText;
    String url;
    @nullable
    String session;

    @nullable
    String imageBase64;
    @nullable
    String imageSubtitle;
    @nullable
    String imageTitle;
    @nullable
    String caption;
    @nullable
    String secondaryCaption;
    @nullable
    String tertiaryCaption;
    @nullable
    String subcaption;

    boolean isLive;
}
package com.bluebubbles.messaging.helpers;

import android.os.Handler;

public class NotifyRunnable implements Runnable {
    private final Runnable mRunnable;
    private final Handler mHandler;
    private boolean mFinished = false;

    public  NotifyRunnable(final Handler handler, final Runnable r) {
        mRunnable = r;
        mHandler = handler;
    }

    public boolean isFinished() {
        return mFinished;
    }

    @Override
    public void run() {
        synchronized (mHandler) {
            mRunnable.run();
            mFinished = true;
            mHandler.notifyAll();
        }
    }
}

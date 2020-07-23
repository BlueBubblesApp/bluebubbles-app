package com.bricktheworld.giftextfield;

import android.content.Context;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

public class EditTextView implements PlatformView, MethodChannel.MethodCallHandler {
    private final EditText editText;
    private LinearLayout layout;
    private final MethodChannel methodChannel;

    public EditTextView(Context context, BinaryMessenger messenger, int id) {
        LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        layout = (LinearLayout) inflater.inflate(R.layout.text_field, null);
        editText = (EditText) layout.findViewById(R.id.edit_text);
        editText.requestFocus();
        editText.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence charSequence, int i, int i1, int i2) {

            }

            @Override
            public void onTextChanged(CharSequence charSequence, int i, int i1, int i2) {

            }

            @Override
            public void afterTextChanged(Editable editable) {
                Log.d("editText", "onchanged");
            }
        });
//        editText.setTextColor();
        methodChannel = new MethodChannel(messenger, "giftextfield_" + id);
        methodChannel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall methodCall, MethodChannel.Result result) {

    }

    @Override
    public View getView() {
        return layout;
    }

    @Override
    public void dispose() {

    }
}

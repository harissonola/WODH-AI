package com.example.wodh_ai

import io.flutter.embedding.android.FlutterActivity
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import android.os.Bundle

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize Facebook SDK
        FacebookSdk.sdkInitialize(applicationContext)
        AppEventsLogger.activateApp(this)
    }
}
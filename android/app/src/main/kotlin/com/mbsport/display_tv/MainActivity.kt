package com.mbsport.display_tv

import android.os.Bundle
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Habilitar aceleración hardware para WebView (mejor rendimiento de video)
        WebView.setWebContentsDebuggingEnabled(false)
        super.onCreate(savedInstanceState)
    }
}

package com.Barrim.AppBarrim

import android.content.Intent
import android.os.Bundle
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.android.FlutterActivity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions

class MainActivity : FlutterActivity() {

    lateinit var googleSignInClient: GoogleSignInClient
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestEmail()
            .requestIdToken(getString(R.string.default_web_client_id))
            .build()

        googleSignInClient = GoogleSignIn.getClient(this, gso)
        
        // Enable edge-to-edge display for Android 15+ compatibility
        // Using WindowCompat for FlutterActivity compatibility
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Handle system insets to prevent content from being hidden behind system bars
        // This approach works with the modern edge-to-edge implementation
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(android.R.id.content)) { view, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
            insets
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle notification taps
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent) {
        // Handle notification data here
        val data = intent.extras
        if (data != null) {
            // Process notification data
            println("Notification data: $data")
            
            // You can navigate to specific screens based on notification data
            val type = data.getString("type")
            when (type) {
                "booking_request" -> {
                    // Navigate to booking details
                    println("Opening booking details")
                }
                "general" -> {
                    // Navigate to general notification screen
                    println("Opening general notifications")
                }
            }
        }
    }
}

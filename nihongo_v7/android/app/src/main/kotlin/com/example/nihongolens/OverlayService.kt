package com.example.nihongolens

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

class OverlayService : Service() {

    companion object {

        var instance: OverlayService? = null

        fun updateTexts(jp: String, en: String) {
            instance?.apply {
                latestJapanese = jp
                latestEnglish = en
                lastUpdate = System.currentTimeMillis()
            }
        }
    }

    private lateinit var wm: WindowManager
    private lateinit var root: LinearLayout

    private var japaneseTv: TextView? = null
    private var englishTv: TextView? = null

    private val handler = Handler(Looper.getMainLooper())

    private var latestJapanese = ""
    private var latestEnglish = ""

    private var lastUpdate = System.currentTimeMillis()

    override fun onCreate() {
        super.onCreate()

        instance = this

        createNotification()

        wm = getSystemService(WINDOW_SERVICE) as WindowManager

        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20, 12, 20, 12)
            setBackgroundColor(Color.argb(170, 0, 0, 0))
        }

        japaneseTv = TextView(this).apply {
            setTextColor(Color.LTGRAY)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            maxLines = 1
        }

        englishTv = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 19f)
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 2
        }

        root.addView(japaneseTv)
        root.addView(englishTv)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,

            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,

            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP
        params.y = 0

        wm.addView(root, params)

        startLoop()
    }

    private fun startLoop() {

        handler.post(object : Runnable {

            override fun run() {

                val diff = System.currentTimeMillis() - lastUpdate

                if (diff > 4000) {
                    englishTv?.text = ""
                    japaneseTv?.text = ""
                } else {
                    englishTv?.text = latestEnglish.trim()
                    japaneseTv?.text = latestJapanese.trim()
                }

                handler.postDelayed(this, 250)
            }
        })
    }

    private fun createNotification() {

        val channelId = "overlay"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val channel = NotificationChannel(
                channelId,
                "Overlay",
                NotificationManager.IMPORTANCE_LOW
            )

            val nm = getSystemService(NotificationManager::class.java)

            nm.createNotificationChannel(channel)
        }

        val notification = Notification.Builder(this, channelId)
            .setContentTitle("Nihongo Lens")
            .setContentText("Live translation active")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()

        startForeground(1, notification)
    }

    override fun onDestroy() {
        super.onDestroy()

        instance = null

        try {
            wm.removeView(root)
        } catch (_: Exception) {
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

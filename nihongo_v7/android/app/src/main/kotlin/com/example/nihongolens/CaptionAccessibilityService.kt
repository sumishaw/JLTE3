package com.example.nihongolens

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions

class CaptionAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var lastJapanese = ""
    private var debounceRunnable: Runnable? = null
    private var translator: Translator? = null

    // Known Live Caption / subtitle view IDs across Android versions & apps
    private val CAPTION_VIEW_IDS = setOf(
        "com.google.android.as:id/caption_text",         // Android Live Caption (Pixel)
        "com.google.android.as:id/text",
        "com.google.android.captioning:id/caption_text", // Google Captioning service
        "com.samsung.android.bixby.agent:id/text_view",  // Samsung Live Caption
        "com.sec.android.accessibility.DigitalWellbeing:id/caption",
        "org.videolan.vlc:id/player_overlay_subtitles",  // VLC
        "org.videolan.vlc:id/subtitles",
        "com.google.android.youtube:id/caption_window_text", // YouTube
        "com.google.android.youtube:id/subtitle_text",
        "com.google.android.youtube:id/player_caption_text",
        "com.google.android.apps.youtube.tv:id/caption_text",
        "com.android.chrome:id/caption_text",             // Chrome
        "org.mozilla.firefox:id/caption_text",            // Firefox
        "com.netflix.mediaclient:id/subtitle_text",       // Netflix
        "com.amazon.avod.thirdpartyclient:id/subtitle_text" // Prime Video
    )

    // Packages that carry captions — we watch ALL windows but prioritize these
    private val CAPTION_PACKAGES = setOf(
        "com.google.android.as",           // Android Live Caption
        "com.google.android.captioning",
        "com.google.android.youtube",
        "org.videolan.vlc",
        "com.android.chrome",
        "org.mozilla.firefox",
        "com.netflix.mediaclient",
        "com.amazon.avod.thirdpartyclient",
        "com.samsung.android.bixby.agent",
        "com.brave.browser",
        "com.microsoft.emmx",             // Edge
        "com.opera.browser",
        "com.UCMobile.intl",              // UC Browser
        "tv.twitch.android.app",
        "com.disney.disneyplus",
        "com.hulu.plus"
    )

    companion object {
        @Volatile var latestJapanese = ""
        @Volatile var latestEnglish  = ""
        var instance: CaptionAccessibilityService? = null
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d("NihongoLens", "✅ Accessibility service connected")

        // Dynamically widen the service scope to catch ALL windows
        serviceInfo = serviceInfo?.also { info ->
            info.eventTypes =
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            info.flags =
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            info.notificationTimeout = 50  // faster — 50 ms
            info.packageNames = null       // null = watch ALL packages
        }

        initTranslator()
    }

    // ── Translation model ────────────────────────────────────────────────────

    private fun initTranslator() {
        val options = TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.JAPANESE)
            .setTargetLanguage(TranslateLanguage.ENGLISH)
            .build()
        translator = Translation.getClient(options)
        translator?.downloadModelIfNeeded()
            ?.addOnSuccessListener { Log.d("NihongoLens", "MLKit model ready ✅") }
            ?.addOnFailureListener { Log.e("NihongoLens", "Model download failed: ${it.message}") }
    }

    // ── Event handler ────────────────────────────────────────────────────────

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // Try all windows (catches system Live Caption overlay)
        val windows = windows
        if (windows != null && windows.isNotEmpty()) {
            for (window in windows) {
                val root = window.root ?: continue
                val text = extractCaptions(root, window.title?.toString() ?: "")
                root.recycle()
                if (text.isNotBlank()) {
                    scheduleTranslate(text)
                    return
                }
            }
        }

        // Fallback: scan active window
        val root = rootInActiveWindow ?: return
        val text = extractCaptions(root, "")
        root.recycle()
        if (text.isNotBlank()) scheduleTranslate(text)
    }

    // ── Caption extraction ───────────────────────────────────────────────────

    private fun extractCaptions(root: AccessibilityNodeInfo, windowTitle: String): String {
        val results = mutableListOf<String>()

        // Strategy 1: Look for known caption view IDs first (fastest)
        for (id in CAPTION_VIEW_IDS) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            for (node in nodes) {
                val t = node.text?.toString()?.trim() ?: ""
                if (t.isNotEmpty()) results.add(t)
                node.recycle()
            }
            if (results.isNotEmpty()) break
        }

        // Strategy 2: Deep scan for Japanese text in any node
        if (results.isEmpty()) {
            val sb = StringBuilder()
            deepScan(root, sb)
            val lines = sb.toString().lines()
                .map { it.trim() }
                .filter { it.isNotEmpty() && containsJapanese(it) }
                // Filter out UI chrome — captions are usually short-to-medium
                .filter { it.length in 1..200 }
            results.addAll(lines)
        }

        return results
            .filter { containsJapanese(it) }
            .distinct()
            .joinToString(" ")
            .trim()
    }

    private fun deepScan(node: AccessibilityNodeInfo?, sb: StringBuilder) {
        if (node == null) return
        node.text?.toString()?.let { if (it.isNotBlank()) sb.append(it).append("\n") }
        node.contentDescription?.toString()?.let {
            if (it.isNotBlank() && containsJapanese(it)) sb.append(it).append("\n")
        }
        for (i in 0 until node.childCount) {
            deepScan(node.getChild(i), sb)
        }
    }

    // ── Japanese detection ───────────────────────────────────────────────────

    private fun containsJapanese(text: String): Boolean {
        return text.any { c ->
            c.code in 0x3040..0x309F ||  // Hiragana
            c.code in 0x30A0..0x30FF ||  // Katakana
            c.code in 0x4E00..0x9FAF ||  // CJK Kanji
            c.code in 0xFF65..0xFF9F     // Half-width Katakana
        }
    }

    // ── Debounced translation ────────────────────────────────────────────────

    private fun scheduleTranslate(japanese: String) {
        if (japanese == lastJapanese) return
        debounceRunnable?.let { handler.removeCallbacks(it) }
        debounceRunnable = Runnable {
            if (japanese != lastJapanese) {
                lastJapanese  = japanese
                latestJapanese = japanese
                Log.d("NihongoLens", "🎌 Detected: $japanese")
                doTranslate(japanese)
            }
        }
        handler.postDelayed(debounceRunnable!!, 400)
    }

    private fun doTranslate(japanese: String) {
        translator?.translate(japanese)
            ?.addOnSuccessListener { english ->
                latestEnglish = english
                Log.d("NihongoLens", "🇬🇧 Translated: $english")
                OverlayService.updateText(japanese, english)
                handler.post { MainActivity.instance?.onTranslation(japanese, english) }
            }
            ?.addOnFailureListener { e ->
                Log.e("NihongoLens", "Translation error: ${e.message}")
                OverlayService.updateText(japanese, japanese) // show original if fails
            }
    }

    // ── Cleanup ──────────────────────────────────────────────────────────────

    override fun onInterrupt() {}

    override fun onDestroy() {
        instance = null
        debounceRunnable?.let { handler.removeCallbacks(it) }
        translator?.close()
        super.onDestroy()
    }
}

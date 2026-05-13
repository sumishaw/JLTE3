package com.example.nihongolens

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions

class CaptionAccessibilityService : AccessibilityService() {

    companion object {
        var sourceLang = "ja"
        var targetLang = "en"
    }

    private var translator: Translator? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        recreateTranslator()
    }

    private fun recreateTranslator() {

        try {
            translator?.close()
        } catch (_: Exception) {
        }

        val options = TranslatorOptions.Builder()
            .setSourceLanguage(sourceLang)
            .setTargetLanguage(targetLang)
            .build()

        translator = Translation.getClient(options)

        translator?.downloadModelIfNeeded()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {

        val text = event?.text?.joinToString(" ") ?: return

        if (text.isBlank()) return

        recreateTranslator()

        translator?.translate(text)
            ?.addOnSuccessListener { translated ->

                OverlayService.updateTexts(
                    text,
                    translated
                )
            }
    }

    override fun onInterrupt() {}
}

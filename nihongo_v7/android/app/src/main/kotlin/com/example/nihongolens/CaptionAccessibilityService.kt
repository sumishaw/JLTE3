package com.example.nihongolens

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import com.google.mlkit.nl.languageid.LanguageIdentification
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions

class CaptionAccessibilityService : AccessibilityService() {

    companion object {
        var sourceLang = "auto"
        var targetLang = "en"
    }

    private var translator: Translator? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {

        val text = event?.text?.joinToString(" ") ?: return

        if (text.isBlank()) return

        if (sourceLang == "auto") {

            LanguageIdentification.getClient()
                .identifyLanguage(text)
                .addOnSuccessListener { lang ->
                    createTranslator(lang)
                    translateText(text)
                }

        } else {
            createTranslator(sourceLang)
            translateText(text)
        }
    }

    private fun createTranslator(source: String) {

        try {
            translator?.close()
        } catch (_: Exception) {}

        val options = TranslatorOptions.Builder()
            .setSourceLanguage(source)
            .setTargetLanguage(targetLang)
            .build()

        translator = Translation.getClient(options)

        translator?.downloadModelIfNeeded()
    }

    private fun translateText(text: String) {

        translator?.translate(text)
            ?.addOnSuccessListener {

                OverlayService.updateTexts(text, it)
            }
    }

    override fun onInterrupt() {}
}

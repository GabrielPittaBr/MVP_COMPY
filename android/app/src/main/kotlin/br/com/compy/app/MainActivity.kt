package br.com.compy.app

import com.google.android.play.agesignals.*
import com.google.android.play.agesignals.model.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Ponte com a Play Age Signals API (ECA Digital, arts. 12–14). O Dart chama
 * `check` no cadastro e no aceite dos Termos; a resposta é só a faixa etária,
 * usada para adequar o app à idade (ver lib/core/services/age_signals_service.dart).
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "br.com.compy.app/age_signals")
            .setMethodCallHandler { call, result ->
                if (call.method == "check") checkAgeSignals(result) else result.notImplemented()
            }
    }

    private fun checkAgeSignals(result: MethodChannel.Result) {
        val manager = AgeSignalsManagerFactory.create(applicationContext)
        val access = AgeSignalsAccessRequest.builder().setActivity(this).build()
        manager.requestAgeSignalsAccess(access)
            .addOnSuccessListener { accessResult ->
                if (accessResult.ageSignalsStatus() != AgeSignalsStatus.SHARED) {
                    result.success(mapOf("status" to "not_shared"))
                    return@addOnSuccessListener
                }
                manager.checkAgeSignals(AgeSignalsRequest.builder().build())
                    .addOnSuccessListener { signals ->
                        result.success(
                            mapOf(
                                "status" to "shared",
                                "ageLower" to signals.ageLower(),
                                "ageUpper" to signals.ageUpper(),
                            ),
                        )
                    }
                    .addOnFailureListener { error -> result.success(failure(error)) }
            }
            .addOnFailureListener { error -> result.success(failure(error)) }
    }

    /** Falha vira resposta, não exceção: o app segue com a idade declarada. */
    private fun failure(error: Exception): Map<String, Any?> = mapOf(
        "status" to "error",
        "errorCode" to (error as? AgeSignalsException)?.errorCode,
    )
}

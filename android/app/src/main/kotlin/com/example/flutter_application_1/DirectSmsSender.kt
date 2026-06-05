package com.example.flutter_application_1

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

object DirectSmsSender {
    private const val SMS_SENT_ACTION = "com.example.flutter_application_1.SMS_SENT"

    fun send(
        activity: Activity,
        to: String,
        message: String,
        result: MethodChannel.Result,
    ) {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.SEND_SMS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION_DENIED", "SEND_SMS permission not granted", null)
            return
        }

        val candidates = buildAddressCandidates(to)
        var lastError: Exception? = null

        for (address in candidates) {
            if (trySendFireAndForget(activity, address, message)) {
                result.success(true)
                return
            }
            if (trySendWithStatusCallback(activity, address, message)) {
                result.success(true)
                return
            }
            lastError = IllegalStateException("Failed for $address")
        }

        result.error(
            "SEND_FAILED",
            lastError?.message ?: "SMS send failed for all number formats",
            null,
        )
    }

    fun openSmsApp(
        activity: Activity,
        to: String,
        message: String,
        result: MethodChannel.Result,
    ) {
        try {
            val address = buildAddressCandidates(to).first()
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("smsto:$address")
                putExtra("sms_body", message)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            activity.startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.error("OPEN_FAILED", error.message, null)
        }
    }

    private fun trySendFireAndForget(
        context: Context,
        to: String,
        message: String,
    ): Boolean {
        return try {
            val smsManager = resolveSmsManager(context)
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(to, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(to, null, message, null, null)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun trySendWithStatusCallback(
        activity: Activity,
        to: String,
        message: String,
    ): Boolean {
        val smsManager = resolveSmsManager(activity)
        val parts = smsManager.divideMessage(message)
        val sentIntent = Intent(SMS_SENT_ACTION).setPackage(activity.packageName)
        val sentPendingIntent = PendingIntent.getBroadcast(
            activity,
            to.hashCode(),
            sentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val completed = booleanArrayOf(false)
        val success = booleanArrayOf(false)

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (completed[0]) return
                completed[0] = true
                try {
                    activity.unregisterReceiver(this)
                } catch (_: IllegalArgumentException) {
                }
                success[0] = resultCode == Activity.RESULT_OK
            }
        }

        val filter = IntentFilter(SMS_SENT_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            activity.registerReceiver(receiver, filter)
        }

        return try {
            if (parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent?>(parts.size)
                for (index in parts.indices) {
                    sentIntents.add(
                        if (index == parts.size - 1) sentPendingIntent else null,
                    )
                }
                smsManager.sendMultipartTextMessage(to, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(to, null, message, sentPendingIntent, null)
            }

            // Wait briefly for the modem callback; many OEMs respond quickly.
            val deadline = System.currentTimeMillis() + 8000
            while (!completed[0] && System.currentTimeMillis() < deadline) {
                Thread.sleep(50)
            }
            if (!completed[0]) {
                try {
                    activity.unregisterReceiver(receiver)
                } catch (_: IllegalArgumentException) {
                }
                // No callback — assume queued successfully (common on Transsion/OEM).
                true
            } else {
                success[0]
            }
        } catch (_: Exception) {
            try {
                activity.unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
            false
        }
    }

    private fun buildAddressCandidates(raw: String): List<String> {
        val cleaned = raw.replace(Regex("[^\\d+]"), "").trim()
        val candidates = linkedSetOf<String>()
        when {
            cleaned.startsWith("+63") && cleaned.length == 13 -> {
                candidates.add("0${cleaned.substring(3)}")
                candidates.add(cleaned)
                candidates.add(cleaned.substring(1))
            }
            cleaned.startsWith("63") && cleaned.length == 12 -> {
                candidates.add("0${cleaned.substring(2)}")
                candidates.add("+$cleaned")
                candidates.add(cleaned)
            }
            cleaned.startsWith("0") && cleaned.length == 11 -> {
                candidates.add(cleaned)
                candidates.add("+63${cleaned.substring(1)}")
                candidates.add("63${cleaned.substring(1)}")
            }
            else -> candidates.add(cleaned)
        }
        return candidates.filter { it.isNotBlank() }
    }

    private fun resolveSmsManager(context: Context): SmsManager {
        val subscriptionId = SmsManager.getDefaultSmsSubscriptionId()
        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        } ?: throw IllegalStateException("SmsManager unavailable")

        if (subscriptionId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                smsManager.createForSubscriptionId(subscriptionId)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
            }
        }
        return smsManager
    }
}

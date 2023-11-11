package com.example.pedometer_foreground

import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var stepCountingService : StepCountingService = StepCountingService()

    override fun onStart() {
        super.onStart()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "step_counter").setMethodCallHandler { call, result ->
            // check for our call
            if (call.method == "getStepCount") {
                result.success(stepCountingService.stepCount)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startStepCountingService() {
        val serviceIntent = Intent(this, stepCountingService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
}

class StepCountingService : Service(), SensorEventListener {

    private var sensorManager: SensorManager? = null
    private var stepCounterSensor: Sensor? = null
    var stepCount = 0
    private val CHANNEL_ID = "StepCounterNotificationChannel"

    override fun onCreate() {
        super.onCreate()
        startForeground()
        initializeSensors()
    }

    private fun startForeground() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Step Counter Service")
                .setContentText("Step Counter is active")
                .setContentIntent(pendingIntent)
                .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun initializeSensors() {
        sensorManager = applicationContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        if (stepCounterSensor != null) {
            sensorManager?.registerListener(this, stepCounterSensor, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Handle changes in sensor accuracy if needed
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER) {
            stepCount = event.values[0].toInt()
            sendDataToFlutter(stepCount)
        }
    }

    private fun sendDataToFlutter(stepCounts: Int) {
        // You can send step count to Flutter via a method channel
        // Implement the MethodChannel's send step count to Flutter
        stepCount = stepCounts;
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        // Unregister listener and clean up
        sensorManager?.unregisterListener(this)
    }

    companion object {
        private const val NOTIFICATION_ID = 1
    }
}
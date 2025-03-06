//package com.nth.beluslauncher.belus_launcher
//
//import android.annotation.TargetApi
//import android.app.Activity
//import android.content.Context
//import android.content.Intent
//import android.graphics.Bitmap
//import android.graphics.PixelFormat
//import android.hardware.display.DisplayManager
//import android.media.ImageReader
//import android.media.projection.MediaProjection
//import android.media.projection.MediaProjectionManager
//import android.os.Build
//import android.os.Handler
//import android.os.Looper
//import android.util.Log
//import java.io.ByteArrayOutputStream
//import java.util.concurrent.CompletableFuture
//import android.media.Image
//
//
//object ScreenshotUtil {
//
//    var mediaProjection: MediaProjection? = null
//    private var imageReader: ImageReader? = null
//    private var virtualDisplay: android.hardware.display.VirtualDisplay? = null
//    private var screenDensity: Int = 0
//    private var displayWidth: Int = 0
//    private var displayHeight: Int = 0
//
//    // Call this function from Flutter to initialize MediaProjection
//    fun initializeMediaProjection(activity: Activity, resultCode: Int, data: Intent) {
//        val mediaProjectionManager = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
//        mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data)
//    }
//
//    @TargetApi(Build.VERSION_CODES.N)
//    fun captureScreenshot(context: Context): CompletableFuture<ByteArray?> {
//        val future = CompletableFuture<ByteArray?>()
//
//        // Ensure this runs on the main thread
//        Handler(Looper.getMainLooper()).post {
//            try {
//                if (mediaProjection == null) {
//                    future.completeExceptionally(IllegalStateException("MediaProjection is not initialized. Call initializeMediaProjection first."))
//                    return@post
//                }
//
//                val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
//                val display = (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).defaultDisplay
//
//                // Use display.mode.physicalWidth and display.mode.physicalHeight
//                displayWidth = display.mode.physicalWidth
//                displayHeight = display.mode.physicalHeight
//                screenDensity = context.resources.displayMetrics.densityDpi
//
//                imageReader = ImageReader.newInstance(displayWidth, displayHeight, PixelFormat.RGBA_8888, 2)
//                virtualDisplay = mediaProjection?.createVirtualDisplay(
//                    "ScreenshotVirtualDisplay",
//                    displayWidth,
//                    displayHeight,
//                    screenDensity,
//                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
//                    imageReader?.surface,
//                    null,
//                    null
//                )
//
//                imageReader?.setOnImageAvailableListener({ reader ->
//                    val image = reader.acquireLatestImage()
//                    if (image == null) {
//                        future.complete(null)
//                        return@setOnImageAvailableListener
//                    }
//
//                    val planes = image.planes
//                    if (planes.isEmpty()) {
//                        future.complete(null)
//                        image.close()
//                        return@setOnImageAvailableListener
//                    }
//
//                    val buffer = planes[0].buffer
//                    val pixelStride = planes[0].pixelStride
//                    val rowStride = planes[0].rowStride
//                    val rowPadding = rowStride - pixelStride * displayWidth
//
//                    val bitmap = Bitmap.createBitmap(
//                        displayWidth + rowPadding / pixelStride,
//                        displayHeight,
//                        Bitmap.Config.ARGB_8888
//                    )
//                    bitmap.copyPixelsFromBuffer(buffer)
//
//                    image.close() // Properly close image after usage
//
//                    val stream = ByteArrayOutputStream()
//                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
//                    val byteArray = stream.toByteArray()
//                    future.complete(byteArray)
//
//                    bitmap.recycle() // Recycle to free memory
//                    stopMediaProjection() // Stop projection after one screenshot
//                }, Handler(Looper.getMainLooper()))
//
//
//            } catch (e: Exception) {
//                future.completeExceptionally(e)
//            }
//        }
//
//        return future
//    }
//
//    // Clean up resources
//    private fun stopMediaProjection() {
//        virtualDisplay?.release()
//        imageReader?.close()
//        if (mediaProjection != null) {
//            mediaProjection?.stop()
//        }
//        virtualDisplay = null
//        imageReader = null
//        mediaProjection = null
//    }
//}
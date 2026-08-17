package com.bluebubbles.messaging.services.filesystem

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.annotation.RequiresApi
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.utils.PersistentLog
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream
import java.util.concurrent.Executors

/// Saves an image, video, or audio attachment into the shared media collections so it shows up
/// in the system gallery. Accepts either a `filePath` to copy from or raw `bytes`.
///
/// This replaces the `saver_gallery` plugin. That plugin ran its `ContentResolver.insert` inside
/// a bare `CoroutineScope(Dispatchers.IO)` with no exception handling, so anything MediaProvider
/// threw (most often `IllegalStateException: Failed to build unique file`) escaped the coroutine,
/// reached the default uncaught handler, and killed the process — a Dart-side `try`/`catch` never
/// saw it. Every failure here is funneled into `result.error(...)` instead, so Dart can report the
/// problem and fall back to another save location.
class SaveToGalleryHandler : MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "save-to-gallery"

        /// Display names longer than this risk blowing past the filesystem's limit once
        /// MediaProvider appends its own de-duplication suffix.
        private const val maxFileNameLength: Int = 200

        /// How many `name (n)` variants to try before falling back to a timestamped name.
        private const val collisionRetryLimit: Int = 32

        /// Media types common in iMessage attachments that `MimeTypeMap` doesn't know about on
        /// every API level. Without these the file reads as `application/octet-stream` and gets
        /// turned away from the gallery.
        private val appleMediaTypes = mapOf(
            "heic" to "image/heic",
            "heif" to "image/heif",
            "avci" to "image/heic",
            "caf" to "audio/x-caf",
            "amr" to "audio/amr",
        )

        private val executor = Executors.newSingleThreadExecutor()
    }

    private enum class MediaType { IMAGE, VIDEO, AUDIO }

    override fun handleMethodCall(call: MethodCall, result: MethodChannel.Result, context: Context) {
        val filePath: String? = call.argument("filePath")
        val bytes: ByteArray? = call.argument("bytes")
        val fileName = sanitizeFileName(call.argument("fileName"), filePath)
        val relativePath: String? = call.argument("relativePath")

        if (filePath.isNullOrEmpty() && bytes == null) {
            result.error("NO_DATA", "No file path or bytes were given to save", null)
            return
        }

        val mimeType = resolveMimeType(fileName, filePath, call.argument("mimeType"))
        val mediaType = mediaTypeFor(mimeType)
        if (mediaType == null) {
            // Documents and unrecognized types don't belong in the gallery. Fail fast so the
            // caller can save them somewhere more appropriate.
            result.error("UNSUPPORTED_TYPE", "$mimeType cannot be saved to the gallery", null)
            return
        }

        // Copying a large video on the platform thread would ANR, so hand the work off and post
        // the result back — MethodChannel.Result must be resolved on the main thread.
        val appContext = context.applicationContext
        executor.execute {
            var savedName: String? = null
            var error: Throwable? = null
            try {
                savedName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    saveViaMediaStore(appContext, filePath, bytes, fileName, mimeType, mediaType, relativePath)
                } else {
                    saveToPublicDirectory(appContext, filePath, bytes, fileName, mimeType, mediaType, relativePath)
                }
            } catch (e: Throwable) {
                error = e
                PersistentLog.d(appContext, Constants.logTag, "Failed to save $fileName to the gallery: $e")
            }

            val name = savedName
            val failure = error
            Handler(Looper.getMainLooper()).post {
                if (name != null) {
                    result.success(name)
                } else {
                    result.error("SAVE_FAILED", failure?.message ?: "Could not save $fileName to the gallery", null)
                }
            }
        }
    }

    /// Android 10+ path. Inserts a pending MediaStore row, streams the content into it, then
    /// publishes it so a half-written file never shows up in the gallery.
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveViaMediaStore(
        context: Context,
        filePath: String?,
        bytes: ByteArray?,
        fileName: String,
        mimeType: String,
        mediaType: MediaType,
        relativePath: String?,
    ): String {
        val collection = when (mediaType) {
            MediaType.IMAGE -> MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            MediaType.VIDEO -> MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            MediaType.AUDIO -> MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val resolvedPath = resolveRelativePath(relativePath, mediaType)
        val resolver = context.contentResolver

        // MediaProvider de-duplicates colliding display names itself, but throws once it has tried
        // ~32 suffixes. Retry with a timestamped name so a crowded folder doesn't fail the save.
        var insertError: Throwable? = null
        for (name in listOf(fileName, disambiguate(fileName))) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, resolvedPath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val uri: Uri = try {
                resolver.insert(collection, values)
                    ?: throw Exception("MediaStore returned no URI for $resolvedPath$name")
            } catch (e: Exception) {
                insertError = e
                continue
            }

            try {
                val output = resolver.openOutputStream(uri)
                    ?: throw Exception("Could not open an output stream for $resolvedPath$name")
                output.use { writeContent(it, filePath, bytes) }

                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return name
            } catch (e: Exception) {
                // Don't leave a permanently pending, half-written row behind.
                runCatching { resolver.delete(uri, null, null) }
                throw e
            }
        }

        throw insertError ?: Exception("Could not create a gallery entry for $fileName")
    }

    /// Android 9 and below. Scoped storage doesn't apply yet, so write into the public media
    /// directory directly and ask the media scanner to index it.
    private fun saveToPublicDirectory(
        context: Context,
        filePath: String?,
        bytes: ByteArray?,
        fileName: String,
        mimeType: String,
        mediaType: MediaType,
        relativePath: String?,
    ): String {
        @Suppress("DEPRECATION")
        val directory = File(Environment.getExternalStorageDirectory(), resolveRelativePath(relativePath, mediaType))
        if (!directory.exists() && !directory.mkdirs()) {
            throw Exception("Could not create ${directory.absolutePath}")
        }

        var destination = File(directory, fileName)
        var collisions = 0
        while (destination.exists() && collisions < collisionRetryLimit) {
            collisions++
            destination = File(directory, "${baseName(fileName)} ($collisions)${extensionSuffix(fileName)}")
        }
        if (destination.exists()) destination = File(directory, disambiguate(fileName))

        destination.outputStream().use { writeContent(it, filePath, bytes) }
        MediaScannerConnection.scanFile(context, arrayOf(destination.absolutePath), arrayOf(mimeType), null)
        return destination.name
    }

    private fun writeContent(output: OutputStream, filePath: String?, bytes: ByteArray?) {
        if (!filePath.isNullOrEmpty()) {
            FileInputStream(filePath).use { it.copyTo(output) }
        } else if (bytes != null) {
            output.write(bytes)
        }
        output.flush()
    }

    /// MediaProvider only accepts a handful of top-level directories per collection and throws for
    /// anything else — an audio file under `Pictures/`, or any bare custom folder at the root of
    /// external storage. Keep the caller's sub-folders but swap in a valid primary directory when
    /// theirs isn't allowed for this media type.
    private fun resolveRelativePath(relativePath: String?, mediaType: MediaType): String {
        val default = when (mediaType) {
            MediaType.IMAGE -> Environment.DIRECTORY_PICTURES
            MediaType.VIDEO -> Environment.DIRECTORY_MOVIES
            MediaType.AUDIO -> Environment.DIRECTORY_MUSIC
        }

        val segments = (relativePath ?: "")
            .split('/')
            .map { it.trim() }
            .filter { it.isNotEmpty() && it != "." && it != ".." }
        if (segments.isEmpty()) return "$default/"

        val allowed = when (mediaType) {
            MediaType.IMAGE -> listOf(Environment.DIRECTORY_DCIM, Environment.DIRECTORY_PICTURES)
            MediaType.VIDEO ->
                listOf(Environment.DIRECTORY_DCIM, Environment.DIRECTORY_MOVIES, Environment.DIRECTORY_PICTURES)
            MediaType.AUDIO -> listOf(
                Environment.DIRECTORY_ALARMS,
                Environment.DIRECTORY_MUSIC,
                Environment.DIRECTORY_NOTIFICATIONS,
                Environment.DIRECTORY_PODCASTS,
                Environment.DIRECTORY_RINGTONES,
            )
        }
        val knownRoots = listOf(
            Environment.DIRECTORY_ALARMS,
            Environment.DIRECTORY_DCIM,
            Environment.DIRECTORY_DOCUMENTS,
            Environment.DIRECTORY_DOWNLOADS,
            Environment.DIRECTORY_MOVIES,
            Environment.DIRECTORY_MUSIC,
            Environment.DIRECTORY_NOTIFICATIONS,
            Environment.DIRECTORY_PICTURES,
            Environment.DIRECTORY_PODCASTS,
            Environment.DIRECTORY_RINGTONES,
        )

        val primary = allowed.firstOrNull { it.equals(segments.first(), ignoreCase = true) } ?: default
        // Drop the caller's primary directory when we had to substitute ours, so an image folder
        // doesn't end up nested inside the audio one.
        val rest = if (knownRoots.any { it.equals(segments.first(), ignoreCase = true) }) segments.drop(1) else segments

        return (listOf(primary) + rest).joinToString(separator = "/", postfix = "/")
    }

    /// Strips anything that can't live in a file name and caps the length. MediaProvider throws
    /// (taking the insert down with it) when it can't turn the display name into a real file.
    private fun sanitizeFileName(fileName: String?, filePath: String?): String {
        val raw = fileName?.takeIf { it.isNotBlank() }
            ?: filePath?.let { File(it).name }?.takeIf { it.isNotBlank() }
            ?: "attachment"

        val cleaned = raw
            .replace(Regex("[\\\\/:*?\"<>|\\x00-\\x1f]"), "_")
            .trim()
            .trim('.')
            .ifEmpty { "attachment" }
        if (cleaned.length <= maxFileNameLength) return cleaned

        // A name that is nothing but one absurdly long "extension" gets truncated whole.
        val extension = extensionSuffix(cleaned).takeIf { it.length < maxFileNameLength } ?: ""
        return cleaned.take(maxFileNameLength - extension.length) + extension
    }

    /// Prefers the extension of the display name so the MIME type and the file name agree —
    /// MediaProvider rewrites the extension when they don't.
    private fun resolveMimeType(fileName: String, filePath: String?, declared: String?): String {
        return mimeTypeFromExtension(extensionSuffix(fileName).removePrefix("."))
            ?: filePath?.let { mimeTypeFromExtension(File(it).extension) }
            ?: declared?.takeIf { it.isNotBlank() }
            ?: "application/octet-stream"
    }

    private fun mimeTypeFromExtension(extension: String): String? {
        if (extension.isEmpty()) return null
        val normalized = extension.lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(normalized) ?: appleMediaTypes[normalized]
    }

    private fun mediaTypeFor(mimeType: String): MediaType? = when {
        mimeType.startsWith("image/") -> MediaType.IMAGE
        mimeType.startsWith("video/") -> MediaType.VIDEO
        mimeType.startsWith("audio/") -> MediaType.AUDIO
        else -> null
    }

    private fun baseName(fileName: String): String {
        val dot = fileName.lastIndexOf('.')
        return if (dot > 0) fileName.substring(0, dot) else fileName
    }

    private fun extensionSuffix(fileName: String): String {
        val dot = fileName.lastIndexOf('.')
        return if (dot > 0) fileName.substring(dot) else ""
    }

    private fun disambiguate(fileName: String): String =
        "${baseName(fileName)}_${System.currentTimeMillis()}${extensionSuffix(fileName)}"
}

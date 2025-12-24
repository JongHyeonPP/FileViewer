package com.opjh.fileviewer

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.util.UUID

class LibreOfficeEmbeddedPlatformView(
    private val context: Context,
    messenger: BinaryMessenger,
    private val viewId: Int,
    private val fileId: String,
    private val displayPath: String
) : PlatformView {

    private val root: FrameLayout = FrameLayout(context)
    private val channel = MethodChannel(messenger, "app.channel/lo_embedded_view_$viewId")

    init {
        Log.i(TAG, "init start viewId=$viewId fileId=$fileId displayPath=$displayPath")

        root.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )

        val tv = TextView(context)
        tv.textSize = 14f
        tv.setPadding(24, 24, 24, 24)
        tv.text = "LO embedded 준비 중\nfileId=$fileId\ndisplayPath=$displayPath"
        root.addView(
            tv,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        val copied = tryResolveAndCopyToCache()
        if (copied != null) {
            tv.text = "LO embedded 준비 완료\ncachePath=$copied"

            channel.invokeMethod(
                "onReady",
                mapOf(
                    "cachePath" to copied,
                    "originalFileId" to fileId,
                    "displayPath" to displayPath
                )
            )

            Handler(Looper.getMainLooper()).post {
                ensureLibreOfficeRuntimeExtracted()
                startLibreOfficeMainActivity(copied, displayPath)
            }
        } else {
            tv.text = "LO embedded 실패\nfileId=$fileId"
            channel.invokeMethod(
                "onError",
                mapOf(
                    "reason" to "copy_failed",
                    "originalFileId" to fileId,
                    "displayPath" to displayPath
                )
            )
        }
    }

    private fun tryResolveAndCopyToCache(): String? {
        if (fileId.isBlank()) {
            Log.e(TAG, "fileId empty")
            return null
        }

        return try {
            val cacheDir = File(context.cacheDir, "lo_open")
            if (!cacheDir.exists()) cacheDir.mkdirs()

            val ext = guessExt(displayPath)
            val outFile = File(cacheDir, "open_${UUID.randomUUID()}.$ext")

            Log.i(TAG, "copy start fileId=$fileId displayPath=$displayPath ext=$ext out=${outFile.absolutePath}")

            val inputStream = openInputStreamFromFileId(fileId)
            if (inputStream == null) {
                Log.e(TAG, "openInputStreamFromFileId null fileId=$fileId")
                return null
            }

            inputStream.use { input ->
                FileOutputStream(outFile).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        output.write(buffer, 0, read)
                    }
                    output.flush()
                }
            }

            Log.i(TAG, "copied to cache path=${outFile.absolutePath}")
            logFileInfo("after_copy", outFile.absolutePath)
            outFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "copy failed fileId=$fileId", e)
            null
        }
    }

    private fun openInputStreamFromFileId(id: String): InputStream? {
        val trimmed = id.trim()
        if (trimmed.isEmpty()) return null

        return try {
            val directFile = File(trimmed)
            if (directFile.exists() && directFile.isFile && directFile.canRead()) {
                Log.i(TAG, "openInputStream direct file path=$trimmed")
                return FileInputStream(directFile)
            }

            when {
                trimmed.startsWith("content://") -> {
                    context.contentResolver.openInputStream(Uri.parse(trimmed))
                }
                trimmed.startsWith("file://") -> {
                    val uri = Uri.parse(trimmed)
                    val path = uri.path ?: return null
                    FileInputStream(File(path))
                }
                trimmed.startsWith("/") -> {
                    Log.i(TAG, "openInputStream raw path=$trimmed")
                    FileInputStream(File(trimmed))
                }
                trimmed.startsWith("data/") -> {
                    val fixed = "/$trimmed"
                    Log.i(TAG, "openInputStream fixed raw path=$fixed")
                    FileInputStream(File(fixed))
                }
                else -> {
                    val uri = Uri.parse(trimmed)
                    when (uri.scheme) {
                        "content" -> context.contentResolver.openInputStream(uri)
                        "file" -> {
                            val path = uri.path ?: return null
                            FileInputStream(File(path))
                        }
                        else -> {
                            val fallbackFile = File(trimmed)
                            if (fallbackFile.exists() && fallbackFile.isFile && fallbackFile.canRead()) {
                                Log.i(TAG, "openInputStream fallback file path=$trimmed")
                                FileInputStream(fallbackFile)
                            } else {
                                null
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "openInputStreamFromFileId failed id=$id", e)
            null
        }
    }

    private fun ensureLibreOfficeRuntimeExtracted() {
        try {
            val loRoot = File(context.filesDir, "lo")
            val marker = File(loRoot, "extracted.marker")

            if (marker.exists()) {
                Log.i(TAG, "runtime already extracted marker=${marker.absolutePath}")
                return
            }

            Log.i(TAG, "runtime extract start root=${loRoot.absolutePath}")

            val programDst = File(loRoot, "program")
            val shareDst = File(loRoot, "share")
            val cacheDst = File(loRoot, "cache")

            programDst.mkdirs()
            shareDst.mkdirs()
            cacheDst.mkdirs()

            copyAssetDirRecursive("assets/libreoffice/program", programDst)
            copyAssetDirRecursive("assets/libreoffice/share", shareDst)

            copyAssetDirRecursive("assets/program", programDst)

            val servicesDst = File(programDst, "services")
            servicesDst.mkdirs()
            copyAssetDirRecursive("assets/program/services", servicesDst)

            marker.writeText("ok")

            Log.i(TAG, "runtime extract done marker=${marker.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "runtime extract failed", e)
        }
    }

    private fun copyAssetDirRecursive(assetPath: String, dstDir: File) {
        val cleaned = assetPath.removePrefix("assets/")

        val list = context.assets.list(cleaned) ?: return
        if (list.isEmpty()) return

        for (name in list) {
            val childAsset = "$cleaned/$name"
            val childList = context.assets.list(childAsset)

            if (childList != null && childList.isNotEmpty()) {
                val childDir = File(dstDir, name)
                if (!childDir.exists()) childDir.mkdirs()
                copyAssetDirRecursive("assets/$childAsset", childDir)
            } else {
                val outFile = File(dstDir, name)
                if (outFile.exists() && outFile.length() > 0L) continue

                context.assets.open(childAsset).use { input ->
                    FileOutputStream(outFile).use { output ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val read = input.read(buffer)
                            if (read <= 0) break
                            output.write(buffer, 0, read)
                        }
                        output.flush()
                    }
                }
            }
        }
    }

    private fun startLibreOfficeMainActivity(cachePath: String, originalDisplayPath: String) {
        try {
            logFileInfo("before_start_activity", cachePath)

            val file = File(cachePath)
            if (!file.exists()) {
                Log.e(TAG, "cache file not found path=$cachePath")
                channel.invokeMethod(
                    "onError",
                    mapOf(
                        "reason" to "cache_missing",
                        "originalFileId" to fileId,
                        "displayPath" to displayPath
                    )
                )
                return
            }

            val uri = FileProvider.getUriForFile(
                context,
                context.packageName + ".fileprovider",
                file
            )

            val mimeType = guessMimeType(originalDisplayPath)

            val intent = Intent(Intent.ACTION_VIEW).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setDataAndType(uri, mimeType)
                setClassName(context.packageName, "org.libreoffice.LibreOfficeMainActivity")
            }

            val resolved = context.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            if (resolved == null) {
                Log.e(TAG, "LibreOfficeMainActivity not resolvable")
                channel.invokeMethod(
                    "onError",
                    mapOf(
                        "reason" to "activity_not_found",
                        "originalFileId" to fileId,
                        "displayPath" to displayPath
                    )
                )
                return
            }

            Log.i(TAG, "startActivity target=org.libreoffice.LibreOfficeMainActivity uri=$uri mime=$mimeType")
            context.startActivity(intent)
            Log.i(TAG, "started LibreOfficeMainActivity path=$cachePath")
        } catch (e: Exception) {
            Log.e(TAG, "failed to start LibreOfficeMainActivity path=$cachePath", e)
            channel.invokeMethod(
                "onError",
                mapOf(
                    "reason" to "start_activity_failed",
                    "originalFileId" to fileId,
                    "displayPath" to displayPath
                )
            )
        }
    }

    private fun guessExt(path: String): String {
        val lower = path.lowercase()
        return when {
            lower.endsWith(".docx") -> "docx"
            lower.endsWith(".xlsx") -> "xlsx"
            lower.endsWith(".pptx") -> "pptx"
            lower.endsWith(".odt") -> "odt"
            lower.endsWith(".ods") -> "ods"
            lower.endsWith(".odp") -> "odp"
            lower.endsWith(".pdf") -> "pdf"
            else -> "bin"
        }
    }

    private fun guessMimeType(path: String): String {
        val lower = path.lowercase()
        return when {
            lower.endsWith(".docx") -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            lower.endsWith(".xlsx") -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            lower.endsWith(".pptx") -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            lower.endsWith(".odt") -> "application/vnd.oasis.opendocument.text"
            lower.endsWith(".ods") -> "application/vnd.oasis.opendocument.spreadsheet"
            lower.endsWith(".odp") -> "application/vnd.oasis.opendocument.presentation"
            lower.endsWith(".pdf") -> "application/pdf"
            else -> "application/octet-stream"
        }
    }

    override fun getView(): View {
        Log.i(TAG, "getView viewId=$viewId")
        return root
    }

    override fun dispose() {
        Log.i(TAG, "dispose viewId=$viewId")
    }

    private fun logFileInfo(tag: String, path: String) {
        try {
            val f = File(path)
            Log.i(TAG, "$tag path=$path exists=${f.exists()} len=${f.length()} canRead=${f.canRead()}")
        } catch (e: Exception) {
            Log.e(TAG, "logFileInfo failed tag=$tag path=$path", e)
        }
    }

    companion object {
        private const val TAG = "LO_EMBED"
    }
}

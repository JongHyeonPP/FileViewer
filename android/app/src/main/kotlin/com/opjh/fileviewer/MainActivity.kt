package com.opjh.fileviewer

import android.app.Activity
import android.content.Intent
import android.content.res.AssetManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import android.os.Handler
import android.os.Looper
import kotlin.concurrent.thread


class MainActivity : FlutterActivity() {

    private val initChannelName = "app.channel/file_intent_init"
    private val eventsChannelName = "app.channel/file_intent_events"
    private val pickerChannelName = "app.channel/file_picker"
    private val contentChannelName = "app.channel/file_content"
    private val loChannelName = "app.channel/libreoffice_open"

    private var initChannel: MethodChannel? = null
    private var eventsChannel: MethodChannel? = null
    private var pickerChannel: MethodChannel? = null
    private var contentChannel: MethodChannel? = null
    private var loChannel: MethodChannel? = null

    private var initialFileInfo: HashMap<String, String>? = null
    private var pendingPickerResult: MethodChannel.Result? = null

    private val requestCodePickFile = 1001

    private val loAssetsRoot = "libreoffice"
    private val loAssetsProgram = "$loAssetsRoot/program"
    private val loAssetsShare = "$loAssetsRoot/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.e("LO_TEST", "configureFlutterEngine entered")

        try {
            Log.e("LO_TEST", "before loadLibrary lo-native-code")
            System.loadLibrary("lo-native-code")
            Log.e("LO_TEST", "after loadLibrary lo-native-code success")
        } catch (t: Throwable) {
            Log.e("LO_TEST", "loadLibrary lo-native-code failed", t)
        }

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "lo_embedded_view",
                LibreOfficeEmbeddedViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )

        thread(start = true) {
    ensureLoAssetsExtracted()
    Handler(Looper.getMainLooper()).post {
        Log.i("LO_ASSETS", "extract finished")
    }
}


        initChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            initChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialFile" -> {
                        result.success(initialFileInfo)
                        initialFileInfo = null
                    }
                    else -> result.notImplemented()
                }
            }
        }

        eventsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventsChannelName
        )

        pickerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pickerChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFile" -> {
                        if (pendingPickerResult != null) {
                            result.error("PICK_IN_PROGRESS", "이미 파일 선택이 진행 중입니다", null)
                            return@setMethodCallHandler
                        }

                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf(
                                    "text/*",
                                    "application/json",
                                    "application/xml",
                                    "text/csv",
                                    "application/pdf",
                                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                                    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                                    "image/*"
                                )
                            )
                        }

                        pendingPickerResult = result
                        @Suppress("DEPRECATION")
                        run {
                            startActivityForResult(intent, requestCodePickFile)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        contentChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            contentChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "readBytes" -> {
                        val fileId = call.argument<String>("fileId")
                        if (fileId.isNullOrEmpty()) {
                            result.error("ARGUMENT_ERROR", "fileId 가 비어 있습니다", null)
                            return@setMethodCallHandler
                        }

                        val bytes = readBytesFromUri(fileId)
                        if (bytes == null) {
                            result.error("READ_FAILED", "파일을 읽는 중 오류가 발생했습니다", null)
                        } else {
                            result.success(bytes)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        loChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            loChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        val fileId = call.argument<String>("fileId") ?: ""
                        val displayPath = call.argument<String>("displayPath") ?: ""

                        Log.i("DOCX_OPEN", "start fileId=$fileId displayPath=$displayPath")

                        if (fileId.isBlank()) {
                            result.error(
                                "ARGUMENT_ERROR",
                                "fileId 가 비어 있습니다",
                                mapOf("reason" to "fileId_blank")
                            )
                            return@setMethodCallHandler
                        }

                        ensureLoAssetsExtracted()

                        val openResult = openInLibreOffice(fileId, displayPath)
                        if (openResult) {
                            result.success(true)
                        } else {
                            result.error(
                                "OPEN_FAILED",
                                "LibreOffice 실행에 실패했습니다",
                                mapOf(
                                    "reason" to "start_activity_failed",
                                    "fileId" to fileId,
                                    "displayPath" to displayPath
                                )
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        handleIntent(intent, true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, false)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != requestCodePickFile) return

        val callback = pendingPickerResult
        pendingPickerResult = null
        if (callback == null) return

        if (resultCode != Activity.RESULT_OK) {
            callback.success(null)
            return
        }

        val dataUri: Uri? = data?.data
        if (dataUri == null) {
            callback.success(null)
            return
        }

        val flags = data.flags
        val takeFlags = flags and (
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )

        if (takeFlags != 0) {
            try {
                contentResolver.takePersistableUriPermission(dataUri, takeFlags)
            } catch (_: Exception) {
            }
        }

        val info = buildSharedFileInfo(dataUri)
        if (info == null) {
            callback.error("NO_INFO", "파일 정보를 가져오지 못했습니다", null)
            return
        }

        val map = hashMapOf(
            "fileId" to info.fileId,
            "displayPath" to info.displayPath
        )

        callback.success(map)
    }

    private fun handleIntent(intent: Intent?, isInitial: Boolean) {
        if (intent == null) return

        val action = intent.action
        val data: Uri? = intent.data

        if (action == Intent.ACTION_VIEW && data != null) {
            val info = buildSharedFileInfo(data) ?: return

            val map = hashMapOf(
                "fileId" to info.fileId,
                "displayPath" to info.displayPath
            )

            if (isInitial) {
                initialFileInfo = map
            } else {
                try {
                    eventsChannel?.invokeMethod("onFileShared", map)
                } catch (_: Exception) {
                }
            }
        }
    }

    private data class SharedFileInfo(
        val fileId: String,
        val displayPath: String
    )

    private fun buildSharedFileInfo(uri: Uri): SharedFileInfo? {
        val displayPath = buildDisplayPath(uri)
        val id = uri.toString()
        return SharedFileInfo(id, displayPath)
    }

    private fun buildDisplayPath(uri: Uri): String {
        if ("file".equals(uri.scheme, ignoreCase = true)) {
            return uri.path ?: "unknown"
        }

        var name: String? = null
        var relative: String? = null

        val projection = arrayOf(
            MediaStore.MediaColumns.DISPLAY_NAME,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.MediaColumns.RELATIVE_PATH
            } else {
                MediaStore.MediaColumns.DATA
            }
        )

        try {
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                val relIndex =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        cursor.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
                    } else {
                        cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                    }

                if (cursor.moveToFirst()) {
                    if (nameIndex >= 0) name = cursor.getString(nameIndex)
                    if (relIndex >= 0) relative = cursor.getString(relIndex)
                }
            }
        } catch (_: Exception) {
        }

        if (name == null) name = uri.lastPathSegment ?: "unknown"

        if (!relative.isNullOrEmpty()) {
            val cleaned = if (relative!!.endsWith("/")) relative!! else "${relative!!}/"
            return cleaned + name
        }

        return name!!
    }

    private fun readBytesFromUri(uriString: String): ByteArray? {
        return try {
            val uri = Uri.parse(uriString)
            contentResolver.openInputStream(uri)?.use { input ->
                input.readBytes()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun openInLibreOffice(fileId: String, displayPath: String): Boolean {
        val uri = buildUriForOpen(fileId)
        if (uri == null) {
            Log.e("DOCX_OPEN", "uri null for fileId=$fileId")
            return false
        }

        val mime = detectMime(displayPath, uri)

        Log.i("DOCX_OPEN", "open try uri=$uri mime=$mime")

        val tryTargets = listOf(
            "org.libreoffice.LibreOfficeMainActivity",
            "org.libreoffice.ui.LibreOfficeUIActivity"
        )

        for (target in tryTargets) {
            try {
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mime)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    setClassName(this@MainActivity, target)
                }

                Log.i("DOCX_OPEN", "startActivity target=$target")
                startActivity(intent)
                Log.i("DOCX_OPEN", "success target=$target")
                return true
            } catch (e: Exception) {
                Log.e("DOCX_OPEN", "startActivity exception target=$target", e)
            }
        }

        Log.e("DOCX_OPEN", "openInLibreOffice failed uri=$uri mime=$mime")
        return false
    }

    private fun buildUriForOpen(fileId: String): Uri? {
        return try {
            if (fileId.startsWith("content://")) {
                Uri.parse(fileId)
            } else if (fileId.startsWith("file://")) {
                Uri.parse(fileId)
            } else if (fileId.startsWith("/")) {
                val f = File(fileId)
                if (!f.exists()) return null
                FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    f
                )
            } else {
                val f = File(fileId)
                if (!f.exists()) return null
                FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    f
                )
            }
        } catch (e: Exception) {
            Log.e("DOCX_OPEN", "buildUriForOpen exception", e)
            null
        }
    }

    private fun detectMime(displayPath: String, uri: Uri): String {
        val path = if (displayPath.isNotBlank()) displayPath else uri.toString()
        val lower = path.lowercase()

        return when {
            lower.endsWith(".docx") -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            lower.endsWith(".xlsx") -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            lower.endsWith(".pptx") -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            lower.endsWith(".odt") -> "application/vnd.oasis.opendocument.text"
            lower.endsWith(".ods") -> "application/vnd.oasis.opendocument.spreadsheet"
            lower.endsWith(".odp") -> "application/vnd.oasis.opendocument.presentation"
            lower.endsWith(".pdf") -> "application/pdf"
            else -> "*/*"
        }
    }

    private fun ensureLoAssetsExtracted() {
        val loRoot = File(filesDir, "lo")
        val marker = File(loRoot, "extracted.marker")
        val programDir = File(loRoot, "program")
        val shareDir = File(loRoot, "share")
        val loCacheDir = File(loRoot, "cache")

        if (!loRoot.exists()) loRoot.mkdirs()
        if (!programDir.exists()) programDir.mkdirs()
        if (!shareDir.exists()) shareDir.mkdirs()
        if (!loCacheDir.exists()) loCacheDir.mkdirs()

        val requiredFundamental = File(programDir, "fundamentalrc")
        val requiredWriterXcd = File(shareDir, "registry/writer.xcd")

        val alreadyOk = marker.exists() && requiredFundamental.exists() && requiredWriterXcd.exists()
        if (alreadyOk) {
            Log.i("LO_ASSETS", "skip extracted loRoot=${loRoot.absolutePath}")
            Log.i("LO_ASSETS", "fundamental=${requiredFundamental.absolutePath} exists=${requiredFundamental.exists()}")
            Log.i("LO_ASSETS", "writerXcd=${requiredWriterXcd.absolutePath} exists=${requiredWriterXcd.exists()}")
            return
        }

        Log.i("LO_ASSETS", "extract start loRoot=${loRoot.absolutePath}")

        try {
            val rootChildren = assets.list(loAssetsRoot) ?: emptyArray()
            Log.i("LO_ASSETS", "assets root=$loAssetsRoot childrenCount=${rootChildren.size}")

            val programChildren = assets.list(loAssetsProgram) ?: emptyArray()
            Log.i("LO_ASSETS", "assets path=$loAssetsProgram childrenCount=${programChildren.size}")

            val shareChildren = assets.list(loAssetsShare) ?: emptyArray()
            Log.i("LO_ASSETS", "assets path=$loAssetsShare childrenCount=${shareChildren.size}")

            copyAssetFolderToDir(assets, "libreoffice/program", programDir)
            copyAssetFolderToDir(assets, "libreoffice/share", shareDir)


            writeSofficeRc(loRoot)

            marker.writeText("ok\n", Charsets.UTF_8)

            Log.i(
                "LO_ASSETS",
                "extract done fundamental=${requiredFundamental.exists()} writerXcd=${requiredWriterXcd.exists()}"
            )
        } catch (e: Exception) {
            Log.e("LO_ASSETS", "extract failed", e)
        }
    }

    private fun copyAssetFolderToDir(assetManager: AssetManager, assetPath: String, outDir: File) {
        val children = assetManager.list(assetPath) ?: emptyArray()
        if (children.isEmpty()) {
            val outFile = File(outDir, File(assetPath).name)
            copyAssetFile(assetManager, assetPath, outFile)
            return
        }

        for (child in children) {
            val childAssetPath = "$assetPath/$child"
            val grand = assetManager.list(childAssetPath) ?: emptyArray()
            if (grand.isEmpty()) {
                val outFile = File(outDir, child)
                copyAssetFile(assetManager, childAssetPath, outFile)
            } else {
                val childDir = File(outDir, child)
                if (!childDir.exists()) childDir.mkdirs()
                copyAssetFolderToDir(assetManager, childAssetPath, childDir)
            }
        }
    }

    private fun copyAssetFile(assetManager: AssetManager, assetFilePath: String, outFile: File) {
        val parent = outFile.parentFile
        if (parent != null && !parent.exists()) parent.mkdirs()

        assetManager.open(assetFilePath).use { input ->
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

    private fun writeSofficeRc(loRoot: File) {
        val programDir = File(loRoot, "program")
        if (!programDir.exists()) programDir.mkdirs()

        val fundamentalRc = File(programDir, "fundamentalrc")
        val appLoCache = File(loRoot, "cache")
        if (!appLoCache.exists()) appLoCache.mkdirs()

        val sofficercText = buildString {
            appendLine("[Bootstrap]")
            appendLine("Logo=1")
            appendLine("NativeProgress=1")
            appendLine("URE_BOOTSTRAP=file://${fundamentalRc.absolutePath}")
            appendLine("HOME=${appLoCache.absolutePath}")
            appendLine("OSL_SOCKET_PATH=${appLoCache.absolutePath}")
        }

        val target = File(filesDir.parentFile, "program/sofficerc")
        val targetDir = target.parentFile
        if (targetDir != null && !targetDir.exists()) targetDir.mkdirs()

        target.writeText(sofficercText, Charsets.UTF_8)

        Log.i("LO_ASSETS", "write sofficerc path=${target.absolutePath}")
        Log.i("LO_ASSETS", "sofficerc content=$sofficercText")
    }
}

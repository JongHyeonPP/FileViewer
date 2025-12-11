package com.opjh.fileviewer

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val INIT_CHANNEL = "app.channel/file_intent_init"
    private val EVENTS_CHANNEL = "app.channel/file_intent_events"
    private val PICKER_CHANNEL = "app.channel/file_picker"
    private val CONTENT_CHANNEL = "app.channel/file_content"

    private var initChannel: MethodChannel? = null
    private var eventsChannel: MethodChannel? = null
    private var pickerChannel: MethodChannel? = null
    private var contentChannel: MethodChannel? = null

    private var initialFileInfo: HashMap<String, String>? = null
    private var pendingPickerResult: MethodChannel.Result? = null

    private val REQUEST_CODE_PICK_FILE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        initChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INIT_CHANNEL
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
            EVENTS_CHANNEL
        )

        pickerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PICKER_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFile" -> {
                        if (pendingPickerResult != null) {
                            result.error(
                                "PICK_IN_PROGRESS",
                                "이미 파일 선택이 진행 중입니다",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }

                        pendingPickerResult = result
                        @Suppress("DEPRECATION")
                        run {
                            startActivityForResult(intent, REQUEST_CODE_PICK_FILE)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
        }

        contentChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONTENT_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "readBytes" -> {
                        val fileId = call.argument<String>("fileId")
                        if (fileId.isNullOrEmpty()) {
                            result.error(
                                "ARGUMENT_ERROR",
                                "fileId 가 비어 있습니다",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val bytes = readBytesFromUri(fileId)
                        if (bytes == null) {
                            result.error(
                                "READ_FAILED",
                                "파일을 읽는 중 오류가 발생했습니다",
                                null
                            )
                        } else {
                            result.success(bytes)
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

        if (requestCode != REQUEST_CODE_PICK_FILE) {
            return
        }

        val callback = pendingPickerResult
        pendingPickerResult = null

        if (callback == null) {
            return
        }

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
                val nameIndex =
                    cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                val relIndex =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        cursor.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
                    } else {
                        cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                    }

                if (cursor.moveToFirst()) {
                    if (nameIndex >= 0) {
                        name = cursor.getString(nameIndex)
                    }
                    if (relIndex >= 0) {
                        relative = cursor.getString(relIndex)
                    }
                }
            }
        } catch (_: Exception) {
        }

        if (name == null) {
            name = uri.lastPathSegment ?: "unknown"
        }

        if (relative != null && relative!!.isNotEmpty()) {
            val cleaned = if (relative!!.endsWith("/")) {
                relative!!
            } else {
                "${relative!!}/"
            }
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
}

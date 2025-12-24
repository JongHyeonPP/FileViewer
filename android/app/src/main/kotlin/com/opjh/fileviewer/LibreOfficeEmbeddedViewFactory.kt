package com.opjh.fileviewer

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class LibreOfficeEmbeddedViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        val fileId = params["fileId"] as? String ?: ""
        val displayPath = params["displayPath"] as? String ?: ""
        return LibreOfficeEmbeddedPlatformView(context, messenger, viewId, fileId, displayPath)
    }
}

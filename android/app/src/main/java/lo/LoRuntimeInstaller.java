package com.opjh.fileviewer.lo;

import android.content.Context;
import android.content.res.AssetManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.ArrayDeque;

public final class LoRuntimeInstaller {

    private LoRuntimeInstaller() {}

    public static void ensureInstalled(Context context) throws Exception {
        File dataDir = context.getDataDir();
        File programDir = new File(dataDir, "program");
        File marker = new File(programDir, ".installed");

        if (marker.exists()) {
            return;
        }

        if (!programDir.exists()) {
            boolean ok = programDir.mkdirs();
            if (!ok) {
                throw new IllegalStateException("Failed to create program dir: " + programDir.getAbsolutePath());
            }
        }

        copyAssetTree(context.getAssets(), "program", programDir);

        try (FileOutputStream fos = new FileOutputStream(marker)) {
            fos.write("ok".getBytes());
        }
    }

    private static void copyAssetTree(AssetManager assets, String assetRoot, File outRoot) throws Exception {
        ArrayDeque<String> queue = new ArrayDeque<>();
        queue.add(assetRoot);

        while (!queue.isEmpty()) {
            String path = queue.removeFirst();
            String[] children = assets.list(path);
            if (children == null) {
                continue;
            }

            if (children.length == 0) {
                copyAssetFile(assets, path, new File(outRoot, path.substring(assetRoot.length() + 1)));
                continue;
            }

            File dir = path.equals(assetRoot)
                    ? outRoot
                    : new File(outRoot, path.substring(assetRoot.length() + 1));

            if (!dir.exists()) {
                boolean ok = dir.mkdirs();
                if (!ok) {
                    throw new IllegalStateException("Failed to create dir: " + dir.getAbsolutePath());
                }
            }

            for (String c : children) {
                queue.add(path + "/" + c);
            }
        }
    }

    private static void copyAssetFile(AssetManager assets, String assetPath, File outFile) throws Exception {
        File parent = outFile.getParentFile();
        if (parent != null && !parent.exists()) {
            boolean ok = parent.mkdirs();
            if (!ok) {
                throw new IllegalStateException("Failed to create dir: " + parent.getAbsolutePath());
            }
        }

        try (InputStream is = assets.open(assetPath);
             FileOutputStream os = new FileOutputStream(outFile)) {

            byte[] buf = new byte[1024 * 1024];
            int n;
            while ((n = is.read(buf)) > 0) {
                os.write(buf, 0, n);
            }
        }
    }
}

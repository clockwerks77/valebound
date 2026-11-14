package app.habit_adventure

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The app's only door to files outside its own storage (DESIGN §11).
 *
 * Everything goes through the Storage Access Framework. The user picks a
 * folder once; the permission is persisted; the app writes Markdown files
 * inside that folder and nowhere else. It lists the folder only to find a
 * file of the same name to overwrite. It never reads file contents there and
 * never deletes anything.
 *
 * There is no network code here or anywhere else in the app.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "app.habit_adventure/vault"
    private val prefsName = "vault"
    private val keyTree = "tree_uri"

    private val requestTree = 4101
    private val requestSave = 4102
    private val requestOpen = 4103

    private var pending: MethodChannel.Result? = null
    private var pendingContent: String? = null

    /** Calendar, Health Connect steps and the reminder: see DeviceChannel. */
    private val device = DeviceChannel(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handle(call, result) }
        device.noteIntent(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DeviceChannel.CHANNEL)
            .setMethodCallHandler { call, result -> device.handle(call, result) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        device.noteIntent(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (device.onPermissionsResult(requestCode)) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "status" -> result.success(status())
                "pickFolder" -> launch(
                    result,
                    Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                    ),
                    requestTree,
                    null,
                )
                "forgetFolder" -> {
                    forgetFolder()
                    result.success(null)
                }
                "writeFiles" -> {
                    val files = stringMap(call.argument<Map<*, *>>("files"))
                    Thread {
                        val ok = try {
                            writeFiles(files)
                        } catch (e: Exception) {
                            false
                        }
                        runOnUiThread { result.success(ok) }
                    }.start()
                }
                "shareFiles" -> result.success(
                    shareFiles(stringMap(call.argument<Map<*, *>>("files")))
                )
                "saveDocument" -> launch(
                    result,
                    Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("application/json")
                        .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "backup.json"),
                    requestSave,
                    call.argument<String>("content") ?: "",
                )
                "openDocument" -> launch(
                    result,
                    Intent(Intent.ACTION_OPEN_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("*/*"),
                    requestOpen,
                    null,
                )
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("vault", e.message, null)
        }
    }

    private fun stringMap(raw: Map<*, *>?): Map<String, String> {
        val out = LinkedHashMap<String, String>()
        raw?.forEach { (k, v) -> if (k is String && v is String) out[k] = v }
        return out
    }

    private fun launch(result: MethodChannel.Result, intent: Intent, code: Int, content: String?) {
        if (pending != null) {
            // One picker at a time.
            result.success(if (code == requestTree) status() else null)
            return
        }
        pending = result
        pendingContent = content
        try {
            startActivityForResult(intent, code)
        } catch (e: Exception) {
            pending = null
            pendingContent = null
            result.success(if (code == requestTree) status() else null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != requestTree && requestCode != requestSave && requestCode != requestOpen) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pending
        val content = pendingContent
        pending = null
        pendingContent = null
        if (result == null) return
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        try {
            when (requestCode) {
                requestTree -> {
                    if (uri != null) rememberFolder(uri)
                    result.success(status())
                }
                requestSave -> {
                    if (uri == null) {
                        result.success(false)
                    } else {
                        writeText(uri, content ?: "")
                        result.success(true)
                    }
                }
                else -> result.success(if (uri == null) null else readText(uri))
            }
        } catch (e: Exception) {
            when (requestCode) {
                requestTree -> result.success(status())
                requestSave -> result.success(false)
                else -> result.success(null)
            }
        }
    }

    // ---- the picked folder ------------------------------------------------

    private fun prefs() = getSharedPreferences(prefsName, Context.MODE_PRIVATE)

    private fun treeUri(): Uri? = prefs().getString(keyTree, null)?.let { Uri.parse(it) }

    private val rw = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

    private fun rememberFolder(uri: Uri) {
        val old = treeUri()
        contentResolver.takePersistableUriPermission(uri, rw)
        prefs().edit().putString(keyTree, uri.toString()).apply()
        if (old != null && old != uri) {
            try {
                contentResolver.releasePersistableUriPermission(old, rw)
            } catch (e: Exception) {
                // Already gone; nothing to release.
            }
        }
    }

    private fun forgetFolder() {
        val old = treeUri() ?: return
        prefs().edit().remove(keyTree).apply()
        try {
            contentResolver.releasePersistableUriPermission(old, rw)
        } catch (e: Exception) {
            // Already gone; nothing to release.
        }
    }

    private fun rootDocId(tree: Uri): String = DocumentsContract.getTreeDocumentId(tree)

    private fun folderName(tree: Uri): String? {
        val doc = DocumentsContract.buildDocumentUriUsingTree(tree, rootDocId(tree))
        contentResolver.query(
            doc,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0)
        }
        return null
    }

    private fun status(): Map<String, Any?> {
        val tree = treeUri() ?: return mapOf("chosen" to false, "available" to false, "name" to null)
        val granted = contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isWritePermission
        }
        val name = if (granted) {
            try {
                folderName(tree)
            } catch (e: Exception) {
                null
            }
        } else {
            null
        }
        // Available only if the system still grants it and the folder answers.
        return mapOf("chosen" to true, "available" to (granted && name != null), "name" to name)
    }

    // ---- writing ------------------------------------------------------------

    /** Document id and MIME type of the child called [name], if there is one. */
    private fun findChild(tree: Uri, parentId: String, name: String): Pair<String, String?>? {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getString(1) == name) {
                    return Pair(cursor.getString(0), cursor.getString(2))
                }
            }
        }
        return null
    }

    private fun ensureFolder(tree: Uri, parentId: String, name: String): String? {
        val existing = findChild(tree, parentId, name)
        if (existing != null) {
            return if (existing.second == DocumentsContract.Document.MIME_TYPE_DIR) existing.first else null
        }
        val parent = DocumentsContract.buildDocumentUriUsingTree(tree, parentId)
        val created = DocumentsContract.createDocument(
            contentResolver,
            parent,
            DocumentsContract.Document.MIME_TYPE_DIR,
            name,
        ) ?: return null
        return DocumentsContract.getDocumentId(created)
    }

    private fun writeText(uri: Uri, content: String) {
        // "wt": write and truncate, so a shorter file fully replaces a longer one.
        val stream = contentResolver.openOutputStream(uri, "wt")
            ?: throw IllegalStateException("no stream")
        stream.use { it.write(content.toByteArray(Charsets.UTF_8)) }
    }

    private fun readText(uri: Uri): String? {
        val stream = contentResolver.openInputStream(uri) ?: return null
        return stream.use { String(it.readBytes(), Charsets.UTF_8) }
    }

    /** Writes each `relative/path` under the picked folder. Never outside it. */
    private fun writeFiles(files: Map<String, String>): Boolean {
        val tree = treeUri() ?: return false
        val root = rootDocId(tree)
        for ((path, content) in files) {
            val parts = path.split('/').filter { it.isNotEmpty() && it != "." && it != ".." }
            if (parts.isEmpty()) return false
            var parentId = root
            for (i in 0 until parts.size - 1) {
                parentId = ensureFolder(tree, parentId, parts[i]) ?: return false
            }
            val name = parts.last()
            val existing = findChild(tree, parentId, name)
            val target = if (existing != null) {
                DocumentsContract.buildDocumentUriUsingTree(tree, existing.first)
            } else {
                DocumentsContract.createDocument(
                    contentResolver,
                    DocumentsContract.buildDocumentUriUsingTree(tree, parentId),
                    "text/markdown",
                    name,
                ) ?: return false
            }
            writeText(target, content)
        }
        return true
    }

    // ---- Share… -----------------------------------------------------------------

    private fun shareFiles(files: Map<String, String>): Boolean {
        if (files.isEmpty()) return false
        val dir = File(cacheDir, "share")
        dir.deleteRecursively()
        dir.mkdirs()
        val uris = ArrayList<Uri>()
        for ((path, content) in files) {
            val parts = path.split('/').filter { it.isNotEmpty() && it != "." && it != ".." }
            if (parts.isEmpty()) continue
            val file = File(dir, parts.joinToString(File.separator))
            file.parentFile?.mkdirs()
            file.writeText(content, Charsets.UTF_8)
            uris.add(FileProvider.getUriForFile(this, "$packageName.files", file))
        }
        if (uris.isEmpty()) return false
        val send = Intent(Intent.ACTION_SEND_MULTIPLE)
            .setType("text/markdown")
            .putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val clip = ClipData.newRawUri("export", uris[0])
        for (i in 1 until uris.size) clip.addItem(ClipData.Item(uris[i]))
        send.clipData = clip
        startActivity(Intent.createChooser(send, "Share export"))
        return true
    }
}

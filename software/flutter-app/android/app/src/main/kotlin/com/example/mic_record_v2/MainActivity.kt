package com.example.mic_record_v2

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
	private val channelName = "coffin/shared_storage"
	private val pickFolderRequestCode = 9001
	private var pendingResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"pickSharedFolder" -> {
						if (pendingResult != null) {
							result.error("PENDING", "Another folder picker is active", null)
							return@setMethodCallHandler
						}

						val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
							addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
							addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
							addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
							addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
						}

						pendingResult = result
						startActivityForResult(intent, pickFolderRequestCode)
					}

					"listFiles" -> {
						val treeUriStr = call.argument<String>("treeUri")
						val query = call.argument<String>("query")?.trim().orEmpty()
						if (treeUriStr.isNullOrEmpty()) {
							result.error("INVALID_ARGS", "Missing treeUri", null)
							return@setMethodCallHandler
						}

						val treeUri = Uri.parse(treeUriStr)
						val root = DocumentFile.fromTreeUri(this, treeUri)
						if (root == null || !root.exists()) {
							result.success(emptyList<Map<String, Any?>>())
							return@setMethodCallHandler
						}

						val matches = mutableListOf<Map<String, Any?>>()
						collectMatchingFiles(root, query.lowercase(), matches, 100)
						result.success(matches)
					}

					"copyToCache" -> {
						val uriStr = call.argument<String>("uri")
						val fileName = call.argument<String>("fileName") ?: "shared_file"
						if (uriStr.isNullOrEmpty()) {
							result.error("INVALID_ARGS", "Missing uri", null)
							return@setMethodCallHandler
						}

						val uri = Uri.parse(uriStr)
						val inputStream = contentResolver.openInputStream(uri)
						if (inputStream == null) {
							result.error("OPEN_FAILED", "Unable to open source file", null)
							return@setMethodCallHandler
						}

						val safeName = fileName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
						val tempFile = File(cacheDir, "shared_${System.currentTimeMillis()}_$safeName")
						var totalBytes = 0L

						inputStream.use { input ->
							FileOutputStream(tempFile).use { output ->
								val buffer = ByteArray(1024 * 64)
								var read = input.read(buffer)
								while (read > 0) {
									output.write(buffer, 0, read)
									totalBytes += read
									read = input.read(buffer)
								}
							}
						}

						result.success(mapOf(
							"tempPath" to tempFile.absolutePath,
							"size" to totalBytes
						))
					}

					"deleteFile" -> {
						val uriStr = call.argument<String>("uri")
						if (uriStr.isNullOrEmpty()) {
							result.error("INVALID_ARGS", "Missing uri", null)
							return@setMethodCallHandler
						}

						val uri = Uri.parse(uriStr)
						val doc = DocumentFile.fromSingleUri(this, uri)
						val deleted = doc?.delete() ?: false
						result.success(deleted)
					}

					"fileExists" -> {
						val treeUriStr = call.argument<String>("treeUri")
						val fileName = call.argument<String>("fileName")
						if (treeUriStr.isNullOrEmpty() || fileName.isNullOrEmpty()) {
							result.error("INVALID_ARGS", "Missing treeUri or fileName", null)
							return@setMethodCallHandler
						}

						val treeUri = Uri.parse(treeUriStr)
						val root = DocumentFile.fromTreeUri(this, treeUri)
						if (root == null || !root.exists()) {
							result.success(false)
							return@setMethodCallHandler
						}

						val exists = root.listFiles().any { it.name == fileName }
						result.success(exists)
					}

					"saveFileToSharedFolder" -> {
						val treeUriStr = call.argument<String>("treeUri")
						val sourcePath = call.argument<String>("sourcePath")
						val fileName = call.argument<String>("fileName")
						val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
						if (treeUriStr.isNullOrEmpty() || sourcePath.isNullOrEmpty() || fileName.isNullOrEmpty()) {
							result.error("INVALID_ARGS", "Missing treeUri, sourcePath, or fileName", null)
							return@setMethodCallHandler
						}

						val treeUri = Uri.parse(treeUriStr)
						val root = DocumentFile.fromTreeUri(this, treeUri)
						if (root == null || !root.exists()) {
							result.error("INVALID_TREE", "Shared folder not accessible", null)
							return@setMethodCallHandler
						}

						// Check conflict
						val existing = root.listFiles().firstOrNull { it.name == fileName }
						if (existing != null) {
							result.success(mapOf("status" to "exists"))
							return@setMethodCallHandler
						}

						val created = root.createFile(mimeType, fileName)
						if (created == null) {
							result.error("CREATE_FAILED", "Unable to create file in shared folder", null)
							return@setMethodCallHandler
						}

						val outStream = contentResolver.openOutputStream(created.uri)
						if (outStream == null) {
							result.error("WRITE_FAILED", "Unable to open output stream", null)
							return@setMethodCallHandler
						}

						val sourceFile = File(sourcePath)
						if (!sourceFile.exists()) {
							result.error("SOURCE_MISSING", "Source temp file not found", null)
							return@setMethodCallHandler
						}

						sourceFile.inputStream().use { input ->
							outStream.use { output ->
								val buffer = ByteArray(1024 * 64)
								var read = input.read(buffer)
								while (read > 0) {
									output.write(buffer, 0, read)
									read = input.read(buffer)
								}
							}
						}

						result.success(mapOf(
							"status" to "saved",
							"uri" to created.uri.toString()
						))
					}

					else -> result.notImplemented()
				}
			}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		if (requestCode == pickFolderRequestCode) {
			val result = pendingResult
			pendingResult = null

			if (result == null) {
				super.onActivityResult(requestCode, resultCode, data)
				return
			}

			if (resultCode != Activity.RESULT_OK || data?.data == null) {
				result.success(null)
				return
			}

			val uri = data.data!!
			val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)

			try {
				contentResolver.takePersistableUriPermission(uri, flags)
			} catch (e: SecurityException) {
				result.error("PERMISSION_FAILED", "Failed to persist folder permission", null)
				return
			}

			result.success(uri.toString())
			return
		}

		super.onActivityResult(requestCode, resultCode, data)
	}

	private fun collectMatchingFiles(
		root: DocumentFile,
		queryLower: String,
		results: MutableList<Map<String, Any?>>,
		maxResults: Int
	) {
		if (results.size >= maxResults) return

		for (file in root.listFiles()) {
			if (results.size >= maxResults) break
			if (file.isDirectory) {
				collectMatchingFiles(file, queryLower, results, maxResults)
			} else {
				val name = file.name ?: continue
				if (queryLower.isEmpty() || name.lowercase().contains(queryLower)) {
					results.add(
						mapOf(
							"uri" to file.uri.toString(),
							"name" to name,
							"mimeType" to file.type,
							"size" to file.length(),
							"isDirectory" to file.isDirectory
						)
					)
				}
			}
		}
	}
}

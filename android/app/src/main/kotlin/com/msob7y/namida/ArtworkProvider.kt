package com.msob7y.namida

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File

/// This class exists mainly to provide artwork access to third party apps (like android auto/wearables)
/// tied to a <provider> in AndroidManifest.xml
class ArtworkProvider : ContentProvider() {
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        val filePath = uri.getQueryParameter("path") ?: return null
        val file = File(filePath)
        if (!file.exists()) return null
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri): String = "image/jpeg"
    override fun onCreate(): Boolean = true
    override fun query(uri: Uri, p: Array<String>?, s: String?, sA: Array<String>?, so: String?): Cursor? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, s: String?, sA: Array<String>?): Int = 0
    override fun update(uri: Uri, v: ContentValues?, s: String?, sA: Array<String>?): Int = 0
}
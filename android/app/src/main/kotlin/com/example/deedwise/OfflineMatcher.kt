package com.example.deedwise

import android.content.Context
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.Closeable
import java.io.File
import java.nio.LongBuffer
import kotlin.math.sqrt
import org.json.JSONObject

/** Device-only inference. Prepared assets required; there is no network fallback. */
class OfflineMatcher(context: Context) : Closeable {
    private val env = OrtEnvironment.getEnvironment()
    private val tokenizer: CasedWordPiece
    private val session: OrtSession
    private val automaticMatchingEnabled: Boolean
    private val normalizer: BanglishNormalizer?
    private val embeddingCache = mutableMapOf<String, FloatArray>()
    init {
        val manifest = JSONObject(context.assets.open("offline_model/manifest.json").bufferedReader().use { it.readText() })
        automaticMatchingEnabled = manifest.optBoolean("automatic_matching_enabled", false)
        normalizer = if (manifest.getJSONObject("files").has("banglish_normalization.json")) {
            val data = JSONObject(context.assets.open("offline_model/banglish_normalization.json").bufferedReader().use { it.readText() })
            val words = mutableMapOf<String, String>()
            val groups = data.getJSONArray("groups")
            for (i in 0 until groups.length()) {
                val group = groups.getJSONArray(i)
                val aliases = group.getJSONArray(1)
                for (j in 0 until aliases.length()) words[aliases.getString(j)] = group.getString(0)
            }
            val markers = data.getJSONArray("strong_markers")
            BanglishNormalizer(words, (0 until markers.length()).map { markers.getString(it) }.toSet())
        } else null
        if (manifest.optJSONObject("files")?.has("reference_embeddings.json") == true) {
            val cache = JSONObject(context.assets.open("offline_model/reference_embeddings.json").bufferedReader().use { it.readText() })
            val encoderHash = manifest.getJSONObject("files").getJSONObject("encoder.onnx").getString("sha256")
            val normalizerHash = manifest.getJSONObject("files").optJSONObject("banglish_normalization.json")?.optString("sha256", "") ?: ""
            if (cache.getString("encoder_sha256") == encoderHash &&
                cache.optString("normalizer_sha256", "") == normalizerHash) {
                val entries = cache.getJSONArray("entries")
                for (i in 0 until entries.length()) {
                    val entry = entries.getJSONObject(i)
                    val values = entry.getJSONArray("embedding")
                    val vector = FloatArray(values.length()) { values.getDouble(it).toFloat() }
                    if (vector.size == manifest.getInt("output_dimensions") &&
                        vector.all { it.isFinite() } &&
                        kotlin.math.abs(vector.sumOf { it.toDouble() * it.toDouble() } - 1.0) < 0.001) {
                        embeddingCache["${entry.getString("id")}:${entry.getString("text")}"] = vector
                    }
                }
            }
        }
        tokenizer = CasedWordPiece(context.assets.open("offline_model/vocab.txt").bufferedReader().use { it.readLines() })
        val modelFile = File(context.filesDir, "deedwise-encoder-v1.onnx")
        context.assets.open("offline_model/encoder.onnx").use { source ->
            modelFile.outputStream().use { target -> source.copyTo(target) }
        }
        session = OrtSession.SessionOptions().use { options ->
            options.setIntraOpNumThreads(2)
            env.createSession(modelFile.absolutePath, options)
        }
    }
    private fun encode(text: String): FloatArray {
        val ids = tokenizer.encode(normalizer?.normalize(text) ?: text)
        val shape = longArrayOf(1, ids.size.toLong())
        OnnxTensor.createTensor(env, LongBuffer.wrap(ids), shape).use { tokens ->
            OnnxTensor.createTensor(env, LongBuffer.wrap(LongArray(ids.size) { 1L }), shape).use { attention ->
                session.run(mapOf("input_ids" to tokens, "attention_mask" to attention)).use { result ->
                    @Suppress("UNCHECKED_CAST")
                    val output = (result[0].value as Array<FloatArray>)[0].copyOf()
                    val norm = sqrt(output.sumOf { it.toDouble() * it.toDouble() })
                    require(norm > 0 && norm.isFinite())
                    return FloatArray(output.size) { (output[it] / norm).toFloat() }
                }
            }
        }
    }
    fun match(text: String, rules: List<Map<String, Any>>): Map<String, Any> {
        require(text.isNotBlank())
        if (text.length > 600) throw TextTooLongException()
        val query = encode(text)
        var bestId = ""
        var best = Double.NEGATIVE_INFINITY
        for (rule in rules) {
            val id = rule["id"] as? String ?: continue
            val phrases = rule["phrases"] as? List<*> ?: continue
            for (phrase in phrases.filterIsInstance<String>().filter { it.isNotBlank() }) {
                val reference = embeddingCache.getOrPut("$id:$phrase") { encode(phrase) }
                require(reference.size == query.size)
                val score = query.indices.sumOf { query[it].toDouble() * reference[it].toDouble() }.coerceIn(-1.0, 1.0)
                if (score > best) { best = score; bestId = id }
            }
        }
        require(bestId.isNotEmpty())
        return mapOf("ruleId" to bestId, "score" to best, "engine" to "device-onnx-v1",
            "automaticMatchingEnabled" to automaticMatchingEnabled)
    }
    override fun close() { session.close(); embeddingCache.clear() }
}

class BanglishNormalizer(private val words: Map<String, String>, private val markers: Set<String>) {
    private val latin = Regex("[A-Za-z]+")
    fun normalize(text: String): String {
        if (text.any { it in '\u0980'..'\u09FF' }) return text
        val tokens = latin.findAll(text).map { it.value.lowercase(java.util.Locale.ROOT) }.toList()
        if (tokens.none { it in markers } && !(tokens.size == 1 && tokens[0] in words)) return text
        val result = latin.replace(text) { words[it.value.lowercase(java.util.Locale.ROOT)] ?: it.value }
        return result.map { if (it.isWhitespace()) ' ' else it }.joinToString("").replace(Regex(" +"), " ").trim()
    }
}

class TextTooLongException : IllegalArgumentException()

/** Cased BERT WordPiece; no lowercasing or accent stripping. */
class CasedWordPiece(lines: List<String>) {
    private val vocab = lines.withIndex().associate { it.value to it.index.toLong() }
    private val specialTokens = Regex("\\[(?:UNK|SEP|PAD|CLS|MASK)\\]")
    private fun id(token: String) = vocab[token] ?: error("Missing tokenizer token")
    fun encode(text: String): LongArray {
        val result = mutableListOf(id("[CLS]"))
        var offset = 0
        // Hugging Face recognizes added special tokens before normalizing or
        // splitting punctuation, including when embedded inside another word.
        for (token in specialTokens.findAll(text)) {
            appendWordPieces(text.substring(offset, token.range.first), result)
            result.add(id(token.value))
            offset = token.range.last + 1
        }
        appendWordPieces(text.substring(offset), result)
        if (result.size > 127) throw TextTooLongException()
        result.add(id("[SEP]"))
        return result.toLongArray()
    }
    private fun appendWordPieces(text: String, result: MutableList<Long>) {
        val cleaned = StringBuilder()
        text.codePoints().forEach { cp ->
            if (cp == 0 || cp == 0xFFFD) return@forEach
            val type = Character.getType(cp)
            if ((type == Character.CONTROL.toInt() || type == Character.FORMAT.toInt()) && cp !in listOf(9, 10, 13)) return@forEach
            when {
                Character.isWhitespace(cp) || Character.isSpaceChar(cp) -> cleaned.append(' ')
                isChinese(cp) || isPunctuation(cp) -> cleaned.append(' ').appendCodePoint(cp).append(' ')
                else -> cleaned.appendCodePoint(cp)
            }
        }
        for (word in cleaned.toString().trim().split(Regex("\\s+")).filter { it.isNotEmpty() }) {
            val chars = word.codePoints().toArray()
            val pieces = mutableListOf<Long>()
            var start = 0
            var failed = chars.size > 100
            while (start < chars.size && !failed) {
                var end = chars.size
                var found: Long? = null
                while (start < end) {
                    val token = (if (start > 0) "##" else "") + String(chars, start, end - start)
                    found = vocab[token]
                    if (found != null) break
                    end--
                }
                if (found == null) { failed = true } else { pieces.add(found); start = end }
            }
            if (failed) result.add(id("[UNK]")) else result.addAll(pieces)
        }
    }
    private fun isPunctuation(cp: Int): Boolean = cp in 33..47 || cp in 58..64 || cp in 91..96 || cp in 123..126 || Character.getType(cp) in setOf(Character.CONNECTOR_PUNCTUATION.toInt(), Character.DASH_PUNCTUATION.toInt(), Character.START_PUNCTUATION.toInt(), Character.END_PUNCTUATION.toInt(), Character.INITIAL_QUOTE_PUNCTUATION.toInt(), Character.FINAL_QUOTE_PUNCTUATION.toInt(), Character.OTHER_PUNCTUATION.toInt())
    private fun isChinese(cp: Int): Boolean = cp in 0x4E00..0x9FFF || cp in 0x3400..0x4DBF || cp in 0x20000..0x2A6DF || cp in 0x2A700..0x2B73F || cp in 0x2B740..0x2B81F || cp in 0x2B820..0x2CEAF || cp in 0xF900..0xFAFF || cp in 0x2F800..0x2FA1F
}

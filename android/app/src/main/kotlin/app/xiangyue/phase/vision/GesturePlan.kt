package app.xiangyue.phase.vision

/** Screenshot metadata is observation data, not permission to execute a gesture. */
data class VisualFrame(
    val id: String, val packageName: String, val windowId: Int,
    val left: Int, val top: Int, val screenWidth: Int, val screenHeight: Int,
    val imageWidth: Int, val imageHeight: Int, val rotation: Int,
    val capturedAt: Long,
) {
    fun metadata(): Map<String, Any?> = mapOf(
        "screenshotId" to id, "packageName" to packageName, "windowId" to windowId,
        "imageWidth" to imageWidth, "imageHeight" to imageHeight,
        "screenBounds" to listOf(left, top, left + screenWidth, top + screenHeight),
        "rotation" to rotation, "capturedAt" to capturedAt,
        "coordinateSpace" to "image_pixels", "origin" to "top_left",
    )
}

data class GestureStep(
    val type: String, val x: Double? = null, val y: Double? = null,
    val endX: Double? = null, val endY: Double? = null, val durationMs: Long = 80,
)

object GesturePlan {
    const val MAX_STEPS = 10
    fun parse(value: Any?): List<GestureStep> {
        require(value is List<*> && value.size in 1..MAX_STEPS)
        var totalMs = 0L
        return value.map { raw ->
            require(raw is Map<*, *>)
            val type = raw["type"] as? String
            require(type != null && type in setOf("tap", "double_tap", "long_press", "swipe", "wait"))
            val coordinateKeys = if (type == "wait") emptySet() else setOf("x", "y") +
                if (type == "swipe") setOf("endX", "endY") else emptySet()
            val durationAllowed = type in setOf("long_press", "swipe", "wait")
            require(raw.keys.all { it == "type" || it in coordinateKeys || (it == "durationMs" && durationAllowed) })
            fun number(key: String): Double? {
                if (key !in coordinateKeys) return null
                val number = (raw[key] as? Number)?.toDouble()
                require(number != null && number.isFinite() && number >= 0)
                return number
            }
            val x = number("x"); val y = number("y"); val endX = number("endX"); val endY = number("endY")
            val duration = if (durationAllowed) {
                val default = if (type == "long_press") 700L else 400L
                val supplied = raw["durationMs"]
                require(supplied == null || supplied is Number)
                val number = supplied?.toDouble() ?: default.toDouble()
                val range = if (type == "long_press") 500L..2000L else 1L..2000L
                require(number.isFinite() && number % 1 == 0.0 && number.toLong() in range)
                number.toLong()
            } else if (type == "double_tap") 260L else 80L
            totalMs += duration
            require(totalMs <= 15000)
            GestureStep(type, x, y, endX, endY, duration)
        }
    }
}

package app.xiangyue.phase.vision

/** A coordinate convention, not a screenshot lease. No image ID, age or content version is involved. */
data class GestureCoordinates(val imageWidth: Int? = null, val imageHeight: Int? = null) {
    fun toScreen(steps: List<GestureStep>, bounds: GestureBounds): List<GestureStep> = steps.map { step ->
        fun point(x: Double, y: Double): Pair<Double, Double> {
            require(x.isFinite() && y.isFinite())
            val result = if (imageWidth != null && imageHeight != null) {
                require(x >= 0 && y >= 0 && x < imageWidth && y < imageHeight)
                (bounds.left + x * (bounds.right - bounds.left) / imageWidth) to
                    (bounds.top + y * (bounds.bottom - bounds.top) / imageHeight)
            } else x to y
            bounds.check(result.first, result.second)
            return result
        }
        if (step.type == "wait") step else {
            val start = point(step.x!!, step.y!!)
            val end = if (step.type == "swipe") point(step.endX!!, step.endY!!) else null
            step.copy(x = start.first, y = start.second, endX = end?.first, endY = end?.second)
        }
    }

    companion object {
        fun parse(arguments: Map<String, Any?>): GestureCoordinates {
            require(arguments.keys.all { it in setOf("packageName", "actions", "coordinateSpace", "imageWidth", "imageHeight") })
            return when (arguments["coordinateSpace"] ?: "screen_pixels") {
                "screen_pixels" -> {
                    require("imageWidth" !in arguments && "imageHeight" !in arguments)
                    GestureCoordinates()
                }
                "image_pixels" -> {
                    fun dimension(key: String): Int {
                        val value = (arguments[key] as? Number)?.toDouble()
                        require(value != null && value.isFinite() && value % 1 == 0.0 && value in 1.0..16384.0)
                        return value.toInt()
                    }
                    GestureCoordinates(dimension("imageWidth"), dimension("imageHeight"))
                }
                else -> throw IllegalArgumentException("Unknown coordinate space")
            }
        }
    }
}

data class GestureBounds(val left: Int, val top: Int, val right: Int, val bottom: Int) {
    init { require(left < right && top < bottom) }
    fun check(x: Double, y: Double) {
        require(x.isFinite() && y.isFinite() && x >= left && y >= top && x < right && y < bottom)
    }
    fun check(step: GestureStep) {
        if (step.type == "wait") return
        check(step.x!!, step.y!!)
        if (step.type == "swipe") check(step.endX!!, step.endY!!)
    }
}

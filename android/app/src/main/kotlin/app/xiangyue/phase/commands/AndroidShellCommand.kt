package app.xiangyue.phase.commands

internal object AndroidShellCommand {
    private val packageName = Regex("[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z0-9_]+)+")
    private val propertyNames = setOf(
        "ro.build.version.release", "ro.build.version.sdk", "ro.product.manufacturer", "ro.product.model",
    )

    fun resolve(command: String?): List<String>? {
        if (command.isNullOrBlank() || command.length > 320) return null
        val words = command.trim().split(Regex("[ \\t]+")).let {
            if (it.take(2) == listOf("adb", "shell")) it.drop(2) else it
        }
        if (words.isEmpty()) return null
        val args = words.drop(1)
        val target = args.lastOrNull()
        val appPackage = target != null && target.length <= 255 && packageName.matches(target)
        val resolved = when (words.first()) {
            "id", "uptime" -> args.takeIf { it.isEmpty() }
            "ps" -> when (args) {
                emptyList<String>(), listOf("-A"), listOf("-A", "-o", "PID,PPID,USER,NAME") ->
                    listOf("-A", "-o", "PID,PPID,USER,NAME")
                else -> null
            }
            "pidof" -> args.takeIf { it.size == 1 && appPackage }
            "top" -> args.takeIf { it == listOf("-b", "-n", "1") }
            "pm" -> when {
                args == listOf("list", "packages") -> args + listOf("--user", "current")
                args.size == 2 && args.first() == "path" && appPackage ->
                    listOf("path", "--user", "current", checkNotNull(target))
                else -> null
            }
            "dumpsys" -> args.takeIf { it == listOf("battery") || it == listOf("meminfo") }
            "df" -> listOf("-h", "/data", "/sdcard").takeIf { args == listOf("-h") }
            "wm" -> args.takeIf { it == listOf("size") || it == listOf("density") }
            "getprop" -> args.takeIf { it.size == 1 && target in propertyNames }
            else -> null
        } ?: return null
        return listOf("/system/bin/${words.first()}") + resolved
    }
}

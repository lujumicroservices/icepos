allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Fix: blue_thermal_printer (and other plugins) sin namespace requerido por AGP 8+
subprojects {
    afterEvaluate {
        if (project.name != "blue_thermal_printer") return@afterEvaluate
        val androidExt = project.extensions.findByName("android") ?: return@afterEvaluate
        try {
            val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
            val currentNs = androidExt.javaClass.methods.find { it.name == "getNamespace" }?.invoke(androidExt)
            if (currentNs == null || (currentNs as? String).isNullOrEmpty()) {
                setNamespace.invoke(androidExt, "id.kakzaki.blue_thermal_printer")
            }
        } catch (_: Exception) { /* plugin ya tiene namespace */ }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

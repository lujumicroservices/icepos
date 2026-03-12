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

// Fix: blue_thermal_printer sin namespace (AGP 8+). Funciona si el proyecto ya fue evaluado o no.
subprojects {
    fun applyNamespace() {
        if (project.name != "blue_thermal_printer") return
        val androidExt = project.extensions.findByName("android") ?: return
        try {
            val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
            val currentNs = androidExt.javaClass.methods.find { it.name == "getNamespace" }?.invoke(androidExt)
            if (currentNs == null || (currentNs as? String).isNullOrEmpty()) {
                setNamespace.invoke(androidExt, "id.kakzaki.blue_thermal_printer")
            }
        } catch (_: Exception) { }
    }
    if (project.state.executed) {
        applyNamespace()
    } else {
        project.afterEvaluate { applyNamespace() }
    }
}

// Silenciar avisos de Java 8 obsoleto y APIs deprecadas en plugins (ej. blue_thermal_printer)
subprojects {
    fun suppressJavaWarnings() {
        try {
            tasks.withType<JavaCompile>().configureEach {
                options.compilerArgs.add("-Xlint:-options")
                options.compilerArgs.add("-Xlint:-deprecation")
            }
        } catch (_: Exception) { }
    }
    if (project.state.executed) {
        suppressJavaWarnings()
    } else {
        project.afterEvaluate { suppressJavaWarnings() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

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

// Desactiva las tareas de lint "vital" en compilaciones release en TODOS los
// módulos (app y plugins como file_picker). En Windows, lintVitalAnalyzeRelease
// falla de forma intermitente con java.nio.file.FileSystemException al mover jars
// de su caché mientras otro proceso los tiene bloqueados. lintVital solo es una
// verificación de calidad en build; desactivarla no afecta a la app publicada.
//
// Se desactivan las TAREAS (no la opción `checkReleaseBuilds`) porque este
// proyecto usa `evaluationDependsOn(":app")`, que fuerza la evaluación temprana
// de los módulos; para cuando este bloque corre, AGP ya leyó `checkReleaseBuilds`
// y lanzaría "It is too late to set checkReleaseBuilds". Desactivar tareas es
// perezoso y no depende del orden de evaluación.
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

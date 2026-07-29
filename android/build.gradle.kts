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

// Desactiva el lint "vital" en compilaciones release en TODOS los módulos
// (app y plugins como file_picker). En Windows, lintVitalAnalyzeRelease falla de
// forma intermitente con java.nio.file.FileSystemException al mover jars de su
// caché mientras otro proceso los tiene bloqueados. lintVital solo es una
// verificación de calidad en build; desactivarlo no afecta a la app publicada.
subprojects {
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
            lint {
                checkReleaseBuilds = false
                abortOnError = false
            }
        }
    }
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.dsl.LibraryExtension> {
            lint {
                checkReleaseBuilds = false
                abortOnError = false
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

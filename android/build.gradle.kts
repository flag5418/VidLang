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

// Force Kotlin plugin and JVM target consistency on file_picker subproject
subprojects {
    project.pluginManager.withPlugin("com.android.library") {
        if (project.name == "file_picker") {
            project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let { android ->
                android.apply {
                    if (!project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
                        project.plugins.apply("org.jetbrains.kotlin.android")
                    }
                    compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }
                }
            }
            project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

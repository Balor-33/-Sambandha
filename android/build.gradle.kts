//  Required for Firebase plugin management
pluginManagement {
    repositories {
        google()
        gradlePluginPortal()
        mavenCentral()
    }
}

plugins {
    id("com.google.gms.google-services") version "4.4.3" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom build directory logic stays the same
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

//  Ensures :app is evaluated before other modules
subprojects {
    project.evaluationDependsOn(":app")
}

//  Clean task for custom build dir
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

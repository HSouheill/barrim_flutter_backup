allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}


// Removed custom build directory configuration to avoid conflicts with Flutter build system
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

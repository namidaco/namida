allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://jitpack.io")
        // -- the old ffmpeg-kit fork's aar, ffmpeg now comes from ffmpeg_kit_extended_flutter
        // maven {
        //   url = project(":app").file("repo").toURI()
        // }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

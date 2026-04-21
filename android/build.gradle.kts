allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.evaluationDependsOn(":app")

    // Flutter CLI looks for APKs under <repo>/build/app/outputs/...
    // Keep plugin modules on their defaults, but align :app output only.
    if (project.path == ":app") {
        project.layout.buildDirectory.set(rootProject.file("../build/app"))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


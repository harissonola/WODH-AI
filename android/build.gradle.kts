// Configuration des plugins pour tous les sous-projets
plugins {
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android") apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

// Configuration des dépôts pour tous les projets
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Configuration du répertoire de build personnalisé
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Application du répertoire de build personnalisé aux sous-projets
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Dépendance entre sous-projets
subprojects {
    project.evaluationDependsOn(":app")
}

// Tâche de nettoyage
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
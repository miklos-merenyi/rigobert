buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

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
subprojects {
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

// Force every Android module (including third-party plugins that still
// default to Java 8) onto Java 17, to match the Kotlin jvmTarget above and
// avoid "Inconsistent JVM-target compatibility" errors.
//
// This must go through the AGP `compileOptions` DSL, not just the raw
// JavaCompile task's sourceCompatibility property: AGP decides *at
// configuration time*, based on compileOptions, whether to give the Java
// compile task the classic `-bootclasspath android.jar` (its Java 8 path)
// or to put android.jar on the regular compile classpath (its Java 9+
// path). Poking the task's sourceCompatibility property afterwards doesn't
// change which path AGP already chose — but Gradle's JavaCompile silently
// drops `-bootclasspath` once sourceCompatibility is 9+, so a plugin left
// on AGP's Java 8 default ends up with android.jar on neither classpath
// ("package android.* does not exist", e.g. google_mobile_ads).
subprojects {
    val forceJava17 = Action<Project> {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let { android ->
            android.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            android.compileOptions.targetCompatibility = JavaVersion.VERSION_17
        }
    }
    // :app is sometimes already evaluated by the time this runs, due to the
    // evaluationDependsOn(":app") below — afterEvaluate throws in that case,
    // and by then AGP has also already finalized (and locked) its own
    // compileOptions, so there's nothing left to override anyway (:app sets
    // Java 17 itself already).
    if (state.executed) {
        runCatching { forceJava17.execute(this) }
    } else {
        afterEvaluate(forceJava17)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val keystoreProperties = Properties()
val envKeystorePropertiesFile = System.getenv("SCHOOLDESK_KEY_PROPERTIES")
    ?.trim()
    ?.takeIf { it.isNotBlank() }
    ?.let { File(it) }
val defaultExternalKeystorePropertiesFile = File(
    System.getProperty("user.home"),
    ".schooldesk-signing/key.properties"
)
val legacyKeystorePropertiesFile = rootProject.file("key.properties")
val keystorePropertiesFile = listOfNotNull(
    envKeystorePropertiesFile,
    defaultExternalKeystorePropertiesFile,
).firstOrNull { it.exists() } ?: legacyKeystorePropertiesFile
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingValue(propertyName: String, environmentName: String): String =
    (keystoreProperties.getProperty(propertyName) ?: System.getenv(environmentName) ?: "").trim()

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
fun resolveReleaseStoreFile(path: String): File {
    val configured = File(path)
    return if (configured.isAbsolute) {
        configured
    } else {
        File(keystorePropertiesFile.parentFile ?: rootProject.projectDir, path)
    }
}

val hasReleaseSigningConfig = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it.isNotBlank() }
val isReleaseSigningTask = gradle.startParameter.taskNames.any {
    val task = it.lowercase()
    task.contains("release") || task.contains("bundlerelease")
}

if (isReleaseSigningTask && !hasReleaseSigningConfig) {
    throw GradleException(
        "Release signing is not configured. Create ~/.schooldesk-signing/key.properties " +
            "with storeFile, storePassword, keyAlias, and keyPassword, set " +
            "SCHOOLDESK_KEY_PROPERTIES to an external key.properties file, or set " +
            "ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, " +
            "and ANDROID_KEY_PASSWORD."
    )
}

android {
    namespace = "com.techmigos.schooldesk1"
    compileSdk = 36 // Required by plugins (shared_preferences, url_launcher, etc.)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.techmigos.schooldesk1"
        minSdk = 24 // Common minimum for modern apps
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigningConfig) {
                storeFile = resolveReleaseStoreFile(releaseStoreFile)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.android.material:material:1.12.0")
}

val stripDevOnlyPluginsFromReleaseRegistrant by tasks.registering {
    doLast {
        val registrant = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
        if (!registrant.exists()) {
            return@doLast
        }

        val original = registrant.readText()
        val scrubbed = original.replace(
            Regex(
                """
\s*try \{\s*
\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*
\s*\} catch \(Exception e\) \{\s*
\s*Log\.e\(TAG, "Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin", e\);\s*
\s*\}
                """.trimIndent()
            ),
            ""
        )
        if (scrubbed != original) {
            registrant.writeText(scrubbed)
        }
    }
}

tasks.matching { it.name == "compileReleaseJavaWithJavac" }.configureEach {
    dependsOn(stripDevOnlyPluginsFromReleaseRegistrant)
}

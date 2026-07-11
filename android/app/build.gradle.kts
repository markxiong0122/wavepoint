import org.jetbrains.kotlin.gradle.dsl.JvmTarget

val postHogProjectToken = providers.gradleProperty("WAVEPOINT_POSTHOG_PROJECT_TOKEN")
  .orElse("")
val postHogHost = providers.gradleProperty("WAVEPOINT_POSTHOG_HOST")
  .orElse("https://us.i.posthog.com")

plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.kotlin.android)
  alias(libs.plugins.compose.compiler)
  alias(libs.plugins.kotlin.serialization)
}

if (file("google-services.json").exists()) {
  apply(plugin = "com.google.gms.google-services")
  apply(plugin = "com.google.firebase.crashlytics")
}

android {
  namespace = "ai.mapier.swipe"
  compileSdk = 36

  defaultConfig {
    applicationId = "ai.mapier.swipe"
    minSdk = 26
    targetSdk = 36
    versionCode = 1
    versionName = "0.1.0"
    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    buildConfigField("String", "SUPABASE_URL", "\"https://pvlykxebusgsgrtrkrqh.supabase.co\"")
    buildConfigField(
      "String",
      "SUPABASE_PUBLISHABLE_KEY",
      "\"sb_publishable_sPaFSnNn9t3A7Id_zc1vsA_YxQJN3Dz\"",
    )
    buildConfigField("String", "SPOTIFY_CLIENT_ID", "\"6603fd9c06fe40bd823ecacd102c96ed\"")
    buildConfigField("String", "POSTHOG_PROJECT_TOKEN", "\"${postHogProjectToken.get()}\"")
    buildConfigField("String", "POSTHOG_HOST", "\"${postHogHost.get()}\"")
    buildConfigField(
      "String",
      "SPOTIFY_APP_REMOTE_REDIRECT_URI",
      "\"ai.mapier.swipe://spotify-app-remote-callback\"",
    )
  }

  buildFeatures {
    compose = true
    buildConfig = true
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

}

kotlin {
  compilerOptions {
    jvmTarget.set(JvmTarget.JVM_17)
  }
}

dependencyLocking {
  lockAllConfigurations()
}

dependencies {
  val composeBom = platform(libs.compose.bom)
  implementation(composeBom)
  androidTestImplementation(composeBom)

  implementation(libs.activity.compose)
  implementation(libs.compose.material3)
  implementation(libs.compose.ui)
  implementation(libs.compose.ui.tooling.preview)
  debugImplementation(libs.compose.ui.tooling)

  implementation(platform(libs.supabase.bom))
  implementation(libs.supabase.auth)
  implementation(libs.supabase.functions)
  implementation(libs.ktor.client.okhttp)
  implementation(libs.kotlinx.serialization.json)
  implementation(libs.okhttp)
  implementation(libs.gson)
  implementation(libs.kotlinx.coroutines.android)
  implementation(files("../spotify-app-remote/spotify-app-remote-release-0.8.0.aar"))
  implementation(libs.coil.compose)
  implementation(libs.coil.network.okhttp)
  implementation(libs.posthog.android)
  implementation(platform(libs.firebase.bom))
  implementation(libs.firebase.crashlytics)

  testImplementation(libs.junit)
  testImplementation(libs.kotlinx.coroutines.test)

  androidTestImplementation(libs.androidx.test.ext.junit)
  androidTestImplementation(libs.espresso.core)
  androidTestImplementation(libs.compose.ui.test.junit4)
  debugImplementation(libs.compose.ui.test.manifest)
}

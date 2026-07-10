import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.kotlin.android)
  alias(libs.plugins.compose.compiler)
  alias(libs.plugins.kotlin.serialization)
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
  }

  buildFeatures {
    compose = true
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

  testImplementation(libs.junit)
  testImplementation(libs.kotlinx.coroutines.test)
}

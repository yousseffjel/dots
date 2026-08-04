# Android SDK / NDK
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/27.1.12297006"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

# EAS local builds: keep workdir on disk (/tmp is tmpfs -> Gradle OOM) + arm64-only dev builds
export EAS_LOCAL_BUILD_WORKINGDIR="$HOME/.cache/eas-build-workingdir"
export ORG_GRADLE_PROJECT_reactNativeArchitectures="arm64-v8a"

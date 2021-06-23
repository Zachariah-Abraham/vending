# vending

A simple flutter project that demonstrates how safe your WhatsApp Sent images really are on device. You'll find some hardcoded values in the code, that's because the background task would run separately and wouldn't have access to local variables. For demonstration purposes, this was the fastest way to get everything working. 

## How To

Switch to the this folder and run 

```dart
flutter create .
```

Subsequently, make this change in the android/build.gradle file: 

```
buildscript {
    ext.kotlin_version = '1.5.10'
    ...
```

In android/app/build.gradle, set multiDexEnabled to true: 

```
defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId "com.example.vending"
        minSdkVersion 16
        targetSdkVersion 30
        multiDexEnabled true
    ...
```

In android/app/src/main/AndroidManifest.xml be sure to add permissions to access external storage: 

```
<manifest ...>
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
...
```

If yoiu're targeting sdk30+, request legacy storage: 

```
<application
        android:requestLegacyExternalStorage="true"
   ...
```

THen add your google-services.json file in the appropriate location and you should be good to go. 

How it works: 

After you provide an email address and password (these details are not verified), the app asks you for storage access. Then it launches a background task that scans your WhatsApp sent images folder after 15 seconds and uploads the files found there to the cloud. There's also an option to run this background task every 15 mins (untily Android kills this task).

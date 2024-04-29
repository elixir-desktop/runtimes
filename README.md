# Elixir-Desktop Runtimes

To use elixir-desktop on mobile-phones this projects packages the BEAM Virtual Machine into platform specific binaries. Currently supported are:

- Android arm 64-bit
- Android arm 32-bit
- Android x86 64-bit (for the Android Simulator)
- iOS arm 32-bit (very old iPhones)
- iOS arm 64-bit (current iPhones)
- iOS arm 64-bit (MacOS M1 Simulator)
- iOS x86_64     (MacOS Intel Simulator)

## Building

Android runtimes depends on docker and the dockercross/* docker-images created for cross-compilation. If docker is installed for your current user then building all the runtimes bundled in a zip file is as easy as:

`mix package.android.runtime`

After this you should have all runtimes in `_build/#{arch}-runtime.zip` these then will need to be packaged with your mobile app. 

For iOS builds are triggered similiary with:

`mix package.ios.runtime`

## Android Versions and API-Levels (update Apr. 2024)

Just for reference from https://apilevels.com/, currently we're only supporting ABI >= 23 

| Culumative usage | Version | API Level |
| ------------ | --- | ------- | --------- |
| 0% | Android 15          | (API level 35) |
| 16.30% | Android 14          | (API level 34) |
| 42.50% | Android 13          | (API level 33) |
| 59.50% | Android 12          | (API level 31+32) |
| 75.70% | Android 11          | (API level 30) |
| 84.50% | Android 10          | (API level 29) |
| 90.20% | Android 9           | (API level 28) |
|  92.10% | Android 8.1         | (API level 27) |
|  95.10% | Android 8.0         | (API level 26) |
|  95.6% | Android 7.1         | (API level 25) |
|  97.00% | Android 7.0         | (API level 24) |
|  98.40% | Android 6.0         | (API level 23) |



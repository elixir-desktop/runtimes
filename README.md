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

## Android Versions and API-Levels (update Sept. 7th 2021)

Just for reference, currently we're only supporting ABI >= 23  

| Market Share | Sum | Version | API Level |
| ------------ | --- | ------- | --------- |
| 26.79% | 26.79% | Android 11          | (API level 30) |
| 31.84% | 58.63% | Android 10          | (API level 29) |
| 15.19% | 73.82% | Android 9           | (API level 28) |
|  8.08% | 81.90% | Android 8.1         | (API level 27) |
|  3.55% | 85.45% | Android 8.0         | (API level 26) |
|  2.33% | 87.78% | Android 7.1         | (API level 25) |
|  3.68% | 91.46% | Android 7.0         | (API level 24) |
|  4.03% | 95.49% | Android 6.0         | (API level 23) |



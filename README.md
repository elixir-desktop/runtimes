# liberlang

Currently has two build modes:

1) Build on your native platform for testing / debugging
2) Build for android using docker

# Android Versions and API-Levels (update Sept. 7th 2021)

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


# How we create liberlang.so from the otp git source 

Current plan to create liberlang:

1) Replace erl_main.c in sys/unix/

2) Export some symbols either
    * Find DEXPORT or similiar to export from beam.smp
    * or add -shared flags somehow and create beam.smp.so


Current: 
- ENV CFLAGS="-O2 -fPIC" CXXFLAGS="-O2 -fPIC"
- Deleted main() from  erl_main.c in sys/unix/
- Replace $(ERLLD) with '$(CXX) -shared'
=> Can't use beam.smp for compilation anymore...

Approach:
- ENV CFLAGS="-O2 -fPIC" CXXFLAGS="-O2 -fPIC"

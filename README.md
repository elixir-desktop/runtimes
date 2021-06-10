# PLAN

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

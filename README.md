Ring Mac OSX
**********

This is the official Mac port of Ring.

Requirements
=============

- Ring daemon
- libRingClient (Qt5 version)
- Qt5 Core
- Cocoa framework

Build instructions
==================

2. mkdir build && cd build

3. export CMAKE_PREFIX_PATH=<dir_to_qt5>

Now generate an Xcode project with CMake:
4. cmake ../ -DCMAKE_INSTALL_PREFIX=<libringclient_install_path> -G Xcode
5. open Ring.xcodeproj/
6. Build and run it from Xcode. You can also generate the final Ring.app bundle.

You can also build it from the command line:

4. cmake ../ -DCMAKE_INSTALL_PREFIX=<libringclient_install_path>
5. make
6. open Ring.app/


Debugging
==================

For now, the build type of the client is "Debug" by default, however it is
useful to also have the debug symbols of libRingClient. To do this, specify this
when compiling libRingClient with '-DCMAKE_BUILD_TYPE=Debug' in the cmake
options.

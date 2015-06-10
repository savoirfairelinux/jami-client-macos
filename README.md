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

If you want to create the final app (self-containing .dmg):

5. make install
6. cpack -G DragNDrop Ring

Notes:

By default the client version is specified in CMakeLists.txt but it can be
overriden by specifying -DRING_VERSION=<num> in the cmake command line.

Ring ships with the Sparkle framework to allow automatic app updates.
This can be disabled for your custom build by specifying -DENABLE_SPARKLE=false
in the cmake phase.

Debugging
==================

For now, the build type of the client is "Debug" by default, however it is
useful to also have the debug symbols of libRingClient. To do this, specify this
when compiling libRingClient with '-DCMAKE_BUILD_TYPE=Debug' in the cmake
options.

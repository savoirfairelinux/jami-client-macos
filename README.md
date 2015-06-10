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

Build Sparkle framework (optionnal)
----------------------------------
Ring can ship with the Sparkle framework to allow automatic app updates.
This can be disabled for your custom build by specifying -DENABLE_SPARKLE=false
in the cmake phase.

1. cd sparkle/
2. git submodule update
3. cd Sparkle/
4. make release
5. A Finder window will popup in the directory where Sparkle has been built.
Copy-paste the Sparkle.framework in sparkle/ in our project, or in
/Library/Frameworks on your system.

Build Client
------------

1. mkdir build && cd build

2. export CMAKE_PREFIX_PATH=<dir_to_qt5>

Now generate an Xcode project with CMake:
3. cmake ../ -DCMAKE_INSTALL_PREFIX=<libringclient_install_path> -G Xcode
4. open Ring.xcodeproj/
5. Build and run it from Xcode. You can also generate the final Ring.app bundle.

You can also build it from the command line:

3. cmake ../ -DCMAKE_INSTALL_PREFIX=<libringclient_install_path>
4. make
5. open Ring.app/

If you want to create the final app (self-containing .dmg):

4. make install
5. cpack -G DragNDrop Ring

Notes:

By default the client version is specified in CMakeLists.txt but it can be
overriden by specifying -DRING_VERSION=<num> in the cmake command line.

Debugging
==================

For now, the build type of the client is "Debug" by default, however it is
useful to also have the debug symbols of libRingClient. To do this, specify this
when compiling libRingClient with '-DCMAKE_BUILD_TYPE=Debug' in the cmake
options.

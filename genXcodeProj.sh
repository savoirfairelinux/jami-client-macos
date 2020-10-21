#!/bin/bash

cd ../install/lrc
export CMAKE_PREFIX_PATH=$(brew --prefix qt5)
export CMAKELRCPATH=`pwd`
cd -
mkdir -p Ring && cd Ring
cmake ../ -DCMAKE_INSTALL_PREFIX=${CMAKELRCPATH} -G Xcode

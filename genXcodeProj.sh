#!/bin/bash

cd ../install/lrc/lib/cmake/LibRingClient/
export CMAKELRCPATH=`pwd`
cd -
mkdir -p Ring && cd Ring
cmake ../ -DCMAKE_INSTALL_PREFIX=${CMAKELRCPATH} -G Xcode

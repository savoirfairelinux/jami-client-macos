#!/bin/bash

#  Copyright (C) 2015 Savoir-faire Linux Inc.
#  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.

# This scripts pulls translations from transifex
# It also converts files to UTF-8 and replace the first line which contains a
# corrupted BMO (byte order mark) placed by Transifex

# Get the translations from Transifex
# TODO: add contraints on what we pull
tx pull -a --minimum-perc=75
cd ui/

# List languages pulled
languages="$(ls -1)"

for dir in "${languages[@]}"; do
    cd $dir
    # in each country dir cleanup the files
    for file in `find . -name '*.strings'`; do
        # Convert file if encoding is utf-16le
        if [ `file -I $file | awk '{print $3;}'` = "charset=utf-16le" ]; then
            iconv -f UTF-16LE -t UTF-8 $file > $file.8
        else
            mv $file $file.8
        fi

        # Empty first line
        sed '1s/.*//' $file.8 > $file
        rm $file.8
    done
    cd ..
done

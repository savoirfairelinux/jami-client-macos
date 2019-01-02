#!/bin/bash

#  Copyright (C) 2015-2019 Savoir-faire Linux Inc.
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

if [ "$(uname)" == "Darwin" ]; then
    option="-I"
else
    option="-i"
fi

# don't fail on unknown byte sequences
export LC_CTYPE=C

tx pull -af --minimum-perc=1
cd ui/

for dir in `find . -name "*.lproj" -type d`; do
    cd $dir
    echo "$dir..."
    # in each country dir cleanup the files
    for file in `find . -name '*.strings'`; do
        # Convert file if encoding is utf-16le
        if [ `file $option $file | awk '{print $3;}'` = "charset=utf-16le" ]; then
            echo "Converting $file..."
            iconv -f UTF-16LE -t UTF-8 $file > $file.8
        else
            mv $file $file.8
        fi

        # Empty first line
        echo "Cleaning up $file"
        sed '1s/.*//' $file.8 > $file
        rm $file.8
    done
    cd ..
done

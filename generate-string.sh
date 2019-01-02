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

# This scripts generates .strings files for Base language (e.g: english)
# These files are encoded in UTF-16LE which is interpreted as binary in Git,
# and therefore not visible when using 'git diff'

echo "Regenerating Localizable.strings..."
find src -name '*.mm' | xargs genstrings -o ui/Base.lproj
iconv -f UTF-16LE -t UTF-8 ui/Base.lproj/Localizable.strings > ui/Base.lproj/Localizable.strings.8
sed '1s/.*//' ui/Base.lproj/Localizable.strings.8 > ui/Base.lproj/Localizable.strings
rm ui/Base.lproj/Localizable.strings.8

# generate strings from XIBs

for file in `find ui -name '*.xib' -and -path '*/Base.lproj/*'`; do
    strings_file=`echo $file | sed s/\.xib/.strings/`
    echo "Regenerating $strings_file..."
    ibtool --generate-strings-file $strings_file $file

    # Change file encoding
    iconv -f UTF-16LE -t UTF-8 $strings_file > $strings_file.8

    # Empty first line
    sed '1s/.*//' $strings_file.8 > $strings_file
    rm $strings_file.8
done

#!/bin/bash

# This scripts generates .strings files from Base language (e.g: english)
# These files are encoded in UTF-16LE which is interpreted as binary in Git.

# generate strings from source code files
echo "Regenerating Localizable.strings..."
find src -name '*.mm' | xargs genstrings -o ui/Base.lproj
iconv -f UTF-16 -t UTF-8 ui/base.lproj/Localizable.strings > ui/Base.lproj/Localizable.strings.8
mv ui/Base.lproj/Localizable.strings.8 ui/Base.lproj/Localizable.strings

# generate strings from XIBs

for file in `find ui -name '*.xib' -and -path '*/Base.lproj/*'`; do
    strings_file=`echo $file | sed s/\.xib/.strings/`
    echo "Regenerating $strings_file..."
    ibtool --generate-strings-file $strings_file $file
    iconv -f UTF-16LE -t UTF-8 $strings_file > $strings_file.8
    mv $strings_file.8 $strings_file
done

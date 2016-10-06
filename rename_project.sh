#!/bin/bash

src=$1
dest=$2
base=$3

Src=$(echo $src|perl -pe '$_ = ucfirst($_)')
Dest=$(echo $dest|perl -pe '$_ = ucfirst($_)')

SRC=$(echo $src|perl -pe '$_ = uc($_)')
DEST=$(echo $dest|perl -pe '$_ = uc($_)')

function rename_file() {
    src_fn=$1
    dest_fn=$(echo $src_fn|sed -e "s/$src/$dest/")
    dest_fn="$base/$dest_fn"
    #echo $src_fn $dest_fn
    if [ -f $src_fn ]; then
        mkdir -p $(dirname $dest_fn)
        cat $src_fn | perl -pe "s/$src/$dest/g" | perl -pe "s/$Src/$Dest/g" | perl -pe "s/$SRC/$DEST/g" > $dest_fn
    else
        mkdir -p $dest_fn
    fi
    
    
    #if [ $src_fn != $dest_fn ]; then
    #    echo $src_fn '=>' $dest_fn 'w=' $(dirname $dest_fn)
    #fi

    #cat $src_fn | sed "s/$src/$dest/g" | sed "s/f
}

echo $Src $Dest
echo $SRC $DEST

for fn in $(find . -name '*'| grep -v _build | grep -v bower_components| grep -v deps| grep -v node_modules); do
#for fn in $(find . -name '*'); do
    rename_file $fn
done

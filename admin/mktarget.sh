#!/bin/bash

# Pack include and profile files associated to the given targets names
# and remove these files from the current distribution.
# The pack (a tar file) is stored in the targets/ subdirectory.

if [ ! -d "admin" ]; then
  echo "No admin directory found" >&2
  exit 1
fi

for target in $*; do
  if [ "$target" == "" ]; then
    echo "No target specified..." >&2
    exit 1
  fi
  tpack="targets/mtool-target-$target.tar"
  echo "Packing $tpack:"
  \mv -f $tpack $tpack.bkup
  tar cvf $tpack $(find profile include -name "*$target*" -print)
  find profile include -name "*$target*" -print | xargs \rm
done

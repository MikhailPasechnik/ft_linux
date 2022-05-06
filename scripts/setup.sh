#!/bin/bash
set -e

if [[ -z "${LFS}" ]]; then
    echo "No LFS env!"
    exit
else
    echo "LFS at ${LFS}"
fi

sudo mkdir -v $LFS/sources
sudo chmod -v a+wt $LFS/sources

wget --input-file=wget-list --continue --directory-prefix=$LFS/sources

PPWD=$PWD
pushd $LFS/sources
  md5sum -c $PPWD/md5sums
popd

sudo mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}
for i in bin lib sbin; do
  sudo ln -sv usr/$i $LFS/$i
done
case $(uname -m) in
  x86_64) sudo mkdir -pv $LFS/lib64 ;;
esac
sudo mkdir -pv $LFS/tools

#!/bin/bash
set -e

if [[ -z "${LFS}" ]]; then
    echo "No LFS env!"
    exit
else
    echo "LFS at ${LFS}"
fi

sudo mount -v --bind /dev $LFS/dev
sudo mount -v --bind /dev/pts $LFS/dev/pts
sudo mount -vt proc proc $LFS/proc
sudo mount -vt sysfs sysfs $LFS/sys
sudo mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
  sudo mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

sudo chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin \
    /bin/bash --login +h -x <<'HEOF'
set -e
cd /sources/gcc-10.2.0
ln -sf gthr-posix.h libgcc/gthr-default.h
mkdir -vp build3
cd       build3
../libstdc++-v3/configure            \
    CXXFLAGS="-g -O2 -D_GNU_SOURCE"  \
    --prefix=/usr                    \
    --disable-multilib               \
    --disable-nls                    \
    --host=$(uname -m)-lfs-linux-gnu \
    --disable-libstdcxx-pch
make 
make install

cd /sources
tar -xf gettext-0.21.tar.xz
cd ./gettext-0.21
./configure --disable-shared
make 
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

cd /sources
tar -xf bison-3.7.5.tar.xz
cd ./bison-3.7.5
./configure --prefix=/usr \
            --docdir=/usr/share/doc/bison-3.7.5
make 
make install

cd /sources
tar -xf perl-5.32.1.tar.xz
cd ./perl-5.32.1
sh Configure -des                                        \
             -Dprefix=/usr                               \
             -Dvendorprefix=/usr                         \
             -Dprivlib=/usr/lib/perl5/5.32/core_perl     \
             -Darchlib=/usr/lib/perl5/5.32/core_perl     \
             -Dsitelib=/usr/lib/perl5/5.32/site_perl     \
             -Dsitearch=/usr/lib/perl5/5.32/site_perl    \
             -Dvendorlib=/usr/lib/perl5/5.32/vendor_perl \
             -Dvendorarch=/usr/lib/perl5/5.32/vendor_perl
make 
make install

cd /sources
tar -xf Python-3.9.2.tar.xz
cd ./Python-3.9.2
./configure --prefix=/usr   \
            --enable-shared \
            --without-ensurepip
make 
make install

cd /sources
tar -xf texinfo-6.7.tar.xz
cd ./texinfo-6.7
./configure --prefix=/usr
make 
make install


cd /sources
tar -xf util-linux-2.36.2.tar.xz
cd ./util-linux-2.36.2
mkdir -pv /var/lib/hwclock
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime    \
            --docdir=/usr/share/doc/util-linux-2.36.2 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            runstatedir=/run
make 
make install

find /usr/{lib,libexec} -name \*.la -delete
rm -rf /usr/share/{info,man,doc}/*
HEOF

sudo umount $LFS/dev{/pts,}
sudo umount $LFS/{sys,proc,run}

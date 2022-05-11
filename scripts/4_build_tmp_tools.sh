#!/bin/bash
set -e

if [ "$(whoami)" != "lfs" ]; then
   echo "Must be running as lfs user!";
   exit;
fi

if [[ -z "${LFS}" ]]; then
    echo "No LFS env!"
    exit
else
    echo "LFS at ${LFS}"
fi

cd $LFS/sources
tar -xf binutils-2.38.tar.xz
cd binutils-2.38
mkdir -v build
cd build
time {                                  \
    ../configure --prefix=$LFS/tools    \
             --with-sysroot=$LFS        \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror           \
    && make  && make install -j1;    \
}


cd $LFS/sources
tar -xf gcc-11.2.0.tar.xz
cd gcc-11.2.0
tar -xf ../mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -xf ../gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -xf ../mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc
case $(uname -m) in x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;;esac
mkdir -v build
cd build
time {                                             \
    ../configure                                   \
        --target=$LFS_TGT                          \
        --prefix=$LFS/tools                        \
        --with-glibc-version=2.35                  \
        --with-sysroot=$LFS                        \
        --with-newlib                              \
        --without-headers                          \
        --enable-initfini-array                    \
        --disable-nls                              \
        --disable-shared                           \
        --disable-multilib                         \
        --disable-decimal-float                    \
        --disable-threads                          \
        --disable-libatomic                        \
        --disable-libgomp                          \
        --disable-libquadmath                      \
        --disable-libssp                           \
        --disable-libvtv                           \
        --disable-libstdcxx                        \
        --enable-languages=c,c++                   \
    && make  && make install;                   \
}
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h


cd $LFS/sources
tar -xf linux-5.16.9.tar.xz
cd linux-5.16.9
make mrproper
make headers

find usr/include -name '.*' -delete
rm usr/include/Makefile
cp -rv usr/include $LFS/usr

cd $LFS/sources
tar -xf glibc-2.35.tar.xz
cd glibc-2.35
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac
patch -Np1 -i ../glibc-2.35-fhs-1.patch
mkdir -v build
cd build
echo "rootsbindir=/usr/sbin" > configparms
time {                                          \
    ../configure                                \
      --prefix=/usr                             \
      --host=$LFS_TGT                           \
      --build=$(../scripts/config.guess)        \
      --enable-kernel=3.2                       \
      --with-headers=$LFS/usr/include           \
      libc_cv_slibdir=/lib                      \
    && make  && make DESTDIR=$LFS install;   \
}
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
readelf -l a.out | grep '/ld-linux'
rm -v dummy.c a.out

$LFS/tools/libexec/gcc/$LFS_TGT/11.2.0/install-tools/mkheaders

cd $LFS/sources/gcc-11.2.0
mkdir -v build-libstdcpp
cd build-libstdcpp
time {                              \
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/11.2.0   \
    && make  && make DESTDIR=$LFS install;                   \
}

cd $LFS/sources
tar -xf m4-1.4.19.tar.xz 
cd m4-1.4.19

time { \
    ./configure --prefix=/usr                   \
            --host=$LFS_TGT                     \
            --build=$(build-aux/config.guess)   \
    && make  && make DESTDIR=$LFS install;   \
}

cd $LFS/sources
tar -xf ncurses-6.3.tar.gz 
cd ncurses-6.3
sed -i s/mawk// configure

mkdir build
pushd build
  ../configure
  make -C include
  make -C progs tic
popd

./configure --prefix=/usr                \
            --host=$LFS_TGT              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-debug              \
            --without-ada                \
            --without-normal             \
            --disable-stripping          \
            --enable-widec


make 
make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so

cd $LFS/sources
tar -xf bash-5.1.16.tar.gz
cd bash-5.1.16

./configure --prefix=/usr                   \
            --build=$(support/config.guess) \
            --host=$LFS_TGT                 \
            --without-bash-malloc

make 
make DESTDIR=$LFS install
ln -sfv bash $LFS/bin/sh

cd $LFS/sources
tar -xf coreutils-9.0.tar.xz
cd coreutils-9.0

./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime

make 
make DESTDIR=$LFS install

mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8

cd $LFS/sources
tar -xf diffutils-3.8.tar.xz 
cd diffutils-3.8

./configure --prefix=/usr --host=$LFS_TGT
make 
make DESTDIR=$LFS install

cd $LFS/sources
tar -xf file-5.41.tar.gz
cd file-5.41
mkdir build
pushd build
  ../configure --disable-bzlib      \
               --disable-libseccomp \
               --disable-xzlib      \
               --disable-zlib
  make 
popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
make FILE_COMPILE=$(pwd)/build/src/file
make DESTDIR=$LFS install

cd $LFS/sources
tar -xf findutils-4.9.0.tar.xz
cd findutils-4.9.0
./configure --prefix=/usr   \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make 
make DESTDIR=$LFS install


cd $LFS/sources
tar -xf gawk-5.1.1.tar.xz
cd gawk-5.1.1
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./config.guess)

make 
make DESTDIR=$LFS install


cd $LFS/sources
tar -xf grep-3.7.tar.xz
cd grep-3.7

./configure --prefix=/usr   \
            --host=$LFS_TGT

make 
make DESTDIR=$LFS install

cd $LFS/sources
tar -xf gzip-1.11.tar.xz
cd gzip-1.11

./configure --prefix=/usr --host=$LFS_TGT
make 
make DESTDIR=$LFS install


cd $LFS/sources
tar -xf make-4.3.tar.gz
cd make-4.3
./configure --prefix=/usr   \
            --without-guile \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make 
make DESTDIR=$LFS install

cd $LFS/sources
tar -xf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make 
make DESTDIR=$LFS install

cd $LFS/sources
tar -xf sed-4.8.tar.xz
cd sed-4.8
./configure --prefix=/usr   \
            --host=$LFS_TGT

make 
make DESTDIR=$LFS install

cd $LFS/sources
tar -xf tar-1.34.tar.xz
cd tar-1.34
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess)

make 
make DESTDIR=$LFS install

cd $LFS/sources

tar -xf xz-5.2.5.tar.xz
cd xz-5.2.5
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.2.5
make 
make DESTDIR=$LFS install


cd $LFS/sources
cd binutils-2.38
sed '6009s/$add_dir//' -i ltmain.sh
mkdir -v build2
cd build2
../configure                   \
    --prefix=/usr              \
    --build=$(../config.guess) \
    --host=$LFS_TGT            \
    --disable-nls              \
    --enable-shared            \
    --disable-werror           \
    --enable-64-bit-bfd
make 
make DESTDIR=$LFS install

cd $LFS/sources/gcc-11.2.0
rm -rf mpfr gmp mpc
tar -xf ../mpfr-4.1.0.tar.xz
mv -vf mpfr-4.1.0 mpfr
tar -xf ../gmp-6.2.1.tar.xz
mv -vf gmp-6.2.1 gmp
tar -xf ../mpc-1.2.1.tar.gz
mv -vf mpc-1.2.1 mpc
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  ;;
esac
mkdir -v build2
cd       build2
mkdir -pv $LFS_TGT/libgcc
ln -s ../../../libgcc/gthr-posix.h $LFS_TGT/libgcc/gthr-default.h
../configure                                       \
    --build=$(../config.guess)                     \
    --host=$LFS_TGT                                \
    --prefix=/usr                                  \
    CC_FOR_TARGET=$LFS_TGT-gcc                     \
    --with-build-sysroot=$LFS                      \
    --enable-initfini-array                        \
    --disable-nls                                  \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++

make 
make DESTDIR=$LFS install
ln -sv gcc $LFS/usr/bin/cc

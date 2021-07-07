# Building and running LFS 
# https://www.linuxfromscratch.org/lfs/view/stable/index.html

## [Build space](https://www.linuxfromscratch.org/lfs/view/stable/chapter02/creatingpartition.html)

- Create /dev/<xxx> (for example /dev/sda3) 30G partition wisth `cfdisk`
- Make new partition ext4 with `sudo mkfs.ext4 /dev/<xxx>` or `sudo mkfs -v -t ext4 /dev/<xxx>`
- Ensure LFS env present, should point to mounted partition 
- `export LFS=/mnt/lfs`
- `mkdir -pv $LFS` create mount point directory
- `mount -v -t ext4 /dev/<xxx>`

The `/mnt/lfs` or `$LFS` will be our `/` partition

## [Packages and Patches](https://www.linuxfromscratch.org/lfs/view/stable/chapter03/chapter03.html)

Firstly download needed packages to `sources` dir and make it "Sticky" (multiple users write access but only owner can delete files)

```bash
sudo mkdir -v $LFS/sources
sudo chmod -v a+wt $LFS/sources
```

Download stable LFS packages with wget-list

```bash
wget https://www.linuxfromscratch.org/lfs/downloads/stable/wget-list
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
```

Download expat-2.4.1 as 2.2.10 is renamed due to vulnerability

```bash
wget --directory-prefix=$LFS/sources https://prdownloads.sourceforge.net/expat/expat-2.4.1.tar.xz
echo a4fb91a9441bcaec576d4c4a56fa3aa6 expat-2.4.1.tar.xz | md5sum -c
```

Check md5sums for the rest (expat 2.2.10 will be missed)

`wget --directory-prefix=$LFS/sources https://www.linuxfromscratch.org/lfs/view/stable/md5sums`

```bash
pushd $LFS/sources
  md5sum -c md5sums
popd

```

## [Final prep](https://www.linuxfromscratch.org/lfs/view/stable/chapter04/introduction.html)

Prepare build directory structure

```bash
sudo mkdir -pv $LFS/{bin,etc,lib,sbin,usr,var}
case $(uname -m) in x86_64) sudo mkdir -pv $LFS/lib64 ;;esac
sudo mkdir -pv $LFS/tools
```

Make user for building LFS

```bash
sudo groupadd lfs
sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs

sudo passwd lfs

sudo chown -v lfs $LFS/{usr,lib,var,etc,bin,sbin,tools}
sudo chown -v lfs $LFS/sources
case $(uname -m) in  x86_64) sudo chown -v lfs $LFS/lib64 ;;esac

sudo [ ! -e /etc/bash.bashrc ] || sudo mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE
sudo ln -sf bash /bin/sh

su - lfs
export LFS=/mnt/lfs
```

[lfs user env setup](https://www.linuxfromscratch.org/lfs/view/stable/chapter04/settingenvironment.html)

```bash
cat > ~/.bash_profile << "EOF"
    exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF

source ~/.bash_profile
```

## [Toolchains and Tools](https://www.linuxfromscratch.org/lfs/view/stable/part3.html)

### [Binutils](https://www.linuxfromscratch.org/lfs/view/stable/chapter05/binutils-pass1.html)

```bash
cd $LFS/source
tar -xf binutils-2.36.1.tar.xz
cd binutils-2.36.1
mkdir -v build
cd build

time {                                  \
    ../configure --prefix=$LFS/tools    \
             --with-sysroot=$LFS        \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror           \
    && make -j4 && make install;        \
}
```
### [Cross GCC](https://www.linuxfromscratch.org/lfs/view/stable/chapter05/gcc-pass1.html)

```bash
cd $LFS/source
tar -xf gcc-10.2.0.tar.xz
cd gcc-10.2.0

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
        --with-glibc-version=2.11                  \
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
    && make -j4 && make install;                   \
}

cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
```


### [Linux API Headers for Glibc](https://www.linuxfromscratch.org/lfs/view/stable/chapter05/linux-headers.html)

```bash
cd $LFS/sources
tar -xf linux-5.10.17.tar.xz
cd linux-5.10.17
make mrproper
make headers

find usr/include -name '.*' -delete
rm usr/include/Makefile
cp -rv usr/include $LFS/usr

```

### [Glibc](https://www.linuxfromscratch.org/lfs/view/stable/chapter05/glibc.html)

```bash
cd $LFS/sources
tar -xf glibc-2.33.tar.xz
cd glibc-2.33

case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac

patch -Np1 -i ../glibc-2.33-fhs-1.patch

mkdir -v build
cd build

time {                                          \
    ../configure                                \
      --prefix=/usr                             \
      --host=$LFS_TGT                           \
      --build=$(../scripts/config.guess)        \
      --enable-kernel=3.2                       \
      --with-headers=$LFS/usr/include           \
      libc_cv_slibdir=/lib                      \
    && make -j4 && make DESTDIR=$LFS install;   \
}

```

#### Sanity check

```bash
echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
readelf -l a.out | grep '/ld-linux'
```

Should be like this

`      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]`


```bash
rm -v dummy.c a.out
```

Finnaly install headers

```bash
$LFS/tools/libexec/gcc/$LFS_TGT/10.2.0/install-tools/mkheaders
```

### [Libstdc++](https://www.linuxfromscratch.org/lfs/view/stable/chapter05/gcc-libstdc++-pass1.html)

```bash
cd $LFS/sources/gcc-10.2.0
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
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/10.2.0   \
    && make -j4 && make DESTDIR=$LFS install;                   \
}
```

## [Cross Compiling Temporary Tools](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/chapter06.html)

### [M4](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/m4.html)

```bash
cd $LFS/sources
tar -xf m4-1.4.18.tar.xz 
cd m4-1.4.18
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h

time { \

    ./configure --prefix=/usr                   \
            --host=$LFS_TGT                     \
            --build=$(build-aux/config.guess)   \
    && make -j4 && make DESTDIR=$LFS install;   \
}

```

### [Ncurses](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/ncurses.html)

```bash
cd $LFS/sources
tar -xf ncurses-6.2.tar.gz 
cd ncurses-6.2
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
            --enable-widec


make -j4
make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so
mv -v $LFS/usr/lib/libncursesw.so.6* $LFS/lib
ln -sfv ../../lib/$(readlink $LFS/usr/lib/libncursesw.so) $LFS/usr/lib/libncursesw.so
```

### [Bash](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/bash.html)

```bash
cd $LFS/sources
tar -xf bash-5.1.tar.gz
cd bash-5.1

./configure --prefix=/usr                   \
            --build=$(support/config.guess) \
            --host=$LFS_TGT                 \
            --without-bash-malloc

make -j4
make DESTDIR=$LFS install
mv $LFS/usr/bin/bash $LFS/bin/bash
ln -sv bash $LFS/bin/sh
```

### [Coreutils](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/coreutils.html)

```bash
cd $LFS/sources
tar -xf coreutils-8.32.tar.xz
cd coreutils-8.32

./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime

make -j4
make DESTDIR=$LFS install

mv -v $LFS/usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} $LFS/bin
mv -v $LFS/usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm}        $LFS/bin
mv -v $LFS/usr/bin/{rmdir,stty,sync,true,uname}               $LFS/bin
mv -v $LFS/usr/bin/{head,nice,sleep,touch}                    $LFS/bin
mv -v $LFS/usr/bin/chroot                                     $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1                        $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'                                           $LFS/usr/share/man/man8/chroot.8

```

### [Diffutils](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/diffutils.html)

```bash
cd $LFS/sources
tar -xf diffutils-3.7.tar.xz 
cd diffutils-3.7

./configure --prefix=/usr --host=$LFS_TGT
make -j4
make DESTDIR=$LFS install

```

### [File](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/file.html)

```bash
cd $LFS/sources
tar -xf file-5.39.tar.gz
cd file-5.39
mkdir build
pushd build
  ../configure --disable-bzlib      \
               --disable-libseccomp \
               --disable-xzlib      \
               --disable-zlib
  make -j4
popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
make FILE_COMPILE=$(pwd)/build/src/file
make DESTDIR=$LFS install

```

### [Findutils](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/findutils.html)

```bash
cd $LFS/sources
tar -xf findutils-4.8.0.tar.xz
cd findutils-4.8.0
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j4
make DESTDIR=$LFS install
mv -v $LFS/usr/bin/find $LFS/bin
sed -i 's|find:=${BINDIR}|find:=/bin|' $LFS/usr/bin/updatedb
```

### [Gawk](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/gawk.html)

```bash
cd $LFS/sources
tar -xf gawk-5.1.0.tar.xz
cd gawk-5.1.0
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./config.guess)

make -j4
make DESTDIR=$LFS install

```

### [Grep](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/grep.html)

```bash
cd $LFS/sources
tar -xf grep-3.6.tar.xz
cd grep-3.6

./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --bindir=/bin

make -j4
make DESTDIR=$LFS install

```

### [Gzip](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/gzip.html)

```bash
cd $LFS/sources
tar -xf gzip-1.10.tar.xz
cd gzip-1.10

./configure --prefix=/usr --host=$LFS_TGT
make -j4
make DESTDIR=$LFS install
mv -v $LFS/usr/bin/gzip $LFS/bin
```

### [Make](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/make.html)

```bash
cd $LFS/sources
tar -xf make-4.3.tar.xz
cd make-4.3
./configure --prefix=/usr   \
            --without-guile \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j4
make DESTDIR=$LFS install

```

### [Patch](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/patch.html)

```bash
cd $LFS/sources
tar -xf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j4
make DESTDIR=$LFS install

```

### [Sed](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/sed.html)

```bash
cd $LFS/sources
tar -xf sed-4.8.tar.xz
cd sed-4.8
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --bindir=/bin
make -j4
make DESTDIR=$LFS install

```

### [Tar](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/tar.html)

```bash
cd $LFS/sources
tar -xf tar-1.34.tar.xz
cd tar-1.34
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --bindir=/bin

make -j4
make DESTDIR=$LFS install

```

### [Xz](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/xz.html)

```bash
cd $LFS/sources

tar -xf xz-5.2.5.tar.xz
cd xz-5.2.5
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.2.5
make -j4
make DESTDIR=$LFS install
mv -v $LFS/usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat}  $LFS/bin
mv -v $LFS/usr/lib/liblzma.so.*                       $LFS/lib
ln -svf ../../lib/$(readlink $LFS/usr/lib/liblzma.so) $LFS/usr/lib/liblzma.so

```

### [Binutils - Pass 2](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/binutils-pass2.html)

```bash
cd $LFS/sources
cd binutils-2.36.1
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
make -j4
make DESTDIR=$LFS install
install -vm755 libctf/.libs/libctf.so.0.0.0 $LFS/usr/lib
```

### [Gcc - Pass 2](https://www.linuxfromscratch.org/lfs/view/stable/chapter06/gcc-pass2.html)


```bash
cd $LFS/sources/gcc-10.2.0
tar -xf ../mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -xf ../gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -xf ../mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc
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

make -j4
make DESTDIR=$LFS install
ln -sv gcc $LFS/usr/bin/cc

```

## [Entering Chroot and Building Additional Temporary Tools](https://www.linuxfromscratch.org/lfs/view/stable/chapter07/introduction.html)


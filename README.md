# Building and running LFS

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
```


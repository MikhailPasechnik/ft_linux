#!/bin/bash
set -e

if [[ -z "${LFS}" ]]; then
    echo "No LFS env!"
    exit
else
    echo "LFS at ${LFS}"
fi

if id "lfs" &>/dev/null; then
    echo 'lfs user already exists!'
else
    sudo groupadd lfs
    sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs

    sudo passwd lfs

    sudo chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
    sudo chown -v lfs $LFS/sources
    case $(uname -m) in  x86_64) sudo chown -v lfs $LFS/lib64 ;;esac

    sudo [ ! -e /etc/bash.bashrc ] || sudo mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE
    sudo ln -sf bash /bin/sh
fi


sudo su lfs <<'EOF'
cat > ${HOME}/.bash_profile <<EOL
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOL
cat > ${HOME}/.bashrc <<EOL
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=\$LFS/tools/bin:$PATH
CONFIG_SITE=\$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOL
EOF


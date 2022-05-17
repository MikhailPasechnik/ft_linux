find /mnt/lfs/sources/*.tar.* | sed -e "s/\.tar\..*//" | xargs sudo rm -rf

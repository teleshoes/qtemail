#!/bin/sh
project="qtemail"
dir=$HOME/Code/$project
mnt=/scratchbox/users/$USER/home/$USER/$project

sudo /scratchbox/sbin/sbox_ctl start
sudo /scratchbox/sbin/sbox_sync

mkdir $mnt
sudo mount -o bind $dir $mnt

/scratchbox/login -d $HOME/$project ./build-src-deb.sh

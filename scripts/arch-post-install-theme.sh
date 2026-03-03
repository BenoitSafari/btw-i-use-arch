#!/bin/bash

screen_res=2k
icon_dir=tmp-theme-icon
theme_dir=tmp-theme
current_dir=$(pwd)
cd $HOME

git clone git@github.com:vinceliuice/Tela-circle-icon-theme.git $icon_dir
git clone git@github.com:vinceliuice/Graphite-gtk-theme.git $theme_dir

cd ./$icon_dir
./install.sh black
cd ../$theme_dir
./install.sh -l -c dark --tweaks rimless
sudo ./install.sh --gdm --libadwaita -c dark --tweaks rimless 
cd ./other/grub2
sudo ./install.sh -s $screen_res -b 

user_ext=(
    xcursor-breeze
    gnome-shell-extension-color-picker
    gnome-shell-extension-dash-to-dock
    gnome-shell-extension-appindicator 
    gnome-shell-extension-blur-my-shell
    gnome-shell-extension-lan-ip-address-git 
    gnome-shell-extension-rounded-window-corners-reborn-git
    gnome-shell-extension-top-bar-organizer
)

echo "###############################################################"
echo "# [BTW-I-USE-ARCH] Installing user desktop extensions."
echo "###############################################################"
yay -S --noconfirm ${user_ext[@]}

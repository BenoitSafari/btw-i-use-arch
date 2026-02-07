#!/bin/bash

screen_res=2k
icon_dir=tmp-theme-icon
theme_dir=tmp-theme
current_dir=$(pwd)
cd $HOME

git clone git@github.com:vinceliuice/Tela-circle-icon-theme.git $icon_dir
git clone git clone git@github.com:vinceliuice/Graphite-gtk-theme.git $theme_dir

cd ./$icon_dir
./install.sh nord
cd ../$theme_dir
./install.sh -l -c dark --tweaks nord rimless
sudo ./install.sh --gdm -l -c dark --tweaks nord rimless 
cd ./other/grub2
sudo ./install.sh -s $screen_res -b 



user_ext=(
    gnome-shell-extension-appindicator 
    gnome-shell-extension-blur-my-shell
    gnome-shell-extension-lan-ip-address-git 
    gnome-shell-extension-rounded-window-corners-reborn-git
)

echo "###############################################################"
echo "# [ARCH-INSTALL-SCRIPT] Installing user desktop extensions."
echo "###############################################################"
yay -S --noconfirm ${user_ext[@]}

username=$(whoami)
wallpaper_path="/home/$username/Pictures/wallpaper.jpg"
cp .wallpaper.jpg/ $wallpaper_path
gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper_path"
gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_path"
gsettings set org.gnome.desktop.background picture-options 'zoom'

gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com || true
gnome-extensions enable ubuntu-appindicators@ubuntu.com || true
gnome-extensions enable blur-my-shell@aunetx || true
gnome-extensions enable 'system-monitor@gnome-shell-extensions.gcampax.github.com'
gnome-extensions enable 'launch-new-instance@gnome-shell-extensions.gcampax.github.com'
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.appindicator"; then
    gsettings set org.gnome.shell.extensions.appindicator icon-size 16
fi
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.blur-my-shell"; then
    gsettings set org.gnome.shell.extensions.blur-my-shell hacks-level 1
    gsettings set org.gnome.shell.extensions.blur-my-shell settings-version 2
    gsettings set org.gnome.shell.extensions.blur-my-shell.appfolder brightness 0.5
    gsettings set org.gnome.shell.extensions.blur-my-shell.appfolder sigma 100
    gsettings set org.gnome.shell.extensions.blur-my-shell.appfolder style-dialogs 1
    gsettings set org.gnome.shell.extensions.blur-my-shell.applications blur true
    gsettings set org.gnome.shell.extensions.blur-my-shell.applications enable-all false
    gsettings set org.gnome.shell.extensions.blur-my-shell.applications dynamic-opacity false
    gsettings set org.gnome.shell.extensions.blur-my-shell.applications sigma 60
    gsettings set org.gnome.shell.extensions.blur-my-shell.applications whitelist "['kitty']"
    gsettings set org.gnome.shell.extensions.blur-my-shell.panel blur true
    gsettings set org.gnome.shell.extensions.blur-my-shell.panel brightness 0.6
    gsettings set org.gnome.shell.extensions.blur-my-shell.panel sigma 100
    gsettings set org.gnome.shell.extensions.blur-my-shell.panel override-background true
    
    BLUR_PIPELINES="{'pipeline_default': {'name': <'Default'>, 'effects': <[<{'type': <'native_static_gaussian_blur'>, 'id': <'effect_000000000000'>, 'params': <{'radius': <30>, 'brightness': <0.59999999999999998>}>}>, <{'type': <'noise'>, 'id': <'effect_86633551428100'>, 'params': <@a{sv} {}>}>]>}}"
    gsettings set org.gnome.shell.extensions.blur-my-shell pipelines "$BLUR_PIPELINES"
fi

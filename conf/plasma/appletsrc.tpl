# Template for ~/.config/plasma-org.kde.plasma.desktop-appletsrc
# Rendered by apply-benoit-layout.sh — do not copy verbatim.
#
# Placeholders:
#   @HOME@              user home directory
#   @ACTIVITY_ID@       current Plasma activity UUID (target machine)
#   @WALLPAPER@         absolute path to the wallpaper image
#   @WALLPAPER_FILL@    org.kde.image FillMode (2 = scaled & cropped, 6 = pad/centered)
#   @THERMAL_SENSORS@   JSON array for the thermalmonitor applet
#
# Layout:
#   Containment 399 — desktop (folder view), primary screen
#   Containment 400 — top panel, 32px, opaque, centered, custom length
#   Containment 425 — bottom dock, 64px, translucent, auto-hide, fit content
#   Containment 458 — desktop (folder view), secondary screen — dropped when single-head

[ActionPlugins][0]
MiddleButton;NoModifier=org.kde.paste
RightButton;NoModifier=org.kde.contextmenu

[ActionPlugins][1]
RightButton;NoModifier=org.kde.contextmenu

[Containments][399]
ItemGeometriesHorizontal=
activityId=@ACTIVITY_ID@
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][399][Wallpaper][org.kde.image][General]
Color=32,32,32
FillMode=@WALLPAPER_FILL@
Image=@WALLPAPER@
SlidePaths=@HOME@/.local/share/wallpapers/,/usr/share/wallpapers/

[Containments][400]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=3
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][400][Applets][405]
activityId=
formfactor=0
immutability=1
lastScreen=-1
location=0
plugin=org.kde.plasma.systemtray
popupHeight=441
popupWidth=440
wallpaperplugin=org.kde.image

[Containments][400][Applets][405][Applets][406]
immutability=1
plugin=org.kde.plasma.vault

[Containments][400][Applets][405][Applets][407]
immutability=1
plugin=org.kde.plasma.cameraindicator

[Containments][400][Applets][405][Applets][408]
immutability=1
plugin=org.kde.plasma.clipboard

[Containments][400][Applets][405][Applets][409]
immutability=1
plugin=org.kde.plasma.devicenotifier

[Containments][400][Applets][405][Applets][410]
immutability=1
plugin=org.kde.plasma.manage-inputmethod

[Containments][400][Applets][405][Applets][411]
immutability=1
plugin=org.kde.plasma.notifications

[Containments][400][Applets][405][Applets][412]
immutability=1
plugin=org.kde.plasma.keyboardindicator

[Containments][400][Applets][405][Applets][414]
immutability=1
plugin=org.kde.kscreen

[Containments][400][Applets][405][Applets][415]
immutability=1
plugin=org.kde.plasma.keyboardlayout

[Containments][400][Applets][405][Applets][416]
immutability=1
plugin=org.kde.plasma.networkmanagement

[Containments][400][Applets][405][Applets][417]
immutability=1
plugin=org.kde.plasma.volume

[Containments][400][Applets][405][Applets][417][Configuration][General]
currentTab=streams
migrated=true

[Containments][400][Applets][405][Applets][422]
immutability=1
plugin=org.kde.plasma.brightness

[Containments][400][Applets][405][Applets][423]
immutability=1
plugin=org.kde.plasma.bluetooth

[Containments][400][Applets][405][Applets][423][Configuration][General]
showNumberOfConnectedDevices=true

[Containments][400][Applets][405][Applets][441]
immutability=1
plugin=org.kde.plasma.mediacontroller

[Containments][400][Applets][405][General]
disabledStatusNotifiers=electron
extraItems=org.kde.plasma.vault,org.kde.plasma.cameraindicator,org.kde.plasma.clipboard,org.kde.plasma.devicenotifier,org.kde.plasma.manage-inputmethod,org.kde.plasma.mediacontroller,org.kde.plasma.keyboardindicator,org.kde.kscreen,org.kde.plasma.brightness,org.kde.plasma.keyboardlayout,org.kde.plasma.networkmanagement,org.kde.plasma.volume,org.kde.plasma.bluetooth,org.kde.plasma.notifications
hiddenItems=org.kde.plasma.notifications
knownItems=org.kde.plasma.vault,org.kde.plasma.bluetooth,org.kde.plasma.cameraindicator,org.kde.plasma.clipboard,org.kde.plasma.devicenotifier,org.kde.plasma.manage-inputmethod,org.kde.plasma.mediacontroller,org.kde.plasma.notifications,org.kde.plasma.keyboardindicator,org.kde.plasma.weather,org.kde.kscreen,org.kde.plasma.battery,org.kde.plasma.brightness,org.kde.plasma.keyboardlayout,org.kde.plasma.networkmanagement,org.kde.plasma.volume,org.kde.plasma.printmanager
shownItems=org.kde.plasma.volume,org.kde.plasma.bluetooth

[Containments][400][Applets][419]
immutability=1
plugin=org.kde.plasma.digitalclock

[Containments][400][Applets][419][Configuration]
popupHeight=451
popupWidth=559

[Containments][400][Applets][419][Configuration][Appearance]
autoFontAndSize=false
boldText=true
dateDisplayFormat=BesideTime
fontFamily=JetBrainsMono Nerd Font
fontSize=8
fontStyleName=Bold
fontWeight=700
showSeconds=Always
showWeekNumbers=true

[Containments][400][Applets][431]
immutability=1
plugin=org.kde.plasma.colorpicker

[Containments][400][Applets][431][Configuration]
popupHeight=325
popupWidth=324

[Containments][400][Applets][435]
immutability=1
plugin=org.kde.plasma.minimizeall

[Containments][400][Applets][437]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][400][Applets][437][Configuration][General]
expanding=false
length=20

[Containments][400][Applets][438]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][400][Applets][439]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][400][Applets][447]
immutability=1
plugin=com.benoitsafari.ipdisplay

[Containments][400][Applets][447][Configuration]
popupHeight=135
popupWidth=560

[Containments][400][Applets][449]
immutability=1
plugin=com.benoitsafari.systemmonitorbar

[Containments][400][Applets][451]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][400][Applets][451][Configuration][General]
expanding=false
length=20

[Containments][400][Applets][452]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][400][Applets][452][Configuration][General]
expanding=false
length=6

[Containments][400][Applets][453]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][400][Applets][453][Configuration][General]
expanding=false
length=2

[Containments][400][Applets][455]
immutability=1
plugin=org.kde.plasma.panelspacer

[Containments][400][Applets][455][Configuration][General]
expanding=false
length=22

[Containments][400][Applets][456]
immutability=1
plugin=com.benoitsafari.diskusage

[Containments][400][Applets][456][Configuration]
popupHeight=323
popupWidth=755

[Containments][400][Applets][457]
immutability=1
plugin=com.benoitsafari.nasdiskusage

[Containments][400][Applets][457][Configuration]
popupHeight=213
popupWidth=540

[Containments][400][Applets][461]
immutability=1
plugin=org.kde.olib.thermalmonitor

[Containments][400][Applets][461][Configuration]
popupHeight=181
popupWidth=288

[Containments][400][Applets][461][Configuration][General]
sensors=@THERMAL_SENSORS@

[Containments][400][General]
AppletOrder=452;447;451;456;457;455;449;461;438;419;439;431;437;405;435;453

[Containments][425]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][425][Applets][403]
immutability=1
plugin=org.kde.plasma.icontasks

[Containments][425][Applets][403][Configuration][General]
launchers=applications:kitty.desktop,preferred://filemanager

[Containments][425][Applets][446]
immutability=1
plugin=org.kde.plasma.kickoff

[Containments][425][Applets][446][Configuration]
popupHeight=471
popupWidth=635

[Containments][425][Applets][446][Configuration][General]
alphaSort=true
compactMode=true
favoritesDisplay=1
favoritesPortedToKAstats=true
icon=archlinux
switchCategoryOnHover=true
systemFavorites=suspend\\,hibernate\\,reboot\\,shutdown

[Containments][425][General]
AppletOrder=446;403

[Containments][458]
activityId=@ACTIVITY_ID@
formfactor=0
immutability=1
lastScreen=1
location=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][458][Wallpaper][org.kde.image][General]
Color=32,32,32
FillMode=@WALLPAPER_FILL@
Image=@WALLPAPER@

[ScreenMapping]
itemsOnDisabledScreens=
screenMapping=

#!/usr/bin/env bash

if [ $EUID != 0 ]; then
	echo "this script must be run as root"
	echo ""
	echo "usage:"
	echo "su -"
	echo "./install_dependencies.sh"
	exit $exit_code
   exit 1
fi

pacman -Sy --needed make pkg-config gcc openal glew freeglut freeimage freetype2 cairo poco gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav raspberrypi-firmware gst-omx-rpi assimp boost libxcursor opencv assimp glfw-x11  uriparser curl pugixml libgconf-2-4

wget http://ci.openframeworks.cc/rtaudio-armv7hf.tar.bz2
tar xjf rtaudio-armv7hf.tar.bz2 -C /

exit_code=$?
if [ $exit_code != 0 ]; then
	echo "error installing packages, there could be an error with your internet connection"
	exit $exit_code
fi

# Update addon_config.mk files to use OpenCV 3 or 4 depending on what's installed
addons_dir="$(readlink -f "$ROOT/../../../addons")"
$(pkg-config opencv4 --exists)
exit_code=$?
if [ $exit_code != 0 ]; then
	echo "Updating ofxOpenCV to use openCV3"
	sed -i -E 's/ADDON_PKG_CONFIG_LIBRARIES =(.*)opencv4(.*)$/ADDON_PKG_CONFIG_LIBRARIES =\1opencv\2/' "$addons_dir/ofxOpenCv/addon_config.mk"
else
	echo "Updating ofxOpenCV to use openCV4"
	sed -i -E 's/ADDON_PKG_CONFIG_LIBRARIES =(.*)opencv\s/ADDON_PKG_CONFIG_LIBRARIES =\1opencv4 /g' "$addons_dir/ofxOpenCv/addon_config.mk"
	sed -i -E 's/ADDON_PKG_CONFIG_LIBRARIES =(.*)opencv$/ADDON_PKG_CONFIG_LIBRARIES =\1opencv4/g' "$addons_dir/ofxOpenCv/addon_config.mk"
fi

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
ccache -M 50G
source build/envsetup.sh
breakfast $1
croot
brunch $1

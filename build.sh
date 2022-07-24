#!/bin/bash

echo
echo "--------------------------------------"
echo "    Pixel Experience 12.1 Buildbot    "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"
echo
export USE_CCACHE=1
export CCACHE_EXEC=$(command -v ccache)

set -e

BL=$PWD/treble_build_awaken
BD=$HOME/builds

BRANCH="awaken"

PEMK="$BL/peplus.mk"

initRepos() {
    if [ ! -d .repo ]; then
        echo "--> Initializing Awaken workspace"
        repo init -u https://github.com/Project-Awaken/android_manifest -b 12.1
        echo
		
		echo
		git clone https://github.com/jgudec/treble_manifest .repo/local_manifests -b android-12.0
		echo
		
		if [ -f .repo/local_manifests/replace.xml ]; then
		echo
		rm .repo/local_manifests/replace.xml
		echo
		fi
    fi
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
    echo
}

applyPatches() {
    echo "--> Applying prerequisite patches"
    bash $BL/apply-patches.sh $BL prerequisite $BRANCH
    echo
	

    echo "--> Applying PHH patches"
    bash $BL/apply-patches.sh $BL phh $BRANCH
    echo

    echo "--> Applying personal patches"
    bash $BL/apply-patches.sh $BL personal
    echo
	
	echo "--> Applying final personal patch"
    cd $PWD/vendor/partner_gms
	git am $BL/patches/platform_vendor_partner_gms/0001-Remove-SearchLauncher.patch
	cd ../..
    echo
}

generateSH(){
	cd ~/awaken/device/phh/treble
	bash generate.sh ~/awaken/vendor/awaken/config/common.mk
	cd ~/awaken
	echo
}

setupEnv() {
    echo "--> Setting up build environment"
	. build/envsetup.sh
    mkdir -p $BD
    echo
}

buildTrebleApp() {
    echo "--> Building treble_app"
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    echo
}

buildVariant() {
    echo "--> Building treble_arm64_bgN"
    lunch treble_arm64_bgN-userdebug
    make installclean
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-treble_arm64_bgN.img
    echo
}

generatePackages() {
    echo "--> Generating packages"
	xz -cv $BD/system-treble_arm64_bgN.img -T0 > $BD/AwakenOS_arm64-ab-12.1-$BUILD_DATE-UNOFFICIAL.img.xz
    rm -rf $BD/system-*.img
    echo
}

START=`date +%s`
BUILD_DATE="$(date +%Y%m%d)"

initRepos
syncRepos
applyPatches
generateSH
setupEnv
buildTrebleApp
buildVariant
generatePackages

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo

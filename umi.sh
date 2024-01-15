#!/bin/bash
#set -e
## Copy this script inside the kernel directory
LINKER="lld"
DIR=`readlink -f .`
MAIN=`readlink -f ${DIR}/..`
KERNEL_DEFCONFIG=umi_user_defconfig

if [ ! -d "$MAIN/clang" ]; then
	mkdir "$MAIN/clang"
    pushd "$MAIN/clang" > /dev/null
	wget https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-16-link.txt
	clang_link="$(cat Clang-16-link.txt)"
    wget -q $clang_link
	tar -xf $(basename $clang_link)
	popd > /dev/null
fi
export PATH="$MAIN/clang/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_COMPILER_STRING="$($MAIN/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"



# Correct panel dimensions for HyperOS/MIUI ROMs
function hyperos_fix_dimens()
{
	sed -i 's/<70>/<695>/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel-j3s-37-02-0a-dsc-video.dtsi
	sed -i 's/<70>/<695>/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi
	sed -i 's/<70>/<695>/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi
	sed -i 's/<71>/<710>/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel-j1s*
	sed -i 's/<71>/<710>/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel-j2*
	sed -i 's/<155>/<1544>/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel-j3s-37-02-0a-dsc-video.dtsi
	sed -i 's/<155>/<1545>/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi
	sed -i 's/<155>/<1546>/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi
	sed -i 's/<154>/<1537>/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel-j1s*
	sed -i 's/<154>/<1537>/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel-j2*
}

# Enable back MI fod dimlayer support on HyperOS/MIUI
function hyperos_fix_fod()
{
	sed -i 's/mi,mdss-panel-on-dimming-delay = <120>;/mi,mdss-panel-on-dimming-delay = <120>;\n\tmi,mdss-dsi-panel-fod-dimlayer-enabled;/' arch/arm64/boot/dts/vendor/qcom/dsi-panel*
	sed -i 's/qcom,mdss-dsi-dispparam-/mi,mdss-dsi-/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel*
	sed -i 's/39 01 00 00 00 00 03 51 05 21]/]/g' arch/arm64/boot/dts/vendor/qcom/dsi-panel*
	sed -i 's/qcom,pon-dbc-delay = <15625>/qcom,pon-dbc-delay = <31250>/g' arch/arm64/boot/dts/vendor/qcom/pm*.dtsi

}

hyperos_fix_dimens
hyperos_fix_fod

KERNEL_DIR=`pwd`
ZIMAGE_DIR="$KERNEL_DIR/out/arch/arm64/boot"
# Speed up build process
MAKE="./makeparallel"
BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

if [[ $1 == "ksu" ]]; then 
	# kernel-SU add
	curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
	echo "**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****"
fi

echo -e "$blue***********************************************"
echo "          BUILDING KERNEL          "
echo -e "***********************************************$nocol"
make $KERNEL_DEFCONFIG O=out CC=clang
make -j$(nproc --all) O=out \
                      CC=clang \
                      ARCH=arm64 \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      NM=llvm-nm \
                      OBJDUMP=llvm-objdump \
                      STRIP=llvm-strip

TIME="$(date "+%Y%m%d-%H%M%S")"
mkdir -p tmp
cp -fp $ZIMAGE_DIR/Image tmp
#cp -fp $ZIMAGE_DIR/dtbo.img tmp
#cp -fp $ZIMAGE_DIR/dtb tmp
cp -rp ./AnyKernel3/* tmp
cd tmp
7za a -mx9 tmp.zip *
cd ..
rm *.zip
cp -fp tmp/tmp.zip official-umi-hyperos-v2.85-$TIME.zip
rm -rf tmp
echo $TIME

# Kernel-SU remove
git checkout drivers/Makefile &>/dev/null
rm -rf KernelSU
rm -rf drivers/kernelsu

# dtsi change remove
git checkout arch/arm64/boot/dts/vendor &>/dev/null

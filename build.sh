#!/bin/bash
sudo apt update && sudo apt install ccache
# Export
echo "Environment Setup"
export TELEGRAM_TOKEN
export TELEGRAM_CHAT
echo "Export Path"
export ARCH="arm64"
export SUBARCH="arm64"
export PATH="/usr/lib/ccache:$PATH"
export KBUILD_BUILD_USER="B4gol"
export KBUILD_BUILD_HOST="CircleCI"
export branch="11-master"
export device="riva"
export CONFIG=final_defconfig
export LOCALVERSION="-b4gol"
export kernel_repo="https://github.com/B4gol/platform-kernelist-xiaomi-rova.git"
export tc_repo="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9"
export tc_name="aarch64-linux_androidkernel-"
export tc_v="4.9.x"
export zip_name="decker-""$device""-"$(env TZ='Asia/Jakarta' date +%Y%m%d)""
export KERNEL_DIR=$(pwd)
export KERN_IMG="$KERNEL_DIR"/kernel/out/arch/"$ARCH"/boot/Image.gz-dtb
export ZIP_DIR="$KERNEL_DIR"/AnyKernel
export CONFIG_DIR="$KERNEL_DIR"/kernel/arch/"$ARCH"/configs
export CORES=$(grep -c ^processor /proc/cpuinfo)
export THREAD="-j$CORES"
CROSS_COMPILE+="ccache "
CROSS_COMPILE+="$KERNEL_DIR"/"$tc_name"-"$tc_v"/bin/"$tc_name-"
export CROSS_COMPILE

function sync(){
	SYNC_START=$(date +"%s")
	curl -v -F "chat_id=$TELEGRAM_CHAT" -F "parse_mode=html" -F text="Sync Started" https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage
	cd "$KERNEL_DIR" && git clone -b "$branch" "$kernel_repo" --depth 1 kernel
	cd "$KERNEL_DIR" && git clone "$tc_repo" "$tc_name"-"$tc_v"
	chmod -R a+x "$KERNEL_DIR"/"$tc_name"-"$tc_v"
	SYNC_END=$(date +"%s")
	SYNC_DIFF=$((SYNC_END - SYNC_START))
	curl -v -F "chat_id=$TELEGRAM_CHAT" -F "parse_mode=html" -F text="Sync completed successfully in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds" https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage > /dev/null
}
function build(){
	BUILD_START=$(date +"%s")
	cd "$KERNEL_DIR"/kernel
	export last_tag=$(git log -1 --oneline)
	curl -v -F "chat_id=$TELEGRAM_CHAT" -F "parse_mode=html" -F text="Build Started" https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage > /dev/null
	make  O=out "$CONFIG_DIR/$CONFIG" "$THREAD" > "$KERNEL_DIR"/kernel.log
	make "$THREAD" O=out >> "$KERNEL_DIR"/kernel.log
	BUILD_END=$(date +"%s")
	BUILD_DIFF=$((BUILD_END - BUILD_START))
	export BUILD_DIFF
}
function success(){
	curl -v -F "chat_id=$TELEGRAM_CHAT" -F document=@"$ZIP_DIR"/"$zip_name".zip -F "parse_mode=html" -F caption="Build completed successfully in $((BUILD_DIFF / 60)):$((BUILD_DIFF % 60))
	Dev : ""$KBUILD_BUILD_USER""
	Product : Redmi 4a/5a
	Device : #""$device""
	Branch : ""$branch""
	Host : ""$KBUILD_BUILD_HOST""
	Commit : ""$last_tag""
	Compiler : ""$(${CROSS_COMPILE}gcc --version | head -n 1)""
	Date : ""$(env TZ=Asia/Jakarta date)""" https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument
	
	curl -v -F "chat_id=$TELEGRAM_CHAT" -F document=@"$KERNEL_DIR"/kernel.log https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument > /dev/null
	exit 0
}
function failed(){
	curl -v -F "chat_id=$TELEGRAM_CHAT" -F document=@"$KERNEL_DIR"/kernel.log -F "parse_mode=html" -F "caption=Build failed in $((BUILD_DIFF / 60)):$((BUILD_DIFF % 60))" https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument > /dev/null
	exit 1
}
function check_build(){
	if [ -e "$KERN_IMG" ]; then
		cp "$KERN_IMG" "$ZIP_DIR"
		cd "$ZIP_DIR"
		mv zImage-dtb zImage
		zip -r "$zip_name".zip ./*
		success
	else
		failed
	fi
}
function main(){
	sync
	build
	check_build
}

main

#!/bin/zsh
clear
echo "#############\n# Build For #\n#############"
select opt in "Big Sur" "Monterey"; do
  case $opt in
  	"Big Sur")
		version="RamDisk_BS"
		OS="11"
		break
		;;
	"Monterey")
		version="RamDisk_Monterey"
		OS="12"
		break
		;;
    "Exit")
      exit
      ;;
    *)
      echo "This is not an option, please try again"
      ;;
  esac
done

clear
echo "####################\n# SkyLight Flavors #\n####################"
select opt in "SkyLight Pro" "SkyLite" "SkyLight"; do
  case $opt in
  	"SkyLight Pro")
		cursor="# spin cursor hack
# TODO: proper fix
#symbol _CGXHWCursorIsAllowed
#return 0x0"
		backdrop="# WSBackdropGetCorrectedColor remove 0x17 (MenuBarDark) material background
#set 0x26ef70
#write 0x00000000000000000000000000000000"
		break
		;;
	"SkyLite")
		cursor="# spin cursor hack
# TODO: proper fix
#symbol _CGXHWCursorIsAllowed
#return 0x0"
		backdrop="# WSBackdropGetCorrectedColor remove 0x17 (MenuBarDark) material background
set 0x26ef70
write 0x00000000000000000000000000000000"
		break
		;;
	"SkyLight")
		cursor="# spin cursor hack
# TODO: proper fix
symbol _CGXHWCursorIsAllowed
return 0x0"
		backdrop="# WSBackdropGetCorrectedColor remove 0x17 (MenuBarDark) material background
set 0x26ef70
write 0x00000000000000000000000000000000"
		break
		;;
    "Exit")
      exit
      ;;
    *)
      echo "This is not an option, please try again"
      ;;
  esac
done

lipo -thin x86_64 "./SkyLight" -output "./SkyLightPatched"

./Renamer "SkyLightPatched" "SkyLightPatched" _SLSNewWindowWithOpaqueShape _SLSSetMenuBars _SLSCopyDevicesDictionary _SLSCopyCoordinatedDistributedNotificationContinuationBlock _SLSShapeWindowInWindowCoordinates _SLSEventTapCreate _SLSWindowSetShadowProperties


./Binpatcher "SkyLightPatched" "SkyLightPatched" "
# the transparency hack
set 0x216c60
nop 0x4

$cursor

# menubar height (22.0 --> 24.0)
set 0xb949c
write 0x38

$backdrop

# force 0x17 for light, inactive
set 0xb6db6
write 0x17
set 0xb6da3
write 0x17
set 0xb6db0
write 0x17

# override blend mode
# 0: works
# 1: invisible light
# 2: invisible dark
# 3+: corrupt
set 0xb6e4a
write 0x00
set +0x3
nop 0x4

# hide backstop (Mojave Shadows)
# TODO: weird
set 0xb88b6
nop 0x2
set 0xb8861
nop 0x2
set 0xb8877
nop 0x8

# prevent prefpane crash
# TODO: shim SLSInstallRemoteContextNotificationHandlerV2 instead
symbol ___SLSRemoveRemoteContextNotificationHandler_block_invoke
return 0x0"

if test -e "$code/Stuff/anti-thing.txt"
then
	./Binpatcher "SkyLight" "SkyLight" "$(cat "$code/Stuff/anti-thing.txt")"
fi
################
## Build Wrappers
##################

set -e
folderOut="Wrapped"
rm -rf "$folderOut"
mkdir "$folderOut"

function build
{
	oldIn="$1"
	newIn="$2"
	mainInstall="$3"

	prefixOut="Wrapped/$4"
	mkdir -p "$prefixOut"
	
	name="$(basename "$mainInstall")"
	mainNameOut="$name"
	oldNameOut="${name}Old.dylib"
	
	prefixInstall="$(dirname "$mainInstall")"
	oldInstall="$prefixInstall/$oldNameOut"
	
	mainOut="$prefixOut/$mainNameOut"
	oldOut="$prefixOut/$oldNameOut"

	cp "$oldIn" "$oldOut"
	install_name_tool -id "$oldInstall" "$oldOut"
	
	mainIn="$prefixOut/${name}Wrapper.m"
	shimsIn="$PWD/Shims"
	./Stubber "$oldIn" "$newIn" "$shimsIn" "$mainIn"
	
	    clang -fmodules -I "./Utils" -Wno-unused-getter-return-value -Wno-objc-missing-super-calls -mmacosx-version-min="$OS" -DMAJOR="$OS" -dynamiclib -compatibility_version 1.0.0 -current_version 1.0.0 -install_name "$mainInstall" -Xlinker -reexport_library "$oldOut" -I "$PWD/Shims" "$mainIn" -o "$mainOut" "${@:5}"
	
	codesign -f -s - "$oldOut"
	codesign -f -s - "$mainOut"
}

build "SkyLightPatched" "./$version/SkyLight" "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight" "Common" -F "/System/Library/PrivateFrameworks" -framework AppleSystemInfo -framework CoreBrightness

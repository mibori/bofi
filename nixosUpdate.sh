#!/bin/sh

# show line number when execute by bash -x makeUSB.sh
[ "$BASH" ] && \
    export PS4='    +\t $BASH_SOURCE:$LINENO: ${FUNCNAME[0]:+${FUNCNAME[0]}():}'

# Exit if there is an unbound variable or an error
set -o nounset
set -o errexit


scriptname=$(basename "$0")
scriptname="${0}"
mntpoint="${1}"

# Show usage
showUsage() {
	cat <<- EOF
	Generate NixOS configs
	Example: [sudo] $scriptname mount/point
	EOF
}


if [[ -z "$mntpoint" ]] ; then
    showUsage
    exit 2
fi

if [ ! -d "$mntpoint" ] ; then
    echo "Mount point should be exists"
    exit 3
fi

if [ ! -d "$mntpoint"/boot/grub ] ; then
    echo "Directory should have boot/grub installed"
    exit 4
fi


generated="$mntpoint"/boot/grub/mbusb.d/nixos-generated.d
rm -rf "$generated"
mkdir -p "$generated"

createConfig() {
    configname="$1"
cat <<EOCFG > "$generated"/"$configname".cfg  
for isofile in \$isopath/$configname; do
  if [ -e "\$isofile" ]; then
    regexp --set=isoname "\$isopath/(.*)" "\$isofile"
    submenu "\$isoname ->" "\$isofile" {
      iso_path="\$2"
      loopback loop "\$iso_path"
      root=(loop)
      menuentry "NixOS Installer" {
        bootoptions="init=/nix/store/vld9s6ywaicbflahjdgrxw9glngfd212-nixos-system-nixos-19.03.173279.878531fbdbb/init root=LABEL=NIXOS_ISO boot.shell_on_fail loglevel=4"
        linux /boot/bzImage \$bootoptions
        initrd /boot/initrd
      }
    }
  fi
done
EOCFG
    
}

echo finding isos
for isoFile in "$mntpoint"/boot/isos/nixos-*.iso ; do
    echo "$isoFile" found
    isoName=$(basename "$isoFile")
    isoMntPoint=~/isomounts/"$isoName"
    
    # Disabled because bsdtar has a problem with libarchive on Macos    
    if command -v 7z >/dev/null 2>&1 ; then
        echo 7z tool found
        rm -rf "$isoMntPoint"/isolinux
        mkdir -p "$isoMntPoint"
        7z x -o"$isoMntPoint" -i\!isolinux/isolinux.cfg "$isoFile"

        createConfig "$isoName" 
    elif command -v xorriso >/dev/null 2>&1 ; then
        echo xorriso tool found
        rm -rf "$isoMntPoint"/isolinux
        mkdir -p "$isoMntPoint"/isolinux
        xorriso -osirrox on -indev "$isoFile" -extract isolinux/isolinux.cfg "$isoMntPoint"/isolinux/isolinux.cfg
        createConfig "$isoName" 
    elif command -v isoinfo >/dev/null 2>&1 ; then
        echo isoinfo tool found, but not tested yet
        # rm -rf "$isoMntPoint"/isolinux
        # mkdir -p "$isoMntPoint"/isolinux
        # isoinfo -J -x /isolinux/isolinux.cfg -i "$isoFile" > "$isoMntPoint"/isolinux/isolinux.cfg
        # createConfig "$isoName" 
    elif [ "Linux" = $(uname) ] ; then
        echo no tools found
        echo use linux mount

        if [ "$EUID" -ne 0 ] ; then 
            echo "Please run as root"
            exit 1
        fi

        mkdir -p "$isoMntPoint"
        mount -o loop "$isoFile" "$isoMntPoint"
        createConfig "$isoName"
        umount "$isoMntPoint"
    else
        echo no tools found
        echo incompatible platform
        exit 5
    fi

done





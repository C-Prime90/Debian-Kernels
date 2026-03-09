#!/bin/bash

TOP="$PWD"

# Generate Kernel List
kList="$(find . -type d -name 'cprime-*' | sed 's|./||' | sort -V | tac) Exit"
for i in $kList; do options+=("$i"); done

# Display User Prompt
echo -e "\033[1m\033[4mKernel Selection\033[0m\n"
PS3="$(echo -e '\nSelect Kernel: ')"
select opt in "${options[@]}"; do
	case $opt in
		"Exit")
			break
			;;
		*)
			# Set-up Environment
			export CC="clang"
			export LD="ld.lld"
			export LLVM="1"
			export LLVM_IAS="1"
			export CONCURRENCY_LEVEL="$(nproc)"

			# Download Source
			dlDir="downloads"
			if [ ! -f "$dlDir/$(basename $(cat $opt/link.url))" ]; then
				echo "Downloading Source..."
				mkdir -p $dlDir
				wget $(cat $opt/link.url) -O $dlDir/$(basename $(cat $opt/link.url)) || exit 1
			fi

			# Extract Source
			echo -e "\nExtracting Source..."
			buildDir="build/$(echo $opt | sed 's/cprime/linux/')"
			mkdir -p build; rm -rf $buildDir
			tar -xf $dlDir/$(basename $(cat $opt/link.url)) -C build || exit 1

			# Patch Source
			echo -e "\nPatching Source..."
			cd build/linux-*
			for i in $(find $TOP/$opt -name '*.patch' | sort -V); do
				echo -e "\tApplying Patch: $opt/$(basename $i)" | sed 's/\t//' | tee -a patch.log
				patch -Np1 < $i >>patch.log || err="1"
				[ -n "$err" ] && echo -e "\t\tPatch: $opt/$(basename $i) Failed!!!" | sed 's/\t//' | tee -a patch.log && exit 1
				echo -e "\n" >>patch.log
			done
			cd $TOP

			# Build Kernel
			echo -e "\nBuilding Kernel...\n"
			cp $opt/$(echo $opt | sed 's/cprime/config/') $buildDir/.config || exit 1
			sed -i "s/CONFIG_LOCALVERSION=\".*/CONFIG_LOCALVERSION=\"-cprime+$(cat $TOP/version.txt)\"/" $buildDir/.config
			PS3="$(echo -e '\nSelect: ')"
			select conf in Configure Build; do
				case $conf in
					"Configure")
						make -C $buildDir menuconfig || exit 1
						echo -e "\n1) Configure\n2) Build"
					;;
					*)
						break
					;;
				esac
			done
			make -C $buildDir bindeb-pkg -j$(nproc) || exit 1
			break
			;;
	esac
done

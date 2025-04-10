pkgbase=linux-sultan
_major=6.14
_minor=0
pkgver=${_major}.${_minor}
pkgrel=1
pkgdesc='Linux Kernel with rice from Sultan Alsawaf'
url='https://github.com/kerneltoast/kernel_x86_laptop'
license=('GPL-2.0-only')
arch=(x86_64)
makedepends=('bc' 'cpio' 'gettext' 'libelf' 'pahole' 'perl' 'python' 'tar' 'xz' 'clang' 'llvm' 'lld')
options=(!debug !strip)

_srcname=linux-$pkgver
_srctag=v$pkgver
source=(
  "https://github.com/Reinazhard/kernel_x86_laptop/archive/refs/heads/v${_major}-sultan.zip"
  auto-cpu-optimization.sh
)

# Linux CachyOS additions
_kernver="$pkgver-$pkgrel"
_patchsource="https://raw.githubusercontent.com/cachyos/kernel-patches/master/${_major}"
_nv_ver=570.133.07
_nv_pkg="NVIDIA-Linux-x86_64-${_nv_ver}"
source+=("https://us.download.nvidia.com/XFree86/Linux-x86_64/${_nv_ver}/${_nv_pkg}.run"
         "${_patchsource}/misc/nvidia/0001-Enable-atomic-kernel-modesetting-by-default.patch"
         "${_patchsource}/misc/0001-clang-polly.patch"
         "${_patchsource}/misc/0001-acpi-call.patch"
         "${_patchsource}/misc/dkms-clang.patch"
	 "${_patchsource}/0004-bbr3.patch"
	 "${_patchsource}/0005-cachy.patch"
	 "${_patchsource}/0006-crypto.patch"
	 "${_patchsource}/0007-fixes.patch"
	 )

export KBUILD_BUILD_HOST=archlinux
export KBUILD_BUILD_TIMESTAMP="$(date -Ru${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH})"

BUILD_FLAGS=(
    CC=clang
    LD=ld.lld
    LLVM=1
    LLVM_IAS=1
    AR=llvm-ar
    NM=llvm-nm
)

prepare() {
  rm -rf $_srcname
  mv kernel_x86_laptop-${_major}-sultan $_srcname
  cd $_srcname

  echo "Setting version..."
  echo "-$pkgrel" > localversion.10-pkgrel
  echo "${pkgbase#linux}" > localversion.20-pkgname

  local src
  for src in "${source[@]}"; do
    src="${src%%::*}"
    # Skip nvidia patches
    [[ "$src" == "${_patchsource}"/misc/nvidia/*.patch ]] && continue
    src="${src##*/}"
    src="${src%.zst}"
    [[ $src = *.patch ]] || continue
    echo "Applying patch $src..."
    patch -Np1 < "../$src"
  done

  echo "Setting config..."
  make archlinux_defconfig -j4 "${BUILD_FLAGS[@]}"

  make -s kernelrelease > version
  echo "Prepared $pkgbase version $(<version)"

  echo "Setting performance governor..."
  scripts/config -d CPU_FREQ_DEFAULT_GOV_SCHEDUTIL \
      -e CPU_FREQ_DEFAULT_GOV_PERFORMANCE

  echo "Enabling KBUILD_CFLAGS -O3..."
  scripts/config -d CC_OPTIMIZE_FOR_PERFORMANCE \
      -e CC_OPTIMIZE_FOR_PERFORMANCE_O3

  echo "Selecting lazy preempt type..."
  scripts/config -e PREEMPT_DYNAMIC -d PREEMPT -d PREEMPT_VOLUNTARY \
      -e PREEMPT_LAZY -d PREEMPT_NONE

  echo "Selecting thin LLVM level..."
  scripts/config -e LTO_CLANG_THIN

  echo "Selecting madvise TRANSPARENT_HUGEPAGE config..."
  scripts/config -d TRANSPARENT_HUGEPAGE_ALWAYS -e TRANSPARENT_HUGEPAGE_MADVISE

  echo "Optimizing CPU automatically..."
  "${srcdir}"/auto-cpu-optimization.sh

  echo "Configuring Nvidia Modules..."
  cd "${srcdir}"
  rm -rf "${_nv_pkg}"
  sh "${_nv_pkg}.run" --extract-only

  # Use fbdev and modeset as default
  patch -Np1 -i "${srcdir}/0001-Enable-atomic-kernel-modesetting-by-default.patch" -d "${srcdir}/${_nv_pkg}/kernel"

}

build() {
  cd $_srcname

  make all -j4 "${BUILD_FLAGS[@]}"
  local MODULE_FLAGS=(
      SYSSRC="${srcdir}/${_srcname}"
      SYSOUT="${srcdir}/${_srcname}"
  )
  MODULE_FLAGS+=(NV_EXCLUDE_BUILD_MODULES='__EXCLUDE_MODULES')
  cd "${srcdir}/${_nv_pkg}/kernel"
  make "${BUILD_FLAGS[@]}" "${MODULE_FLAGS[@]}" -j"$(nproc)" modules
}

_package() {
  pkgdesc="The $pkgdesc kernel and modules"
  depends=('coreutils' 'initramfs' 'kmod')
  optdepends=(
    'wireless-regdb: to set the correct wireless channels of your country'
    'linux-firmware: firmware images needed for some devices'
    'scx-scheds: to use sched-ext schedulers'
  )
  provides=('KSMBD-MODULE' 'VIRTUALBOX-GUEST-MODULES' 'WIREGUARD-MODULE')
  replaces=(wireguard-lts)

  cd $_srcname
  local modulesdir="$pkgdir/usr/lib/modules/$(<version)"

  echo "Installing boot image..."
  # systemd expects to find the kernel here to allow hibernation
  # https://github.com/systemd/systemd/commit/edda44605f06a41fb86b7ab8128dcf99161d2344
  install -Dm644 "$(make -s image_name)" "$modulesdir/vmlinuz"

  # Used by mkinitcpio to name the kernel
  echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"

  echo "Installing modules..."
  make INSTALL_MOD_PATH="$pkgdir/usr" INSTALL_MOD_STRIP=1 \
    DEPMOD=/doesnt/exist modules_install  # Suppress depmod

  # remove build link
  rm "$modulesdir"/build

  # licenses
  install -vDm 644 LICENSES/deprecated/{GPL-1.0,ISC,Linux-OpenIB,X11,Zlib} -t "$pkgdir/usr/share/licenses/$pkgname/"
  install -vDm 644 LICENSES/preferred/{BSD,MIT}* -t "$pkgdir/usr/share/licenses/$pkgname/"
  install -vDm 644 LICENSES/exceptions/* -t "$pkgdir/usr/share/licenses/$pkgname/"
}

_package-headers() {
  pkgdesc="Headers and scripts for building modules for the $pkgdesc kernel"
  depends=(pahole)

  cd $_srcname
  local builddir="$pkgdir/usr/lib/modules/$(<version)/build"

  echo "Installing build files..."
  install -Dt "$builddir" -m644 .config Makefile Module.symvers System.map \
    localversion.* version vmlinux
  install -Dt "$builddir/kernel" -m644 kernel/Makefile
  install -Dt "$builddir/arch/x86" -m644 arch/x86/Makefile
  cp -t "$builddir" -a scripts
  ln -srt "$builddir" "$builddir/scripts/gdb/vmlinux-gdb.py"

  # required when STACK_VALIDATION is enabled
  install -Dt "$builddir/tools/objtool" tools/objtool/objtool

  echo "Installing headers..."
  cp -t "$builddir" -a include
  cp -t "$builddir/arch/x86" -a arch/x86/include
  install -Dt "$builddir/arch/x86/kernel" -m644 arch/x86/kernel/asm-offsets.s

  install -Dt "$builddir/drivers/md" -m644 drivers/md/*.h
  install -Dt "$builddir/net/mac80211" -m644 net/mac80211/*.h

  # https://bugs.archlinux.org/task/13146
  install -Dt "$builddir/drivers/media/i2c" -m644 drivers/media/i2c/msp3400-driver.h

  # https://bugs.archlinux.org/task/20402
  install -Dt "$builddir/drivers/media/usb/dvb-usb" -m644 drivers/media/usb/dvb-usb/*.h
  install -Dt "$builddir/drivers/media/dvb-frontends" -m644 drivers/media/dvb-frontends/*.h
  install -Dt "$builddir/drivers/media/tuners" -m644 drivers/media/tuners/*.h

  # https://bugs.archlinux.org/task/71392
  install -Dt "$builddir/drivers/iio/common/hid-sensors" -m644 drivers/iio/common/hid-sensors/*.h

  echo "Installing KConfig files..."
  find . -name 'Kconfig*' -exec install -Dm644 {} "$builddir/{}" \;

  echo "Removing unneeded architectures..."
  local arch
  for arch in "$builddir"/arch/*/; do
    [[ $arch = */x86/ ]] && continue
    echo "Removing $(basename "$arch")"
    rm -r "$arch"
  done

  echo "Removing documentation..."
  rm -r "$builddir/Documentation"

  echo "Removing broken symlinks..."
  find -L "$builddir" -type l -printf 'Removing %P\n' -delete

  echo "Removing loose objects..."
  find "$builddir" -type f -name '*.o' -printf 'Removing %P\n' -delete

  echo "Stripping build tools..."
  local file
  while read -rd '' file; do
    case "$(file -Sib "$file")" in
      application/x-sharedlib\;*)      # Libraries (.so)
        strip -v $STRIP_SHARED "$file" ;;
      application/x-archive\;*)        # Libraries (.a)
        strip -v $STRIP_STATIC "$file" ;;
      application/x-executable\;*)     # Binaries
        strip -v $STRIP_BINARIES "$file" ;;
      application/x-pie-executable\;*) # Relocatable binaries
        strip -v $STRIP_SHARED "$file" ;;
    esac
  done < <(find "$builddir" -type f -perm -u+x ! -name vmlinux -print0)

  echo "Stripping vmlinux..."
  strip -v $STRIP_STATIC "$builddir/vmlinux"

  echo "Adding symlink..."
  mkdir -p "$pkgdir/usr/src"
  ln -sr "$builddir" "$pkgdir/usr/src/$pkgbase"

  # licenses
  install -vDm 644 LICENSES/deprecated/{ISC,Linux-OpenIB,X11,Zlib} -t "$pkgdir/usr/share/licenses/$pkgname/"
  install -vDm 644 LICENSES/preferred/{BSD*,MIT} -t "$pkgdir/usr/share/licenses/$pkgname/"
  install -vDm 644 LICENSES/exceptions/* -t "$pkgdir/usr/share/licenses/$pkgname/"
}

_package-nvidia(){
    pkgdesc="nvidia module of ${_nv_ver} driver for the ${pkgbase} kernel"
    depends=("$pkgbase=$_kernver" "nvidia-utils=${_nv_ver}" "libglvnd")
    provides=('NVIDIA-MODULE')
    conflicts=("$pkgbase-nvidia-open")
    license=('custom')

    cd "$_srcname"
    local modulesdir="$pkgdir/usr/lib/modules/$(<version)"

    cd "${srcdir}/${_nv_pkg}"
    install -dm755 "${modulesdir}"
    install -m644 kernel/*.ko "${modulesdir}"
    install -Dt "$pkgdir/usr/share/licenses/${pkgname}" -m644 LICENSE
}

pkgname=(
  "$pkgbase"
  "$pkgbase-headers"
  "$pkgbase-nvidia"
)

for _p in "${pkgname[@]}"; do
  eval "package_$_p() {
    $(declare -f "_package${_p#$pkgbase}")
    _package${_p#$pkgbase}
  }"
done

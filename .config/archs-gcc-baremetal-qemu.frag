{
 "sources": {
    "arc-gnu-toolchain": {
      "repo": "https://github.com/foss-for-synopsys-dwc-arc-processors/arc-gnu-toolchain.git"
    },
    "arc-gcc": {
      "repo": "https://github.com/foss-for-synopsys-dwc-arc-processors/gcc.git",
      "branch": "arc64"
    }
  },
  "tasks": {
    "archs-gcc-baremetal-qemu": {
      "description": "This task runs the GCC testsuite for ARCHS CPU for Baremetal Applications (arc-elf32-gcc) using QEMU (qemu-system-arc) as emulator.",
      "pre_condition": [
        "test -d $var(@SOURCE)/arc-gnu-toolchain/.git",
        "test -d $var(@SOURCE)/arc-gcc/.git",
        "which arc-elf32-gcc",
        "which qemu-system-arc",
        "which runtest"
      ],
      "execute": [
        "cp -r $var(@CONFIG_SOURCE_PATH)/parallel/m2 $var(@WORKSPACE)",
        "erb target_alias=arc-elf32 $var(@WORKSPACE)/m2/config-make.erb > $var(@WORKSPACE)/m2/config-make",
        "erb workspace=$var(@WORKSPACE) gcc_dir=$var(@SOURCE)/arc-gcc target_triplet=arc-unknown-elf32 target_alias=arc-elf32 toolchain_install_dir=$(dirname $(which arc-elf32-gcc))/../ hostcflags='' hostcxxflags='' plugincflags='' $var(@CONFIG_SOURCE_PATH)/parallel/site.exp.erb > site.exp",
        "$var(@CONFIG_SOURCE_PATH)/parallel/configure --with-gcc=$var(@SOURCE)/arc-gcc --with-target-alias=arc-elf32 --with-target-triplet=arc-unknown-elf32",
        "PATH=$var(@SOURCE)/arc-gnu-toolchain/scripts/wrapper/qemu/:$PATH DEJAGNU_SIM_OPTIONS='-Wq,-semihosting' DEJAGNU=$var(@SOURCE)/arc-gnu-toolchain/dejagnu/site.exp QEMU_CPU=archs make check -j$var(NJOBS) RUNTESTFLAGS=\"--target_board=arc-sim --ignore 'plugin.exp gcov.exp'\"",
        "cp $var(@WORKSPACE)/testsuite/gcc/gcc.sum $var(@WORKSPACE)/testsuite/gcc/gcc.log $var(@PERSISTENT_WS)",
        "cp $var(@WORKSPACE)/testsuite/g++/g++.sum $var(@WORKSPACE)/testsuite/g++/g++.log $var(@PERSISTENT_WS)",
        "ruby $var(@CONFIG_SOURCE_PATH)/scripts/versions.rb -p $var(@SOURCE)/arc-gcc -n gcc > $var(@WORKSPACE)/gcc.json",
        "ruby $var(@CONFIG_SOURCE_PATH)/scripts/versions.rb -p $var(@SOURCE)/arc-gnu-toolchain > $var(@WORKSPACE)/arc-gnu-toolchain.json",
        "cp $(dirname $(which arc-elf32-gcc))/../archs-gcc-baremetal.json $var(@WORKSPACE)/ || ruby $var(@CONFIG_SOURCE_PATH)/scripts/version_check.rb gcc \"$(arc-elf32-gcc -v 2>&1)\" > $var(@WORKSPACE)/archs-gcc-baremetal.json",
        "cp $(dirname $(which qemu-system-arc))/../qemu.json $var(@WORKSPACE)/ || ruby $var(@CONFIG_SOURCE_PATH)/scripts/version_check.rb qemu \"$(qemu-system-arc --version)\" > $var(@WORKSPACE)/qemu.json",
        "cp $(dirname $(which runtest))/../dejagnu.json $var(@WORKSPACE) || ruby $var(@CONFIG_SOURCE_PATH)/scripts/version_check.rb dejagnu \"$(runtest --version)\" > $var(@WORKSPACE)/dejagnu.json"
      ],
      "publish_header": [
        "cat $var(@WORKSPACE)/archs-gcc-baremetal.json",
        "cat $var(@WORKSPACE)/arc-gnu-toolchain.json",
        "cat $var(@WORKSPACE)/gcc.json",
        "cat $var(@WORKSPACE)/qemu.json",
        "cat $var(@WORKSPACE)/dejagnu.json"
      ],
      "comparator": "ruby $var(@CONFIG_SOURCE_PATH)/scripts/compare.rb -t $var(@BUILDNAME) -f gcc.sum $var(@OPTIONS)",
      "report": "$var(@SOURCE)/arc-gnu-toolchain/scripts/testsuite-filter newlib $var(@SOURCE)/arc-gnu-toolchain/test/allowlist/gcc/archs/gcc.json $(find $var(@WORKSPACE)/testsuite -name *.sum |paste -sd ',' -)"
    }
  }
}

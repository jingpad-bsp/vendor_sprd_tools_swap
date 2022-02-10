#!/bin/bash

build_version=''
build_user=''
build_date=''
PARA="_para"
PROP="_prop"
CONFIG="_config"

readonly results_dir="./summary_results"
config_path=""

mem_configs=(
CONFIG_ANDROID_LOW_MEMORY_KILLER
CONFIG_OOM_NOTIFIER
CONFIG_MULTIPLE_OOM_KILLER
CONFIG_ANDROID_LOW_MEMORY_KILLER_MEMINFO
CONFIG_E_SHOW_MEM
CONFIG_LOWMEM_NOTIFY_KOBJ
CONFIG_MEMCG
CONFIG_PSI
CONFIG_KSM
CONFIG_PROCESS_RECLAIM
CONFIG_SCAN_BALANCE_ANON_FILE
CONFIG_DIRECT_SWAPPINESS
CONFIG_ZRAM
CONFIG_COMPACTION
CONFIG_SLUB_DEBUG
CONFIG_SLUB_DEBUG_ON
CONFIG_ENHANCE_SMAPS_INFO
CONFIG_DEBUG_KMEMLEAK
)

mem_feature_check=(
"lmk"
"psi"
"emem"
"zram"
"direct_swappiness"
)

get_para() {
    local para=$(adb shell cat $1)
    echo "$1: $para"
}

get_prop() {
    local prop=$(adb shell getprop |grep "\[$1\]")
    if [[ -z $prop ]]; then
	echo "[$1]: NOT SET"
    else
	echo "$prop"
    fi

}

get_value() {
    local value=$(adb shell cat $1 |grep $2)
    if [[ -z $value ]]; then
	echo "[$2] : NOT FOUND"
    else
	echo "$value"
    fi
}

mem_info() {
    get_prop    \
	"ro.boot.ddrsize"
    get_prop	\
	"ro.config.low_ram"
    get_prop	\
	"ro.config.per_app_memcg"
    get_prop	\
	"ro.lmk.use_minfree_levels"
    get_prop	\
	"sys.lmk.minfree_levels"
    get_prop	\
	"ro.lmk.vmpressurenhanced"
    get_para	\
	"/proc/sys/vm/extra_free_kbytes"
    get_para	\
	"/proc/sys/vm/swappiness"
}

lmk_config="CONFIG_ANDROID_LOW_MEMORY_KILLER"
lmk() {
    get_prop	\
	"sys.lmk.autocalc"
    get_para	\
	 "/sys/module/lowmemorykiller/parameters/adj"
    get_para	\
	 "/sys/module/lowmemorykiller/parameters/minfree"
    get_para	\
	"/sys/module/lowmemorykiller/parameters/enable_adaptive_lmk"
}

psi_config="CONFIG_PSI"
psi() {
    get_prop	\
	"ro.lmk.use_psi"
    get_prop	\
	"ro.lmk.medium_some_threshold"
    get_prop	\
	"ro.lmk.critical_full_threshold"
}

emem_config="CONFIG_E_SHOW_MEM"
emem() {
    get_para	\
	"/sys/module/emem/parameters/enable"
}

zram_config="CONFIG_ZRAM"
zram() {
    get_para	\
	"/sys/block/zram0/comp_algorithm"
    get_value	\
	"/proc/meminfo"	\
	"SwapTotal"
}

direct_swappiness_config="CONFIG_DIRECT_SWAPPINESS"
direct_swappiness() {
    get_para	\
	"/proc/sys/vm/direct_swappiness"
}

ppr_config="CONFIG_PROCESS_RECLAIM"
ppr() {
    get_para	\
	"/sys/module/process_reclaim/parameters/enable_process_reclaim"
}


usage() {
    cat <<EOF
    Usage:
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]];do
	case "$1" in
	    -h|--help)
		usage
		exit 0
		;;
	    *)
		echo "Unknow option $1"
		usage
		exit 1
		;;
	esac
    done
}

get_device_info() {
    #get build version
    build_version=$(adb shell getprop "ro.build.fingerprint"|cut -d '/' -f 2)

    build_user=$(adb shell getprop "ro.build.fingerprint"|cut -d '/' -f 5|cut -d ':' -f 2)

    #get build data
    build_date=$(adb shell getprop |grep "ro.build.date]"|cut -d ']' -f 2|cut -d '[' -f 2|tr ' ' '-')

    echo "============= device info ==================== "
    echo "$build_version-$build_user($build_date)"
    echo "============================================== "
}

get_mem_config() {
    if ! mkdir -p "$results_dir"; then
	echo >&2 "Unable to kernel result directory: $results_dir"
	exit 1
    fi

    config_path="$results_dir/kernel-config.txt"
    adb shell cat /proc/config.gz | gunzip > "$config_path"

    echo "===============  memory config  ============= "
    for config in ${mem_configs[@]};do
	if (grep -iq "$config=" "$config_path"); then
	    echo "$config : Y"
	else
	    echo "$config : N"
	fi
    done
    echo "============================================== "
}

get_mem_func_para() {
    echo "==============  memory func para  ============ "
    for func in ${mem_feature_check[@]};do
	local config
	eval config=\$$func$CONFIG
	if (grep -iq "$config=" "$config_path"); then
	    echo "----------------  $func para "
	    $func
	fi
    done
    echo "============================================== "
}

get_mem_basic_info() {
    echo "================  memory info  =============== "
    mem_info
    echo "============================================== "
}

main() {
    parse_arguments "$@"
    adb root >/dev/null 2>&1
    sleep 1
    adb remount >/dev/null 2>&1
    get_device_info
    get_mem_basic_info
    get_mem_config
    get_mem_func_para
}

main "$@"

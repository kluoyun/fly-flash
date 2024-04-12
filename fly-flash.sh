#!/bin/bash

###########################################################
#*                    fly flash tool                     *#
#*     The ownership of this file belongs to Mellow      *#
#*                                                       *#
#*                 DO NOT EDIT THIS FILE                 *#
#*                                                       *#
###########################################################

# @file   fly-flash
# @author Mellow(Xiaok) (https://github.com/Mellow-3D)
# Created Date: 19-07-2023
# -----
# Last Modified: 12-04-2024
# Modified By: Xiaok
# -----
# @copyright (c) 2022 Mellow

VERSION="v0.0.5"

BASE_USER="fly"

G_EXPORT="/sys/class/gpio/export"
V3_RST="100" #PD4
V3_BT1="98"  #PD2

C8_RST="143" #PE15
C8_BT1="142" #PE14

RST="-1"
BT1="-1"

loge() {
    echo -e "\033[34m[${1}]\033[0m: \033[31m${2}\033[0m"
}
logi() {
    echo -e "\033[34m[${1}]\033[0m: \033[32m${2}\033[0m"
}
handle_error() {
    loge EN "Error occurred! Exiting..."
    loge CN "出现错误! 正在退出..."
    exit 1
}
trap 'handle_error' ERR

if [[ -z "${SUDO_USER}" ]] && [[ "$(whoami)" != "root" ]]; then
    loge EN "Requires \"sudo \" privileges"
    loge CN "请使用\"sudo \"权限执行"
    exit 1
fi

uid=$(id -u)
if [ $uid -ne 0 ]; then
    loge EN "The current user does not have root permissions"
    loge CN "当前用户没有root权限"
    exit 1
fi

if [ ! -f "$G_EXPORT" ]; then
    loge EN "The system does not support"
    loge CN "系统不支持"
    exit 1
fi

KP_DIR="/home/${BASE_USER}/klipper"
if [ ! -d "${KP_DIR}" ]; then
    loge EN "No installed Klipper found"
    loge CN "没有找到已安装的Klipper"
    exit 1
fi

KP_ENV_DIR="/home/${BASE_USER}/klippy-env"
if [ ! -d "${KP_DIR}" ]; then
    loge EN "No installed Klipper virtual environment found"
    loge CN "没有找到已安装的Klipper虚拟环境"
    exit 1
fi
KPYTHON="${KP_ENV_DIR}/bin/python"

HIDFLASH="${KP_DIR}/lib/hidflash/hid-flash"
if [ ! -e "$HIDFLASH" ]; then
    cd "${KP_DIR}/lib/hidflash"
    make >/dev/null
    cp -rf $HIDFLASH /bin/hid-flash
    sudo chmod -R 777 /bin/hid-flash
fi
if [ ! -e "/bin/hid-flash" ]; then
    cd "${KP_DIR}/lib/hidflash"
    make >/dev/null
    cp -rf $HIDFLASH /bin/hid-flash
    sudo chmod 777 /bin/hid-flash
fi

init() {
    G_RST="/sys/class/gpio/gpio${RST}"
    G_BOOT1="/sys/class/gpio/gpio${BT1}"
    if [ ! -d "${G_RST}" ]; then
        echo "${RST}" >$G_EXPORT
    # else
    #     echo "GPIO(RST)已经存在"
    fi

    if [ ! -d "${G_BOOT1}" ]; then
        echo "${BT1}" >$G_EXPORT
    # else
    #     echo "GPIO(BT1)已经存在"
    fi

    echo "out" >"${G_RST}/direction"
    echo "out" >"${G_BOOT1}/direction"
}

RST_LOW() {
    echo "0" >"${G_RST}/value"
}

RST_HIGH() {
    echo "1" >"${G_RST}/value"
}

BOOT1_LOW() {
    echo "0" >"${G_BOOT1}/value"
}

BOOT1_HIGH() {
    echo "0" >"${G_BOOT1}/value"
}

reset() {
    logi EN "Reset MCU"
    logi CN "重置MCU"
    RST_LOW
    sleep 0.2
    RST_HIGH

    sleep 0.2

    logi EN "Reset Done"
    logi EN "重置成功"
}

hid() {
    logi EN "Enable HID mode"
    logi CN "启用HID模式"
    BOOT1_HIGH

    sleep 0.1

    reset

    sleep 0.5
    logi EN "Looking for HID device. . ."
    logi CN "正在查找HID设备。。。"
    for i in {1..6}; do
        device_info=$(lsusb | grep "1209:beba")
        if [ -z "$device_info" ]; then
            if [ $i -gt 5 ]; then
                loge EN "HID device not found"
                loge CN "找不到HID设备"
                exit 1
            fi
            loge EN "Failed to query the HID device for the ${i} time"
            loge CN "第${i}次查询HID设备失败"
            sleep 1
            continue
        else
            break
        fi
    done
    logi EN "Has entered HID mode"
    logi CN "已进入HID模式"
}

dfu() {
    logi EN "Enable DFU mode"
    logi CN "启用DFU模式"
    BOOT1_LOW

    sleep 0.1

    logi EN "To enter DFU mode, you need to manually press the \"BT0 button\" or use a jumper cap to short-circuit the BT0 pin header\n \
      Please press and hold the \"BT0 button\" and don't let go and then\n\
      Please press Enter or any key to continue (CTRL+C to exit):"
    logi CN "进入DFU模式需要手动按\"BT0按键\"或使用跳线帽短接BT0排针\n \
      请按住\"BT0按键\"不要松开然后\n\
      请按回车键或任意键继续(CTRL+C 退出):"
    read -n 1
    reset

    sleep 0.2
    logi EN "You can now release the button and the DFU device is being queried. . ."
    logi CN "现在可以松开按键，正在查询DFU设备。。。"
    for i in {1..6}; do
        device_info=$(lsusb | grep "0483:df11")
        if [ -z "$device_info" ]; then
            if [ $i -gt 5 ]; then
                loge EN "DFU device not found. Your device does not support DFU mode or you did not press BT0"
                loge CN "没有找到DFU设备，您的设备不支持DFU模式或您没有按BT0"
                exit 1
            fi
            loge EN "Failed to query the DFU device for the ${i} time"
            loge CN "第${i}次查询DFU设备失败"
            sleep 1
            continue
        else
            break
        fi
    done
    logi EN "Has entered DFU mode"
    logi CN "已进入DFU模式"
}

katapult_usb() {
    logi EN "Enable Katapult usb mode"
    logi CN "启用Katapult usb模式"

    BOOT1_HIGH

    RST_LOW
    sleep 0.1
    RST_HIGH
    sleep 0.1
    RST_LOW
    sleep 0.1
    RST_HIGH

    BOOT1_LOW

    sleep 0.2
    logi EN "Querying for Katapult devices. . ."
    logi CN "正在查询Katapult设备。。。"
    for i in {1..6}; do
        device_info=$(lsusb | grep "1d50:6177")
        if [ -z "$device_info" ]; then
            if [ $i -gt 5 ]; then
                loge EN "Katapult device not found, your device may not have pre-burned Katapult USB firmware"
                loge CN "没有找到Katapult设备，您的设备可能没有预烧录Katapult USB固件"
                exit 1
            fi
            loge EN "Failed to query the DFU device for the ${i} time"
            loge CN "第${i}次查询Katapult设备失败"
            sleep 1
            continue
        else
            break
        fi
    done
    logi EN "Has entered Katapult USB mode"
    logi CN "已进入Katapult USB模式"
}

start() {
    logi EN "Disable HID mode"
    logi CN "禁用HID模式"
    BOOT1_LOW

    sleep 0.1

    reset
}

flash() {
    flash_mode=$1
    filepath=$2
    if [ -z "$filepath" ]; then
        filepath="/home/fly/klipper/out/klipper.bin"
    fi
    if [ -z "$ADDRESS" ]; then
        ADDRESS="0x08000000"
    fi

    if [ ! -e "$filepath" ]; then
        loge EN "Firmware file: ${filepath} does not exist, please compile the firmware first"
        loge CN "固件文件: ${filepath} 不存在，请先编译固件"
        exit 1
    fi

    logi EN "use [${flash_mode}] Flash firmware file:${filepath}"
    logi CN "使用 [${flash_mode}] 烧录固件:${filepath}"

    if [ "${flash_mode}" == "hid" ]; then
        hid

        sleep 0.1
        logi EN "Start HID flash"
        logi CN "开始HID烧录"
        hid-flash $filepath
    elif [ "${flash_mode}" == "dfu" ]; then
        dfu

        sleep 0.1
        logi EN "Start DFU flash"
        logi CN "开始DFU烧录"
        sudo dfu-util -a 0 -d 0483:df11 --dfuse-address $ADDRESS -D $filepath
    elif [ "${flash_mode}" == "katapult" ]; then
        katapult_usb

        sleep 0.1

        KA_DIR="/home/${BASE_USER}/katapult"
        if [ ! -d "${KP_DIR}" ]; then
            loge EN "No installed Katapult found"
            loge CN "没有找到已安装的Katapult"
            exit 1
        fi

        katapult_device=$(ls /dev/serial/by-id/* | grep usb-katapult | awk 'NR==1')
        if [ $? -ne 0 ]; then
            loge EN "No available katapult usb device found"
            loge CN "没有找到可用的katapult usb设备"
            exit 1
        fi

        KA_FLASHTOOL="${KA_DIR}/scripts/flashtool.py"

        logi EN "Start Katapult USB flash: [$katapult_device]"
        logi CN "开始Katapult USB烧录: [$katapult_device]"

        sudo $KPYTHON $KA_FLASHTOOL -d $katapult_device -f $filepath
    else
        loge EN "Unsupported flash mode: ${flash_mode}"
        loge CN "不支持的烧录模式：${flash_mode}"
        exit 1
    fi

    sleep 0.2

    start
}

help() {
    echo "fly-flash $VERSION"
    echo "fly-flash -d <device> -a <address> <-h,-s,-r,-u,-k> -f <firmware file>"
    echo "  -d  [required]  Target motherboard model"
    echo "  -h  [optional]  Boot MCU into HID mode"
    echo "  -u  [optional]  Boot MCU into DFU mode"
    echo "  -k  [optional]  Boot MCU into Katapult mode"
    echo "  -s  [optional]  Let the MCU start normally"
    echo "  -r  [optional]  Restart MCU"
    echo "  -a  <address>  [optional]  DFU mode burning firmware address, default 0x08000000"
    echo "  -f  <firmware> [optional]  Burn firmware to MCU, default /home/fly/klipper/out/klipper.bin"
    echo "  --help          help information"
    echo "  --version       Version Information"
    echo "Example: sudo fly-flash -d c8 -h -f"
    echo "Example: sudo fly-flash -d c8 -u -f ./hid_bootloader.bin"
    logi EN "When using -f to burn, you must have either -h or -u parameter to specify the burning mode."
    logi CN "使用-f烧录时，必须有-h或-u或-k任意一个参数来指定烧录模式"
}

long_options="help,version"
while getopts ":a:f:d:hrsuk-" opt; do
    case $opt in
    -)
        [ $OPTIND -ge 1 ] && optind=$(expr $OPTIND - 1) || optind=$OPTIND
        eval OPTION="\$$optind"
        OPTARG=$(echo $OPTION | cut -d'=' -f2)
        OPTION=$(echo $OPTION | cut -d'=' -f1)
        case $OPTION in
        --help)
            help
            exit 0
            ;;
        --version)
            echo "fly-flash ${VERSION}"
            exit 0
            ;;
        \?)
            help
            exit 1
            ;;
        esac
        ;;
    d)
        DEVICE=$OPTARG
        ;;
    h)
        MM="hid"
        FD="hid"
        ;;
    r)
        MM="reset"
        ;;
    s)
        MM="start"
        ;;
    u)
        MM="dfu"
        FD="dfu"
        ;;
    k)
        MM="katapult"
        FD="katapult"
        ;;
    a)
        ADDRESS=$OPTARG
        ;;
    f)
        FILE=$OPTARG
        MM="flash"
        ;;
    \?)
        loge EN "Invalid option: -$OPTARG" >&2
        loge CN "无效选项: -$OPTARG" >&2
        help
        exit 1
        ;;
    :)
        if [ "${OPTARG}" == "f" ] && [ "${FILE}" == "" ]; then
            FILE="${KP_DIR}/out/klipper.bin"
            MM="flash"
        elif [ "${OPTARG}" == "a" ] && [ "${ADDRESS}" == "" ]; then
            ADDRESS="0x08000000"
        else
            loge EN "Option -$OPTARG requires an argument." >&2
            loge CN "选项 -$OPTARG 需要参数" >&2
            help
            exit 1
        fi
        ;;
    esac
done

if [ "${DEVICE}" == "auto" ]; then
    CMD_BOARD=$(grep -oP '(?<=board=)[^ ]*' /proc/cmdline)
    if [[ $CMD_BOARD == "" ]] || [[ $CMD_BOARD == "none" ]]; then
        loge EN "Automatic detection of device model failed"
        loge CN "自动探测设备型号失败"
        exit 1
    fi
    DEVICE=${CMD_BOARD}
fi

if [ "${DEVICE}" == "gemini-v3" ] || [ "${DEVICE}" == "fly-gemini-v3" ]; then
    logi EN "Device: FLY-Gemini v3"
    logi CN "设备: FLY-Gemini v3"
    RST=$V3_RST
    BT1=$V3_BT1
    init
elif [ "${DEVICE}" == "c8" ] || [ "${DEVICE}" == "fly-c8" ]; then
    logi EN "Device: FLY-C8"
    logi CN "设备: FLY-C8"
    RST=$C8_RST
    BT1=$C8_BT1
    init
else
    logi EN "Unsupported device: ${DEVICE} !!! \n\
      Please include device model parameters -d. \n\
      for example: \n\
          sudo fly-flash -d gemini-v3 \n\
          sudo fly-flash -d c8\n"
    logi CN "不支持的设备: ${DEVICE} !!! \n\
      请包含设备型号参数 -d \n\
      比如: \n\
          sudo fly-flash -d gemini-v3 \n\
          sudo fly-flash -d c8"
    exit 1
fi

if [ "${MM}" == "start" ]; then
    start
elif [ "${MM}" == "hid" ]; then
    hid
elif [ "${MM}" == "reset" ]; then
    reset
elif [ "${MM}" == "dfu" ]; then
    dfu
elif [ "${MM}" == "katapult" ]; then
    katapult_usb
elif [ "${MM}" == "flash" ]; then
    if [ "${FILE}" == "" ]; then
        FILE="${KP_DIR}/out/klipper.bin"
    fi
    flash $FD $FILE
else
    loge EN "Unsupported parameters: ${MM} !!!"
    loge CN "不支持的操作: ${MM} !!!"
    exit 1
fi

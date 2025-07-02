#!/bin/bash

#
# 一个用于简化 supergfxctl 模式切换的脚本
# 版本 2.0: 增加了 status 检查功能
#

# 检查 supergfxctl 是否可用
if ! command -v supergfxctl &> /dev/null; then
    echo "错误：未找到 'supergfxctl' 命令。"
    echo "请确保 asus-linux 系列工具已正确安装。"
    exit 1
fi

# 用法说明函数
usage() {
    echo "一个简化的 supergfxctl 控制脚本"
    echo "---------------------------------"
    echo "用法: $(basename "$0") [命令]"
    echo
    echo "可用命令:"
    echo "  amd      - 切换到 Integrated 模式 (集成显卡)"
    echo "  mix      - 切换到 Hybrid 模式 (混合模式)"
    echo "  nv       - 切换到 AsusMuxDgpu 模式 (NVIDIA 独显)"
    echo "  status   - 检查并显示当前的显卡模式"
    echo
    exit 1
}

# --- 主逻辑 ---

# 如果未提供参数，则显示用法说明
if [ -z "$1" ]; then
    usage
fi

# 使用 case 语句处理所有输入命令
case "$1" in
    "status")
        # supergfxctl 的 -g (--get) 选项需要 sudo 权限
        current_mode=$(sudo supergfxctl -g)
        if [ $? -ne 0 ]; then
            echo "错误: 无法获取当前显卡模式。"
            exit 1
        fi
        echo "当前显卡模式为: $current_mode"
        ;;

    "amd"|"mix"|"nv")
        # --- 切换逻辑 ---
        current_mode=$(sudo supergfxctl -g)
        if [ $? -ne 0 ]; then
            echo "错误: 无法获取当前显卡模式。请检查supergfxctl的状态。"
            exit 1
        fi

        # 将用户输入映射到 supergfxctl 的模式名称
        target_mode_long=""
        if [ "$1" == "amd" ]; then
            target_mode_long="Integrated"
        elif [ "$1" == "mix" ]; then
            target_mode_long="Hybrid"
        else
            target_mode_long="AsusMuxDgpu"
        fi

        # 检查是否已经处于目标模式
        if [ "$current_mode" == "$target_mode_long" ]; then
            echo "当前已处于 $target_mode_long 模式，无需切换。"
            exit 0
        fi

        echo "当前模式: $current_mode"
        echo "目标模式: $target_mode_long"
        echo "---------------------------------"

        # 设置新模式
        echo "正在设置模式..."
        sudo supergfxctl -m "$target_mode_long"
        if [ $? -ne 0 ]; then
            echo "错误: 设置模式失败！请检查 supergfxctl 的输出。"
            exit 1
        fi
        echo "模式已设置为 $target_mode_long。需要执行后续操作来应用更改。"
        echo

        # 根据切换规则决定是注销还是重启
        if [ "$current_mode" == "Hybrid" ] && [ "$target_mode_long" == "Integrated" ]; then
            read -p "从 Hybrid 切换到 Integrated 需要注销。是否立即注销？ (y/n): " confirm
            if [[ "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
                echo "正在注销..."
                loginctl terminate-user "$(whoami)"
            else
                echo "操作已取消。新模式将在您下次手动注销后生效。"
            fi
        else
            read -p "切换显卡模式需要重启。是否立即重启？ (y/n): " confirm
            if [[ "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
                echo "正在重启..."
                sudo reboot
            else
                echo "操作已取消。新模式将在您下次手动重启后生效。"
            fi
        fi
        ;;

    *)
        echo "错误: 无效的命令 '$1'"
        usage
        ;;
esac

exit 0

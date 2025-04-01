#!/bin/bash

# 显示用法信息
function show_usage {
    echo "用法: $0 [选项] <客户端名称>"
    echo "选项:"
    echo "  -h, --help         显示此帮助信息"
    echo "  -n, --nopass       创建没有密码的客户端证书 (默认会要求设置密码)"
    echo "  -o, --output FILE  指定输出的ovpn文件名 (默认为<客户端名称>.ovpn)"
    echo "  -v, --volume NAME  指定Docker卷名称 (默认为'ovpn-data')"
    echo
    echo "示例:"
    echo "  $0 client1                   # 创建带密码的client1客户端配置"
    echo "  $0 -n client2                # 创建无密码的client2客户端配置"
    echo "  $0 -o vpn-home.ovpn home     # 创建带密码的home客户端配置并输出到vpn-home.ovpn"
    echo "  $0 --nopass -o corp.ovpn work # 创建无密码的work客户端配置并输出到corp.ovpn"
    exit 1
}

# 设置默认值
OVPN_DATA="ovpn-data"
USE_PASS=true
OUTPUT_FILE=""
CLIENT_NAME=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            ;;
        -n|--nopass)
            USE_PASS=false
            shift
            ;;
        -o|--output)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "错误: --output 选项需要一个文件名参数"
                exit 1
            fi
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--volume)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "错误: --volume 选项需要一个卷名参数"
                exit 1
            fi
            OVPN_DATA="$2"
            shift 2
            ;;
        -*)
            echo "错误: 未知选项 $1"
            show_usage
            ;;
        *)
            if [[ -z "$CLIENT_NAME" ]]; then
                CLIENT_NAME="$1"
                shift
            else
                echo "错误: 多余的参数 $1"
                show_usage
            fi
            ;;
    esac
done

# 检查是否提供了客户端名称
if [[ -z "$CLIENT_NAME" ]]; then
    echo "错误: 必须提供客户端名称"
    show_usage
fi

# 如果未指定输出文件名，则使用默认值
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${CLIENT_NAME}.ovpn"
fi

# 验证Docker卷是否存在
if ! docker volume inspect "$OVPN_DATA" &>/dev/null; then
    echo "错误: Docker卷 '$OVPN_DATA' 不存在"
    echo "提示: 您可以使用以下命令创建卷:"
    echo "  docker volume create --name $OVPN_DATA"
    exit 1
fi

echo "=============================================="
echo "OpenVPN客户端配置生成器"
echo "=============================================="
echo "客户端名称: $CLIENT_NAME"
echo "Docker卷: $OVPN_DATA"
echo "密码保护: $([ "$USE_PASS" = true ] && echo "是" || echo "否")"
echo "输出文件: $OUTPUT_FILE"
echo "=============================================="
echo

# 创建客户端证书
echo "正在生成客户端证书..."
if [[ "$USE_PASS" = true ]]; then
    echo "您将被要求为客户端证书设置密码"
    docker run -v "$OVPN_DATA":/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full "$CLIENT_NAME"
else
    echo "创建无密码客户端证书"
    docker run -v "$OVPN_DATA":/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full "$CLIENT_NAME" nopass
fi

# 检查上一条命令是否成功
if [[ $? -ne 0 ]]; then
    echo "错误: 创建客户端证书失败"
    exit 1
fi

# 导出客户端配置
echo "正在导出客户端配置..."
docker run -v "$OVPN_DATA":/etc/openvpn --rm kylemanna/openvpn ovpn_getclient "$CLIENT_NAME" > "$OUTPUT_FILE"

# 检查导出是否成功
if [[ $? -ne 0 ]]; then
    echo "错误: 导出客户端配置失败"
    exit 1
fi

echo "成功创建客户端配置文件: $OUTPUT_FILE"
echo
echo "使用说明:"
echo "1. 将此文件安全地传输到客户端设备"
echo "2. 使用OpenVPN客户端软件导入此配置文件"
if [[ "$USE_PASS" = true ]]; then
    echo "3. 连接时将需要输入您设置的密码"
fi
echo
echo "如需撤销此客户端的访问权限，请运行:"
echo "  docker run -v $OVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_revokeclient $CLIENT_NAME"
echo "  docker restart openvpn"

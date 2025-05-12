#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/nockchain.sh"

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请以 root 权限运行此脚本 (sudo)"
    exit 1
fi

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "================================================================"
        echo "脚本由哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本，请按键盘 Ctrl + C"
        echo "请选择要执行的操作:"
        echo "1. 安装部署节点"
        echo "================================================================"
        read -p "请输入选项 (1): " choice

        case $choice in
            1)
                install_and_deploy_node
                ;;
            *)
                echo "无效选项，请输入 1"
                sleep 2
                ;;
        esac
    done
}

# 安装和部署节点函数
function install_and_deploy_node() {
    # 检查是否安装 Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo "未检测到 Docker，正在安装 Docker..."
        # 更新包索引并安装依赖
        sudo apt update
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        # 添加 Docker 的 GPG 密钥
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        # 添加 Docker 仓库
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        # 更新包索引并安装 Docker
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        # 将当前用户添加到 docker 组以避免每次使用 docker 时需要 sudo
        sudo usermod -aG docker "$USER"
        # 启用 Docker 服务并重启
        sudo systemctl enable docker
        sudo systemctl restart docker
        echo "Docker 安装成功。版本：$(docker --version)"
    else
        echo "Docker 已安装。版本：$(docker --version)"
    fi

    # 更新系统并升级软件包
    sudo apt update && sudo apt upgrade -y

    # 安装依赖，包括git、net-tools（用于端口检测）和screen
    sudo apt install -y curl build-essential git net-tools screen

    # 安装Rust环境（使用 -y 参数自动接受默认安装）
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # 配置环境变量
    # 将Cargo的二进制路径添加到~/.bashrc或~/.zshrc
    if [ -f "$HOME/.bashrc" ]; then
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
        source "$HOME/.bashrc"
    elif [ -f "$HOME/.zshrc" ]; then
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.zshrc"
        source "$HOME/.zshrc"
    else
        echo "未找到 ~/.bashrc 或 ~/.zshrc，请手动将以下内容添加到您的 shell 配置文件："
        echo 'export PATH="$HOME/.cargo/bin:$PATH"'
    fi

    # 验证Rust安装
    if command -v rustc >/dev/null 2>&1; then
        echo "Rust 安装成功。版本：$(rustc --version)"
    else
        echo "Rust 安装失败，请检查上面的输出以获取错误信息。"
        exit 1
    fi

    # 克隆nockchain仓库
    git clone https://github.com/zorp-corp/nockchain
    if [ $? -eq 0 ]; then
        echo "成功克隆 nockchain 仓库到 ./nockchain"
    else
        echo "克隆 nockchain 仓库失败，请检查网络或仓库地址。"
        exit 1
    fi

    # 进入nockchain目录
    cd nockchain || { echo "无法进入 nockchain 目录"; exit 1; }

    # 编译Hoon
    make install-choo
    if [ $? -eq 0 ]; then
        echo "成功编译 Hoon (install-choo)"
    else
        echo "编译 Hoon (install-choo) 失败，请检查上面的输出以获取错误信息。"
        exit 1
    fi

    # 编译Nockchain
    make build-hoon-all
    if [ $? -eq 0 ]; then
        echo "成功编译 Nockchain ( Stuartartsbuild-hoon-all
        make build
        if [ $? -eq 0 ]; then
            echo "成功编译 Nockchain (build)"
        else
            echo "编译 Nockchain (build) 失败，请检查上面的输出以获取错误信息。"
            exit 1
        fi

    # 将编译后的二进制路径添加到 PATH
    export PATH="$PATH:$(pwd)/target/release"
    echo "已将 $(pwd)/target/release 添加到 PATH"

    # 创建钱包并捕获公钥
    echo "正在创建钱包..."
    PUBLIC_KEY=$(wallet keygen 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$PUBLIC_KEY" ]; then
        echo "成功创建钱包，公钥：$PUBLIC_KEY"
    else
        echo "创建钱包失败 (wallet keygen)，请检查上面的输出以获取错误信息。"
        exit 1
    fi

    # 替换 Makefile 中的 export MINING_PUBKEY
    MAKEFILE="Makefile"
    if [ -f "$MAKEFILE" ]; then
        sed -i "s/export MINING_PUBKEY := .*/export MINING_PUBKEY := $PUBLIC_KEY/" "$MAKEFILE"
        if [ $? -eq 0 ]; then
            echo "成功替换 $MAKEFILE 中的 MINING_PUBKEY 为 $PUBLIC_KEY"
        else
            echo "替换 $MAKEFILE 中的 MINING_PUBKEY 失败，请检查文件内容或权限。"
            exit 1
        fi
    else
        echo "未找到 $MAKEFILE 文件，请确认包含 'export MINING_PUBKEY' 的文件路径。"
        exit 1
    fi

    # 检测端口 3005 和 3006 是否被占用，并选择可用端口
    LEADER_PORT=3005
    FOLLOWER_PORT=3006
    MAX_PORT=65535

    # 函数：检查端口是否被占用并返回可用端口
    find_available_port() {
        local port=$1
        while ss -tuln | grep -q ":$port "; do
            echo "端口 $port 已被占用，尝试下一个端口..."
            port=$((port + 1))
            if [ $port -gt $MAX_PORT ]; then
                echo "错误：无法找到可用端口（已达到 $MAX_PORT）。"
                exit 1
            fi
        done
        echo $port
    }

    # 检查并分配 leader 和 follower 端口
    LEADER_PORT=$(find_available_port $LEADER_PORT)
    echo "为 Leader 分配端口：$LEADER_PORT"
    FOLLOWER_PORT=$(find_available_port $FOLLOWER_PORT)
    echo "为 Follower 分配端口：$FOLLOWER_PORT"

    # 确保 leader 和 follower 端口不相同
    if [ $LEADER_PORT -eq $FOLLOWER_PORT ]; then
        FOLLOWER_PORT=$(find_available_port $((FOLLOWER_PORT + 1)))
        echo "Leader 和 Follower 端口冲突，已为 Follower 重新分配端口：$FOLLOWER_PORT"
    fi

    # 更新 Makefile 中的端口（假设 Makefile 中有 LEADER_PORT 和 FOLLOWER_PORT 变量）
    if [ -f "$MAKEFILE" ]; then
        # 添加或更新 LEADER_PORT 和 FOLLOWER_PORT
        if grep -q "export LEADER_PORT :=" "$MAKEFILE"; then
            sed -i "s/export LEADER_PORT := .*/export LEADER_PORT := $LEADER_PORT/" "$MAKEFILE"
        else
            echo "export LEADER_PORT := $LEADER_PORT" >> "$MAKEFILE"
        fi
        if grep -q "export FOLLOWER_PORT :=" "$MAKEFILE"; then
            sed -i "s/export FOLLOWER_PORT := .*/export FOLLOWER_PORT := $FOLLOWER_PORT/" "$MAKEFILE"
        else
            echo "export FOLLOWER_PORT := $FOLLOWER_PORT" >> "$MAKEFILE"
        fi
        echo "已更新 $MAKEFILE 中的 LEADER_PORT 为 $LEADER_PORT 和 FOLLOWER_PORT 为 $FOLLOWER_PORT"
    else
        echo "警告：未找到 $MAKEFILE，端口未更新。请手动在 make 命令中指定端口：Leader ($LEADER_PORT), Follower ($FOLLOWER_PORT)"
    fi

    # 在 screen 会话中运行 nockchain leader
    echo "在 screen 会话 'leader' 中启动 nockchain Leader..."
    screen -dmS leader bash -c "cd $(pwd) && make run-nockchain-leader"
    if [ $? -eq 0 ]; then
        echo "成功在 screen 'leader' 中启动 make run-nockchain-leader"
    else
        echo "启动 screen 'leader' 失败，请检查错误信息。"
        exit 1
    fi

    # 在 screen 会话中运行 nockchain follower
    echo "在 screen 会话 'follower' 中启动 nockchain Follower..."
    screen -dmS follower bash -c "cd $(pwd) && make run-nockchain-follower"
    if [ $? -eq 0 ]; then
        echo "成功在 screen 'follower' 中启动 make run-nockchain-follower"
    else
        echo "启动 screen 'follower' 失败，请检查错误信息。"
        exit 1
    fi

    echo "节点安装和部署完成！"
    echo "可以使用 'screen -r leader' 或 'screen -r follower' 查看运行状态。"
    read -p "按 Enter 键返回主菜单..."
}

# 启动主菜单
main_menu

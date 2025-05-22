#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/nock.sh"

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
        echo "1. 安装部署nock"
        echo "2. 备份密钥"
        echo "请输入选项 (1-2):"
        read -r choice
        case $choice in
            1)
                install_nock
                ;;
            2)
                backup_keys
                ;;
            *)
                echo "无效选项，请输入 1 或 2"
                sleep 2
                ;;
        esac
    done
}

# 安装部署nock 函数
function install_nock() {
    # 设置错误处理：任何命令失败时退出
    set -e

    # 更新系统并升级软件包
    echo "正在更新系统并升级软件包..."
    apt-get update && apt-get upgrade -y

    # 安装必要的软件包（包括 screen）
    echo "正在安装必要的软件包..."
    apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev screen -y

    # 安装 Rust
    echo "正在安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # 配置环境变量（Cargo 路径）
    echo "正在配置 Cargo 环境变量..."
    source $HOME/.cargo/env || { echo "错误：无法 source $HOME/.cargo/env，请检查 Rust 安装"; exit 1; }

    # 克隆 nockchain 仓库并进入目录
    echo "正在清理旧的 nockchain 和 .nockapp 目录..."
    rm -rf nockchain .nockapp
    echo "正在克隆 nockchain 仓库..."
    git clone https://github.com/zorp-corp/nockchain
    cd nockchain || { echo "无法进入 nockchain 目录，克隆可能失败"; exit 1; }

    # 执行 make install-hoonc
    echo "正在执行 make install-hoonc..."
    make install-hoonc || { echo "执行 make install-hoonc 失败，请检查 nockchain 仓库的 Makefile 或依赖"; exit 1; }

    # 验证 hoonc 安装
    echo "正在验证 hoonc 安装..."
    if command -v hoonc >/dev/null 2>&1; then
        echo "hoonc 安装成功，可用命令：hoonc"
    else
        echo "警告：hoonc 命令不可用，安装可能不完整。"
    fi

    # 安装节点二进制文件
    echo "正在安装节点二进制文件..."
    make build || { echo "执行 make build 失败，请检查 nockchain 仓库的 Makefile 或依赖"; exit 1; }

    # 安装钱包二进制文件
    echo "正在安装钱包二进制文件..."
    make install-nockchain-wallet || { echo "执行 make install-nockchain-wallet 失败，请检查 nockchain 仓库的 Makefile 或依赖"; exit 1; }

    # 安装 Nockchain
    echo "正在安装 Nockchain..."
    make install-nockchain || { echo "执行 make install-nockchain 失败，请检查 nockchain 仓库的 Makefile 或依赖"; exit 1; }

    # 询问用户是否创建钱包，默认继续（y）
    echo "构建完毕，是否创建钱包？[Y/n]"
    read -r create_wallet
    create_wallet=${create_wallet:-y}  # 默认值为 y
    if [[ ! "$create_wallet" =~ ^[Yy]$ ]]; then
        echo "已跳过钱包创建。"
    else
        echo "正在自动创建钱包..."
        # 执行 nockchain-wallet keygen
        if ! command -v nockchain-wallet >/dev/null 2>&1; then
            echo "错误：nockchain-wallet 命令不可用，请检查 target/release 目录或构建过程。"
            exit 1
        fi
        nockchain-wallet keygen > wallet_keys.txt || { echo "错误：nockchain-wallet keygen 执行失败"; exit 1; }
        echo "钱包密钥已保存到 wallet_keys.txt，请妥善保管！"
    fi

    # 持久化 nockchain 的 target/release 到 PATH
    echo "正在将 $(pwd)/target/release 添加到 PATH..."
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "export PATH=\"\$PATH:$(pwd)/target/release\"" "$HOME/.bashrc"; then
            echo "export PATH=\"\$PATH:$(pwd)/target/release\"" >> "$HOME/.bashrc"
            source "$HOME/.bashrc"
        fi
    elif [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "export PATH=\"\$PATH:$(pwd)/target/release\"" "$HOME/.zshrc"; then
            echo "export PATH=\"\$PATH:$(pwd)/target/release\"" >> "$HOME/.zshrc"
            source "$HOME/.zshrc"
        fi
    else
        echo "未找到 ~/.bashrc 或 ~/.zshrc，请手动添加：export PATH=\"\$PATH:$(pwd)/target/release\""
    fi

    # 复制 .env_example 到 .env
    echo "正在复制 .env_example 到 .env..."
    if [ -f ".env" ]; then
        cp .env .env.bak
        echo ".env 已备份为 .env.bak"
    fi
    if [ ! -f ".env_example" ]; then
        echo "错误：.env_example 文件不存在，请检查 nockchain 仓库。"
        exit 1
    fi
    cp .env_example .env || { echo "错误：无法复制 .env_example 到 .env"; exit 1; }

    # 提示用户输入 MINING_PUBKEY 用于 .env
    echo "请输入您的 MINING_PUBKEY（用于 .env 文件）："
    read -r public_key
    if [ -z "$public_key" ]; then
        echo "错误：未提供 MINING_PUBKEY，请重新运行脚本并输入有效的公钥。"
        exit 1
    fi

    # 更新 .env 文件中的 MINING_PUBKEY
    echo "正在更新 .env 文件中的 MINING_PUBKEY..."
    if ! grep -q "^MINING_PUBKEY=" .env; then
        echo "MINING_PUBKEY=$public_key" >> .env
    else
        sed -i "s|^MINING_PUBKEY=.*|MINING_PUBKEY=$public_key|" .env || {
            echo "错误：无法更新 .env 文件中的 MINING_PUBKEY。"
            exit 1
        }
    fi

    # 验证 .env 更新
    if grep -q "^MINING_PUBKEY=$public_key$" .env; then
        echo ".env 文件更新成功！"
    else
        echo "错误：.env 文件更新失败，请检查文件内容。"
        exit 1
    fi

    # 检查端口 3005 和 3006 是否被占用
    echo "正在检查端口 3005 和 3006 是否被占用..."
    LEADER_PORT=3005
    FOLLOWER_PORT=3006
    if command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -q ":$LEADER_PORT "; then
            echo "错误：端口 $LEADER_PORT 已被占用，请释放该端口或选择其他端口后重试。"
            exit 1
        fi
        if ss -tuln | grep -q ":$FOLLOWER_PORT "; then
            echo "错误：端口 $FOLLOWER_PORT 已被占用，请释放该端口或选择其他端口后重试。"
            exit 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tuln | grep -q ":$LEADER_PORT "; then
            echo "错误：端口 $LEADER_PORT 已被占用，请释放该端口或选择其他端口后重试。"
            exit 1
        fi
        if netstat -tuln | grep -q ":$FOLLOWER_PORT "; then
            echo "错误：端口 $FOLLOWER_PORT 已被占用，请释放该端口或选择其他端口后重试。"
            exit 1
        fi
    else
        echo "错误：未找到 ss 或 netstat 命令，无法检查端口占用。"
        exit 1
    fi
    echo "端口 $LEADER_PORT 和 $FOLLOWER_PORT 未被占用，可继续执行。"

    # 验证 nockchain 命令是否可用
    echo "正在验证 nockchain 命令..."
    if ! command -v nockchain >/dev/null 2>&1; then
        echo "错误：nockchain 命令不可用，请检查 target/release 目录或构建过程。"
        exit 1
    fi

    # 提示用户输入 mining pubkey 用于运行 nockchain
    echo "请输入用于运行 nockchain 的 mining pubkey："
    read -r mining_pubkey
    if [ -z "$mining_pubkey" ]; then
        echo "错误：未提供 mining pubkey，请重新运行脚本并输入有效的公钥。"
        exit 1
    fi

    # 提示用户输入 BTC 主网 RPC token
    echo "请输入您的 BTC 主网 RPC token："
    read -r rpc_token
    if [ -z "$rpc_token" ]; then
        echo "错误：未提供 RPC token，请重新运行脚本并输入有效的 token。"
        exit 1
    fi

    # 执行 curl 调用 BTC 主网 RPC
    echo "正在调用 BTC 主网 RPC 获取索引信息..."
    curl -X POST "https://rpc.ankr.com/btc/$rpc_token" \
         -d '{ "id": "hmm", "method": "getindexinfo", "params": [] }' > btc_index_info.json 2>&1
    if [ $? -eq 0 ]; then
        echo "成功调用 BTC 主网 RPC，结果已保存到 btc_index_info.json"
    else
        echo "错误：BTC 主网 RPC 调用失败，请检查 token 或网络连接。"
        exit 1
    fi

    # 清理现有的 miner screen 会话（避免冲突）
    echo "正在清理现有的 miner screen 会话..."
    screen -ls | grep -q "miner" && screen -X -S miner quit

    # 启动 screen 会话运行 nockchain --mining_pubkey <your_pubkey> --mine
    echo "正在启动 screen 会话 'miner' 并运行 nockchain..."
    screen -dmS miner bash -c "nockchain --mining_pubkey \"$mining_pubkey\" --mine > miner.log 2>&1 || echo 'nockchain 运行失败' >> miner_error.log; exec bash"
    if [ $? -eq 0 ]; then
        echo "screen 会话 'miner' 已启动，日志输出到 miner.log，可使用 'screen -r miner' 查看。"
    else
        echo "错误：无法启动 screen 会话 'miner'。"
        exit 1
    fi

    # 最终成功信息
    echo "所有步骤已成功完成！"
    echo "当前目录：$(pwd)"
    echo "MINING_PUBKEY（.env）已设置为：$public_key"
    echo "Mining Pubkey（运行）已设置为：$mining_pubkey"
    echo "Leader 端口：$LEADER_PORT"
    echo "Follower 端口：$FOLLOWER_PORT"
    echo "BTC 主网 RPC 调用结果已保存到 btc_index_info.json"
    echo "Nockchain 节点运行在 screen 会话 'miner' 中，日志在 miner.log，可使用 'screen -r miner' 查看。"
    if [[ "$create_wallet" =~ ^[Yy]$ ]]; then
        echo "请妥善保存 wallet_keys.txt 中的密钥信息！"
    fi
    echo "按 Enter 键返回主菜单..."
    read -r
}

# 备份密钥函数
function backup_keys() {
    # 检查 nockchain-wallet 是否可用
    if ! command -v nockchain-wallet >/dev/null 2>&1; then
        echo "错误：nockchain-wallet 命令不可用，请先运行选项 1 安装部署nock。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    fi

    # 检查 nockchain 目录是否存在
    if [ ! -d "nockchain" ]; then
        echo "错误：nockchain 目录不存在，请先运行选项 1 安装部署nock。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    fi

    # 进入 nockchain 目录
    cd nockchain || { echo "错误：无法进入 nockchain 目录"; exit 1; }

    # 执行 nockchain-wallet export-keys
    echo "正在备份密钥..."
    nockchain-wallet export-keys > nockchain_keys_backup.txt 2>&1
    if [ $? -eq 0 ]; then
        echo "密钥备份成功！已保存到 $(pwd)/nockchain_keys_backup.txt"
        echo "请妥善保管该文件，切勿泄露！"
    else
        echo "错误：密钥备份失败，请检查 nockchain-wallet export-keys 命令输出。"
        echo "详细信息见 $(pwd)/nockchain_keys_backup.txt"
    fi

    echo "按 Enter 键返回主菜单..."
    read -r
}

# 保存脚本到指定路径
echo "正在保存脚本到 $SCRIPT_PATH..."
cp "$0" "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH" || { echo "错误：无法保存脚本到 $SCRIPT_PATH"; exit 1; }

# 启动主菜单
main_menu

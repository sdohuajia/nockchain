#!/bin/bash

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
        echo "3. 查看日志"
        echo "4. 重启挖矿"
        echo "5. 查询余额"
        echo "请输入选项 (1-5):"
        read -r choice
        case $choice in
            1)
                install_nock
                ;;
            2)
                backup_keys
                ;;
            3)
                view_log
                ;;
            4)
                restart_mining
                ;;
            5)
                check_balance
                ;;
            *)
                echo "无效选项，请输入 1、2、3、4 或 5"
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

    # 设置 vm.overcommit_memory
    echo "正在设置 vm.overcommit_memory=1..."
    sudo sysctl -w vm.overcommit_memory=1 || { echo "错误：无法设置 vm.overcommit_memory=1"; exit 1; }

    # 配置环境变量（Cargo 路径）
    echo "正在配置 Cargo 环境变量..."
    source $HOME/.cargo/env || { echo "错误：无法 source $HOME/.cargo/env，请检查 Rust 安装"; exit 1; }

    # 克隆 nockchain 仓库并进入目录
    echo "正在清理旧的 nockchain 和 .nockapp 目录..."
    rm -rf nockchain .nockapp
    echo "正在克隆 nockchain 仓库..."
    git clone https://github.com/zorp-corp/nockchain
    cd nockchain || { echo "无法进入 nockchain 目录，克隆可能失败"; exit 1; }
    echo "当前目录：$(pwd)"

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

    # 执行 make install-hoonc
    echo "正在执行 make install-hoonc..."
    make install-hoonc || { echo "执行 make install-hoonc 失败，请检查 nockchain 仓库的 Makefile 或依赖"; exit 1; }
    export PATH="$HOME/.cargo/bin:$PATH"

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
    export PATH="$HOME/.cargo/bin:$PATH"

    # 安装钱包二进制文件
    echo "正在安装钱包二进制文件..."
    make install-nockchain-wallet || { echo "执行 make install-nockchain-wallet 失败，请检查 nockchain 仓库的 Makefile 或依赖"; exit 1; }
    export PATH="$HOME/.cargo/bin:$PATH"

    # 安装 Nockchain
    echo "正在安装 Nockchain..."
    make install-nockchain || { echo "执行 make install-nockchain 失败，请检查 nockchain 仓库的 Makefile 或依赖"; exit 1; }
    export PATH="$HOME/.cargo/bin:$PATH"

    # 询问用户是否创建钱包，默认继续（y）
    echo "构建完毕，是否创建钱包？[Y/n]"
    read -r create_wallet
    create_wallet=${create_wallet:-y}  # 默认值为 y
    if [[ ! "$create_wallet" =~ ^[Yy]$ ]]; then
        echo "已跳过钱包创建。"
    else
        echo "正在自动创建钱包..."
        nockchain-wallet keygen
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

    # 提示用户输入 MINING_PUBKEY 用于 .env 和运行 nockchain
    echo "请输入您的 MINING_PUBKEY（用于 .env 文件和运行 nockchain）："
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

    # 备份密钥
    echo "正在执行 nockchain-wallet export-keys..."
    nockchain-wallet export-keys > keys.export 2>&1
    if [ $? -eq 0 ]; then
        echo "密钥备份成功！已保存到 $(pwd)/keys.export"
    else
        echo "错误：密钥备份失败，请检查 nockchain-wallet export-keys 命令输出。"
        echo "详细信息见 $(pwd)/keys.export"
        exit 1
    fi

    # 导入密钥
    echo "正在执行 nockchain-wallet import-keys --input keys.export..."
    nockchain-wallet import-keys --input keys.export 2>&1
    if [ $? -eq 0 ]; then
        echo "密钥导入成功！"
    else
        echo "错误：密钥导入失败，请检查 nockchain-wallet import-keys 命令或 keys.export 文件。"
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

    # 清理现有的 miner1 screen 会话（避免冲突）
    echo "正在清理现有的 miner1 screen 会话..."
    screen -ls | grep -q "miner1" && screen -X -S miner1 quit

    # 启动 screen 会话运行 nockchain
    echo "正在创建 $HOME/nockchain/miner1 目录并进入..."
    mkdir -p miner1 && cd miner1 || { echo "错误：无法创建或进入 $HOME/nockchain/miner1 目录"; exit 1; }
    echo "当前目录：$(pwd)"

    echo "正在启动 screen 会话 'miner1' 并运行 nockchain..."
    screen -dmS miner1 bash -c "RUST_LOG=info,nockchain=info,nockchain_libp2p_io=info,libp2p=info,libp2p_quic=info \
    MINIMAL_LOG_FORMAT=true \
    nockchain --mining-pubkey \"$public_key\" --mine > miner1.log 2>&1 || echo 'nockchain 运行失败' >> miner_error.log; exec bash"
    if [ $? -eq 0 ]; then
        echo "screen 会话 'miner1' 已启动，日志输出到 $HOME/nockchain/miner1/miner1.log，可使用 'screen -r miner1' 查看。"
        # 等待片刻以确保日志写入
        sleep 5
        # 检查并显示 miner1.log 内容
        if [ -f "miner1.log" ]; then
            echo "以下是 miner1.log 的内容："
            echo "----------------------------------------"
            cat miner1.log
            echo "----------------------------------------"
        else
            echo "警告：miner1.log 文件尚未生成，可能 nockchain 尚未开始写入日志。"
            echo "请稍后使用 'screen -r miner1' 或选项 3 查看日志。"
        fi
    else
        echo "错误：无法启动 screen 会话 'miner1'。"
        exit 1
    fi

    # 最终成功信息
    echo "所有步骤已成功完成！"
    echo "当前目录：$(pwd)"
    echo "MINING_PUBKEY 已设置为：$public_key"
    echo "Leader 端口：$LEADER_PORT"
    echo "Follower 端口：$FOLLOWER_PORT"
    echo "Nockchain 节点运行在 screen 会话 'miner1' 中，日志在 $HOME/nockchain/miner1/miner1.log，可使用 'screen -r miner1' 或选项 3 查看。"
    if [[ "$create_wallet" =~ ^[Yy]$ ]]; then
        echo "钱包密钥已生成，请妥善保存！"
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
    if [ ! -d "$HOME/nockchain" ]; then
        echo "错误：nockchain 目录不存在，请先运行选项 1 安装部署nock。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    fi

    # 进入 nockchain 目录
    cd "$HOME/nockchain" || { echo "错误：无法进入 nockchain 目录"; exit 1; }

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

# 查看日志函数
function view_log() {
    LOG_FILE="$HOME/nockchain/miner1/miner1.log"
    if [ -f "$LOG_FILE" ]; then
        echo "正在显示日志文件：$LOG_FILE"
        tail -f "$LOG_FILE"
    else
        echo "错误：日志文件 $LOG_FILE 不存在，请确认是否已运行安装部署nock。"
    fi
    echo "按 Enter 键返回主菜单..."
    read -r
}

# 重启挖矿函数
function restart_mining() {
    # 检查 nockchain 目录是否存在
    if [ ! -d "$HOME/nockchain" ]; then
        echo "错误：nockchain 目录不存在，请先运行选项 1 安装部署nock。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    fi

    # 进入 nockchain/miner1 目录
    cd "$HOME/nockchain/miner1" || { echo "错误：无法进入 $HOME/nockchain/miner1 目录"; exit 1; }
    echo "当前目录：$(pwd)"

    # 检查 .env 文件是否存在并读取 MINING_PUBKEY
    if [ ! -f "../.env" ]; then
        echo "错误：.env 文件不存在，请先运行选项 1 安装部署nock。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    fi

    # 从 .env 文件中提取 MINING_PUBKEY
    public_key=$(grep "^MINING_PUBKEY=" ../.env | cut -d'=' -f2)
    if [ -z "$public_key" ]; then
        echo "错误：未找到 MINING_PUBKEY，请检查 .env 文件。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    fi
    echo "使用 MINING_PUBKEY：$public_key"

    # 验证 nockchain 命令是否可用
    echo "正在验证 nockchain 命令..."
    if ! command -v nockchain >/dev/null 2>&1; then
        echo "错误：nockchain 命令不可用，请检查安装或 PATH 配置。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    fi

    # 清理现有的 miner1 screen 会话（避免冲突）
    echo "正在清理现有的 miner1 screen 会话..."
    screen -ls | grep -q "miner1" && screen -X -S miner1 quit

    # 清理 .data.nockchain 和 socket 文件
    echo "警告：将删除 .data.nockchain 和 /opt/nockchain/.socket/nockchain_npc.sock，可能需要重新同步数据。继续？[Y/n]"
    read -r confirm
    confirm=${confirm:-y}
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消清理操作。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    fi
    echo "正在清理 .data.nockchain 和 /opt/nockchain/.socket/nockchain_npc.sock..."
    rm -rf ./.data.nockchain /opt/nockchain/.socket/nockchain_npc.sock || {
        echo "错误：无法删除 .data.nockchain 或 /opt/nockchain/.socket/nockchain_npc.sock，可能文件正在使用。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    }
    echo "已清理 .data.nockchain 和 /opt/nockchain/.socket/nockchain_npc.sock" >> miner1.log

    # 启动 screen 会话运行 nockchain
    echo "正在启动 screen 会话 'miner1' 并运行 nockchain..."
    screen -dmS miner1 bash -c "RUST_LOG=info,nockchain=info,nockchain_libp2p_io=info,libp2p=info,libp2p_quic=info \
    MINIMAL_LOG_FORMAT=true \
    nockchain --mining-pubkey \"$public_key\" --mine > miner1.log 2>&1 || echo 'nockchain 运行失败' >> miner_error.log; exec bash"
    if [ $? -eq 0 ]; then
        echo "screen 会话 'miner1' 已启动，日志输出到 $HOME/nockchain/miner1/miner1.log，可使用 'screen -r miner1' 查看。"
        # 等待片刻以确保日志写入
        sleep 5
        # 检查并显示 miner1.log 内容
        if [ -f "miner1.log" ]; then
            echo "以下是 miner1.log 的内容："
            echo "----------------------------------------"
            cat miner1.log
            echo "----------------------------------------"
        else
            echo "警告：miner1.log 文件尚未生成，可能 nockchain 尚未开始写入日志。"
            echo "请稍后使用 'screen -r miner1' 或选项 3 查看日志。"
        fi
    else
        echo "错误：无法启动 screen 会话 'miner1'。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    fi

    echo "挖矿已重启！"
    echo "按 Enter 键返回主菜单..."
    read -r
}

# 查询余额函数
function check_balance() {
    # 保存当前目录，以便完成后返回
    local ORIGINAL_DIR=$(pwd)

    # 切换到 ~/nockchain/miner1 目录
    if [ ! -d "$HOME/nockchain/miner1" ]; then
        echo "错误：目录 ~/nockchain/miner1 不存在，请确认目录是否正确或先运行选项 1 安装部署nock。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    fi

    echo "正在切换到 ~/nockchain/miner1 目录..."
    cd "$HOME/nockchain/miner1" || {
        echo "错误：无法切换到 ~/nockchain/miner1 目录。"
        echo "按 Enter 键返回主菜单..."
        read -r
        return
    }

    # 检查 nockchain-wallet 是否可用
    if ! command -v nockchain-wallet >/dev/null 2>&1; then
        echo "错误：nockchain-wallet 命令不可用，请先运行选项 1 安装部署nock。"
        echo "按 Enter 键返回主菜单..."
        read -r
        cd "$ORIGINAL_DIR" # 返回原目录
        return
    fi

    # 检查 nockchain 目录是否存在
    if [ ! -d "$HOME/nockchain" ]; then
        echo "错误：nockchain 目录不存在，请先运行选项 1 安装部署nock。"
        echo "按 Enter 键返回主菜单..."
        read -r
        cd "$ORIGINAL_DIR" # 返回原目录
        return
    fi

    # 检查 socket 文件是否存在
    SOCKET_PATH=".socket/nockchain_npc.sock"
    if [ ! -S "$SOCKET_PATH" ]; then
        echo "错误：socket 文件 $SOCKET_PATH 不存在，请确保 nockchain 节点正在运行（可尝试选项 4 重启挖矿）。"
        echo "按 Enter 键返回主菜单..."
        read -r
        cd "$ORIGINAL_DIR" # 返回原目录
        return
    fi

    # 执行余额查询命令
    echo "正在查询余额..."
    nockchain-wallet --nockchain-socket "$SOCKET_PATH" list-notes > balance_output.txt 2>&1
    if [ $? -eq 0 ]; then
        echo "余额查询成功！以下是查询结果："
        echo "----------------------------------------"
        cat balance_output.txt
        echo "----------------------------------------"
    else
        echo "错误：余额查询失败，请检查 nockchain-wallet 命令或节点状态。"
        echo "详细信息见 $(pwd)/balance_output.txt"
    fi

    # 返回原目录
    echo "正在返回原目录 $ORIGINAL_DIR..."
    cd "$ORIGINAL_DIR" || echo "警告：无法返回原目录 $ORIGINAL_DIR，请手动切换目录。"

    echo "按 Enter 键返回主菜单..."
    read -r
}

# 启动主菜单
main_menu

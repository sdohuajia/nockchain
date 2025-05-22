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
        echo "请输入选项 (1-3):"
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
            *)
                echo "无效选项，请输入 1、2 或 3"
                sleep 2
                ;;
        esac
    done
}

# 查看日志函数
function view_log() {
    LOG_FILE="$HOME/nockchain/miner.log"
    if [ -f "$LOG_FILE" ]; then
        echo "正在显示日志文件：$LOG_FILE"
        less "$LOG_FILE"
    else
        echo "错误：日志文件 $LOG_FILE 不存在，请确认是否已运行安装部署nock。"
    fi
    echo "按 Enter 键返回主菜单..."
    read -r
}

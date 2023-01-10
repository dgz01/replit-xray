#!/bin/sh
# 脚本项目的 URL 是：
# https://github.com/XTLS/Xray-install
# FILES_PATH 默认路径./
FILES_PATH=${FILES_PATH:-./}
# 设置Xray 当前版本号
CURRENT_VERSION=''
# 设置Xray 最新发布版本号
RELEASE_LATEST=''
# 配色
echo_color() {
    case $1 in
        black)
            echo -e "\033[42;30m\033[1m\033[3m$2\033[0m"
            ;;
        red)
            echo -e "\033[40;31m\033[1m\033[3m$2\0331m\033[0m"
            ;;
        green)
            echo -e "\033[40;32m\033[1m\033[3m$2\0331m\033[0m"
            ;;
        yellow)
            echo -e "\033[40;33m\033[1m\033[3m$2\0331m\033[0m" 
            ;;
        blue)
            echo -e "\033[40;34m\033[1m\033[3m$2\0331m\033[0m"
            ;;
        purple)
            echo -e "\033[40;35m\033[1m\033[3m$2\0331m\033[0m" 
            ;;
        cyan)
            echo -e "\033[40;36m\033[1m\033[3m$2\0331m\033[0m"
            ;;
        white)
            echo -e "\033[40;37m\033[2m\033[3m$2\0331m\033[0m" 
            ;;
        *) 
            echo "Example: echo_color red string"
    esac
}
# 1.获取Xray 当前版本号
get_current_version() {
    # [ -f file ]：如果 file 存在并且是一个普通文件，则为true
    if [[ -f "${FILES_PATH}/web" ]]; then
        #打印web版本号第1行的第2个字段
        CURRENT_VERSION="$(${FILES_PATH}/web -version | awk 'NR==1 {print $2}')"
        CURRENT_VERSION="v${CURRENT_VERSION#v}"
    else
        CURRENT_VERSION=""
    fi
}
# 2.获取Xray 最新发布版本号
get_latest_version() {
    # local 命令创建局部变量
    local tmp_file
    # mktemp - 创建临时文件或目录
    tmp_file="$(mktemp)"
    # ! 逻辑非 curl -s 不显示进度表或错误消息-H使用帮助。-o下载文件到临时文件
    # 下载不成功执行then
    if ! curl -sS -H "Accept: application/vnd.github.v3+json" -o "$tmp_file" 'https://api.github.com/repos/XTLS/Xray-core/releases/latest'; then
        # 删除临时文件
        "rm" "$tmp_file"
        echo '错误：获取发布列表失败，请检查您的网络。'
        #echo 'error: Failed to get release list, please check your network.'
        exit 1
    fi
    # 获取Xray 最新发布版本号
    RELEASE_LATEST="$(jq .tag_name "$tmp_file" | sed 's/\"//g')"
    if [[ -z "$RELEASE_LATEST" ]]; then
        # if grep -q "超出 API 速率限制" "$tmp_file"; then
        if grep -q "API rate limit exceeded" "$tmp_file"; then
            #echo "error: github API rate limit exceeded"
            echo "错误：超出 github API 速率限制"
        else
            #echo "error: Failed to get the latest release version."
            echo "错误：无法获取最新版本。"
        fi
        "rm" "$tmp_file"
        exit 1
    fi
    "rm" "$tmp_file"
}
# 4.下载xray
download_xray() {
    # 拼接网址版本号和文件名
    DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/$RELEASE_LATEST/Xray-linux-64.zip"
    # ! 逻辑非 wget -o 日志文件 [URL]将系统生成的所有消息定向到该选项指定的日志文件 -q,–quiet 不显示输出信息；
    # 下载文件到变量ZIP_FILE
    if ! wget -qO "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        # echo 'error: Download failed! Please check your network or try again.'
        echo '错误：下载失败！ 请检查您的网络或重试。'
        return 1
    fi
    return 0
    # ! 逻辑非 wget -o 日志文件 [URL]将系统生成的所有消息定向到该选项指定的日志文件 -q,–quiet 不显示输出信息；
    # 下载验证码文件.dgst
    if ! wget -qO "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst"; then
        # echo 'error: Download failed! Please check your network or try again.'
        echo '错误：下载失败！ 请检查您的网络或重试。'
        return 1
    fi
    # 检查是否发现验证码文件
    if [[ "$(cat "$ZIP_FILE".dgst)" == 'Not Found' ]]; then
        # echo 'error: This version does not support verification. Please replace with another version.'
        echo '错误：此版本不支持验证。 请更换为其他版本。'
        return 1
    fi

    # Xray 存档验证
    # 分别取出，'md5' 'sha1' 'sha256' 'sha512'
    for LISTSUM in 'md5' 'sha1' 'sha256' 'sha512'; do
        # 与文件的相比对
        SUM="$(${LISTSUM}sum "$ZIP_FILE" | sed 's/ .*//')"
        CHECKSUM="$(grep ${LISTSUM^^} "$ZIP_FILE".dgst | grep "$SUM" -o -a | uniq)"
        # 判断两者是否一致
        if [[ "$SUM" != "$CHECKSUM" ]]; then
            # echo 'error: Check failed! Please check your network or try again.'
            echo '错误：检查失败！ 请检查您的网络或重试。'
            return 1
        fi
    done
}
# 5.解压web.zip
decompression() {
    busybox unzip -q "$1" -d "$TMP_DIRECTORY"
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -ne 0 ]; then
        "rm" -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
}
# 6.安装xray
install_xray() {
    install -m 755 ${TMP_DIRECTORY}/xray ${FILES_PATH}/web
}
# 7.运行xray
run_xray() {
    # 将服务器上的变量tr_password的默认值传给TR_PASSWORD变量
    TR_PASSWORD=$(curl -s $REPLIT_DB_URL/tr_password)
    # 将服务器上变量tr_path的默认值传给TR_PATH变量
    TR_PATH=$(curl -s $REPLIT_DB_URL/tr_path)
    # 这里是调试信息
    echo_color white $(curl -s "$REPLIT_DB_URL?prefix=")
    echo_color white "服务器上的默认密码:$(curl -s $REPLIT_DB_URL/tr_password)"
    echo_color white "服务器上的默认路径:$(curl -s $REPLIT_DB_URL/tr_path)"
    # 判断服务器上的默认密码是否为空    
    if [ "${TR_PASSWORD}" = "" ]; then
        # 随机生成一个8位密码
        NEW_PASS="$(echo $RANDOM | md5sum | head -c 8; echo)"
        # 将密码上传到服务器
        curl -sXPOST $REPLIT_DB_URL/tr_password="${NEW_PASS}" 
    fi
    # 判断服务器默认的WSPATH路径是否为空
    if [ "${TR_PATH}" = "" ]; then
        # 随机生成一个6位的路径
        NEW_PATH=$(echo $RANDOM | md5sum | head -c 6; echo)
        # 上传到服务器
        curl -sXPOST $REPLIT_DB_URL/tr_path="${NEW_PATH}"
    fi
    # 判断用户设置的密码是否为空
    if [ "${PASSWORD}" = "" ]; then
        # 获取服务器上的密码
        USER_PASSWORD=$(curl -s $REPLIT_DB_URL/tr_password)
    else
        # 获取用户输入的密码
        USER_PASSWORD=${PASSWORD}
    fi
    # 判断用户设置的WSPATH路径是否为空
    if [ "${WSPATH}" = "" ]; then
        # 获取服务器上生成的WSPATH路径
        USER_PATH=/$(curl -s $REPLIT_DB_URL/tr_path)
    else
        # 获取用户输入的WSPATH的值
        USER_PATH=${WSPATH}
    fi
    # 拷贝配置文件
    cp -f ./config.yaml /tmp/config.yaml
    # 隐藏明文
    sed -i "s|PASSWORD|${USER_PASSWORD}|g;s|WSPATH|${USER_PATH}|g" /tmp/config.yaml
    ./web -c /tmp/config.yaml 2>&1 >/dev/null &
    PATH_IN_LINK=$(echo ${USER_PATH} | sed "s|\/|\%2F|g")
    # 拼接配置文件
    echo ""
    echo_color red "Share Link:"
    echo_color black trojan://"${USER_PASSWORD}@${REPL_SLUG}.${REPL_OWNER}.repl.co:443?security=tls&type=ws&path=${PATH_IN_LINK}#Replit"
    echo trojan://"${USER_PASSWORD}@${REPL_SLUG}.${REPL_OWNER}.repl.co:443?security=tls&type=ws&path=${PATH_IN_LINK}#Replit" >/tmp/link
    echo ""
    # 生成二维码文件需要加载pkgs.qrencode.bin
    # qrencode -t ansiutf8 < /tmp/link
    # 不断的刷新日志信息
    tail -f
}

# 两个非常重要的变量
# mktemp -d 创建临时目录
# 创建一个临时目录用来保存下载的文件，
TMP_DIRECTORY="$(mktemp -d)"
# web.zip 未来将要下载的文件的地址 $变量 读取变量的值
ZIP_FILE="${TMP_DIRECTORY}/web.zip"
# 1.获取Xray 当前版本号
get_current_version
# 测试变量的值
#echo ${TMP_DIRECTORY}
#echo ${ZIP_FILE}
echo
echo
echo_color yellow  "系统当前使用的xray版本:${CURRENT_VERSION}"
# 2.获取Xray 最新发布版本号
get_latest_version
echo
echo_color purple  "目前最新的xray版本:${RELEASE_LATEST}"
# 3.判断当前版本号和最新版本号是否一致
if [ "${RELEASE_LATEST}" = "${CURRENT_VERSION}" ]; then
    # echo "xray的安装目录是:${TMP_DIRECTORY}}"
    # 删除临时目录
   "rm" -rf "$TMP_DIRECTORY"
   # 执行run_xray函数
   run_xray
fi
# 4.下载xray
download_xray
# 测试变量的值
# echo ${ZIP_FILE}
# $? 为上一个命令的退出码，用来判断上一个命令是否执行成功。返回值是0，表示上一个命令执行成功；如果不是零，表示上一个命令执行失败。
# 获取上一个命令的退出码
EXIT_CODE=$?
# -eq	等于 应用于：整型比较
if [ ${EXIT_CODE} -eq 0 ]; then
    # : 是一个内建指令：\"什么事都不干\"，但返回状态值 0。
    :
else
    # 删除临时目录
    "rm" -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    run_xray
fi
# 5.解压web.zip
decompression "$ZIP_FILE"
# 6.安装xray
install_xray
# echo "xray的安装目录是:${TMP_DIRECTORY}"
# 删除临时目录
"rm" -rf "$TMP_DIRECTORY"
# 7.运行xray
run_xray

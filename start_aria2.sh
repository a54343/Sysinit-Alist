#!/bin/bash

# Aria2配置
PORT=6800
BT_PORT=10003
CONF_PATH="/root/.aria2/aria2.conf"

# 检测TCP端口(6800)是否被占用
check_and_kill_port() {
    local port=$1
    local protocol=${2:-tcp}  # 默认检测TCP
    
    echo "检测${protocol^^}端口 $port 是否被占用..."
    
    if [ "$protocol" = "udp" ]; then
        if netstat -ulnp | grep -q ":$port "; then
            return 1
        fi
    else
        if lsof -i :$port > /dev/null; then
            return 1
        fi
    fi
    return 0
}

kill_port_process() {
    local port=$1
    local protocol=${2:-tcp}
    
    echo "${protocol^^}端口 $port 被占用，尝试终止占用进程..."
    
    if [ "$protocol" = "udp" ]; then
        PID=$(netstat -ulnp | awk -v port=":$port" '$4 ~ port {print $NF}' | cut -d'/' -f1)
    else
        PID=$(lsof -t -i :$port)
    fi
    
    if [ -n "$PID" ]; then
        kill -9 $PID
        sleep 1
        # 再次检测
        if check_and_kill_port $port $protocol; then
            echo "占用进程已终止。"
        else
            echo "无法终止占用进程，请手动处理！"
            exit 1
        fi
    else
        echo "未找到占用进程，可能是系统保留端口。"
        exit 1
    fi
}

# 检测并处理6800 TCP端口
if ! check_and_kill_port $PORT; then
    kill_port_process $PORT
fi

# 检测并处理10003 UDP端口
if ! check_and_kill_port $BT_PORT udp; then
    kill_port_process $BT_PORT udp
fi

# 启动 aria2
echo "正在启动 aria2..."
aria2c --conf-path="$CONF_PATH" -D

# 检查是否启动成功
if lsof -i :$PORT > /dev/null; then
    echo "aria2 已成功启动，监听端口 $PORT"
else
    echo "aria2 启动失败！"
    exit 1
fi

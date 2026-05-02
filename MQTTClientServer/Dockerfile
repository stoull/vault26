# 多阶段构建 Dockerfile for Swift Server Project

# ============================================
# 构建阶段
# ============================================
# FROM swift:5.9 as builder
#swift:6.2-bookworm-slim as builder
# FROM swift:5.10-bookworm AS builder
FROM swift:6.2-bookworm AS builder

# 设置工作目录
WORKDIR /app

# 复制 Package.swift 和 Package.resolved（如果存在）
COPY Package.swift Package.resolved* ./

# 1. 安装编译环境（build-essential）
# RUN apt-get update && apt-get install -y build-essential

# 2. 解析 Swift 依赖
RUN swift package resolve

# 复制源代码
COPY . .

# 构建并把产物放到固定路径（含 SPM 资源包 MQTTClientServer_App.resources；COPY App* 拷不到它）
RUN swift build -c release -Xswiftc -Osize --static-swift-stdlib \
    && BIN="$(swift build -c release --show-bin-path)" \
    && mkdir -p /artifacts \
    && cp "$BIN/App" /artifacts/ \
    && cp -r "$BIN/MQTTClientServer_App.resources" /artifacts/

# ============================================
# 运行阶段
# ============================================
# FROM ubuntu:22.04
# FROM alpine:latest
FROM debian:bookworm

LABEL maintainer="Hut <strongwindcarrywater@gmail.com>" \
      author="Hut" \
      version="1.0" \
      description="My custom image with Swift"

# 安装运行时依赖
# RUN apt-get update && apt-get install -y \
#     libcurl4 \
#     libxml2 \
#     libc6 \
#     && rm -rf /var/lib/apt/lists/*

# 声明卷挂载点，docker-compose 可以实际挂载这些卷
# VOLUME ["/app/log"]

# 创建非 root 用户
RUN useradd -u 1100 -m -s /bin/bash mqtt_client

# 设置工作目录
WORKDIR /app

# 创建必要的目录
# 相对于WORKDIR的相对路径,即/app/shared_data
# RUN mkdir -p log && touch log/mqtt.log

COPY --from=builder /artifacts/ /app/

# 修改文件所有者
RUN chown -R mqtt_client:mqtt_client /app

# 切换到非 root 用户
USER mqtt_client

# 暴露端口（根据你的应用实际端口修改）
EXPOSE 8020

# 启动应用
CMD ["./App"]

# 使用 shell 形式以便调试
# CMD ["/bin/bash", "-c", "ls -la /app/release/ && echo 'Looking for executable.. .' && find /app/release -type f -executable && exec /app/release/App"]

# ============================================================
# SuperBizAgent - 生产环境 Docker 镜像
# 包含 FastAPI + CLS MCP + Monitor MCP 三个服务（supervisord 管理）
# ============================================================
FROM python:3.11-slim

LABEL maintainer="chief"
LABEL description="SuperBizAgent - 企业级智能 OnCall Agent"

# 安装系统依赖 + supervisor
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---- 依赖层（利用 Docker 缓存）----
COPY pyproject.toml README.md ./
RUN pip install --no-cache-dir -e . && \
    rm -rf /root/.cache/pip

# ---- 代码层 ----
COPY . .

# 复制 supervisord 配置到系统目录
COPY deploy/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 创建必要目录
RUN mkdir -p logs uploads volumes

# FastAPI + 两个 MCP 服务端口
EXPOSE 9900 8003 8004

# 由 supervisord 管理三个服务进程
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf", "-n"]

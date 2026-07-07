# 生产部署指南

## 架构

```
用户 → 域名:80/443
        │
    ┌───▼───┐
    │ Nginx  │  (反代 + SSL)
    └───┬───┘
        │
    ┌───▼──────────┐
    │    app        │  FastAPI + CLS MCP + Monitor MCP
    │  9900/8003/8004│  (supervisord 管理 3 进程)
    └───┬──────────┘
        │
    ┌───▼──────────┐
    │   standalone  │  Milvus 向量数据库 (19530)
    │ etcd + minio  │
    └──────────────┘
```

## 前置条件

- 一台云服务器（推荐 2C4G，Ubuntu 22.04）
- 已安装 Docker + Docker Compose
- 阿里云 DashScope API Key

## 一、部署步骤

### 1. 服务器上获取代码

```bash
# 方式 1：git clone（推荐）
git clone <你的仓库地址> /opt/super-biz-agent
cd /opt/super-biz-agent

# 方式 2：直接上传
# 本地打包代码
tar czf super-biz-agent.tar.gz --exclude=.venv --exclude=__pycache__ --exclude=.git .
# 传到服务器
scp super-biz-agent.tar.gz user@your-server:/opt/
# 服务器上解压
ssh user@your-server
cd /opt && tar xzf super-biz-agent.tar.gz
```

### 2. 配置环境变量

```bash
cd /opt/super-biz-agent
vim deploy/.env.production
# 把 DASHSCOPE_API_KEY 改为真实 key
# 确认 MILVUS_HOST=standalone
```

### 3. 启动全部服务

```bash
# 首次启动（构建镜像 + 启动所有容器）
docker compose up -d

# 查看启动状态
docker compose ps
docker compose logs -f app   # 看应用日志

# 健康检查
curl http://localhost:9900/health
```

### 4. 上传知识库文档

```bash
# 等 Milvus 和 FastAPI 都就绪后
for file in aiops-docs/*.md; do
    curl -X POST http://localhost:9900/api/upload -F "file=@$file"
    sleep 1
done
```

### 5. 配置域名 + HTTPS（可选）

```bash
# 购买域名，DNS 指向服务器 IP

# 安装 certbot（服务器上）
apt install -y certbot
certbot certonly --standalone -d your-domain.com

# 复制证书
mkdir -p deploy/ssl
cp /etc/letsencrypt/live/your-domain.com/fullchain.pem deploy/ssl/
cp /etc/letsencrypt/live/your-domain.com/privkey.pem deploy/ssl/

# 编辑 nginx.conf，取消注释 SSL 部分
# 然后重启 nginx
docker compose restart nginx
```

## 二、日常管理

```bash
# 查看所有服务状态
docker compose ps

# 查看日志
docker compose logs -f app        # 应用日志
docker compose logs -f nginx      # Nginx 日志
docker compose logs -f standalone # Milvus 日志

# 更新代码后重新部署
git pull                                         # 拉取最新代码
docker compose build app                         # 重新构建镜像
docker compose up -d app                         # 滚动更新

# 重启所有服务
docker compose restart

# 停止所有服务
docker compose down

# 停止并删除数据卷（⚠️ 会清空 Milvus 数据和上传文件）
docker compose down -v
```

## 三、服务端口说明

| 服务 | 容器内端口 | 宿主机暴露 | 用途 |
|------|-----------|-----------|------|
| FastAPI | 9900 | 9900 | Web 界面 + API |
| CLS MCP | 8003 | 不暴露 | 日志查询（App 内部调用） |
| Monitor MCP | 8004 | 不暴露 | 监控数据（App 内部调用） |
| Milvus | 19530 | 19530 | 向量数据库（App 内部调用） |
| Nginx | 80/443 | 80/443 | 反向代理入口 |

## 四、文件说明

```
deploy/
├── .env.production      ← 生产环境配置（填入 API Key 后部署）
├── nginx.conf            ← Nginx 反向代理配置
├── supervisord.conf      ← 容器内进程管理（FastAPI + MCP）
└── README.md             ← 本文档

docker-compose.yml        ← 全量服务编排
Dockerfile                ← 应用镜像构建
```

## 五、迁移到云服务（降本）

如果不想在服务器上自建 Milvus（省掉 700MB+ 内存），可以用云向量数据库替代：

### 阿里云 PAI 向量检索

```bash
# pip install dashvector
# 修改 app/core/milvus_client.py → 替换为 DashVector HTTP API 调用
# docker-compose.yml 中移除 etcd/minio/standalone 服务
# 2C2G 服务器即可运行
```

### 腾讯云 VectorDB

```bash
# pip install tcvectordb
# 同样替换向量存储实现
```

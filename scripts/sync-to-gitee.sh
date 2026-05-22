#!/bin/bash

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要环境变量
check_env_vars() {
    log_info "检查环境变量..."
    
    if [ -z "$GITEE_USERNAME" ]; then
        log_error "GITEE_USERNAME 环境变量未设置"
        exit 1
    fi
    
    if [ -z "$GITEE_TOKEN" ]; then
        log_error "GITEE_TOKEN 环境变量未设置"
        exit 1
    fi
    
    log_info "环境变量检查通过"
}

# 验证 Gitee 认证
verify_gitee_auth() {
    log_info "验证 Gitee 认证..."
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token ${GITEE_TOKEN}" \
        "https://gitee.com/api/v5/user")
    
    if [ "$response" != "200" ]; then
        log_error "Gitee 认证失败，请检查 token 是否有效"
        exit 1
    fi
    
    log_info "Gitee 认证验证通过"
}

# 检查仓库是否存在
check_repo_exists() {
    local repo_owner="$1"
    local repo_name="$2"
    
    log_info "检查仓库 ${repo_owner}/${repo_name} 是否存在..."
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://gitee.com/api/v5/repos/${repo_owner}/${repo_name}")
    
    if [ "$response" == "200" ]; then
        log_info "仓库已存在"
        return 0
    else
        log_warn "仓库不存在"
        return 1
    fi
}

# 创建仓库
create_repo() {
    local repo_owner="$1"
    local repo_name="$2"
    
    log_info "创建仓库 ${repo_owner}/${repo_name}..."
    
    local response=$(curl -s -w "%{http_code}" -o /tmp/gitee_response.json \
        -X POST \
        -H "Authorization: token ${GITEE_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${repo_name}\",
            \"description\": \"Mirror repository for hermes-agent\",
            \"private\": false,
            \"has_issues\": true,
            \"has_wiki\": true,
            \"can_comment\": true
        }" \
        "https://gitee.com/api/v5/user/repos")
    
    if [ "$response" == "201" ] || [ "$response" == "200" ]; then
        log_info "仓库创建成功"
        return 0
    else
        log_error "仓库创建失败，HTTP 状态码: $response"
        if [ -f /tmp/gitee_response.json ]; then
            log_error "响应内容: $(cat /tmp/gitee_response.json)"
        fi
        return 1
    fi
}

# 同步代码
sync_code() {
    local source_repo="https://github.com/NousResearch/hermes-agent.git"
    local target_repo="https://oauth2:${GITEE_TOKEN}@gitee.com/${GITEE_USERNAME}/hermes-agent.git"
    
    log_info "开始同步代码..."
    
    # 克隆源仓库
    if [ -d "hermes-agent-mirror" ]; then
        log_warn "清理旧的镜像目录..."
        rm -rf hermes-agent-mirror
    fi
    
    log_info "克隆源仓库: ${source_repo}"
    git clone --mirror "${source_repo}" hermes-agent-mirror
    
    cd hermes-agent-mirror
    
    # 添加目标仓库远程地址
    log_info "配置目标仓库: ${GITEE_USERNAME}/hermes-agent"
    git remote add gitee "${target_repo}" 2>/dev/null || git remote set-url gitee "${target_repo}"
    
    # 推送代码
    log_info "推送代码到 Gitee..."
    git push gitee --mirror
    
    cd ..
    
    log_info "代码同步完成！"
}

# 主函数
main() {
    log_info "=== 开始同步流程 ==="
    
    # 检查环境变量
    check_env_vars
    
    # 验证认证
    verify_gitee_auth
    
    # 检查并创建仓库（如果需要）
    if ! check_repo_exists "${GITEE_USERNAME}" "hermes-agent"; then
        create_repo "${GITEE_USERNAME}" "hermes-agent"
    fi
    
    # 同步代码
    sync_code
    
    log_info "=== 同步流程完成 ==="
}

# 执行主函数
main "$@"

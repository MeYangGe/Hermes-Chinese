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
    
    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "GITHUB_TOKEN 环境变量未设置"
        exit 1
    fi
    
    if [ -z "$RUN_NUMBER" ]; then
        log_error "RUN_NUMBER 环境变量未设置"
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

# 更新 Pull Log
update_pull_log() {
    log_info "更新 Pull Log..."
    
    local CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 配置 git
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    
    # 读取现有日志
    if [ -f UPDATE_LOG.md ]; then
        # 在表格末尾添加新行
        sed -i "3a| ${CURRENT_DATE} | 同步 #${RUN_NUMBER} | 自动同步 hermes-agent 到 Gitee |" UPDATE_LOG.md
    else
        # 创建新日志文件
        echo "# 拉取同步日志" > UPDATE_LOG.md
        echo "" >> UPDATE_LOG.md
        echo "| Date | Version | Changes |" >> UPDATE_LOG.md
        echo "|------|---------|---------|" >> UPDATE_LOG.md
        echo "| ${CURRENT_DATE} | 同步 #${RUN_NUMBER} | 自动同步 hermes-agent 到 Gitee |" >> UPDATE_LOG.md
    fi
    
    # 提交日志更新
    git add UPDATE_LOG.md
    git commit -m "docs: 更新拉取日志 - 同步 #${RUN_NUMBER}" || echo "无更新"
    git push
    
    log_info "Pull Log 更新完成！"
}

# 创建或更新 Release
create_release() {
    log_info "创建 Release..."
    
    # 创建一个简单的临时文件用于 JSON payload
    cat > /tmp/release_payload.json << EOF
{
    "tag_name": "sync-${RUN_NUMBER}",
    "name": "hermes-agent 镜像同步",
    "body": "## Hermes Agent 自动同步\n\n自动从 GitHub (NousResearch/hermes-agent) 同步到 Gitee 镜像仓库。\n\n**同步时间**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")\n**同步方式**: 完整镜像同步（包含所有分支和标签）\n\n### 配置说明\n- 同步频率：每6小时自动同步\n- 支持手动触发：通过 GitHub Actions 页面手动运行\n- 镜像仓库：Gitee 对应仓库",
    "draft": false,
    "prerelease": false
}
EOF
    
    # 使用 GitHub API 创建 Release
    local response=$(curl -s -w "%{http_code}" -o /tmp/github_response.json \
        -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d @/tmp/release_payload.json \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases")
    
    if [ "$response" == "201" ]; then
        log_info "Release 创建成功"
    else
        log_warn "Release 创建可能失败，HTTP 状态码: $response"
        if [ -f /tmp/github_response.json ]; then
            log_warn "响应内容: $(cat /tmp/github_response.json)"
        fi
    fi
    
    # 清理临时文件
    rm -f /tmp/release_payload.json
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
    
    # 更新 Pull Log
    update_pull_log
    
    # 创建 Release
    create_release
    
    log_info "=== 同步流程完成 ==="
}

# 执行主函数
main "$@"

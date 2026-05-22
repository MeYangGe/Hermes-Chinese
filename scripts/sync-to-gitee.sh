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

# 加载配置文件
load_config() {
    local config_file="config.json"
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件 $config_file 不存在"
        exit 1
    fi
    
    log_info "加载配置文件..."
    
    # 读取配置
    SOURCE_REPO=$(jq -r '.source.repo' "$config_file")
    TARGET_REPO=$(jq -r '.target.repo' "$config_file")
    CREATE_RELEASE=$(jq -r '.sync.create_release' "$config_file")
    UPDATE_LOG=$(jq -r '.sync.update_log' "$config_file")
    
    # 验证配置
    if [ "$SOURCE_REPO" == "null" ] || [ -z "$SOURCE_REPO" ]; then
        log_error "配置文件中 source.repo 未设置"
        exit 1
    fi
    
    if [ "$TARGET_REPO" == "null" ] || [ -z "$TARGET_REPO" ]; then
        log_error "配置文件中 target.repo 未设置"
        exit 1
    fi
    
    log_info "配置加载完成"
    log_info "  源仓库: github.com/${SOURCE_REPO}"
    log_info "  目标仓库: gitee.com/${GITEE_USERNAME}/${TARGET_REPO}"
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
    
    if [ -z "$GITHUB_REPOSITORY" ]; then
        log_error "GITHUB_REPOSITORY 环境变量未设置"
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
            \"description\": \"Mirror repository for ${SOURCE_REPO}\",
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
    local source_repo="https://github.com/${SOURCE_REPO}.git"
    local target_repo="https://oauth2:${GITEE_TOKEN}@gitee.com/${GITEE_USERNAME}/${TARGET_REPO}.git"
    local need_push=false
    
    log_info "开始同步代码..."
    
    # 检查镜像目录是否存在
    if [ -d "repo-mirror" ]; then
        log_info "发现已存在的镜像目录，直接拉取更新..."
        cd repo-mirror
        
        # 保存拉取前的状态
        local before_branches=$(git branch -a | sort | sha256sum | awk '{print $1}')
        local before_tags=$(git tag | sort | sha256sum | awk '{print $1}')
        local before_commits=$(git rev-list --all --count)
        
        # 确保远程源仓库地址正确
        git remote set-url origin "${source_repo}"
        
        # 拉取最新更新
        log_info "从源仓库拉取最新更新..."
        git remote update --prune 2>&1 | while read -r line; do
            log_info "[拉取进度] $line"
        done
        
        # 比较拉取前后的状态
        local after_branches=$(git branch -a | sort | sha256sum | awk '{print $1}')
        local after_tags=$(git tag | sort | sha256sum | awk '{print $1}')
        local after_commits=$(git rev-list --all --count)
        
        if [ "$before_branches" != "$after_branches" ] || [ "$before_tags" != "$after_tags" ] || [ "$before_commits" != "$after_commits" ]; then
            log_info "检测到新的变更，需要推送"
            need_push=true
        else
            log_info "没有检测到新的变更，跳过推送"
            need_push=false
        fi
    else
        log_info "镜像目录不存在，克隆源仓库: ${source_repo}"
        git clone --mirror --progress "${source_repo}" repo-mirror 2>&1 | while read -r line; do
            log_info "[克隆进度] $line"
        done
        cd repo-mirror
        need_push=true
    fi
    
    # 显示仓库信息
    log_info "仓库信息:"
    log_info "  分支数: $(git branch -a | wc -l)"
    log_info "  标签数: $(git tag | wc -l)"
    log_info "  提交数: $(git rev-list --all --count)"
    log_info "  仓库大小: $(git count-objects -vH | grep 'size-pack' | awk '{print $2}')"
    
    # 添加/更新目标仓库远程地址
    log_info "配置目标仓库: ${GITEE_USERNAME}/${TARGET_REPO}"
    git remote add gitee "${target_repo}" 2>/dev/null || git remote set-url gitee "${target_repo}"
    
    # 根据需要决定是否推送
    if [ "$need_push" = true ]; then
        log_info "推送代码到 Gitee (这可能需要几分钟，请耐心等待)..."
        log_info "提示：如果长时间无响应，可能是网络问题，请稍后重试"
        
        git push gitee --mirror --progress 2>&1 | while read -r line; do
            log_info "[推送进度] $line"
        done
    else
        log_info "无新内容，跳过推送步骤"
    fi
    
    cd ..
    
    log_info "代码同步完成！"
    
    # 返回是否有推送的状态
    [ "$need_push" = true ] && return 0 || return 2
}

# 更新 Pull Log
update_pull_log() {
    if [ "$UPDATE_LOG" != "true" ]; then
        log_info "配置禁用更新日志，跳过"
        return 0
    fi
    
    log_info "更新 Pull Log..."
    
    local CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 配置 git
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    
    # 读取现有日志
    if [ -f UPDATE_LOG.md ]; then
        # 在表格末尾添加新行
        sed -i "3a| ${CURRENT_DATE} | 同步 #${RUN_NUMBER} | 自动同步 ${SOURCE_REPO} 到 Gitee |" UPDATE_LOG.md
    else
        # 创建新日志文件
        echo "# 拉取同步日志" > UPDATE_LOG.md
        echo "" >> UPDATE_LOG.md
        echo "| Date | Version | Changes |" >> UPDATE_LOG.md
        echo "|------|---------|---------|" >> UPDATE_LOG.md
        echo "| ${CURRENT_DATE} | 同步 #${RUN_NUMBER} | 自动同步 ${SOURCE_REPO} 到 Gitee |" >> UPDATE_LOG.md
    fi
    
    # 提交日志更新
    git add UPDATE_LOG.md
    git commit -m "docs: 更新拉取日志 - 同步 #${RUN_NUMBER}" || echo "无更新"
    git push
    
    log_info "Pull Log 更新完成！"
}

# 创建或更新 Release
create_release() {
    if [ "$CREATE_RELEASE" != "true" ]; then
        log_info "配置禁用创建 Release，跳过"
        return 0
    fi
    
    log_info "创建 Release..."
    
    # 创建一个简单的临时文件用于 JSON payload
    cat > /tmp/release_payload.json << EOF
{
    "tag_name": "sync-${RUN_NUMBER}",
    "name": "${SOURCE_REPO} 镜像同步",
    "body": "## ${SOURCE_REPO} 自动同步\n\n自动从 GitHub (${SOURCE_REPO}) 同步到 Gitee 镜像仓库。\n\n**同步时间**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")\n**同步方式**: 完整镜像同步（包含所有分支和标签）\n\n### 配置说明\n- 同步频率：每日自动同步\n- 支持手动触发：通过 GitHub Actions 页面手动运行\n- 镜像仓库：Gitee 对应仓库",
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
    
    # 加载配置
    load_config
    
    # 检查环境变量
    check_env_vars
    
    # 验证认证
    verify_gitee_auth
    
    # 检查并创建仓库（如果需要）
    if ! check_repo_exists "${GITEE_USERNAME}" "${TARGET_REPO}"; then
        create_repo "${GITEE_USERNAME}" "${TARGET_REPO}"
    else
        log_info "目标仓库已存在，准备进行镜像同步（将使用 GitHub 内容完全覆盖 Gitee 仓库）"
    fi
    
    # 同步代码
    local sync_exit_code=0
    sync_code || sync_exit_code=$?
    
    if [ $sync_exit_code -eq 0 ]; then
        # 有新内容，更新 Pull Log 和创建 Release
        log_info "检测到新内容，更新日志和创建 Release"
        update_pull_log
        create_release
        log_info "=== 同步流程完成 ==="
    elif [ $sync_exit_code -eq 2 ]; then
        # 没有新内容，跳过后续步骤
        log_info "=== 同步流程完成（无新内容） ==="
    else
        # 同步失败
        log_error "=== 同步流程失败 ==="
        exit 1
    fi
}

# 执行主函数
main "$@"

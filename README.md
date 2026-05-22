# GitHub to Gitee 同步工具

一个通用的 GitHub Actions 工具，用于每日自动将 GitHub 仓库同步到 Gitee 镜像仓库。

---

## 核心特性

| 特性 | 说明 |
|:---:|------|
| ⏰ **每日同步** | 每日 UTC 00:00 自动同步（支持手动触发） |
| 🔄 **完整镜像** | 同步所有分支、标签和完整提交历史 |
| ⚡ **增量更新** | 使用缓存机制，只同步变更内容 |
| 📝 **自动日志** | 每次同步自动记录到 [UPDATE_LOG.md](UPDATE_LOG.md) |
| 🚀 **自动发布** | 每次同步后自动创建 Release 记录 |
| 🔒 **安全可靠** | 使用加密 Token 认证，无需明文密码 |
| 🎯 **灵活配置** | 通过配置文件自定义源仓库和目标仓库 |

---

## 快速开始

### 1. Fork 本仓库

点击右上角的 **Fork** 按钮，将本仓库复制到你的 GitHub 账号下。

### 2. 配置密钥

在你 Fork 的仓库中，进入 **Settings > Secrets and variables > Actions**，添加以下密钥：

| 密钥名称 | 说明 |
|---------|------|
| `GITEE_USERNAME` | 你的 Gitee 用户名 |
| `GITEE_TOKEN` | 你的 Gitee 私人令牌（[获取地址](https://gitee.com/profile/personal_access_tokens)） |

### 3. 修改配置文件

编辑 [config.json](config.json) 文件，配置你要同步的仓库：

```json
{
  "source": {
    "repo": "NousResearch/hermes-agent",
    "branch": "main"
  },
  "target": {
    "repo": "hermes-agent"
  },
  "sync": {
    "frequency": "daily",
    "create_release": true,
    "update_log": true
  }
}
```

**配置说明：**
- `source.repo`: 源 GitHub 仓库（格式：`owner/repo`）
- `target.repo`: 目标 Gitee 仓库名称
- `sync.create_release`: 是否创建 Release（true/false）
- `sync.update_log`: 是否更新日志（true/false）

### 4. 触发同步

- **自动同步**：系统每日 UTC 00:00 自动执行
- **手动同步**：进入 **Actions** 页面 → 点击 **Sync to Gitee** → 点击 **Run workflow**

---

## 同步说明

### 同步内容
✅ 所有分支（包括 main/master 和其他分支）  
✅ 所有标签（tags）  
✅ 完整提交历史  
✅ 所有文件内容  

### 同步频率
- **定时任务**：每日 UTC 00:00 执行一次
- **手动触发**：随时可通过 Actions 页面手动运行

### 智能特性
- **缓存机制**：保存镜像仓库，避免重复克隆
- **变更检测**：只在有新内容时才推送
- **自动创建**：目标仓库不存在时自动创建

---

## 工作原理

```
┌─────────────────────┐         ┌──────────────────────┐
│  GitHub Actions     │         │  Gitee 镜像仓库       │
│  定时任务            │         │                      │
│                     │  推送    │                      │
│  1. 读取配置        │────────▶│  gitee.com/          │
│  2. 拉取/克隆仓库   │         │  username/repo       │
│  3. 检测变更        │         │                      │
│  4. 镜像推送        │         │                      │
│  5. 更新日志        │         │                      │
│  6. 创建 Release    │         │                      │
└─────────────────────┘         └──────────────────────┘
```

---

## 项目结构

```
repo-sync/
├── .github/
│   └── workflows/
│       └── sync-to-gitee.yml    # 同步工作流配置
├── scripts/
│   └── sync-to-gitee.sh         # 同步脚本
├── config.json                   # 配置文件
├── UPDATE_LOG.md                # 拉取同步日志（自动维护）
└── README.md                    # 项目说明文档
```

---

## 常见问题

### Q: 如何查看同步状态？
**A:** 在 GitHub 仓库的 **Actions** 页面可以查看每次同步的运行状态和详细日志。

### Q: 同步会覆盖 Gitee 上的修改吗？
**A:** 是的，镜像同步使用 `--mirror` 参数，会完全覆盖目标仓库。**请勿在 Gitee 镜像仓库上直接修改代码。**

### Q: 如何获取 Gitee Token？
**A:** 登录 Gitee → 头像 → 设置 → 私人令牌 → 生成新令牌，勾选 `projects` 权限。

### Q: 同步失败怎么办？
**A:** 检查以下项：
1. Gitee 用户名和 Token 是否正确
2. config.json 配置是否正确
3. GitHub Actions 运行日志中的错误信息

### Q: 如何查看历史同步记录？
**A:** 查看 [UPDATE_LOG.md](UPDATE_LOG.md) 文件，每次同步都会自动添加新记录。

### Q: 可以同步多个仓库吗？
**A:** 当前版本一次只能同步一个仓库。如需同步多个仓库，可以 Fork 多个副本或修改配置支持多个仓库。

---

## 注意事项

⚠️ **重要提示：**
- 本工具仅提供自动镜像同步功能
- 所有代码版权归原仓库作者所有
- 建议在 Gitee 镜像仓库中仅做只读访问
- 请确保 Gitee Token 具有足够的权限

---

## 许可证

本项目仅供学习和个人使用。

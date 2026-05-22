## 项目简介

**Hermes Agent 自动同步工具** 是一个基于 GitHub Actions 的自动化同步工具，用于将 [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) 仓库自动镜像到 Gitee。

通过定时任务和完整镜像同步，确保国内开发者可以便捷地访问最新代码。

---

## 核心特性

| 特性 | 说明 |
|:---:|------|
| ⏰ **定时同步** | 每 6 小时自动同步一次（支持手动触发） |
| 🔄 **完整镜像** | 同步所有分支、标签和完整提交历史 |
| 📝 **自动日志** | 每次同步自动记录到 [UPDATE_LOG.md](UPDATE_LOG.md) |
| 🚀 **自动发布** | 每次同步后自动创建 Release 记录 |
| 🔒 **安全可靠** | 使用加密 Token 认证，无需明文密码 |

---

## 快速开始

### 1. 配置密钥

在 GitHub 仓库的 **Settings > Secrets and variables > Actions** 中添加：

| 密钥名称 | 说明 |
|---------|------|
| `GITEE_USERNAME` | 你的 Gitee 用户名 |
| `GITEE_TOKEN` | 你的 Gitee 私人令牌（[获取地址](https://gitee.com/profile/personal_access_tokens)） |

### 2. 触发同步

- **自动同步**：系统每 6 小时自动执行
- **手动同步**：进入 **Actions** 页面 → 点击 **Sync to Gitee** → 点击 **Run workflow**

---

## 同步说明

### 同步内容
✅ 所有分支（包括 main/master 和其他分支）  
✅ 所有标签（tags）  
✅ 完整提交历史  
✅ 所有文件内容  

### 同步频率
- **定时任务**：每 6 小时执行一次（UTC 时间 00:00, 06:00, 12:00, 18:00）
- **手动触发**：随时可通过 Actions 页面手动运行

---

## 工作原理

```
┌─────────────────────┐         ┌──────────────────────┐
│  GitHub Actions     │         │  Gitee 镜像仓库       │
│  定时任务            │         │                      │
│                     │  推送    │                      │
│  1. 克隆 GitHub     │────────▶│  gitee.com/          │
│     仓库             │         │  username/hermes-    │
│  2. 镜像推送        │         │  agent               │
│  3. 更新日志        │         │                      │
│  4. 创建 Release    │         │                      │
└─────────────────────┘         └──────────────────────┘
```

**同步流程：**
1. GitHub Actions 定时触发或手动触发
2. 从 `https://github.com/NousResearch/hermes-agent.git` 克隆完整镜像
3. 使用认证的 Gitee 账号推送到 Gitee 仓库（`--mirror` 模式）
4. 自动在 [UPDATE_LOG.md](UPDATE_LOG.md) 中记录同步信息（时间、编号）
5. 自动创建 Release 记录同步状态

---

## 拉取日志

每次同步成功后，系统会自动在 [UPDATE_LOG.md](UPDATE_LOG.md) 中记录：

```
| Date | Version | Changes |
|------|---------|---------|
| 2026-05-22 12:30:45 | 同步 #1 | 自动同步 hermes-agent 到 Gitee |
```

查看完整同步历史：[UPDATE_LOG.md](UPDATE_LOG.md)

---

## 项目结构

```
hermes-agent-sync/
├── .github/
│   └── workflows/
│       └── sync-to-gitee.yml    # 同步工作流配置（含自动日志记录）
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
2. Gitee 上是否已创建对应的空仓库
3. GitHub Actions 运行日志中的错误信息

### Q: 如何查看历史同步记录？
**A:** 查看 [UPDATE_LOG.md](UPDATE_LOG.md) 文件，每次同步都会自动添加新记录。

---

## 注意事项

⚠️ **重要提示：**
- 本工具仅提供自动镜像同步功能
- 所有代码版权归 [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) 原作者所有
- 建议在 Gitee 镜像仓库中仅做只读访问


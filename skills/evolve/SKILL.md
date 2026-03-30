---
name: codeman-evolve
description: "CodeMan 自进化引擎 Skill。根据 Review 发现的高频问题自动草拟新的 Rule 或 Skill，经用户确认后写入项目。由 Review Skill 自动触发（同类问题 ≥ 2 次），或用户说'创建规范'、'添加规则'时触发。"
---

# CodeMan 自进化引擎 Skill

## 概述

CodeMan 的自进化能力：将 Review 中发现的高频问题自动沉淀为 Rule 或 Skill，使框架在使用中持续变强。

---

## 触发条件

### 自动触发（由 Review Skill 调用）

| 触发条件 | 创建类型 | 是否需要用户确认 |
|---------|---------|---------------|
| 同类问题出现 ≥ 2 次 | Rule | ✅ 需要确认 |
| 识别到可复用的编码模式 | Skill | ✅ 需要确认 |
| 涉及架构约束的新约束 | Rule | ✅ 需要确认 |
| 项目初始化时（技术栈基础规范） | Rule | ❌ 自动创建 |
| 已有 Skill/Rule 的小幅格式修正 | Rule/Skill | ❌ 自动创建 |

### 手动触发（用户主动）

用户说：
- "创建规范：{规范描述}"
- "添加规则：{规则描述}"
- "把这个模式提取为 Skill"

---

## 执行步骤

### Step 1: 分析触发原因

读取触发信息：
- Review 报告中的高频问题记录
- 用户的描述（手动触发时）

分析：
- 问题的本质是什么？
- 是编码规范问题（适合 Rule）还是工作流程问题（适合 Skill）？
- 规范的适用范围是什么（全局/项目/模块）？

### Step 2: 判断创建类型

**创建 Rule 的场景：**
- 代码风格和命名规范
- 禁止使用某些模式
- 文件结构要求
- 安全约束
- 性能约束

**创建 Skill 的场景：**
- 多步骤的工作流程
- 需要读取多个文档的操作
- 有明确输入输出的任务

### Step 3: 草拟内容

**草拟 Rule（.mdc 格式）：**

```markdown
---
description: "{规范描述}。当{触发条件}时自动加载。"
globs: "{适用的文件 glob 模式，如 src/**/*.tsx}"
alwaysApply: {true/false}
---

# {规范名称}

## {规范类别}
- {规范条目1}
- {规范条目2}

## 禁止
- 禁止{禁止行为1}
- 禁止{禁止行为2}
```

**Rule 质量约束：**
- 必须 < 50 行
- 聚焦单一关注点（一个 Rule 只管一件事）
- description 必须包含明确的触发条件
- 条目必须具体可操作，不能模糊

**草拟 Skill（SKILL.md 格式）：**

```markdown
---
name: codeman-{skill-name}
description: "{技能描述}。当{触发条件}时使用。"
---

# {Skill 名称}

## 概述
{一段话描述 Skill 的目标}

## 前置条件
{需要读取的文档列表}

## 执行步骤
### Step 1: {步骤名}
{具体操作}

## 产出
{产出清单}
```

**Skill 质量约束：**
- 必须 < 500 行
- description 必须包含明确的触发关键词
- 必须有前置条件、执行步骤、产出三个部分
- 必须包含"不确定即停"规则

### Step 4: 【人工确认点】展示草拟内容

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
自进化建议 — 请确认
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
触发原因：{触发原因描述}
建议创建：{Rule/Skill} — {名称}
适用范围：{L1 全局/L2 项目/L3 模块}

草拟内容：
---
{草拟的 Rule 或 Skill 内容}
---

存放路径：{.codeman/rules/ 或 .codeman/skills/}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
确认创建？（或提出修改意见，或说"取消"）
```

### Step 5: 用户确认后写入

**创建 Rule：**

1. 确定存放路径：
   - L1 全局层：`.codeman/rules/global-{name}.mdc`
   - L2 项目层：`.codeman/rules/proj-{name}.mdc`
   - L3 模块层：`.codeman/rules/mod-{name}.mdc`

2. 写入文件

3. 更新 `.codeman/rules/INDEX.md`：
   ```markdown
   | {规范名} | {文件名} | {层级} | {适用范围} | {创建日期} |
   ```

4. 同步到 `.cursor/rules/`（加 `codeman-` 前缀）：
   ```bash
   cp .codeman/rules/{name}.mdc .cursor/rules/codeman-{name}.mdc
   ```

**创建 Skill：**

1. 确定存放路径：`.codeman/skills/{skill-name}/SKILL.md`

2. 创建目录和文件

3. 更新 `.codeman/skills/INDEX.md`：
   ```markdown
   | {Skill 名} | {目录名} | {触发条件} | {创建日期} |
   ```

4. 注册到 Cursor Agent Skills（提示用户手动操作）：
   ```
   请在 Cursor Settings → Agent → Skills 中添加：
   路径：{项目路径}/.codeman/skills/{skill-name}/SKILL.md
   ```

### Step 6: 确认创建成功

```
自进化完成！
已创建：{Rule/Skill} — {名称}
存放路径：{路径}
同步状态：✅ 已同步到 .cursor/rules/（Rule）

该规范将在后续开发中自动生效。
```

---

## 项目初始化时的批量创建

在 Orchestrator Skill 的 S0 初始化阶段，根据技术栈自动创建基础规范：

**React + TypeScript 项目：**
- `proj-react-component.mdc`（组件规范）
- `proj-typescript-strict.mdc`（TypeScript 严格模式规范）
- `proj-tailwind-styling.mdc`（样式规范，如使用 Tailwind）

**Go 项目：**
- `proj-go-error-handling.mdc`（错误处理规范）
- `proj-go-naming.mdc`（命名规范）

**Python 项目：**
- `proj-python-typing.mdc`（类型注解规范）
- `proj-python-fastapi.mdc`（FastAPI 规范，如使用 FastAPI）

**通用（所有项目）：**
- `global-git-convention.mdc`（已内置）
- `global-code-quality.mdc`（已内置）
- `global-security-baseline.mdc`（已内置）

---

## 产出清单

| 产出 | 路径 | 说明 |
|------|------|------|
| 新 Rule 文件 | `.codeman/rules/{name}.mdc` | 项目规范 |
| 新 Skill 文件 | `.codeman/skills/{name}/SKILL.md` | 工作流 Skill |
| Rules 索引更新 | `.codeman/rules/INDEX.md` | 规范清单 |
| Skills 索引更新 | `.codeman/skills/INDEX.md` | Skill 清单 |
| Cursor 同步 | `.cursor/rules/codeman-*.mdc` | Rules 同步 |

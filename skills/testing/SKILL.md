---
name: codeman-testing
description: "CodeMan 测试验证 Skill。当 CodeMan 工作流进入测试阶段时使用。先根据 PRD 生成 L2-L5 测试用例和自动化脚本，用户确认后逐层执行。由 Orchestrator Skill 调度，或用户说'开始测试'、'测试验证'时触发。"
---

# CodeMan 测试验证 Skill

## 宿主环境说明

**CODEMAN_HOME** 路径规则：Cursor 为 `~/.cursor/skills/.codeman`，Claude Code / OpenCode 为 `~/.claude/skills/.codeman`。

---

## 概述

本 Skill 分两大阶段：**先根据 PRD 生成测试用例和自动化脚本，再逐层执行**。确保所有 PRD 功能点都有对应的测试覆盖。**测试基准来源于 PRD，而非代码。**

```
阶段一：用例生成 + 脚本编写          阶段二：自动化执行
┌──────────────────────────┐    ┌──────────────────────────┐
│ 读取 PRD 验收标准           │    │ L1 单元测试（自动化）      │
│ → 生成 L2 用例 + API 脚本   │    │ L2 集成测试（自动化脚本）   │
│ → 生成 L3 用例 + Playwright │ →  │ L3 E2E 测试（Playwright）  │
│ → 生成 L4 用例 + Midscene   │    │ L4 UI 视觉（Midscene.js）  │
│ → 生成 L5 用例 + 工具命令   │    │ L5 非功能（自动化命令）     │
│ → 生成测试数据初始化脚本     │    │ → 生成测试报告             │
│ → 用户确认用例              │    └──────────────────────────┘
└──────────────────────────┘
```

---

## 核心原则：自动化优先

**能自动化的一律自动化，人工介入是最后手段，不是默认选项。**

| 原则 | 说明 |
|------|------|
| 测试数据自动生成 | 编写 seed/fixture 脚本，不要求用户手动创建数据 |
| UI 操作自动化 | 用 Playwright/Midscene 脚本模拟用户操作，不标记为"待人工" |
| API 调用自动化 | 用测试框架脚本直接调用，不手动 curl |
| 断言自动化 | 每个预期结果都写成代码断言，不用"人工确认是否正确" |
| 降级有明确边界 | 只有当自动化工具本身不可用时才暂停确认，不是"不确定就跳过" |

**标记 `[待人工]` 的唯一条件：** 自动化工具无法安装或运行（如 Playwright MCP 不可用），且没有其他自动化替代方案。不是因为"不想写脚本"或"不好自动化"。

---

## 前置条件

执行前必须完成：

```
1. 读取 .codeman/docs/prd/INDEX.md
   → 获取所有 PRD 功能点（测试基准来源）

2. 读取相关 PRD 碎片文件 feat-*.md
   → 获取验收标准、边界场景、UI 设计要求

3. 读取 .codeman/docs/tests/INDEX.md（如存在）
   → 了解已有测试覆盖，避免重复

4. 读取 .codeman/config.yaml
   → 了解测试框架配置、技术栈

5. 读取 .codeman/docs/DIRECTIVES.md
   → 加载"需求精粹卡"中的关键验收标准
   → 确保每条关键验收标准都有对应测试用例

6. 读取 .codeman/docs/api/INDEX.md 和 api-*.md
   → 了解 API 接口定义（L2 测试需要）
```

---

## 阶段一：测试用例生成 + 自动化脚本编写（L2-L5）

### 核心原则

**每个功能点的测试用例必须从 PRD 验收标准和边界场景中推导，不是从代码反推。每个用例必须附带可执行的自动化脚本。**

用例生成前，逐条读取 PRD 碎片文件（`feat-*.md`）中的：
- `## 功能点明细` 表格中每一行的验收标准
- `## 边界场景` 中列出的每一个边界情况
- `## UI 设计要求` 中的视觉规范（如有）
- `## 数据字典` 中的字段定义
- 需求精粹卡中的关键验收标准（DIRECTIVES.md）

### Step 0: 生成测试数据初始化脚本

**在生成任何测试用例之前，先为项目生成测试数据初始化脚本。** 这是所有自动化测试的基础。

根据 PRD 数据字典和业务规则，生成：

**1) 数据库 Seed 脚本**（如有后端）：
```javascript
// tests/fixtures/seed.js
// 测试数据初始化脚本 — 每次运行测试前自动执行

const TEST_DATA = {
  users: [
    { id: 'test-user-001', email: 'test@example.com', name: '测试用户', role: 'user' },
    { id: 'test-admin-001', email: 'admin@example.com', name: '管理员', role: 'admin' },
  ],
  // 根据 PRD 数据字典生成各类测试数据
};

// 插入测试数据
async function seed() {
  // 清空 → 插入 → 返回 fixtures 引用
}
```

**2) API Mock 数据**（如有外部依赖）：
```javascript
// tests/fixtures/mocks.js
// 外部服务 Mock — 邮件、支付、第三方 API 等
```

**3) 测试前置条件脚本**：
```bash
#!/bin/bash
# tests/setup.sh — 测试环境初始化
# 启动测试数据库 → 运行 seed → 启动测试服务器
```

**所有测试用例的前置条件必须引用这些脚本，而不是要求用户手动操作。**

### Step 1: 生成 L2 集成测试用例 + 可执行脚本

基于 API 接口文档和 PRD 验收标准，为每个接口生成：

**用例来源：**

| 用例类型 | 来源 | 要求 |
|---------|------|------|
| 正常请求 | PRD 功能点明细 → 验收标准 | 每个接口至少 1 个正常路径用例 |
| 鉴权验证 | PRD 约束 + 通用规则 | 无 token → 401；无权限 → 403 |
| 参数校验 | PRD 输入约束 | 缺少必填参数 → 400 + 错误信息 |
| 边界数据 | PRD 边界场景 | 超长字符串、特殊字符、空数组 |
| 幂等性 | PRD 业务规则 | 重复请求的行为是否符合预期 |
| 数据库交互 | PRD 数据规则 | CRUD 正确性、事务回滚、并发一致性 |

**每个用例必须包含可执行的测试脚本**（根据 config.yaml 中的技术栈选择框架）：

```javascript
// tests/integration/api-auth.test.js（示例：Node.js + Jest）
const { TEST_DATA } = require('../fixtures/seed');

describe('F001: 用户注册', () => {
  test('TC-F001-L2-01: 正常注册', async () => {
    const res = await api.post('/api/auth/register', {
      name: '新用户',
      email: `new-${Date.now()}@test.com`,
      password: 'Test1234!'
    });
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('user_id');
    expect(res.body).toHaveProperty('token');
  });

  test('TC-F001-L2-02: 邮箱已存在', async () => {
    // 使用 seed 中已有的用户邮箱
    const res = await api.post('/api/auth/register', {
      name: '重复用户',
      email: TEST_DATA.users[0].email,
      password: 'Test1234!'
    });
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('邮箱已注册');
  });
});
```

**输出格式（写入 test-*.md）：**
```markdown
## TC-{ID}-L2-{NN}: {测试场景名称}

**测试层级：** L2 集成测试
**PRD 来源：** F{ID}.{子ID} — {验收标准原文}
**自动化脚本：** `tests/integration/{文件名}.test.js` → TC-{ID}-L2-{NN}
**测试数据：** 引用 `tests/fixtures/seed.js` 中的 TEST_DATA

**前置条件：**
- 测试数据库已 seed（自动，通过 setup.sh）

**测试步骤：**
1. 调用 {接口}，参数：{参数}
2. 验证响应状态码
3. 验证响应体字段

**预期结果：** {预期的系统响应}

**断言要点：**
- [ ] `expect(res.status).toBe({N})`
- [ ] `expect(res.body).toHaveProperty('{field}')`

**执行状态：** ⬜ 未执行
```

### Step 2: 生成 L3 E2E 端到端测试用例 + Playwright 脚本

**核心原则：每条验收标准对应至少 1 个 E2E 用例，每个用例必须有 Playwright 自动化脚本。**

按以下分类生成测试用例：

| 用例类型 | 来源 | 要求 |
|---------|------|------|
| 正常路径用例 | PRD 功能点明细 → 验收标准 | 每条验收标准至少 1 个 |
| 边界场景用例 | PRD 边界场景 | 每个边界场景至少 1 个 |
| 异常场景用例 | PRD 边界场景中的错误情况 | 每个错误情况至少 1 个 |

**每个用例必须生成 Playwright 自动化脚本**：

```typescript
// tests/e2e/register.spec.ts（示例）
import { test, expect } from '@playwright/test';

test.describe('F001: 用户注册', () => {
  test.beforeEach(async ({ page }) => {
    // 使用 seed 脚本确保测试数据存在
    await page.goto('/register');
  });

  test('TC-F001-L3-01: 正常注册流程', async ({ page }) => {
    await page.fill('[data-testid="name-input"]', '新用户');
    await page.fill('[data-testid="email-input"]', `e2e-${Date.now()}@test.com`);
    await page.fill('[data-testid="password-input"]', 'Test1234!');
    await page.click('[data-testid="submit-btn"]');

    // 验证注册成功
    await expect(page.locator('[data-testid="success-msg"]')).toBeVisible();
    await expect(page).toHaveURL('/dashboard');
  });

  test('TC-F001-L3-02: 邮箱格式错误', async ({ page }) => {
    await page.fill('[data-testid="email-input"]', 'invalid-email');
    await page.fill('[data-testid="password-input"]', 'Test1234!');
    await page.click('[data-testid="submit-btn"]');

    await expect(page.locator('[data-testid="error-msg"]')).toContainText('邮箱格式');
  });
});
```

**输出格式（写入 test-*.md）：**
```markdown
## TC-{ID}-L3-{NN}: {测试场景名称}

**测试层级：** L3 E2E 端到端
**PRD 来源：** F{ID}.{子ID} — {验收标准原文}
**自动化脚本：** `tests/e2e/{文件名}.spec.ts` → TC-{ID}-L3-{NN}

**前置条件：**
- 测试服务器已启动（自动）
- 测试数据已 seed（自动）

**Playwright 脚本：**
```typescript
// 直接附带可执行的测试代码
```

**预期结果：** {预期的系统响应}

**断言要点：**
- [ ] `await expect(page.locator(...)).toBeVisible()`
- [ ] `await expect(page).toHaveURL(...)`

**执行状态：** ⬜ 未执行
```

### Step 3: 生成 L4 UI 视觉测试用例 + Midscene.js 脚本

基于 PRD 碎片文件中的 UI 设计要求，为每个页面/组件生成：

| 用例类型 | 来源 | 要求 |
|---------|------|------|
| 布局验证 | PRD UI 设计要求 | 每个页面至少 1 个布局用例 |
| 交互验证 | PRD 交互规范 | 每个交互流程至少 1 个用例 |
| 设计稿对照 | 设计截图引用 | 有截图的页面必须对照验证 |
| 响应式验证 | PRD 兼容性要求 | 移动端/平板/桌面至少各 1 个 |

**每个用例生成 Midscene.js 自动化脚本 + Playwright 视觉对比脚本**：

```typescript
// tests/visual/register-page.spec.ts
import { test, expect } from '@playwright/test';
import { PuppeteerAgent } from '@midscene/web/puppeteer';

test('TC-F001-L4-01: 注册页面布局验证', async ({ page }) => {
  await page.goto('/register');
  const agent = new PuppeteerAgent(page);

  // Midscene.js 自然语言断言 — 自动化视觉验证
  await agent.aiAssert('注册表单居中显示，宽度约为 400px');
  await agent.aiAssert('主按钮颜色为蓝色，占满表单宽度');
  await agent.aiAssert('输入框有合理的间距，标签在输入框上方');

  // 响应式验证 — 自动化多视口
  await page.setViewportSize({ width: 375, height: 812 });
  await agent.aiAssert('表单在移动端宽度占满屏幕，按钮在表单底部');

  // 截图对比（如有设计稿）
  await expect(page).toHaveScreenshot('register-page.png', {
    maxDiffPixelRatio: 0.05,
  });
});
```

**输出格式（写入 test-*.md）：**
```markdown
## TC-{ID}-L4-{NN}: {测试场景名称}

**测试层级：** L4 UI 视觉测试
**PRD 来源：** F{ID} — {UI 设计要求原文}
**自动化脚本：** `tests/visual/{文件名}.spec.ts` → TC-{ID}-L4-{NN}
**设计截图：** {截图路径，如有}

**Midscene.js 断言（自动化执行）：**
```typescript
await agent.aiAssert('{自然语言描述的 UI 断言}');
```

**Playwright 截图对比（自动化执行）：**
```typescript
await expect(page).toHaveScreenshot('{基准截图}', { maxDiffPixelRatio: 0.05 });
```

**执行状态：** ⬜ 未执行
```

### Step 4: 生成 L5 非功能测试用例 + 自动化命令

根据 config.yaml 中的 `l5_nonfunctional` 配置决定是否生成：

| 用例类型 | 来源 | 要求 |
|---------|------|------|
| 性能测试 | PRD 性能约束 + 通用阈值 | API P95 < 200ms，LCP < 2.5s |
| 安全扫描 | PRD 安全要求 + 通用基线 | 0 个高危漏洞 |
| 可访问性 | PRD 无障碍要求（如有） | 评分 ≥ 90 |

**每个用例生成可直接执行的命令脚本**：

```bash
#!/bin/bash
# tests/nonfunctional/run-performance.sh
npx lighthouse http://localhost:3000 --output=json --output-path=./test-results/lighthouse.json
k6 run tests/nonfunctional/api-perf.js
```

**输出格式（写入 test-*.md）：**
```markdown
## TC-{ID}-L5-{NN}: {测试场景名称}

**测试层级：** L5 非功能测试
**测试类型：** 性能 / 安全 / 可访问性
**自动化脚本：** `tests/nonfunctional/{脚本名}`

**执行命令（自动化）：**
```bash
{可直接执行的命令}
```

**阈值：**
- {具体阈值，如：API 响应时间 P95 < 200ms}

**断言要点：**
- [ ] 自动化脚本输出结果与阈值对比

**执行状态：** ⬜ 未执行
```

### Step 5: 输出用例规划总表并确认

生成完所有用例和脚本后，输出总表等待用户确认：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
测试用例规划总表
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
功能点：{N} 个 | PRD 验收标准：{M} 条 | 边界场景：{K} 个

测试数据初始化：
  ✅ tests/fixtures/seed.js — 测试数据自动初始化
  ✅ tests/fixtures/mocks.js — 外部服务 Mock
  ✅ tests/setup.sh — 测试环境自动初始化

L2 集成测试（{X} 个用例，全部自动化）：
  → tests/integration/api-auth.test.js（{N} 个用例）
  → tests/integration/api-users.test.js（{N} 个用例）

L3 E2E 测试（{Y} 个用例，全部 Playwright 自动化）：
  → tests/e2e/register.spec.ts（{N} 个用例）
  → tests/e2e/login.spec.ts（{N} 个用例）

L4 UI 视觉测试（{Z} 个用例，Midscene + Playwright 自动化）：
  → tests/visual/register-page.spec.ts（{N} 个用例）

L5 非功能测试（{W} 个用例，命令行自动化）：
  → tests/nonfunctional/run-performance.sh
  → tests/nonfunctional/run-security.sh

自动化率：{100%} | 人工介入点：{0 个}
总计：{N} 个用例，覆盖 {M} 条验收标准（{覆盖率}%）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
确认后写入测试用例文档和自动化脚本。
```

### Step 6: 写入测试用例文档和自动化脚本

用户确认后：
1. 为每个功能点写入 `.codeman/docs/tests/test-{功能名}.md`
2. 生成所有自动化脚本到项目 `tests/` 目录
3. 更新 `.codeman/docs/tests/INDEX.md`

---

## 阶段二：逐层执行测试

### L1 单元测试

**目标：** 验证开发 Skill 已同步生成的单元测试，补充遗漏的测试用例。

**全部自动化执行：**

1. 运行项目单元测试：
   ```bash
   {项目测试命令，如 npm test / go test ./... / pytest}
   ```

2. 检查覆盖率报告：
   ```bash
   {项目测试命令} --coverage
   ```

3. 覆盖率不达标时，自动补充测试用例：
   - 核心业务逻辑：≥ 80%
   - 工具函数/纯函数：≥ 90%

4. 覆盖维度检查（对每个核心函数/方法）：
   - [ ] 正常路径（标准输入 → 预期输出）
   - [ ] 边界条件（空值、最大/最小值）
   - [ ] 异常输入（非法格式、类型错误）
   - [ ] 错误处理（异常情况的错误响应）

5. 记录测试结果

---

### L2 集成测试

**全部自动化执行：**

1. 运行测试数据初始化脚本：
   ```bash
   bash tests/setup.sh
   ```

2. 运行所有集成测试脚本：
   ```bash
   {项目测试命令} tests/integration/
   ```

3. 每个用例自动执行断言，记录通过/失败

4. 执行记录：
   - 执行状态（通过/失败/跳过）
   - 失败原因（自动从测试框架输出中提取）

---

### L3 E2E 端到端测试

**全部 Playwright 自动化执行：**

1. 启动测试服务器（如适用）：
   ```bash
   npm run dev:test &
   ```

2. 运行测试数据初始化：
   ```bash
   bash tests/setup.sh
   ```

3. 执行所有 E2E 测试脚本：
   ```bash
   npx playwright test tests/e2e/
   ```

4. 自动截图记录通过/失败状态

5. 执行记录：
   - 执行状态（通过/失败/跳过）
   - 失败截图路径
   - 失败原因（自动从 Playwright 输出中提取）

**降级策略：** Playwright MCP 不可用时，使用项目已安装的 Playwright 直接运行（`npx playwright test`），这是标准用法，不需要 MCP。

---

### L4 UI 视觉测试

**全部自动化执行：**

1. 确认 Midscene.js 已安装（如 config.yaml 启用）：
   ```bash
   npm ls @midscene/web || npm install @midscene/web --save-dev
   ```

2. 执行所有视觉测试脚本：
   ```bash
   npx playwright test tests/visual/
   ```

3. 自动化验证内容：
   - Midscene.js 自然语言断言（布局、颜色、间距）
   - Playwright 截图对比（与基准截图差异 ≤ 5%）
   - 响应式多视口验证（375px / 768px / 1440px）

4. 输出自动化 UI 对照表

---

### L5 非功能测试

**全部自动化执行：**

1. 执行性能测试脚本：
   ```bash
   bash tests/nonfunctional/run-performance.sh
   ```

2. 执行安全扫描：
   ```bash
   bash tests/nonfunctional/run-security.sh
   ```

3. 自动化对比阈值，输出通过/失败

---

## 测试执行策略

```
阶段一：用例生成 + 脚本编写
  读取 PRD → 生成测试数据脚本 → 生成 L2 脚本 → 生成 L3 脚本 → 生成 L4 脚本 → 生成 L5 脚本 → 用户确认

阶段二：自动化执行
  setup.sh（测试数据初始化）
  → L1 单元测试（自动化）
  → L2 集成测试（自动化脚本）
  → L3 E2E 测试（Playwright 自动化）
  → L4 UI 视觉（Midscene + Playwright 自动化）
  → L5 非功能（命令行自动化）
  → 生成测试报告
```

---

## 需求覆盖率追踪矩阵

测试完成后，更新 `.codeman/docs/tests/INDEX.md` 中的覆盖矩阵。

**矩阵粒度要求：追踪到验收标准级别（子功能点），不只是功能点级别。**

```markdown
## 需求覆盖率追踪矩阵

| PRD 来源 | 验收标准 / 边界场景 | L1 单元 | L2 集成 | L3 E2E | L4 UI | L5 非功能 | 覆盖状态 |
|---------|-----------------|---------|---------|--------|-------|---------|---------|
| F001.1 {子功能} | {验收标准原文} | ✅ {N}个 | ✅ TC-L2-01 | ✅ TC-L3-01 | ✅ TC-L4-01 | ⬜ | ✅ 完整 |
| F001.1 {子功能} | [边界] {边界场景原文} | ✅ {N}个 | ✅ TC-L2-03 | ✅ TC-L3-03 | ⬜ | ⬜ | ⚠️ 缺UI |
| F001.2 {子功能} | {验收标准原文} | ✅ {N}个 | ⬜ | ⬜ | ⬜ | ⬜ | ❌ 未执行 |
```

**覆盖规则：**
- 每条验收标准：必须有对应 L3 E2E 用例（TC 编号可追溯）
- 每个边界场景：必须有对应 L2 或 L3 用例
- 含业务逻辑的功能点：至少 L1 + L3
- 纯 UI 展示的功能点：至少 L4
- 涉及 UI 交互的功能点：必须有 L4

**覆盖率计算：**
- PRD 验收标准覆盖率 = 有 E2E 用例的验收标准数 / 总验收标准数
- 边界场景覆盖率 = 有测试用例的边界场景数 / 总边界场景数
- 目标：两项均达到 **100%**

**精粹卡验收标准交叉校验：**
生成覆盖矩阵后，额外对照 DIRECTIVES.md 中"需求精粹卡 → 关键验收标准"列表，
逐条确认每条 [A{N}] 验收标准都有 E2E 测试覆盖。如有遗漏，标记为 Critical 级别缺失。

---

## 生成测试报告

测试完成后，生成 `.codeman/docs/tests/test-report-latest.md`：

```markdown
# 测试报告

> 生成时间：{YYYY-MM-DDTHH:MM:SS}
> 版本：{Git commit hash}

## 摘要

| 测试层级 | 用例总数 | 通过 | 失败 | 跳过 | 通过率 | 自动化率 |
|---------|---------|------|------|------|--------|---------|
| L1 单元测试 | {N} | {N} | {N} | {N} | {%} | 100% |
| L2 集成测试 | {N} | {N} | {N} | {N} | {%} | 100% |
| L3 E2E 测试 | {N} | {N} | {N} | {N} | {%} | 100% |
| L4 UI 视觉 | {N} | {N} | {N} | {N} | {%} | 100% |
| L5 非功能 | {N} | {N} | {N} | {N} | {%} | 100% |

## 覆盖率

- 单元测试覆盖率：{%}（目标：核心业务 ≥ 80%）
- PRD 验收标准覆盖率：{%}（目标：100%）
- 测试自动化率：{%}（目标：100%）

## 失败用例

| 用例 | 层级 | 脚本路径 | 失败原因 | 严重程度 |
|------|------|---------|---------|---------|
| {用例名} | L{N} | {脚本路径} | {原因} | {High/Medium/Low} |

## UI 设计对照

不一致项：{N} 个
{对照表}
```

---

## 不确定即停

遇到以下情况必须暂停，严禁自行推测：

- PRD 验收标准描述模糊，不确定测试用例的预期结果
- 测试用例的前置条件不明确（如不确定测试数据应该是什么状态）
- 不确定某个 API 的正确响应格式（文档与实际不一致）
- 发现 PRD 与技术方案矛盾（如 PRD 说"A"，实现是"B"）
- 测试失败但不确定是 bug 还是测试用例写错了
- 不确定某个边界场景应该怎么验证

**暂停格式：**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ 需人工确认
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
关于测试"{不确定点}"，我理解到以下几种可能：

1. {理解A}：[对应的测试方式/预期结果]
2. {理解B}：[对应的测试方式/预期结果]

请问您的意思是哪种？
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 产出清单

| 产出 | 路径 | 说明 |
|------|------|------|
| 测试用例文档 | `.codeman/docs/tests/test-*.md` | 每个功能点的测试用例（L2-L5） |
| 测试数据脚本 | `tests/fixtures/seed.js` | 测试数据自动初始化 |
| Mock 数据 | `tests/fixtures/mocks.js` | 外部服务 Mock |
| 测试环境脚本 | `tests/setup.sh` | 测试环境自动初始化 |
| L2 集成测试脚本 | `tests/integration/*.test.js` | 可执行的 API 测试 |
| L3 E2E 测试脚本 | `tests/e2e/*.spec.ts` | Playwright 自动化脚本 |
| L4 UI 视觉脚本 | `tests/visual/*.spec.ts` | Midscene + Playwright 脚本 |
| L5 非功能脚本 | `tests/nonfunctional/*` | 性能/安全/可访问性脚本 |
| 测试报告 | `.codeman/docs/tests/test-report-latest.md` | 最新测试结果 |
| 覆盖矩阵 | `.codeman/docs/tests/INDEX.md` | 功能点→测试用例映射（L1-L5） |
| STATUS 更新 | `.codeman/docs/STATUS.md` | 测试进度更新 |

---

## 完成后

**全部通过：**
```
测试验证完成！
阶段一：测试用例 {N} 个 + 自动化脚本全部生成
阶段二：自动化执行
  L1 单元测试：{N} 个，通过率 100%
  L2 集成测试：{N} 个，通过率 100%
  L3 E2E 测试：{N} 个，通过率 100%
  L4 UI 视觉：{N} 个，通过率 100%
  L5 非功能：{N} 个，通过率 100%
PRD 验收标准覆盖率：100%
测试自动化率：100%
人工介入点：0 个

下一步：部署清单生成
是否立即开始？
```

**有失败用例：**
```
测试验证发现 {N} 个失败用例，进入修复闭环。
失败详情见 .codeman/docs/tests/test-report-latest.md
```
→ 自动调用修复闭环 Skill

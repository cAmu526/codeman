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
阶段一：用例生成 + 脚本编写               阶段二：逐层执行（门禁自检）
┌──────────────────────────────┐    ┌─────────────────────────────────┐
│ 启动判断（全新 / 续测）         │    │ 代码审查预检 → [门禁]            │
│ → 读取 PRD 验收标准             │    │ L1 单元测试   → [门禁]            │
│ → 生成 L2a DB + L2b API 脚本   │    │ L2a DB 直查   → [门禁]            │
│ → 生成 L3 用例 + Playwright    │ →  │ L2b API 集成  → [门禁]            │
│ → 生成 L4 用例 + Midscene      │    │ L3 E2E 测试   → [门禁]            │
│ → 生成 L5 用例 + 工具命令      │    │ L4 UI 视觉    → [门禁]            │
│ → 生成测试数据初始化脚本        │    │ L5 非功能     → 生成测试报告       │
│ → 用户确认用例                 │    │ （防虚假通过 + 证据审计贯穿全程）  │
└──────────────────────────────┘    └─────────────────────────────────┘
```

---

## 核心原则：自动化优先 + E2E 优先

**能自动化的一律自动化，有 UI 的功能一律用 E2E 浏览器测试。人工介入是最后手段。**

| 原则 | 说明 |
|------|------|
| E2E 优先 | 有 UI 的功能，优先用 Playwright 在浏览器中端到端测试，不只测 API |
| 测试数据通过浏览器创建 | 需要前置数据时，用 Playwright 模拟用户操作创建（如通过注册页面创建用户），不只靠数据库 seed |
| 测试数据自动生成 | 同时提供 seed/fixture 脚本作为快速初始化手段 |
| UI 操作自动化 | 用 Playwright/Midscene 脚本模拟用户操作，不标记为"待人工" |
| API 调用自动化 | 用测试框架脚本直接调用，不手动 curl |
| 断言自动化 | 每个预期结果都写成代码断言，不用"人工确认是否正确" |
| 降级有明确边界 | 只有当自动化工具本身不可用时才暂停确认，不是"不确定就跳过" |

**E2E 优先的具体规则：**
- PRD 功能点有 UI → 必须有 L3 E2E Playwright 脚本（不只是 L2 API 测试）
- 需要创建测试数据 → 优先通过 Playwright 操作 UI 创建（如填写表单、点击按钮），其次用 seed 脚本
- 数据验证 → 通过 Playwright 在浏览器中验证页面展示的数据，不只验证 API 返回值
- 交互流程（注册→登录→操作→验证）→ 用一个完整的 E2E 脚本串起来

**标记 `[待人工]` 的唯一条件：** 自动化工具无法安装或运行（如 Playwright 无法启动浏览器），且没有其他自动化替代方案。不是因为"不想写脚本"或"不好自动化"。

---

## 防虚假通过（不可妥协）

**测试通过的唯一标准是实际执行结果，不是代码审查推断。** 这是本 Skill 最重要的约束。

### 各层级通过的唯一证据

| 测试层级 | 通过的唯一证据 | 严禁行为 |
|---------|-------------|---------|
| L1 单元测试 | 测试框架（pytest/vitest/jest）的实际运行输出 | 仅凭"代码逻辑正确"判定通过 |
| L2 集成测试 | API 脚本或 DB 脚本的实际运行输出 + 响应体/查询结果 | 仅凭代码审查判定接口正确 |
| L3 E2E 测试 | Playwright 脚本实际运行通过 + 截图证据 | 仅凭"页面代码已渲染 xxx"判定通过 |
| L4 UI 视觉 | Midscene.js 断言通过 + Playwright 截图对比结果 | 仅凭"样式看起来正确"判定通过 |
| L5 非功能 | 工具命令实际运行输出（Lighthouse/k6/npm audit） | 仅凭"已配置 xxx"判定通过 |

### 禁止行为清单

以下行为视为**虚假通过**，严格禁止：

1. **推断式通过**：用"代码已实现 xxx""逻辑看起来正确""应该能正常显示"等推断性语言标记通过
2. **跨层级标记**：在代码审查阶段将 L2/L3/L4/L5 用例标记为通过（代码审查只能发现问题，不能证明通过）
3. **无证据通过**：测试报告中「实际结果」栏为空或只有推断描述
4. **环境不可用时标通过**：环境/工具不可用时，必须标记 `⏳ 待验证`，严禁标记 ✅
5. **只验证存在不验证正确**：L3 只检查元素 `toBeVisible()` 不校验布局/交互；L2 只检查 `status 200` 不校验响应数据格式

### 标记 ✅ 前的强制自检

**每个用例标记为 ✅ 通过之前，必须逐项确认以下条件全部为「是」：**

- [ ] 我是否**实际执行**了验证操作（运行脚本 / 发起请求 / 浏览器运行），而非仅审查代码？
- [ ] 「实际结果」栏填写的是**真实观察到的输出**（脚本日志 / API 响应体 / 截图内容），而非推断？
- [ ] 对于 L3/L4 用例，是否有 Playwright 运行结果或截图作为证据？
- [ ] 对于 L2 用例，是否已对照文档校验了响应数据格式（不只是状态码）？
- [ ] 该用例是否在其**对应的执行层级**被标记（而非在代码审查阶段提前标记）？

**任意一项为「否」→ 该用例必须保持 ⏳ 状态，不得标记 ✅。**

---

## 启动判断

执行本 Skill 前，先判断当前是全新测试还是续测。

### 模式 A：全新测试

检查 `.codeman/docs/tests/test-report-latest.md` 是否存在。**若不存在**，进入完整流程（前置条件 → 阶段一 → 阶段二）。

### 模式 B：续测模式（已有测试报告）

**若已存在测试报告**，执行以下步骤：

**① 读取已有报告，统计各状态用例**
- 列出 ✅ 通过、❌ 失败、⏳ 待验证 的数量

**② 对 ✅ 用例做合法性审查（不可跳过）**
- 检查每个标记为 ✅ 的用例，确认其「验证证据」栏有实际执行证据（脚本输出 / API 响应 / 截图）
- 若发现 L2/L3/L4/L5 用例的通过依据是推断性描述（如"代码已实现""逻辑正确"）→ **强制降级为 ⏳**
- 输出降级摘要：降级了多少用例、原因

**③ 检查用例完整性**
- 对照 PRD 功能点和验收标准，检查是否有遗漏的测试场景
- 若有遗漏 → 补充缺失用例后再执行
- 若已完整 → 继续

**④ 增量执行**
- 只执行 ⏳ 和 ❌ 状态的用例，跳过已通过的
- 按 L1 → L2 → L3 → L4 → L5 顺序执行

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

### 双维度分类标注

每个测试用例必须标注**两个维度**：

**维度 1 — 测试层级**（决定测试什么）：L1 / L2 / L3 / L4 / L5（已有体系）

**维度 2 — 自动化程度**（决定怎么执行）：

| 标注 | 适用场景 | 执行策略 |
|------|---------|---------|
| `[全自动]` | 脚本独立运行，无需任何人工介入 | 直接执行，不暂停 |
| `[半自动-认证]` | 需要用户先完成一次登录/授权，之后自动执行 | 整个层级只暂停一次收集凭证，之后批量执行 |
| `[半自动-数据]` | 需要用户提供特定测试数据或前置操作 | 暂停一次收集所有所需数据，之后批量执行 |
| `[待人工]` | 涉及第三方系统操作、文件上传等确实无法自动化的场景 | 汇总后一次性告知用户，集中完成 |

**防滥用规则：**
- `[待人工]` 占比**不得超过总用例的 10%**，超过则说明自动化方案不充分，需优化
- 表单填写、数据创建、页面导航等操作**不允许**标为 `[待人工]`，必须用 Playwright 自动化
- 同类型人工介入**只暂停一次**，之后批量执行，不逐个询问

**用例编号格式：** `TC-{功能ID}-{层级}-{序号} [{自动化程度}]`
示例：`TC-F001-L3-01 [全自动]`、`TC-F002-L2-03 [半自动-认证]`

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

**L2 集成测试用于验证纯后端逻辑（无 UI 交互的场景）。有 UI 的功能由 L3 E2E 覆盖。**

基于 API 接口文档和 PRD 验收标准，为每个接口生成：

**⚠️ 数据格式校验核心原则：响应数据的「预期格式」必须从技术文档（`tech-*.md`）和 API 文档（`api-*.md`）中获取，可结合 PRD 数据字典辅助判断。严禁从代码中反推预期格式——因为代码本身可能就是 bug 的来源。**

**用例来源：**

| 用例类型 | 来源 | 要求 |
|---------|------|------|
| 正常请求 | PRD 功能点明细 → 验收标准 | 每个接口至少 1 个正常路径用例 |
| **响应数据格式** | **API 文档（`api-*.md`）+ 技术文档（`tech-*.md`）** | **每个接口必须校验完整响应结构（见下方详细要求）** |
| 鉴权验证 | PRD 约束 + 通用规则 | 无 token → 401；无权限 → 403 |
| 参数校验 | PRD 输入约束 | 缺少必填参数 → 400 + 错误信息 |
| 边界数据 | PRD 边界场景 | 超长字符串、特殊字符、空数组 |
| 幂等性 | PRD 业务规则 | 重复请求的行为是否符合预期 |
| 数据库交互 | PRD 数据规则 | CRUD 正确性、事务回滚、并发一致性 |

**L2 与 L3 的分工：**

| 测试场景 | L2（API 层） | L3（E2E 浏览器层） |
|---------|-------------|-------------------|
| 接口正确性 | ✅ 直接调用 API 验证 | ✅ 通过浏览器操作触发 API 并验证 |
| 鉴权/权限 | ✅ API 层验证 token | ✅ 浏览器登录→操作→验证权限 |
| 数据创建 | ✅ API 直接创建 | ✅ **优先通过浏览器 UI 操作创建** |
| 用户流程 | ❌ 不覆盖 | ✅ 浏览器完整流程 |
| 页面展示 | ❌ 不覆盖 | ✅ 浏览器验证页面内容 |
| 表单校验 | ✅ API 层验证参数 | ✅ 浏览器填写表单验证提示 |

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

#### 响应数据格式校验要求（L2 必做）

**不能只测接口是否返回数据，必须校验数据格式是否符合 API 文档定义。** 校验粒度如下：

| 校验维度 | 说明 | 示例 |
|---------|------|------|
| 字段完整性 | 响应体包含文档中定义的所有字段，不多不少 | `expect(Object.keys(res.body)).toEqual(expect.arrayContaining(['user_id', 'email', 'role']))` |
| 字段类型 | 每个字段的数据类型与文档一致 | `expect(typeof res.body.user_id).toBe('string')` |
| 枚举值范围 | 枚举类型字段的值在文档允许范围内 | `expect(['user', 'admin', 'editor']).toContain(res.body.role)` |
| 嵌套对象结构 | 嵌套对象的子字段同样逐层校验 | `expect(res.body.profile).toMatchObject({ avatar: expect.any(String), bio: expect.any(String) })` |
| 数组元素格式 | 数组中每个元素的结构和类型一致 | `res.body.items.forEach(item => expect(item).toHaveProperty('id', expect.any(String)))` |
| 日期/时间格式 | 时间字段符合文档约定的格式（如 ISO 8601） | `expect(res.body.created_at).toMatch(/^\d{4}-\d{2}-\d{2}T/)` |
| 分页结构 | 列表接口的分页元数据结构完整 | `expect(res.body.pagination).toMatchObject({ page: expect.any(Number), total: expect.any(Number) })` |
| 空值/可选字段 | 可选字段为 null 或缺失时类型仍正确 | `expect(res.body.nickname === null \|\| typeof res.body.nickname === 'string').toBe(true)` |

**完整校验示例（对照 API 文档）：**

```javascript
// 假设 api-auth.md 定义的 POST /api/auth/register 响应格式为：
// { user_id: string(UUID), email: string, role: enum("user"|"admin"), 
//   profile: { avatar: string|null, bio: string }, created_at: string(ISO8601) }

test('TC-F001-L2-03: 注册响应数据格式校验', async () => {
  const res = await api.post('/api/auth/register', {
    name: '格式校验用户',
    email: `fmt-${Date.now()}@test.com`,
    password: 'Test1234!'
  });

  // 1. 状态码
  expect(res.status).toBe(201);

  // 2. 顶层字段完整性 — 不多不少
  const expectedKeys = ['user_id', 'email', 'role', 'profile', 'created_at'];
  expect(Object.keys(res.body).sort()).toEqual(expectedKeys.sort());

  // 3. 字段类型
  expect(typeof res.body.user_id).toBe('string');
  expect(typeof res.body.email).toBe('string');

  // 4. UUID 格式
  expect(res.body.user_id).toMatch(
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  );

  // 5. 枚举值范围
  expect(['user', 'admin']).toContain(res.body.role);

  // 6. 嵌套对象结构
  expect(res.body.profile).toBeDefined();
  expect(typeof res.body.profile).toBe('object');
  expect(res.body.profile.avatar === null || typeof res.body.profile.avatar === 'string').toBe(true);
  expect(typeof res.body.profile.bio).toBe('string');

  // 7. 日期格式（ISO 8601）
  expect(res.body.created_at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
  expect(new Date(res.body.created_at).toString()).not.toBe('Invalid Date');
});

// 列表接口的数组元素 + 分页结构校验
test('TC-F002-L2-01: 用户列表响应格式校验', async () => {
  const res = await api.get('/api/users?page=1&limit=10');

  expect(res.status).toBe(200);

  // 分页元数据结构
  expect(res.body.pagination).toMatchObject({
    page: expect.any(Number),
    limit: expect.any(Number),
    total: expect.any(Number),
    total_pages: expect.any(Number),
  });

  // 数组元素格式 — 逐个校验结构一致性
  expect(Array.isArray(res.body.items)).toBe(true);
  res.body.items.forEach(user => {
    expect(typeof user.user_id).toBe('string');
    expect(typeof user.email).toBe('string');
    expect(['user', 'admin']).toContain(user.role);
    expect(typeof user.profile).toBe('object');
  });
});
```

**数据格式校验的来源优先级：**
1. **API 文档**（`api-*.md`）中的响应格式定义 — 最权威
2. **技术文档**（`tech-*.md`）中的接口契约 — 补充细节
3. **PRD 数据字典**（`feat-*.md`）中的字段定义 — 辅助判断

**严禁从代码（如 TypeScript interface、数据库 Schema）反推预期格式。** 因为测试的目的就是验证代码实现是否符合文档定义，如果预期来自代码本身，则无法发现代码错误。

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
- [ ] 字段完整性：响应体包含文档定义的所有字段
- [ ] 字段类型：每个字段类型与 API 文档一致
- [ ] 枚举值范围：枚举字段值在文档允许范围内
- [ ] 嵌套对象：子字段结构与文档定义一致
- [ ] 数组元素：每个元素格式与文档定义一致
- [ ] 格式约束：日期、UUID 等特殊格式正确

**数据格式校验来源：** API 文档 `api-{接口名}.md` 第 {N} 节

**执行状态：** ⬜ 未执行
```

### Step 2: 生成 L3 E2E 端到端测试用例 + Playwright 脚本

**核心原则：每条验收标准对应至少 1 个 E2E 用例。所有有 UI 的功能必须通过浏览器端到端测试，不只测 API。不能只验证元素是否存在，还必须根据 PRD 的 UI 原型图校验具体布局和交互逻辑。**

**⚠️ UI 原型图校验核心原则：**

E2E 测试必须对照 PRD 碎片文件（`feat-*.md`）中的以下内容进行校验：
1. **`## 界面原型（ASCII 方框图）`** — 验证页面区域划分、元素排列顺序、控件位置
2. **`## UI 设计要求`** 中的文字描述 — 验证布局、交互、响应式等具体要求
3. **`### 设计资产引用`** 中的设计截图/Figma 链接 — 如有，需读取截图或访问链接对照验证

**当 PRD 文字描述、ASCII 原型图、设计截图/Figma 链接之间存在冲突时，必须暂停并向用户确认以哪个为准，不得自行推测。**

**E2E 测试覆盖要求：**

| 场景 | 要求 | 示例 |
|------|------|------|
| 正常用户流程 | 从用户视角完成整个操作链路 | 注册→登录→访问受保护页面 |
| **布局结构校验** | **对照 ASCII 原型图验证页面区域划分和元素排列** | **侧栏在左、主内容在右、底栏在底部** |
| **CSS 级别校验** | **验证元素间距、对齐、尺寸等样式是否符合设计要求** | **表单宽度 400px、按钮居中、输入框间距 16px** |
| **交互逻辑校验** | **对照 PRD 验证所有交互行为（状态变化、反馈、动画、流程）** | **点击提交→按钮 loading→成功提示→跳转** |
| 数据创建 | 通过浏览器操作 UI 创建测试数据 | 通过表单填写提交创建用户/订单 |
| 数据验证 | 在浏览器中验证页面展示的数据 | 检查列表页显示刚创建的记录 |
| 交互反馈 | 验证用户操作后的页面反馈 | 成功提示、错误提示、loading 状态 |
| 边界场景 | 模拟用户输入边界数据 | 超长文本、空值、特殊字符 |
| 异常场景 | 模拟用户触发错误路径 | 网络断开、重复提交、权限不足 |

按以下分类生成测试用例：

| 用例类型 | 来源 | 要求 |
|---------|------|------|
| 正常路径用例 | PRD 功能点明细 → 验收标准 | 每条验收标准至少 1 个 |
| 边界场景用例 | PRD 边界场景 | 每个边界场景至少 1 个 |
| 异常场景用例 | PRD 边界场景中的错误情况 | 每个错误情况至少 1 个 |

**每个用例必须生成 Playwright 自动化脚本。测试数据优先通过浏览器 UI 操作创建：**

```typescript
// tests/e2e/register.spec.ts（示例）
import { test, expect } from '@playwright/test';

test.describe('F001: 用户注册', () => {
  test('TC-F001-L3-01: 通过浏览器注册并验证', async ({ page }) => {
    // ① 通过浏览器 UI 创建测试数据（不依赖数据库 seed）
    await page.goto('/register');
    await page.fill('[data-testid="name-input"]', '新用户');
    await page.fill('[data-testid="email-input"]', `e2e-${Date.now()}@test.com`);
    await page.fill('[data-testid="password-input"]', 'Test1234!');
    await page.click('[data-testid="submit-btn"]');

    // ② 在浏览器中验证注册结果
    await expect(page.locator('[data-testid="success-msg"]')).toBeVisible();
    await expect(page).toHaveURL('/dashboard');

    // ③ 验证用户数据在页面中正确展示
    await expect(page.locator('[data-testid="user-name"]')).toContainText('新用户');
  });

  test('TC-F001-L3-02: 通过浏览器测试注册表单校验', async ({ page }) => {
    await page.goto('/register');

    // 测试空提交
    await page.click('[data-testid="submit-btn"]');
    await expect(page.locator('[data-testid="error-msg"]')).toContainText('必填');

    // 测试邮箱格式
    await page.fill('[data-testid="email-input"]', 'invalid-email');
    await page.fill('[data-testid="password-input"]', 'Test1234!');
    await page.click('[data-testid="submit-btn"]');
    await expect(page.locator('[data-testid="error-msg"]')).toContainText('邮箱格式');
  });

  test('TC-F001-L3-03: 注册→登录→验证完整流程', async ({ page }) => {
    const email = `e2e-flow-${Date.now()}@test.com`;

    // ① 通过浏览器注册
    await page.goto('/register');
    await page.fill('[data-testid="name-input"]', '流程测试用户');
    await page.fill('[data-testid="email-input"]', email);
    await page.fill('[data-testid="password-input"]', 'Test1234!');
    await page.click('[data-testid="submit-btn"]');
    await expect(page).toHaveURL('/dashboard');

    // ② 登出
    await page.click('[data-testid="logout-btn"]');
    await expect(page).toHaveURL('/login');

    // ③ 用刚注册的账号登录
    await page.fill('[data-testid="email-input"]', email);
    await page.fill('[data-testid="password-input"]', 'Test1234!');
    await page.click('[data-testid="submit-btn"]');
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid="user-name"]')).toContainText('流程测试用户');
  });
});
```

#### 布局结构校验要求（L3 必做）

**不能只验证元素是否存在（`toBeVisible`），还必须对照 PRD 中的 ASCII 原型图和 UI 设计要求验证具体布局。**

**校验维度：**

| 校验维度 | 说明 | 对照来源 |
|---------|------|---------|
| 区域划分 | 页面是否按原型图划分为正确的区域（侧栏、主内容、头部、底栏等） | ASCII 方框图 |
| 元素排列顺序 | 区域内的元素顺序是否与原型一致 | ASCII 方框图 |
| 元素间距/对齐 | 间距、对齐方式是否符合设计要求 | UI 设计要求 + 设计截图 |
| 尺寸约束 | 元素宽高是否在设计要求的范围内 | UI 设计要求 + 设计截图 |
| 响应式布局 | 不同视口下布局是否正确变化 | UI 设计要求中的响应式描述 |

**布局校验示例：**

```typescript
// 假设 PRD ASCII 原型图为：
// ┌──────────────────────────────────────┐
// │  注册页面                       [×]  │
// ├──────────────────────────────────────┤
// │         ┌────────────────┐          │
// │         │ Logo           │          │
// │         │ [姓名输入框]    │          │
// │         │ [邮箱输入框]    │          │
// │         │ [密码输入框]    │          │
// │         │ [注册按钮]      │          │
// │         │ 已有账号？登录   │          │
// │         └────────────────┘          │
// └──────────────────────────────────────┘

test('TC-F001-L3-04: 注册页面布局结构校验', async ({ page }) => {
  await page.goto('/register');

  // ① 区域划分 — 对照 ASCII 原型：表单居中显示
  const form = page.locator('[data-testid="register-form"]');
  const formBox = await form.boundingBox();
  const viewport = page.viewportSize();
  // 表单水平居中（左右边距近似相等）
  const leftMargin = formBox.x;
  const rightMargin = viewport.width - formBox.x - formBox.width;
  expect(Math.abs(leftMargin - rightMargin)).toBeLessThan(20);

  // ② 元素排列顺序 — 对照 ASCII 原型：Logo → 姓名 → 邮箱 → 密码 → 按钮 → 登录链接
  const logo = page.locator('[data-testid="logo"]');
  const nameInput = page.locator('[data-testid="name-input"]');
  const emailInput = page.locator('[data-testid="email-input"]');
  const passwordInput = page.locator('[data-testid="password-input"]');
  const submitBtn = page.locator('[data-testid="submit-btn"]');
  const loginLink = page.locator('[data-testid="login-link"]');

  const [logoBox, nameBox, emailBox, pwdBox, btnBox, linkBox] = await Promise.all([
    logo.boundingBox(), nameInput.boundingBox(), emailInput.boundingBox(),
    passwordInput.boundingBox(), submitBtn.boundingBox(), loginLink.boundingBox(),
  ]);
  // 垂直排列顺序正确
  expect(logoBox.y).toBeLessThan(nameBox.y);
  expect(nameBox.y).toBeLessThan(emailBox.y);
  expect(emailBox.y).toBeLessThan(pwdBox.y);
  expect(pwdBox.y).toBeLessThan(btnBox.y);
  expect(btnBox.y).toBeLessThan(linkBox.y);

  // ③ 尺寸约束 — 对照 UI 设计要求中的具体数值（如有）
  // 按钮宽度与表单同宽（占满表单宽度）
  expect(Math.abs(btnBox.width - formBox.width)).toBeLessThan(40);
});
```

#### 交互逻辑校验要求（L3 必做）

**不能只验证最终结果，必须对照 PRD 验证完整的交互流程：状态变化、过渡反馈、条件分支等。**

**校验维度：**

| 校验维度 | 说明 | 对照来源 |
|---------|------|---------|
| 状态变化 | 操作前后 UI 状态的完整变化链路 | PRD 功能点明细 + 业务流程图 |
| 表单反馈 | 校验提示的时机、内容、位置 | PRD 边界场景 + UI 设计要求 |
| Loading/过渡态 | 异步操作的 loading 指示和过渡效果 | PRD UI 设计要求中的交互描述 |
| 条件分支 | 不同条件下的 UI 响应是否符合流程图 | PRD 业务功能流程图 |
| 禁用/启用逻辑 | 按钮、输入框等的启用/禁用条件 | PRD 业务规则 |
| 动画/过渡效果 | 出现/消失动画是否符合设计要求 | UI 设计要求 |

**交互逻辑校验示例：**

```typescript
test('TC-F001-L3-05: 注册表单交互逻辑校验', async ({ page }) => {
  await page.goto('/register');

  // ① 初始状态 — 按钮禁用（表单未填写时）
  const submitBtn = page.locator('[data-testid="submit-btn"]');
  await expect(submitBtn).toBeDisabled();  // 对照 PRD 业务规则

  // ② 填写过程中的实时反馈
  await page.fill('[data-testid="email-input"]', 'invalid');
  await page.locator('[data-testid="password-input"]').focus(); // 触发 blur
  await expect(page.locator('[data-testid="email-error"]')).toContainText('邮箱格式');

  // ③ 表单完整填写后按钮启用
  await page.fill('[data-testid="name-input"]', '用户');
  await page.fill('[data-testid="email-input"]', `test-${Date.now()}@test.com`);
  await page.fill('[data-testid="password-input"]', 'Test1234!');
  await expect(submitBtn).toBeEnabled();

  // ④ 提交后的 Loading 状态 — 对照 PRD "点击提交后显示 loading"
  await submitBtn.click();
  await expect(submitBtn).toHaveAttribute('data-loading', 'true');
  // 或检查 loading 指示器
  await expect(page.locator('[data-testid="loading-spinner"]')).toBeVisible();

  // ⑤ 成功后的反馈 — 对照 PRD "注册成功显示提示并跳转"
  await expect(page.locator('[data-testid="success-toast"]')).toBeVisible();
  await expect(page.locator('[data-testid="success-toast"]')).toContainText('注册成功');
  await expect(page).toHaveURL('/dashboard');

  // ⑥ 成功提示自动消失 — 对照 PRD "提示 3 秒后自动消失"（如有此要求）
  await page.waitForTimeout(3500);
  await expect(page.locator('[data-testid="success-toast"]')).not.toBeVisible();
});
```

**测试报告中的不符合项记录：** 当交互逻辑与 PRD 描述不一致时，测试报告必须明确记录：
- 哪个交互行为不符合
- PRD 中的原文描述是什么
- 实际行为是什么
- 严重程度（Critical / Major / Minor）

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
- [ ] 元素可见性：`await expect(page.locator(...)).toBeVisible()`
- [ ] 页面跳转：`await expect(page).toHaveURL(...)`
- [ ] 布局结构：区域划分和元素排列顺序与 ASCII 原型一致
- [ ] CSS 级别：间距、对齐、尺寸符合 UI 设计要求
- [ ] 交互逻辑：状态变化、Loading 反馈、条件分支与 PRD 一致
- [ ] 表单反馈：校验提示的时机、内容、位置与 PRD 一致

**布局校验来源：** PRD `feat-{ID}.md` → `## 界面原型（ASCII 方框图）` + `## UI 设计要求`
**交互校验来源：** PRD `feat-{ID}.md` → `## 功能点明细` + `## 业务功能流程图` + `## 边界场景`

**执行状态：** ⬜ 未执行
```

### Step 3: 生成 L4 UI 视觉测试用例 + Midscene.js 脚本

基于 PRD 碎片文件中的 UI 设计要求、ASCII 原型图、设计截图/Figma 链接，为每个页面/组件生成：

**⚠️ L4 视觉测试不仅是"截图看着像不像"，而是逐项对照 PRD 中所有 UI 规格进行结构化校验。**

| 用例类型 | 来源 | 要求 |
|---------|------|------|
| 布局结构验证 | PRD ASCII 方框图 + UI 设计要求 | 每个页面至少 1 个布局用例，验证区域划分和元素位置 |
| 样式细节验证 | UI 设计要求 + 设计截图 | 颜色、字号、间距、圆角等 CSS 级别样式 |
| 交互视觉验证 | PRD 交互规范 + UI 设计要求 | hover/focus/active/disabled 等状态的视觉变化 |
| 设计稿对照 | 设计截图引用 / Figma 链接 | 有截图/链接的页面必须读取并逐项对照验证 |
| 响应式验证 | PRD 兼容性要求 | 移动端/平板/桌面至少各 1 个 |

**多来源冲突处理规则：**
- PRD 文字描述、ASCII 原型图、设计截图/Figma 如果存在冲突 → **必须暂停，向用户确认以哪个为准**
- 确认后在用例中标注「校验基准来源」，并记录冲突详情供后续追踪

**每个用例生成 Midscene.js 自动化脚本 + Playwright 视觉对比脚本。校验内容必须直接对照 PRD 原文，而非凭感觉判断：**

```typescript
// tests/visual/register-page.spec.ts
import { test, expect } from '@playwright/test';
import { PuppeteerAgent } from '@midscene/web/puppeteer';

test('TC-F001-L4-01: 注册页面布局与样式验证', async ({ page }) => {
  await page.goto('/register');
  const agent = new PuppeteerAgent(page);

  // ——— 1. 布局结构校验（对照 ASCII 方框图）———
  // ASCII 原型：表单居中，内含 Logo→输入框×3→按钮→链接
  await agent.aiAssert('页面中央有一个注册表单卡片');
  await agent.aiAssert('表单内从上到下依次是：Logo、姓名输入框、邮箱输入框、密码输入框、注册按钮、登录链接');

  // ——— 2. 样式细节校验（对照 UI 设计要求文字描述）———
  // PRD: "主按钮颜色为品牌蓝 #1677FF，字号 16px，圆角 8px"
  const submitBtn = page.locator('[data-testid="submit-btn"]');
  const btnStyles = await submitBtn.evaluate(el => {
    const s = getComputedStyle(el);
    return { bg: s.backgroundColor, fontSize: s.fontSize, borderRadius: s.borderRadius };
  });
  expect(btnStyles.bg).toBe('rgb(22, 119, 255)'); // #1677FF
  expect(btnStyles.fontSize).toBe('16px');
  expect(btnStyles.borderRadius).toBe('8px');

  // Midscene.js 自然语言断言 — 补充人眼级别判断
  await agent.aiAssert('主按钮颜色为蓝色，占满表单宽度');
  await agent.aiAssert('输入框有合理的间距，标签在输入框上方');

  // ——— 3. 交互状态视觉校验 ———
  // PRD: "输入框 focus 时边框变为品牌蓝"
  await page.locator('[data-testid="email-input"]').focus();
  const focusBorder = await page.locator('[data-testid="email-input"]').evaluate(el =>
    getComputedStyle(el).borderColor
  );
  expect(focusBorder).toBe('rgb(22, 119, 255)');

  // ——— 4. 响应式验证（对照 UI 设计要求中的响应式描述）———
  await page.setViewportSize({ width: 375, height: 812 }); // 移动端
  await agent.aiAssert('表单在移动端宽度占满屏幕，无水平滚动条');
  await agent.aiAssert('按钮在表单底部，可触达');

  await page.setViewportSize({ width: 768, height: 1024 }); // 平板
  await agent.aiAssert('表单居中显示，宽度适中');

  // ——— 5. 设计截图对比（如有设计稿）———
  await page.setViewportSize({ width: 1440, height: 900 }); // 恢复桌面尺寸
  await expect(page).toHaveScreenshot('register-page.png', {
    maxDiffPixelRatio: 0.05,
  });
});

test('TC-F001-L4-02: 注册页面交互视觉状态验证', async ({ page }) => {
  await page.goto('/register');

  // 按钮 disabled 状态的视觉样式
  const submitBtn = page.locator('[data-testid="submit-btn"]');
  const disabledOpacity = await submitBtn.evaluate(el => getComputedStyle(el).opacity);
  expect(parseFloat(disabledOpacity)).toBeLessThan(1); // 禁用状态应有视觉区分

  // 错误提示的视觉样式 — 对照 PRD "错误提示为红色文字"
  await page.fill('[data-testid="email-input"]', 'invalid');
  await page.locator('[data-testid="password-input"]').focus();
  const errorColor = await page.locator('[data-testid="email-error"]').evaluate(el =>
    getComputedStyle(el).color
  );
  expect(errorColor).toMatch(/rgb\(2[0-5]\d, [0-5]?\d, [0-5]?\d\)/); // 红色系
});
```

**读取外部设计资产的处理规则：**
- **设计截图文件**（`.codeman/assets/design/*.png` 等）：利用 AI 多模态能力读取截图，逐项对照 PRD 文字描述验证
- **Figma 链接**：如能通过 Figma API 或 MCP 工具获取设计稿信息，自动获取并对照；否则标注为「需人工对照 Figma」
- **无设计资产**：仅对照 PRD 文字描述和 ASCII 原型图校验，在测试报告中标注「无设计稿，仅对照 PRD 文字描述」

**输出格式（写入 test-*.md）：**
```markdown
## TC-{ID}-L4-{NN}: {测试场景名称}

**测试层级：** L4 UI 视觉测试
**PRD 来源：** F{ID} — {UI 设计要求原文}
**自动化脚本：** `tests/visual/{文件名}.spec.ts` → TC-{ID}-L4-{NN}
**设计截图：** {截图路径，如有}
**校验基准来源：** {PRD 文字描述 / ASCII 原型图 / 设计截图 / Figma 链接}
**多来源冲突：** {无冲突 / 已确认以 {来源} 为准}

**校验维度（逐项对照 PRD）：**

布局结构（对照 ASCII 原型图）：
- [ ] 区域划分与原型一致
- [ ] 元素排列顺序与原型一致
- [ ] 控件位置（左/右/居中等）与原型一致

样式细节（对照 UI 设计要求）：
- [ ] 颜色（背景、文字、边框）与设计要求一致
- [ ] 字号/字重与设计要求一致
- [ ] 间距/圆角等 CSS 细节与设计要求一致

交互状态视觉（对照 UI 设计要求 + 交互描述）：
- [ ] hover/focus/active/disabled 状态视觉反馈正确
- [ ] 错误/成功提示样式与设计一致

设计稿对照：
- [ ] Midscene.js 自然语言断言通过
- [ ] Playwright 截图对比差异 ≤ 5%
- [ ] 设计截图/Figma 逐项对照（如有）

响应式（对照响应式要求）：
- [ ] 移动端（375px）布局正确
- [ ] 平板（768px）布局正确
- [ ] 桌面（1440px）布局正确

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

用例已确认，按以下顺序逐层执行：**代码审查（预检）→ L1 → L2a DB 直查 → L2b API 集成 → L3 → L4 → L5**。

每层执行完毕后必须输出**层间门禁自检**（见后文），确认当层状态正确后才进入下一层。

### 预检步骤：代码审查

**目标：** 在自动化测试执行前，先通过代码审查发现逻辑错误、规范问题、边界遗漏。

**代码审查检查项：**
- 实现是否符合技术方案
- 是否有逻辑错误、类型错误
- 是否遵循项目代码规范（读取 `.codeman/rules/` 中的规则）
- 是否有遗漏的边界情况
- 数据库迁移脚本是否安全（如有）

**⚠️ 代码审查的严格限制：**

代码审查**只能**做以下事情：
1. 发现问题并记录到测试报告「发现的问题」表格
2. 确认代码逻辑层面的正确性（如：算法正确、SQL 合理）

代码审查**严禁**做以下事情：
1. **严禁将 L2/L3/L4/L5 任何用例标记为 ✅ 通过** — 无论代码看起来多正确
2. **严禁用"代码已实现 xxx"作为任何功能性用例的通过依据**

**代码审查完成后输出：**
```
【代码审查预检完成】
- 发现问题：{N} 个（已记录到「发现的问题」表格）
- 严重问题（阻塞测试执行）：{N} 个
- L2-L5 用例状态：全部保持 ⏳（未执行任何自动化测试，不允许标记通过）
→ 进入 L1 单元测试
```

> 若有严重问题（如核心逻辑错误），应暂停执行，等修复后再继续。

---

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

### L2a 数据库直查测试

**目标：** 绕过 API 层，直连数据库验证表结构、迁移、初始数据、约束等。无需 API 认证，可在服务未启动时运行。

**适用场景（有后端数据库时）：**
- 迁移脚本是否正确创建了表结构、字段、索引
- 初始化数据是否正确插入（枚举值、配置项等）
- 外键约束、唯一约束是否生效
- 字段类型、默认值是否与技术文档一致

**执行步骤：**

1. 确认数据库连接可用
2. 运行 DB 直查脚本：
   ```bash
   {数据库测试命令，如 python tests/db/test_db_direct.py / node tests/db/db-check.js}
   ```
3. 每个用例直接查询数据库验证，无需 API 认证
4. 记录通过/失败状态

**DB 脚本设计原则：**
- **只读查询**：DB 直查脚本只做 SELECT，不修改数据
- **无需认证**：直连数据库，不依赖 API Token
- **独立运行**：服务未启动也能执行

> 若项目无后端数据库（纯前端项目），跳过此步骤。

---

### L2b API 集成测试

**全部自动化执行：**

1. 运行测试数据初始化脚本：
   ```bash
   bash tests/setup.sh
   ```

2. 运行所有 API 集成测试脚本：
   ```bash
   {项目测试命令} tests/integration/
   ```

3. 每个用例自动执行断言（包括响应数据格式校验），记录通过/失败

4. **认证处理策略：**
   - `[全自动]` 用例：使用 seed 脚本生成的测试 Token，直接执行
   - `[半自动-认证]` 用例：整个 L2b 层级**只暂停一次**请求用户提供 Token，收到后批量执行所有需认证的用例

5. 执行记录：
   - 执行状态（通过/失败/跳过）
   - 失败原因（自动从测试框架输出中提取）
   - **验证证据**（API 响应体摘要 / 脚本输出行号）

---

### L3 E2E 端到端测试

**全部 Playwright 浏览器自动化执行。这是有 UI 功能的主要测试方式。**

1. 启动测试服务器（如适用）：
   ```bash
   npm run dev:test &
   ```

2. 运行基础数据初始化（如有需要）：
   ```bash
   bash tests/setup.sh
   ```

3. 执行所有 E2E 测试脚本（浏览器自动打开、操作、验证）：
   ```bash
   npx playwright test tests/e2e/
   ```

4. E2E 脚本会自动完成：
   - 打开浏览器，导航到目标页面
   - **通过 UI 操作创建测试数据**（填写表单、点击按钮）
   - **通过 UI 操作完成用户流程**（注册→登录→操作→验证）
   - **在浏览器中验证页面展示**（文字内容、元素可见性、URL 跳转）
   - 自动截图记录通过/失败状态

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
  读取 PRD → 生成测试数据脚本 → 生成 L2a DB 脚本 → 生成 L2b API 脚本 → 生成 L3 脚本 → 生成 L4 脚本 → 生成 L5 脚本 → 用户确认

阶段二：逐层执行（每层之间有门禁自检）
  代码审查预检 → [门禁] →
  L1 单元测试 → [门禁] →
  L2a DB 直查 → [门禁] →
  L2b API 集成 → [门禁] →
  L3 E2E 测试 → [门禁] →
  L4 UI 视觉 → [门禁] →
  L5 非功能 →
  生成测试报告
```

### 层间门禁自检（强制执行）

**每层执行完毕后，必须输出以下格式的自检报告，确认当层状态正确后才能进入下一层。** 此机制防止跨层级标记通过。

**门禁自检输出格式：**

```
【{层级名称} 完成 — 门禁自检】
- 本层用例：共 {N} 个
  - ✅ 通过：{N} 个（均有实际执行证据）
  - ❌ 失败：{N} 个
  - ⏳ 待验证：{N} 个
- 验证方式：{实际运行的命令/工具}
- 后续层级用例状态确认：L{X}-L{Y} 共 {N} 个用例，全部保持 ⏳（未执行，不允许标记通过）
→ 进入 {下一层级名称}
```

**门禁检查规则：**
1. **本层所有用例必须有明确状态**（✅ / ❌ / ⏳），不得遗漏
2. **本层 ✅ 用例必须有实际执行证据**，若发现无证据的 ✅ → 强制降级为 ⏳
3. **后续层级用例必须全部为 ⏳**，若发现后续层级用例已被标记 ✅ → 强制降级并警告
4. **本层有 Critical 级别失败**时 → 暂停，询问用户是否继续或先修复

---

## 需求覆盖率追踪矩阵

测试完成后，更新 `.codeman/docs/tests/INDEX.md` 中的覆盖矩阵。

**矩阵粒度要求：追踪到验收标准级别（子功能点），不只是功能点级别。**

```markdown
## 需求覆盖率追踪矩阵

| PRD 来源 | 验收标准 / 边界场景 | L1 单元 | L2a DB | L2b API | L3 E2E | L4 UI | L5 非功能 | 覆盖状态 |
|---------|-----------------|---------|--------|---------|--------|-------|---------|---------|
| F001.1 {子功能} | {验收标准原文} | ✅ {N}个 | ✅ TC-L2a-01 | ✅ TC-L2b-01 | ✅ TC-L3-01 | ✅ TC-L4-01 | ⬜ | ✅ 完整 |
| F001.1 {子功能} | [边界] {边界场景原文} | ✅ {N}个 | ⬜ | ✅ TC-L2b-03 | ✅ TC-L3-03 | ⬜ | ⬜ | ⚠️ 缺UI |
| F001.2 {子功能} | {验收标准原文} | ✅ {N}个 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ❌ 未执行 |
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
> 模式：{全新测试 / 续测（第 N 次）}

## 摘要

| 测试层级 | 用例总数 | ✅ 通过 | ❌ 失败 | ⏳ 待验证 | 通过率 | 自动化率 |
|---------|---------|--------|--------|----------|--------|---------|
| 代码审查 | {N} | {N} | {N} | — | {%} | — |
| L1 单元测试 | {N} | {N} | {N} | {N} | {%} | {%} |
| L2a DB 直查 | {N} | {N} | {N} | {N} | {%} | {%} |
| L2b API 集成 | {N} | {N} | {N} | {N} | {%} | {%} |
| L3 E2E 测试 | {N} | {N} | {N} | {N} | {%} | {%} |
| L4 UI 视觉 | {N} | {N} | {N} | {N} | {%} | {%} |
| L5 非功能 | {N} | {N} | {N} | {N} | {%} | {%} |

**各层通过分布（必须逐层列出，不可笼统合并）：**
- 代码审查发现问题：{N} 个
- L1 单元测试通过：{N} 个（运行命令：`{命令}`）
- L2a DB 直查通过：{N} 个（运行命令：`{命令}`）
- L2b API 集成通过：{N} 个（运行命令：`{命令}`）
- L3 E2E 测试通过：{N} 个（运行命令：`{命令}`，截图证据 {N} 张）
- L4 UI 视觉通过：{N} 个（运行命令：`{命令}`）
- L5 非功能通过：{N} 个（运行命令：`{命令}`）

## 覆盖率

- 单元测试覆盖率：{%}（目标：核心业务 ≥ 80%）
- PRD 验收标准覆盖率：{%}（目标：100%）
- 测试自动化率：{%}（目标：≥ 90%，`[待人工]` 占比 ≤ 10%）

## 用例明细

> ⚠️ **填写规范：**
> - 「实际结果」列必须填写**实际观察到的输出**（脚本日志 / API 响应体 / 截图内容），不得填写"代码已实现""逻辑正确"等推断性文字
> - 「验证证据」列必须填写具体证据（脚本运行输出 / API 响应摘要 / 截图路径），✅ 用例此列不得为空
> - 每个用例必须在其对应层级被标记，不得跨层级标记

| 编号 | 测试场景 | 层级 | 自动化程度 | 预期结果 | 实际结果 | 验证证据 | 状态 |
|------|---------|------|-----------|---------|---------|---------|------|
| TC-F001-L2b-01 | {场景} | L2b | [全自动] | {预期} | {实际输出} | {脚本输出/响应体} | ✅/❌/⏳ |

## 发现的问题

| 编号 | 问题描述 | 严重程度 | 发现阶段 | 处理方案 | 状态 |
|------|---------|---------|---------|---------|------|
| B-01 | {问题描述} | Critical/Major/Minor | {代码审查/L1/L2/L3/L4/L5} | {修复方案} | ✅ 已修复 / 🔧 待修复 |

## 失败用例

| 用例 | 层级 | 脚本路径 | 失败原因 | 严重程度 |
|------|------|---------|---------|---------|
| {用例名} | L{N} | {脚本路径} | {原因} | {High/Medium/Low} |

## API 数据格式不符合项

| 接口 | 字段路径 | API 文档定义 | 实际返回 | 严重程度 |
|------|---------|-------------|---------|---------|
| {接口路径} | {如 res.body.profile.avatar} | {文档定义：string\|null} | {实际：number} | {Critical/Major/Minor} |

## UI 布局/交互不符合项

| 页面 | 校验维度 | PRD 原文描述 | 实际表现 | 校验来源 | 严重程度 |
|------|---------|-------------|---------|---------|---------|
| {页面名} | {布局/样式/交互} | {PRD 中的原文描述} | {实际的页面表现} | {ASCII 原型/设计截图/UI 要求} | {Critical/Major/Minor} |

## UI 设计对照

不一致项：{N} 个（布局 {N} + 样式 {N} + 交互 {N} + 数据格式 {N}）
{对照表}

## 通过合法性审计（续测模式专用）

> 仅续测模式填写。全新测试可省略此节。

| 用例编号 | 原状态 | 审计结果 | 原因 |
|---------|--------|---------|------|
| {TC-xxx} | ✅ | 维持 ✅ / 降级为 ⏳ | {有脚本输出证据 / 缺乏实际验证证据} |
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
- **PRD 文字描述、ASCII 原型图、设计截图/Figma 链接之间存在冲突**（如原型图显示按钮在左，设计稿显示按钮在右）
- **API 文档与技术文档中的响应格式定义不一致**（如字段类型或结构不同）

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
| L2a DB 直查脚本 | `tests/db/*` | 数据库表结构/迁移/初始数据验证 |
| L2b API 集成脚本 | `tests/integration/*.test.js` | 可执行的 API 测试 + 格式校验 |
| L3 E2E 测试脚本 | `tests/e2e/*.spec.ts` | Playwright 自动化脚本 |
| L4 UI 视觉脚本 | `tests/visual/*.spec.ts` | Midscene + Playwright 脚本 |
| L5 非功能脚本 | `tests/nonfunctional/*` | 性能/安全/可访问性脚本 |
| 测试报告 | `.codeman/docs/tests/test-report-latest.md` | 最新测试结果（含验证证据和合法性审计） |
| 覆盖矩阵 | `.codeman/docs/tests/INDEX.md` | 功能点→测试用例映射（L1-L5） |
| STATUS 更新 | `.codeman/docs/STATUS.md` | 测试进度更新 |

---

## 完成后

**全部通过：**
```
测试验证完成！
阶段一：测试用例 {N} 个 + 自动化脚本全部生成
阶段二：逐层执行（每层均通过门禁自检）
  代码审查：发现 {N} 个问题，已修复
  L1 单元测试：{N} 个，通过率 100%
  L2a DB 直查：{N} 个，通过率 100%
  L2b API 集成：{N} 个，通过率 100%
  L3 E2E 测试：{N} 个，通过率 100%
  L4 UI 视觉：{N} 个，通过率 100%
  L5 非功能：{N} 个，通过率 100%
PRD 验收标准覆盖率：100%
测试自动化率：{%}（[待人工] {N} 个，占比 {%}）
虚假通过检查：0 个降级

下一步：部署清单生成
是否立即开始？
```

**有失败用例：**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
测试发现 {N} 个失败用例
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
失败用例：
  ❌ {用例名}（{层级}）— {失败原因}
  ❌ {用例名}（{层级}）— {失败原因}

失败详情见 .codeman/docs/tests/test-report-latest.md

是否立即进入修复闭环？（直接回复即可，或说"先跳过"/"只修 {用例名}"）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

用户确认后 → 自动调用修复闭环 Skill

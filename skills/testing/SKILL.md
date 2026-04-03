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
│ → 生成测试数据初始化脚本        │    │ 兼容性测试    → [门禁]            │
│ → 用户确认用例                 │    │ L5 非功能     → 生成测试报告       │
│                                │    │ （防虚假通过 + 证据审计贯穿全程）  │
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

#### 前端交互场景全覆盖（L3 用例生成必须逐项检查）

**生成 L3 用例时，必须逐项检查以下 8 类前端交互场景。对每类场景，对照 PRD 功能点明细、业务流程图、UI 设计要求判断是否涉及。涉及的场景必须生成对应用例，不得遗漏。**

##### 场景 1：条件联动 UI

**触发条件：** PRD 中有"当 X 时显示 Y""根据类型切换""选择后联动"等描述。

**用例生成规则：**
- 每个联动条件至少 1 个正向用例（选 A → 出现 X）+ 1 个切换用例（选 A → 切换到 B → X 消失，Y 出现）
- 验证联动后的字段必填/选填状态是否同步变化
- 验证联动字段的默认值是否正确重置

```typescript
test('TC-F003-L3-01: 客户类型联动字段显示', async ({ page }) => {
  await page.goto('/customer/create');

  // ① 选择"企业客户" → 出现企业专属字段
  await page.selectOption('[data-testid="customer-type"]', 'enterprise');
  await expect(page.locator('[data-testid="company-name"]')).toBeVisible();
  await expect(page.locator('[data-testid="tax-number"]')).toBeVisible();
  await expect(page.locator('[data-testid="personal-id"]')).not.toBeVisible();

  // ② 切换为"个人客户" → 企业字段消失，个人字段出现
  await page.selectOption('[data-testid="customer-type"]', 'personal');
  await expect(page.locator('[data-testid="company-name"]')).not.toBeVisible();
  await expect(page.locator('[data-testid="tax-number"]')).not.toBeVisible();
  await expect(page.locator('[data-testid="personal-id"]')).toBeVisible();

  // ③ 验证切换后之前填写的数据被正确清空
  // （先填企业名 → 切回企业 → 应为空）
  await page.selectOption('[data-testid="customer-type"]', 'enterprise');
  await expect(page.locator('[data-testid="company-name"]')).toHaveValue('');

  // ④ 验证联动后必填标记正确
  await expect(page.locator('[data-testid="company-name-required"]')).toBeVisible();
});
```

##### 场景 2：前端业务计算

**触发条件：** PRD 中有价格计算、统计汇总、百分比、进度、自动填充等前端计算逻辑。

**用例生成规则：**
- 每个计算逻辑至少覆盖：正常计算、边界值（0、最大值）、精度（小数点）
- 验证计算结果的显示格式（千分位、货币符号、百分号等）
- 验证输入变化时计算结果实时更新

```typescript
test('TC-F004-L3-01: 订单金额实时计算', async ({ page }) => {
  await page.goto('/order/create');

  // ① 填入数量和单价 → 验证小计实时计算
  await page.fill('[data-testid="quantity"]', '3');
  await page.fill('[data-testid="unit-price"]', '99.9');
  await expect(page.locator('[data-testid="subtotal"]')).toContainText('299.70');

  // ② 填入折扣 → 验证总价更新
  await page.fill('[data-testid="discount"]', '10'); // 10%
  await expect(page.locator('[data-testid="total"]')).toContainText('269.73');

  // ③ 边界值：数量为 0
  await page.fill('[data-testid="quantity"]', '0');
  await expect(page.locator('[data-testid="subtotal"]')).toContainText('0.00');

  // ④ 精度验证：不出现浮点误差（如 0.1+0.2≠0.30000000000000004）
  await page.fill('[data-testid="quantity"]', '1');
  await page.fill('[data-testid="unit-price"]', '0.1');
  const subtotal = await page.locator('[data-testid="subtotal"]').textContent();
  expect(subtotal).not.toContain('0.10000000');

  // ⑤ 显示格式：千分位分隔
  await page.fill('[data-testid="quantity"]', '100');
  await page.fill('[data-testid="unit-price"]', '1234.5');
  await expect(page.locator('[data-testid="subtotal"]')).toContainText('123,450.00');
});
```

##### 场景 3：多步骤向导/流程

**触发条件：** PRD 中有分步骤表单、向导流程、多 Tab 分段填写等描述。

**用例生成规则：**
- 覆盖完整正向流程（step1 → step2 → ... → 完成）
- 覆盖前进/后退按钮逻辑
- 验证步骤间数据保持（返回上一步数据不丢失）
- 验证步骤指示器状态（当前步高亮、已完成步打勾、未达步灰色）
- 验证校验拦截（当前步校验不通过时不能跳到下一步）

```typescript
test('TC-F005-L3-01: 三步注册向导完整流程', async ({ page }) => {
  await page.goto('/register/wizard');

  // ① 步骤指示器初始状态
  await expect(page.locator('[data-testid="step-1"]')).toHaveClass(/active/);
  await expect(page.locator('[data-testid="step-2"]')).toHaveClass(/disabled/);
  await expect(page.locator('[data-testid="step-3"]')).toHaveClass(/disabled/);

  // ② Step 1：填写基本信息 → 下一步
  await page.fill('[data-testid="name"]', '测试用户');
  await page.fill('[data-testid="email"]', 'test@example.com');
  await page.click('[data-testid="next-btn"]');

  // ③ Step 2：步骤指示器更新
  await expect(page.locator('[data-testid="step-1"]')).toHaveClass(/completed/);
  await expect(page.locator('[data-testid="step-2"]')).toHaveClass(/active/);

  // ④ 后退 → 数据保持
  await page.click('[data-testid="prev-btn"]');
  await expect(page.locator('[data-testid="name"]')).toHaveValue('测试用户');
  await expect(page.locator('[data-testid="email"]')).toHaveValue('test@example.com');

  // ⑤ 校验拦截：清空必填字段后点下一步 → 不跳转
  await page.fill('[data-testid="name"]', '');
  await page.click('[data-testid="next-btn"]');
  await expect(page.locator('[data-testid="step-1"]')).toHaveClass(/active/); // 仍在 step1
  await expect(page.locator('[data-testid="name-error"]')).toBeVisible();
});
```

##### 场景 4：动态列表操作

**触发条件：** PRD 中有"添加/删除行""可排序列表""批量操作""分页""搜索筛选"等描述。

**用例生成规则：**
- 添加项：添加后列表数量 +1，新项数据正确
- 删除项：删除后列表数量 -1，确认弹窗（如有）
- 排序：拖拽或点击排序后顺序正确
- 批量操作：全选/部分选 → 批量删除/导出
- 空状态：列表为空时显示空状态提示
- 分页/加载更多：页码切换、数据正确
- 搜索筛选：输入关键词 → 列表过滤 → 清空恢复

```typescript
test('TC-F006-L3-01: 任务列表增删和筛选', async ({ page }) => {
  await page.goto('/tasks');

  // ① 添加项
  const initialCount = await page.locator('[data-testid="task-item"]').count();
  await page.click('[data-testid="add-task-btn"]');
  await page.fill('[data-testid="task-name-input"]', 'E2E 测试任务');
  await page.click('[data-testid="save-btn"]');
  await expect(page.locator('[data-testid="task-item"]')).toHaveCount(initialCount + 1);
  await expect(page.locator('[data-testid="task-item"]').last()).toContainText('E2E 测试任务');

  // ② 搜索筛选
  await page.fill('[data-testid="search-input"]', 'E2E');
  await page.waitForTimeout(500); // 防抖
  const filteredItems = page.locator('[data-testid="task-item"]');
  for (const item of await filteredItems.all()) {
    await expect(item).toContainText('E2E');
  }

  // ③ 清空搜索 → 恢复全量
  await page.fill('[data-testid="search-input"]', '');
  await page.waitForTimeout(500);
  await expect(page.locator('[data-testid="task-item"]')).toHaveCount(initialCount + 1);

  // ④ 删除项（含确认弹窗）
  await page.locator('[data-testid="task-item"]').last().locator('[data-testid="delete-btn"]').click();
  await expect(page.locator('[data-testid="confirm-dialog"]')).toBeVisible();
  await page.click('[data-testid="confirm-yes"]');
  await expect(page.locator('[data-testid="task-item"]')).toHaveCount(initialCount);

  // ⑤ 空状态
  // （假设删除所有后）
  // await expect(page.locator('[data-testid="empty-state"]')).toBeVisible();
  // await expect(page.locator('[data-testid="empty-state"]')).toContainText('暂无任务');
});

test('TC-F006-L3-02: 列表分页', async ({ page }) => {
  await page.goto('/tasks?page=1');

  // ① 第一页有数据
  await expect(page.locator('[data-testid="task-item"]').first()).toBeVisible();

  // ② 点击下一页
  await page.click('[data-testid="next-page"]');
  await expect(page).toHaveURL(/page=2/);
  await expect(page.locator('[data-testid="task-item"]').first()).toBeVisible();

  // ③ 页码指示器
  await expect(page.locator('[data-testid="page-indicator"]')).toContainText('2');
});
```

##### 场景 5：权限差异化 UI

**触发条件：** PRD 中有"管理员可见""仅创建者可编辑""不同角色不同视图"等描述。

**用例生成规则：**
- 每种角色至少 1 个用例，验证该角色能/不能看到的 UI 元素
- 验证无权限操作的拦截方式（按钮隐藏 vs 按钮禁用 vs 点击后提示）
- 标注为 `[半自动-认证]`（需切换账号）

```typescript
test('TC-F007-L3-01: 管理员可见编辑按钮，普通用户不可见', async ({ page }) => {
  // ① 以管理员登录（通过 seed 中的 admin 账号）
  await loginAs(page, 'admin@test.com', 'Admin1234!');
  await page.goto('/settings');
  await expect(page.locator('[data-testid="edit-btn"]')).toBeVisible();
  await expect(page.locator('[data-testid="delete-btn"]')).toBeVisible();

  // ② 以普通用户登录
  await logout(page);
  await loginAs(page, 'user@test.com', 'User1234!');
  await page.goto('/settings');
  await expect(page.locator('[data-testid="edit-btn"]')).not.toBeVisible();
  await expect(page.locator('[data-testid="delete-btn"]')).not.toBeVisible();

  // ③ 验证 URL 直接访问受限页面 → 跳转或提示
  await page.goto('/admin/dashboard');
  // 应跳转到无权限页面或显示提示
  const url = page.url();
  const hasPermissionDenied =
    url.includes('/403') ||
    url.includes('/login') ||
    await page.locator('[data-testid="permission-denied"]').isVisible();
  expect(hasPermissionDenied).toBe(true);
});
```

##### 场景 6：弹窗/抽屉/Popover 交互

**触发条件：** PRD 中有"弹窗确认""侧边抽屉""下拉菜单""气泡提示"等描述。

**用例生成规则：**
- 覆盖完整生命周期：打开 → 操作 → 关闭
- 验证关闭方式：确认按钮 / 取消按钮 / 点击遮罩 / ESC 键
- 验证弹窗内的表单提交和校验
- 验证关闭后页面状态（数据是否刷新）

```typescript
test('TC-F008-L3-01: 删除确认弹窗交互', async ({ page }) => {
  await page.goto('/items');

  // ① 触发弹窗
  await page.locator('[data-testid="item-row"]').first().locator('[data-testid="delete-btn"]').click();
  const dialog = page.locator('[data-testid="confirm-dialog"]');
  await expect(dialog).toBeVisible();

  // ② 弹窗内容正确（对照 PRD 文案）
  await expect(dialog.locator('[data-testid="dialog-title"]')).toContainText('确认删除');
  await expect(dialog.locator('[data-testid="dialog-body"]')).toContainText('不可恢复');

  // ③ 点击取消 → 弹窗关闭，数据不变
  await dialog.locator('[data-testid="cancel-btn"]').click();
  await expect(dialog).not.toBeVisible();
  await expect(page.locator('[data-testid="item-row"]').first()).toBeVisible();

  // ④ 重新打开 → ESC 关闭
  await page.locator('[data-testid="item-row"]').first().locator('[data-testid="delete-btn"]').click();
  await expect(dialog).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(dialog).not.toBeVisible();

  // ⑤ 重新打开 → 点击遮罩关闭（如 PRD 支持）
  await page.locator('[data-testid="item-row"]').first().locator('[data-testid="delete-btn"]').click();
  await expect(dialog).toBeVisible();
  await page.locator('[data-testid="dialog-overlay"]').click({ position: { x: 10, y: 10 } });
  await expect(dialog).not.toBeVisible();

  // ⑥ 确认删除 → 弹窗关闭 + 列表刷新
  await page.locator('[data-testid="item-row"]').first().locator('[data-testid="delete-btn"]').click();
  const countBefore = await page.locator('[data-testid="item-row"]').count();
  await dialog.locator('[data-testid="confirm-btn"]').click();
  await expect(dialog).not.toBeVisible();
  await expect(page.locator('[data-testid="item-row"]')).toHaveCount(countBefore - 1);
});

test('TC-F008-L3-02: 侧边抽屉编辑表单', async ({ page }) => {
  await page.goto('/items');

  // ① 点击编辑 → 抽屉滑出
  await page.locator('[data-testid="item-row"]').first().locator('[data-testid="edit-btn"]').click();
  const drawer = page.locator('[data-testid="edit-drawer"]');
  await expect(drawer).toBeVisible();

  // ② 抽屉内表单有当前数据（回显）
  await expect(drawer.locator('[data-testid="name-input"]')).not.toHaveValue('');

  // ③ 修改并保存
  await drawer.locator('[data-testid="name-input"]').fill('修改后的名称');
  await drawer.locator('[data-testid="save-btn"]').click();

  // ④ 抽屉关闭 + 列表数据更新
  await expect(drawer).not.toBeVisible();
  await expect(page.locator('[data-testid="item-row"]').first()).toContainText('修改后的名称');
});
```

##### 场景 7：键盘交互与无障碍

**触发条件：** PRD 中有"支持键盘导航""无障碍""快捷键"等描述，或 UI 设计要求中有可访问性要求。

**用例生成规则：**
- Tab 导航顺序与视觉顺序一致
- Enter 触发主操作（提交表单、确认弹窗）
- Escape 关闭弹窗/取消操作
- 自定义快捷键（如有）
- 焦点管理：弹窗打开后焦点移入弹窗，关闭后焦点回到触发元素

```typescript
test('TC-F009-L3-01: 表单键盘导航和提交', async ({ page }) => {
  await page.goto('/login');

  // ① Tab 顺序：邮箱 → 密码 → 登录按钮
  await page.keyboard.press('Tab');
  await expect(page.locator('[data-testid="email-input"]')).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(page.locator('[data-testid="password-input"]')).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(page.locator('[data-testid="submit-btn"]')).toBeFocused();

  // ② 填写后 Enter 提交
  await page.locator('[data-testid="email-input"]').focus();
  await page.fill('[data-testid="email-input"]', 'test@example.com');
  await page.fill('[data-testid="password-input"]', 'Test1234!');
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL('/dashboard');
});

test('TC-F009-L3-02: 弹窗焦点管理', async ({ page }) => {
  await page.goto('/items');

  // ① 点击删除 → 弹窗打开 → 焦点移入弹窗
  const deleteBtn = page.locator('[data-testid="item-row"]').first().locator('[data-testid="delete-btn"]');
  await deleteBtn.click();
  const dialog = page.locator('[data-testid="confirm-dialog"]');
  await expect(dialog).toBeVisible();

  // 焦点应在弹窗内（确认或取消按钮）
  const focusedElement = page.locator(':focus');
  await expect(dialog).toContainText(await focusedElement.textContent() || '');

  // ② ESC 关闭 → 焦点回到触发按钮
  await page.keyboard.press('Escape');
  await expect(dialog).not.toBeVisible();
  await expect(deleteBtn).toBeFocused();
});
```

##### 场景 8：前端状态持久化

**触发条件：** PRD 中有"刷新不丢失""记住筛选条件""URL 同步状态""草稿保存"等描述。

**用例生成规则：**
- 页面刷新后关键状态保持（表单草稿、筛选条件、Tab 选中态等）
- URL 参数与页面状态同步（直接访问带参数 URL 能还原状态）
- 浏览器前进/后退时状态正确

```typescript
test('TC-F010-L3-01: 筛选条件刷新保持和 URL 同步', async ({ page }) => {
  await page.goto('/tasks');

  // ① 设置筛选条件
  await page.selectOption('[data-testid="status-filter"]', 'completed');
  await page.fill('[data-testid="search-input"]', '测试');
  await page.waitForTimeout(500);

  // ② 验证 URL 同步（筛选条件反映在 URL 参数中）
  expect(page.url()).toContain('status=completed');
  expect(page.url()).toContain('search=');

  // ③ 刷新页面 → 筛选条件保持
  await page.reload();
  await expect(page.locator('[data-testid="status-filter"]')).toHaveValue('completed');
  await expect(page.locator('[data-testid="search-input"]')).toHaveValue('测试');
  // 列表数据仍然是筛选后的
  for (const item of await page.locator('[data-testid="task-item"]').all()) {
    await expect(item).toContainText('测试');
  }

  // ④ 直接访问带参数 URL → 状态还原
  await page.goto('/tasks?status=pending&search=紧急');
  await expect(page.locator('[data-testid="status-filter"]')).toHaveValue('pending');
  await expect(page.locator('[data-testid="search-input"]')).toHaveValue('紧急');
});

test('TC-F010-L3-02: 表单草稿自动保存', async ({ page }) => {
  await page.goto('/article/create');

  // ① 填写部分内容
  await page.fill('[data-testid="title-input"]', '草稿测试标题');
  await page.fill('[data-testid="content-editor"]', '草稿测试内容...');

  // ② 等待自动保存（对照 PRD 中的自动保存间隔）
  await page.waitForTimeout(3000);
  await expect(page.locator('[data-testid="save-status"]')).toContainText('已保存');

  // ③ 刷新页面 → 草稿恢复
  await page.reload();
  await expect(page.locator('[data-testid="title-input"]')).toHaveValue('草稿测试标题');
  await expect(page.locator('[data-testid="content-editor"]')).toContainText('草稿测试内容');
});
```

#### 前端交互场景覆盖自检

**生成 L3 用例后，必须逐项确认以下场景是否涉及并已覆盖：**

| # | 场景 | 对照来源 | 是否涉及 | 用例编号 |
|---|------|---------|---------|---------|
| 1 | 条件联动 UI | PRD 功能点明细中的联动/切换描述 | ✅/⬜ 不涉及 | TC-xxx |
| 2 | 前端业务计算 | PRD 业务规则中的计算/汇总逻辑 | ✅/⬜ 不涉及 | TC-xxx |
| 3 | 多步骤向导 | PRD 功能流程图中的分步骤流程 | ✅/⬜ 不涉及 | TC-xxx |
| 4 | 动态列表操作 | PRD 中的列表/搜索/排序/分页 | ✅/⬜ 不涉及 | TC-xxx |
| 5 | 权限差异化 UI | PRD 业务规则中的角色/权限描述 | ✅/⬜ 不涉及 | TC-xxx |
| 6 | 弹窗/抽屉/Popover | PRD UI 设计中的弹窗/抽屉交互 | ✅/⬜ 不涉及 | TC-xxx |
| 7 | 键盘交互与无障碍 | PRD 可访问性要求 / UI 设计要求 | ✅/⬜ 不涉及 | TC-xxx |
| 8 | 状态持久化 | PRD 中的"刷新保持""草稿保存" | ✅/⬜ 不涉及 | TC-xxx |

> 标注"⬜ 不涉及"的场景需说明原因（如"纯后端服务，无前端 UI"），不得无理由跳过。

#### 网络异常场景（L3 独立批次，正常用例通过后执行）

**⚠️ 每个涉及 API 调用或页面加载的功能点都必须检查网络异常场景，不论 PRD 是否提到。** PRD 常常遗漏网络异常处理的描述，但用户在真实环境中一定会遇到，这是潜在 bug 的高发区。

**执行策略：** 网络异常用例作为独立批次，在 L3 正常用例全部通过后再执行。不与正常用例混跑，防止网络模拟影响正常用例的断言。

##### 场景 9：弱网/慢速环境

**触发条件：** 所有涉及页面加载或 API 调用的功能点。

**用例生成规则：**
- 模拟 3G 弱网（参数取自 `config.yaml` 的 `testing.network_conditions.slow_3g`）
- 验证 loading 状态在慢速下是否正确展示（不是一闪而过）
- 验证超时后是否有友好提示（不是白屏或无限 loading）
- 验证图片/资源的懒加载或渐进式加载效果

```typescript
import { test, expect } from '@playwright/test';

test.describe('网络异常：弱网环境', () => {
  test('TC-F001-L3-NET-01: 弱网下页面加载有 loading 且不超时白屏', async ({ page, context }) => {
    // 模拟 3G 弱网（根据 config.yaml 配置）
    await context.route('**/*', async (route) => {
      await new Promise(resolve => setTimeout(resolve, 100)); // latency: 100ms
      await route.continue();
    });

    await page.goto('/dashboard');

    // ① loading 状态应该可见（弱网下不会一闪而过）
    // 注意：需在 goto 前设置监听，或用 waitForSelector
    await expect(page.locator('[data-testid="page-skeleton"], [data-testid="loading-spinner"]')
      .first()).toBeVisible({ timeout: 2000 });

    // ② 最终页面应正常加载完成（不是白屏）
    await expect(page.locator('[data-testid="main-content"]')).toBeVisible({ timeout: 15000 });

    // ③ 不应有未捕获的 JS 错误
    const errors: string[] = [];
    page.on('pageerror', err => errors.push(err.message));
    expect(errors).toHaveLength(0);
  });

  test('TC-F001-L3-NET-02: 弱网下表单提交有进度反馈', async ({ page, context }) => {
    // 模拟提交接口慢响应（3 秒延迟）
    await context.route('**/api/register', async (route) => {
      await new Promise(resolve => setTimeout(resolve, 3000));
      await route.continue();
    });

    await page.goto('/register');
    await page.fill('[data-testid="name-input"]', '弱网用户');
    await page.fill('[data-testid="email-input"]', `slow-${Date.now()}@test.com`);
    await page.fill('[data-testid="password-input"]', 'Test1234!');
    await page.click('[data-testid="submit-btn"]');

    // ① 提交后按钮应显示 loading 状态（不是无反馈）
    await expect(page.locator('[data-testid="submit-btn"]')).toBeDisabled();

    // ② 3 秒后应正常完成
    await expect(page).toHaveURL('/dashboard', { timeout: 10000 });
  });
});
```

##### 场景 10：离线 → 恢复在线

**触发条件：** 所有有持续交互的页面（列表、表单、实时数据等）。

**用例生成规则：**
- 操作中途断网 → 验证 UI 有离线指示或错误提示
- 恢复网络 → 验证页面自动恢复或提示用户刷新
- 离线期间的本地操作（如输入）不应丢失

```typescript
test.describe('网络异常：离线与恢复', () => {
  test('TC-F001-L3-NET-03: 操作中离线有提示，恢复后可继续', async ({ page, context }) => {
    await page.goto('/tasks');
    await expect(page.locator('[data-testid="task-list"]')).toBeVisible();

    // ① 模拟离线
    await context.setOffline(true);

    // ② 尝试操作（如刷新列表）→ 应有错误提示
    await page.click('[data-testid="refresh-btn"]');
    await expect(
      page.locator('[data-testid="network-error"], [data-testid="offline-banner"]').first()
    ).toBeVisible({ timeout: 5000 });

    // ③ 之前加载的数据应仍然可见（不清空）
    await expect(page.locator('[data-testid="task-list"]')).toBeVisible();

    // ④ 恢复在线
    await context.setOffline(false);

    // ⑤ 重试操作 → 应成功
    await page.click('[data-testid="refresh-btn"]');
    await expect(page.locator('[data-testid="task-list"]')).toBeVisible();
    // 错误提示应消失
    await expect(
      page.locator('[data-testid="network-error"], [data-testid="offline-banner"]').first()
    ).not.toBeVisible({ timeout: 5000 });
  });

  test('TC-F001-L3-NET-04: 表单填写中离线不丢失数据', async ({ page, context }) => {
    await page.goto('/article/create');

    // ① 填写部分内容
    await page.fill('[data-testid="title-input"]', '离线测试标题');
    await page.fill('[data-testid="content-editor"]', '离线测试内容...');

    // ② 模拟离线
    await context.setOffline(true);

    // ③ 尝试提交 → 应有离线提示，不是静默失败
    await page.click('[data-testid="submit-btn"]');
    await expect(
      page.locator('[data-testid="network-error"], [data-testid="offline-toast"]').first()
    ).toBeVisible({ timeout: 5000 });

    // ④ 已填内容应保留（不被清空）
    await expect(page.locator('[data-testid="title-input"]')).toHaveValue('离线测试标题');
    await expect(page.locator('[data-testid="content-editor"]')).toContainText('离线测试内容');

    // ⑤ 恢复在线 → 重新提交 → 应成功
    await context.setOffline(false);
    await page.click('[data-testid="submit-btn"]');
    await expect(page.locator('[data-testid="success-toast"]')).toBeVisible({ timeout: 10000 });
  });
});
```

##### 场景 11：接口超时/失败

**触发条件：** 所有调用后端 API 的操作。

**用例生成规则：**
- 模拟单个接口超时（不是全局断网）→ 验证超时提示和重试机制
- 模拟接口返回 500/503 → 验证错误展示
- 模拟并发请求中部分失败 → 验证降级展示（成功的数据正常显示，失败的有提示）

```typescript
test.describe('网络异常：接口超时与错误', () => {
  test('TC-F002-L3-NET-01: 单个接口超时有友好提示', async ({ page, context }) => {
    // 模拟列表接口超时（config.yaml 的 timeout_threshold: 10000ms）
    await context.route('**/api/tasks', async (route) => {
      await new Promise(resolve => setTimeout(resolve, 15000)); // 超过阈值
      await route.abort('timedout');
    });

    await page.goto('/tasks');

    // ① 不应无限 loading — 应显示超时提示
    await expect(
      page.locator('[data-testid="timeout-error"], [data-testid="load-failed"]').first()
    ).toBeVisible({ timeout: 12000 });

    // ② 应提供重试按钮
    await expect(page.locator('[data-testid="retry-btn"]')).toBeVisible();
  });

  test('TC-F002-L3-NET-02: 接口 500 错误有错误提示', async ({ page, context }) => {
    // 模拟接口返回 500
    await context.route('**/api/tasks', (route) => {
      route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({ error: 'Internal Server Error' }),
      });
    });

    await page.goto('/tasks');

    // ① 应显示错误提示（不是白屏）
    await expect(
      page.locator('[data-testid="server-error"], [data-testid="error-message"]').first()
    ).toBeVisible({ timeout: 5000 });

    // ② 不应暴露技术细节给用户（如堆栈信息）
    const errorText = await page.locator('[data-testid="server-error"], [data-testid="error-message"]')
      .first().textContent();
    expect(errorText).not.toContain('stack');
    expect(errorText).not.toContain('TypeError');
  });

  test('TC-F002-L3-NET-03: 页面多个接口中部分失败的降级展示', async ({ page, context }) => {
    // 仪表盘页面同时调用多个接口，模拟其中一个失败
    await context.route('**/api/stats', (route) => {
      route.fulfill({ status: 503, body: 'Service Unavailable' });
    });
    // 其余接口正常
    await page.goto('/dashboard');

    // ① 正常接口的数据应正常展示
    await expect(page.locator('[data-testid="task-list"]')).toBeVisible();

    // ② 失败模块应有错误占位，不影响其他模块
    await expect(
      page.locator('[data-testid="stats-error"], [data-testid="stats-unavailable"]').first()
    ).toBeVisible();

    // ③ 整个页面不应崩溃或白屏
    await expect(page.locator('[data-testid="main-content"]')).toBeVisible();
  });
});
```

##### 场景 12：请求中断（操作到一半断网）

**触发条件：** 所有提交类操作（表单提交、文件上传、批量操作等）。

**用例生成规则：**
- 提交请求发出后、响应返回前模拟断网
- 验证 UI 不卡在 loading 状态（有超时兜底）
- 验证数据是否丢失、是否可以重试
- 文件上传中断后的处理（如有）

```typescript
test.describe('网络异常：请求中断', () => {
  test('TC-F003-L3-NET-01: 表单提交过程中断网的恢复', async ({ page, context }) => {
    await page.goto('/tasks/create');
    await page.fill('[data-testid="task-name"]', '中断测试任务');
    await page.fill('[data-testid="task-desc"]', '测试请求中断场景');

    // 拦截提交请求：请求发出后立即断网
    let requestSent = false;
    await context.route('**/api/tasks', async (route) => {
      requestSent = true;
      // 模拟请求发出后网络中断
      await route.abort('connectionfailed');
    });

    // ① 点击提交
    await page.click('[data-testid="submit-btn"]');

    // ② 应有网络错误提示（不是无限 loading）
    await expect(
      page.locator('[data-testid="network-error"], [data-testid="submit-failed"]').first()
    ).toBeVisible({ timeout: 5000 });
    expect(requestSent).toBe(true);

    // ③ 表单数据应保留（不被清空）
    await expect(page.locator('[data-testid="task-name"]')).toHaveValue('中断测试任务');

    // ④ 恢复网络后移除拦截
    await context.unroute('**/api/tasks');

    // ⑤ 重试提交 → 应成功
    await page.click('[data-testid="submit-btn"]');
    await expect(page.locator('[data-testid="success-toast"]')).toBeVisible({ timeout: 10000 });
  });
});
```

#### 网络异常场景覆盖自检

**生成 L3 用例后，每个涉及 API 调用的功能点都必须逐项确认以下网络异常场景：**

| # | 场景 | 检查内容 | 是否涉及 | 用例编号 |
|---|------|---------|---------|---------|
| 9 | 弱网/慢速 | 页面加载有 loading、提交有进度反馈、不白屏 | ✅（所有页面） | TC-xxx |
| 10 | 离线→恢复 | 离线提示、数据不丢失、恢复后可继续 | ✅（所有交互页面） | TC-xxx |
| 11 | 接口超时/500 | 超时提示+重试、500 友好错误、部分失败降级 | ✅（所有 API 调用） | TC-xxx |
| 12 | 请求中断 | 提交中断不卡死、数据保留、可重试 | ✅（所有提交操作） | TC-xxx |

> **与前端交互 8 类场景的区别：** 前端交互场景验证的是"功能在理想环境下是否正确"，网络异常场景验证的是"功能在恶劣环境下是否健壮"。两者都是 L3 的必检项，但网络异常用例作为独立批次在正常用例通过后再跑。

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

### Step 4: 生成 L5 非功能测试用例 + 自动化脚本

根据 `config.yaml` 中的 `testing.l5_nonfunctional` 配置生成。**L5 各子项（性能/安全/可访问性）独立开关，执行前逐项询问用户是否开启。**

#### 4A: 性能测试用例

**前端性能（Lighthouse 逐页面）：**

从 PRD 碎片文件中提取所有有 UI 的页面，为每个页面生成 Lighthouse 检测用例：

| 检测指标 | 阈值（取自 config.yaml） | 说明 |
|---------|----------------------|------|
| LCP（Largest Contentful Paint） | ≤ 2500ms | 最大内容渲染时间 |
| FID（First Input Delay） | ≤ 100ms | 首次输入延迟 |
| CLS（Cumulative Layout Shift） | ≤ 0.1 | 累积布局偏移 |
| Performance Score | ≥ 80 | 综合性能评分 |

```bash
#!/bin/bash
# tests/nonfunctional/run-lighthouse.sh
# 逐页面跑 Lighthouse，每页独立报告
PAGES=("/" "/login" "/dashboard" "/tasks")
for page in "${PAGES[@]}"; do
  npx lighthouse "http://localhost:3000${page}" \
    --output=json \
    --output-path="./test-results/lighthouse${page//\//-}.json" \
    --chrome-flags="--headless --no-sandbox"
done
```

**后端 API 性能（k6 多场景压测）：**

从 API 文档中提取所有接口，生成 k6 压测脚本，包含三个场景：

| 场景 | 并发数 | 持续时间 | 阈值 | 目的 |
|------|--------|---------|------|------|
| 基准（baseline） | 10 VUs | 30s | P95 ≤ 200ms, P99 ≤ 500ms | 验证正常负载下的响应时间 |
| 压力（stress） | 50 VUs | 60s | P95 ≤ 500ms, P99 ≤ 1000ms | 验证高负载下是否降级而非崩溃 |
| 峰值（spike） | 100 VUs | 10s | P95 ≤ 1000ms, 错误率 ≤ 1% | 验证突发流量的处理能力 |

```javascript
// tests/nonfunctional/k6-api-perf.js
import http from 'k6/http';
import { check, sleep } from 'k6';

// 场景配置（取自 config.yaml）
export const options = {
  scenarios: {
    baseline: {
      executor: 'constant-vus',
      vus: 10,
      duration: '30s',
    },
    stress: {
      executor: 'constant-vus',
      vus: 50,
      duration: '60s',
      startTime: '35s', // baseline 结束后开始
    },
    spike: {
      executor: 'constant-vus',
      vus: 100,
      duration: '10s',
      startTime: '100s', // stress 结束后开始
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  // 测试核心接口（从 API 文档自动生成）
  const res = http.get('http://localhost:3000/api/tasks');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  sleep(1);
}
```

**内存泄漏检测（仅 Full 级别）：**

```typescript
// tests/nonfunctional/memory-leak.spec.ts
import { test, expect } from '@playwright/test';

test('内存泄漏检测：重复操作后内存不持续增长', async ({ page }) => {
  await page.goto('/dashboard');

  // 获取初始内存
  const initialMemory = await page.evaluate(() => 
    (performance as any).memory?.usedJSHeapSize / 1024 / 1024 // MB
  );

  // 重复操作 N 轮（取自 config.yaml: operation_rounds）
  for (let i = 0; i < 50; i++) {
    await page.goto('/tasks');
    await page.goto('/dashboard');
    await page.click('[data-testid="refresh-btn"]');
  }

  // 强制 GC（如果可用）
  await page.evaluate(() => {
    if ((window as any).gc) (window as any).gc();
  });

  // 获取最终内存
  const finalMemory = await page.evaluate(() =>
    (performance as any).memory?.usedJSHeapSize / 1024 / 1024
  );

  // 内存增长不超过阈值（config.yaml: growth_threshold: 20MB）
  const growth = finalMemory - initialMemory;
  expect(growth).toBeLessThan(20); // MB
});
```

#### 4B: 安全测试用例

**自动化执行的检测项：**

| 检测项 | 工具/方式 | 阈值 |
|--------|---------|------|
| 依赖漏洞 | `npm audit` / `pip audit` | 0 个 high/critical |
| XSS 检测 | Playwright 注入脚本 + 验证是否执行 | 0 个 XSS 漏洞 |
| CSRF 检测 | 无 CSRF Token 发送修改请求，验证是否拒绝 | 全部拒绝 |
| SQL 注入 | API 参数注入 SQL 语句，验证是否拦截 | 全部拦截 |
| 越权访问 | 无 Token / 伪造 Token / 过期 Token / 其他用户 Token 发送请求 | 全部拒绝（401/403） |
| 敏感信息泄露 | 扫描 API 响应体、页面 HTML、控制台日志 | 不含密码/Token/密钥/手机号/身份证等 |

```bash
#!/bin/bash
# tests/nonfunctional/run-security.sh

echo "=== 依赖漏洞扫描 ==="
npm audit --audit-level=high

echo "=== 敏感信息泄露检测 ==="
# 扫描 API 响应中是否包含敏感字段
node tests/nonfunctional/sensitive-data-scan.js
```

```typescript
// tests/nonfunctional/security-xss.spec.ts
import { test, expect } from '@playwright/test';

test.describe('安全：XSS 检测', () => {
  const XSS_PAYLOADS = [
    '<script>alert("xss")</script>',
    '<img src=x onerror=alert("xss")>',
    '"><script>alert("xss")</script>',
    "javascript:alert('xss')",
  ];

  test('表单输入 XSS payload 不被执行', async ({ page }) => {
    await page.goto('/tasks/create');
    
    for (const payload of XSS_PAYLOADS) {
      await page.fill('[data-testid="task-name"]', payload);
      await page.click('[data-testid="save-btn"]');
      
      // 监听是否有 alert 弹出（XSS 被执行）
      let alertFired = false;
      page.on('dialog', () => { alertFired = true; });
      
      // 导航到展示页面
      await page.goto('/tasks');
      expect(alertFired).toBe(false);
      
      // 验证内容被转义而非执行
      const content = await page.locator('[data-testid="task-item"]').last().innerHTML();
      expect(content).not.toContain('<script>');
    }
  });
});

// tests/nonfunctional/security-auth.spec.ts
test.describe('安全：认证与越权', () => {
  test('无 Token 访问受保护接口返回 401', async ({ request }) => {
    const res = await request.get('/api/tasks');
    expect(res.status()).toBe(401);
  });

  test('伪造 Token 返回 401', async ({ request }) => {
    const res = await request.get('/api/tasks', {
      headers: { Authorization: 'Bearer fake-token-12345' },
    });
    expect(res.status()).toBe(401);
  });

  test('过期 Token 返回 401', async ({ request }) => {
    // 使用一个已知过期的 Token（需从 seed 中获取）
    const res = await request.get('/api/tasks', {
      headers: { Authorization: 'Bearer expired-test-token' },
    });
    expect(res.status()).toBe(401);
  });

  test('普通用户访问管理员接口返回 403', async ({ request }) => {
    // 使用普通用户 Token
    const res = await request.delete('/api/admin/users/test-user-001', {
      headers: { Authorization: 'Bearer user-test-token' },
    });
    expect(res.status()).toBe(403);
  });
});
```

**建议清单（不自动执行，询问用户）：**

执行到安全测试时，输出以下建议清单并询问用户：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
安全测试 — 手动测试建议清单
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
以下安全测试需要人工判断或特定业务上下文，自动化难以覆盖：

□ 业务逻辑漏洞：支付金额是否可篡改、优惠券是否可重复使用、订单状态是否可非法跳转
□ 接口限流：同一 IP/用户短时间大量请求是否被限流
□ 文件上传安全：是否允许上传 .exe/.sh、是否校验文件内容（不只扩展名）、文件大小限制
□ 会话管理：多端登录策略、强制下线、Token 刷新机制

是否需要我协助执行其中某项？（回复编号或"跳过"）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 4C: 可访问性测试用例

**基于 axe-core 逐页面扫描 + WCAG 标准检查：**

| 检查维度 | WCAG AA 要求 | 工具 |
|---------|-------------|------|
| 颜色对比度 | 文字与背景对比度 ≥ 4.5:1（大文字 ≥ 3:1） | axe-core |
| 键盘可达性 | 所有交互元素可通过 Tab 到达、Enter 激活 | Playwright + axe |
| 表单标签 | 所有输入框有关联的 label 或 aria-label | axe-core |
| 图片替代文本 | 所有 `<img>` 有 alt 属性 | axe-core |
| 页面标题 | 每个页面有唯一的 `<title>` | axe-core |
| 焦点可见 | focus 状态有可见的视觉指示 | Playwright |
| 语义化标签 | 使用 heading / landmark / list 等语义化 HTML | axe-core |

```typescript
// tests/nonfunctional/accessibility.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const PAGES = ['/', '/login', '/dashboard', '/tasks'];

for (const pagePath of PAGES) {
  test(`可访问性：${pagePath} 符合 WCAG AA 标准`, async ({ page }) => {
    await page.goto(pagePath);

    // axe-core 扫描（WCAG AA 级别）
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])  // 根据 config.yaml 的 standard 选择
      .analyze();

    // 不应有 critical 或 serious 级别的违规
    const critical = results.violations.filter(v => 
      v.impact === 'critical' || v.impact === 'serious'
    );
    
    if (critical.length > 0) {
      console.log('可访问性违规：');
      critical.forEach(v => {
        console.log(`  [${v.impact}] ${v.id}: ${v.description}`);
        v.nodes.forEach(n => console.log(`    → ${n.html.substring(0, 100)}`));
      });
    }

    expect(critical).toHaveLength(0);
  });
}
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

L3 网络异常测试（{Y2} 个用例，独立批次）：
  → tests/e2e/network/slow-network.spec.ts（{N} 个用例）
  → tests/e2e/network/offline-recovery.spec.ts（{N} 个用例）
  → tests/e2e/network/api-failure.spec.ts（{N} 个用例）
  → tests/e2e/network/request-interrupt.spec.ts（{N} 个用例）

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

### L3 网络异常批次（L3 正常用例通过后执行）

**前提：** L3 正常 E2E 用例全部通过后，才进入网络异常批次。

1. 执行网络异常测试脚本（独立目录，不与正常用例混跑）：
   ```bash
   npx playwright test tests/e2e/network/
   ```

2. 脚本通过 Playwright 的 `context.route()` 和 `context.setOffline()` 模拟：
   - 弱网延迟（参数取自 `config.yaml` 的 `testing.network_conditions.slow_3g`）
   - 完全离线 → 恢复在线
   - 单接口超时/500/503
   - 请求发出后连接中断

3. 执行记录：
   - 各场景通过/失败状态
   - 失败截图路径
   - 网络条件参数（延迟、带宽、离线时长）

**网络异常批次门禁自检：**
```
【L3 网络异常批次完成】
- 弱网场景：{N} 个用例，✅ {N} / ❌ {N}
- 离线恢复：{N} 个用例，✅ {N} / ❌ {N}
- 接口超时/错误：{N} 个用例，✅ {N} / ❌ {N}
- 请求中断：{N} 个用例，✅ {N} / ❌ {N}
- 网络配置：slow_3g（latency={N}ms, download={N}kbps）
→ 进入 L4 UI 视觉测试
```

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

### 兼容性测试（L3/L4 多浏览器 + 多设备执行）

**目标：** 验证 L3 E2E 和 L4 视觉测试在不同浏览器引擎和设备视口下均能通过。

**⚠️ 执行前必须确认：** 兼容性测试会成倍增加运行时间。默认只在 Chromium 上执行 L3/L4，进入兼容性测试阶段前，必须暂停询问用户本次要跑哪些浏览器和设备。

**暂停确认格式：**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
兼容性测试范围确认
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
L3/L4 已在 Chromium 上全部通过。

项目配置的兼容性矩阵（config.yaml）：
  浏览器：Chromium ✅ 已完成 | Firefox | WebKit(Safari)
  设备：桌面 ✅ 已完成 | iPhone 14 | Pixel 7 | iPad Pro 11

本次要跑哪些？
  1. 全部浏览器 + 全部设备（最全面，耗时约 ×{N} 倍）
  2. 全部浏览器 + 仅桌面（验证浏览器差异，不测设备）
  3. 仅 WebKit + iPhone（重点覆盖 Safari 差异）
  4. 跳过兼容性测试（本次不跑）
  5. 自定义（请告诉我具体要跑哪些）

请选择或直接说明：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**用户确认后的执行流程：**

1. 根据用户选择的浏览器和设备，动态生成或修改 `playwright.config.ts`：

```typescript
// tests/playwright.config.ts（兼容性测试配置示例）
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  projects: [
    // 桌面浏览器
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
    // 移动设备模拟
    { name: 'iphone', use: { ...devices['iPhone 14'] } },
    { name: 'android', use: { ...devices['Pixel 7'] } },
    { name: 'ipad', use: { ...devices['iPad Pro 11'] } },
  ],
});
```

2. 运行指定范围的测试：
```bash
# 全部浏览器 + 全部设备
npx playwright test tests/e2e/ tests/visual/ --config=tests/playwright.config.ts

# 仅指定浏览器
npx playwright test tests/e2e/ tests/visual/ --project=firefox --project=webkit

# 仅指定设备
npx playwright test tests/e2e/ tests/visual/ --project=iphone --project=ipad
```

3. 汇总兼容性测试结果：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
兼容性测试结果
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
| 浏览器/设备      | L3 E2E      | L4 视觉     |
|-----------------|-------------|-------------|
| Chromium 桌面    | ✅ {N}/{N}  | ✅ {N}/{N}  |
| Firefox 桌面     | ✅ {N}/{N}  | ❌ {N}/{N}  |
| WebKit 桌面      | ✅ {N}/{N}  | ✅ {N}/{N}  |
| iPhone 14        | ✅ {N}/{N}  | ⚠️ {N}/{N}  |
| Pixel 7          | ✅ {N}/{N}  | ✅ {N}/{N}  |
| iPad Pro 11      | ✅ {N}/{N}  | ✅ {N}/{N}  |

浏览器特有问题：
  ❌ Firefox：{用例名} — {具体差异描述}
  ⚠️ iPhone：{用例名} — {截图差异超过阈值}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**浏览器特有问题的处理：**
- 只在某个浏览器上失败的用例 → 记录为「浏览器兼容性问题」，标注影响范围和浏览器
- 写入测试报告的「兼容性测试结果」章节（非通用失败）
- 严重程度根据浏览器市占率判断：WebKit(Safari) 问题通常 Major，Firefox 问题通常 Minor

**真机测试（可选增强）：**

若 `config.yaml` 中 `testing.compatibility.real_device.enabled: true`，在模拟设备测试通过后，额外通过外部服务运行真机测试：

| Provider | 接入方式 | 说明 |
|---------|---------|------|
| BrowserStack | `npx playwright test --config=tests/browserstack.config.ts` | 需设置 `BROWSERSTACK_USERNAME` 和 `BROWSERSTACK_ACCESS_KEY` 环境变量 |
| Sauce Labs | `npx playwright test --config=tests/saucelabs.config.ts` | 需设置 `SAUCE_USERNAME` 和 `SAUCE_ACCESS_KEY` 环境变量 |

**真机测试重点验证（模拟器无法覆盖的场景）：**
- 原生触摸手势（双指缩放、长按、快速滑动）
- iOS Safari 的地址栏隐藏/显示对布局的影响
- Android 系统返回键行为
- 真实网络环境下的性能表现
- 设备特有的输入法键盘对表单的遮挡

> 真机测试不是必须的。仅在项目有明确的移动端适配需求且需要真机验证时启用。

---

### L5 非功能测试

**L5 各子项独立开关。进入 L5 前，必须逐项询问用户是否开启：**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
L5 非功能测试范围确认
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
config.yaml 配置：

1. 性能测试
   ├ Lighthouse 前端性能（逐页面）     [已启用]
   ├ k6 API 压测（基准/压力/峰值）     [已启用]
   └ 内存泄漏检测（仅 Full 级别）     [已启用]

2. 安全测试
   ├ 自动化检测（npm audit / XSS / CSRF / SQL注入 / 越权 / 敏感信息）  [已启用]
   └ 手动测试建议（业务逻辑漏洞 / 限流 / 文件上传 / 会话管理）        [待确认]

3. 可访问性测试
   └ axe-core WCAG AA 级别扫描        [已启用]

请确认：
  a. 全部执行
  b. 只跑性能 + 安全自动化（跳过可访问性和手动建议）
  c. 自定义选择（告诉我要跑哪些）
  d. 跳过 L5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**用户确认后，按顺序执行：**

#### L5a 性能测试

1. **Lighthouse 前端性能（逐页面）：**
   ```bash
   bash tests/nonfunctional/run-lighthouse.sh
   ```
   - 每个页面独立报告，检查 LCP / FID / CLS / Performance Score
   - 任一页面任一指标不达标 → 标记该用例 ❌ 并记录具体数值

2. **k6 API 压测（三场景顺序执行）：**
   ```bash
   k6 run tests/nonfunctional/k6-api-perf.js
   ```
   - baseline → stress → spike 顺序执行
   - 每个场景独立判定：P95/P99/错误率是否达标

3. **内存泄漏检测（仅 Full 级别）：**
   ```bash
   npx playwright test tests/nonfunctional/memory-leak.spec.ts
   ```
   - 重复操作 50 轮后检测内存增长
   - 增长超过阈值（默认 20MB）→ 标记 ❌

#### L5b 安全测试

1. **自动化检测（全部自动执行）：**
   ```bash
   # 依赖漏洞
   npm audit --audit-level=high

   # XSS + CSRF + 认证越权
   npx playwright test tests/nonfunctional/security-*.spec.ts

   # 敏感信息泄露
   node tests/nonfunctional/sensitive-data-scan.js
   ```

2. **手动测试建议清单（询问用户后决定是否执行）：**
   - 输出建议清单，询问用户是否需要协助执行
   - 用户选择某项 → AI 协助生成对应测试脚本并执行
   - 用户跳过 → 记录为「⏳ 待人工验证」

#### L5c 可访问性测试

1. **axe-core 逐页面扫描：**
   ```bash
   npx playwright test tests/nonfunctional/accessibility.spec.ts
   ```
   - 按 config.yaml 中的 WCAG 标准级别（默认 AA）执行
   - critical/serious 级别违规 → ❌
   - moderate/minor 级别违规 → ⚠️ 记录但不阻塞

**L5 门禁自检：**
```
【L5 非功能测试完成】
- 性能测试：
  - Lighthouse：{N} 页面，✅ {N} / ❌ {N}
  - k6 压测：baseline ✅/❌ | stress ✅/❌ | spike ✅/❌
  - 内存泄漏：{✅ 无泄漏 / ❌ 增长 {N}MB / ⬜ 未执行（非 Full 级别）}
- 安全测试：
  - 自动化：{N} 项，✅ {N} / ❌ {N}
  - 手动建议：{已执行 N 项 / 跳过}
- 可访问性：
  - WCAG {AA} 扫描：{N} 页面，✅ {N} / ❌ {N}（critical {N} + serious {N}）
→ 生成测试报告
```

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
  兼容性测试（确认范围后执行）→ [门禁] →
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

## 回归测试策略

### 三级回归

| 级别 | 名称 | 触发时机 | 测试范围 | 预期耗时 |
|------|------|---------|---------|---------|
| **Smoke** | 冒烟测试 | 每次代码修改后 | L1 全跑 + L2b 抽样 + L3 主流程 | 3-5 分钟 |
| **Regression** | 标准回归 | PR 合并 / 每日定时 / 手动触发 | L1 + L2a + L2b + L3 + L4 | 10-20 分钟 |
| **Full** | 全量测试 | 发版前 / 手动触发 | L1-L5 全部 + 网络异常 + 兼容性 | 30-60 分钟 |

### Smoke 冒烟测试：分层抽样策略

**目标：3-5 分钟内回答"核心功能是不是挂了"。**

冒烟测试不是只跑 P0 用例，而是每层抽样覆盖，确保"接口能通 + 数据格式对 + 主流程走得通"：

| 层级 | 冒烟范围 | 抽样规则 |
|------|---------|---------|
| L1 单元测试 | **全跑** | 单元测试本身很快（秒级），全跑没有额外成本 |
| L2b API 集成 | **每接口 2 个用例** | 1 个正向主流程 + 1 个响应格式校验（覆盖可用性 + 数据正确性） |
| L3 E2E | **每功能 1 个主流程** | P0 功能点的正向完整流程用例（用户最核心的操作路径） |
| L2a / L4 / L5 / 网络异常 / 兼容性 | **默认跳过** | 按影响分析按需追加（见下文） |

**冒烟用例标记：** 阶段一生成用例时，自动标记每个功能的冒烟核心用例。标记规则：
- P0 功能点的正向主流程 E2E 用例 → 标记 `[smoke]`
- 每个 API 接口的正向用例 + 格式校验用例 → 标记 `[smoke]`
- 每个功能最多标记 2-3 个 `[smoke]` 用例

**执行命令：**
```bash
# 冒烟测试：只跑带 [smoke] 标记的用例
{单元测试命令}                                    # L1 全跑
npx playwright test tests/integration/ --grep smoke  # L2b 抽样
npx playwright test tests/e2e/ --grep smoke          # L3 主流程
```

### Regression 标准回归

**目标：10-20 分钟内全面验证功能正确性。**

覆盖 L1 + L2a + L2b + L3 + L4，跳过 L5/网络异常/兼容性（这些耗时长且不是每次都需要）。

### Full 全量测试

**目标：发版前完整验证，不留盲区。**

覆盖所有层级 + 网络异常批次 + 兼容性测试（需确认浏览器范围）。

### 影响分析驱动的按需追加

**默认回归范围是兜底，影响分析可以智能追加或裁剪。** 两层结合：

**第一层：路径规则自动匹配（确定性高，作为兜底）**

| 改动文件路径 | 自动追加的测试 |
|-------------|--------------|
| `src/api/` 或 `server/` 或后端路由 | 对应的 L2b 用例 + 依赖该 API 的 L3 用例 |
| `src/components/` 或前端组件 | 涉及该组件的 L3 + L4 用例 |
| `migrations/` 或数据库 Schema | L2a 全跑 + 相关 L2b 用例 |
| `src/styles/` 或全局样式 | L4 全跑 |
| `package.json` 或依赖变更 | L5 安全扫描（npm audit） |
| `tests/` 或测试脚本自身 | 修改的测试重跑 |

**第二层：AI 补充判断（修复闭环中使用）**

AI 在修复 bug 后读取 `git diff`，分析：
- 改动是否影响了公共模块（工具函数、通用组件、中间件）→ 如果是，扩大回归范围到所有依赖模块
- 改动是否涉及权限/认证逻辑 → 如果是，追加权限相关 L3 用例
- 改动是否涉及数据模型 → 如果是，追加 L2a + 关联接口的 L2b
- 改动是否涉及网络请求处理/错误处理 → 如果是，追加网络异常批次

**影响分析输出格式：**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
影响分析 — 回归范围建议
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
本次改动文件：
  - src/api/auth.ts（后端认证接口）
  - src/components/LoginForm.tsx（前端登录组件）

路径规则匹配（自动追加）：
  + L2b: TC-F001-L2b-01~05（auth 接口相关，5 个用例）
  + L3: TC-F001-L3-01~03（登录流程相关，3 个用例）
  + L4: TC-F001-L4-01（登录页视觉，1 个用例）

AI 补充判断：
  + L3: TC-F007-L3-01（权限差异化 UI，因改动涉及认证逻辑）

建议回归范围：Smoke + 以上 10 个追加用例（预计 5-8 分钟）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 修改后提醒触发回归

**每次代码修改完成后（开发 Skill 或修复闭环 Skill 结束时），必须提醒用户触发回归测试：**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ 代码已修改，建议执行回归测试
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
本次修改涉及：{改动摘要}

建议回归级别：{Smoke / Regression}（基于影响分析）
预计耗时：{N} 分钟

回归范围：
  - L1 单元测试（全跑）
  - L2b: {N} 个用例（{受影响接口}）
  - L3: {N} 个用例（{受影响功能}）
  {+ 影响分析追加的用例}

是否立即执行？（回复"跑回归"开始 / "跳过"暂不执行）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

> 此提醒不可跳过（必须输出），但用户可以选择不执行。

### CI/CD 自动化集成（可选）

**CI/CD 是可选增强，默认不开启。** 在项目初始化时询问用户是否启用。

启用后，CodeMan 在阶段一生成测试脚本时，同时生成 CI 配置文件：

**CI 平台选择（config.yaml 配置）：**
- `github_actions`：生成 `.github/workflows/test.yml`
- `gitlab_ci`：生成 `.gitlab-ci.yml`
- `none`（默认）：不生成 CI 配置

**CI Pipeline 与回归级别的对应关系：**

```
代码推送（push）     → 触发 Smoke 冒烟测试
PR 创建/更新         → 触发 Regression 标准回归
合并到主分支（merge） → 触发 Regression 标准回归
手动触发 / Tag 发版   → 触发 Full 全量测试
```

**测试结果反馈机制：**
- Smoke/Regression 失败 → PR 上显示 ❌，**阻断合并**
- 测试报告摘要自动回写到 PR Comment（通过/失败数、失败详情链接）
- Full 测试结果记录到 Release Notes

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

## 网络异常测试结果

> 网络配置：slow_3g（latency={N}ms, download={N}kbps, upload={N}kbps）

| 场景 | 用例数 | ✅ 通过 | ❌ 失败 | 失败详情 |
|------|--------|--------|--------|---------|
| 弱网/慢速 | {N} | {N} | {N} | {失败用例及原因} |
| 离线→恢复 | {N} | {N} | {N} | {失败用例及原因} |
| 接口超时/错误 | {N} | {N} | {N} | {失败用例及原因} |
| 请求中断 | {N} | {N} | {N} | {失败用例及原因} |

## 兼容性测试结果

> 测试范围：{用户确认的浏览器和设备列表}

| 浏览器/设备 | L3 E2E | L4 视觉 | 特有问题 |
|------------|--------|---------|---------|
| Chromium 桌面 | ✅ {N}/{N} | ✅ {N}/{N} | — |
| Firefox 桌面 | {状态} | {状态} | {问题描述，如无则 —} |
| WebKit 桌面 | {状态} | {状态} | {问题描述} |
| iPhone 14 | {状态} | {状态} | {问题描述} |
| Pixel 7 | {状态} | {状态} | {问题描述} |
| iPad Pro 11 | {状态} | {状态} | {问题描述} |

## L5 非功能测试详细结果

### 性能测试

**Lighthouse 前端性能（逐页面）：**

| 页面 | LCP | FID | CLS | Score | 状态 |
|------|-----|-----|-----|-------|------|
| {页面路径} | {N}ms（阈值 ≤2500） | {N}ms（≤100） | {N}（≤0.1） | {N}（≥80） | ✅/❌ |

**k6 API 压测：**

| 场景 | 并发 | 持续 | P95 | P99 | 错误率 | 状态 |
|------|------|------|-----|-----|--------|------|
| 基准 | 10 VUs | 30s | {N}ms（≤200） | {N}ms（≤500） | {N}% | ✅/❌ |
| 压力 | 50 VUs | 60s | {N}ms（≤500） | {N}ms（≤1000） | {N}% | ✅/❌ |
| 峰值 | 100 VUs | 10s | {N}ms（≤1000） | — | {N}%（≤1%） | ✅/❌ |

**内存泄漏：** {✅ 无泄漏（增长 {N}MB < 阈值 20MB）/ ❌ 疑似泄漏（增长 {N}MB）/ ⬜ 未执行}

### 安全测试

| 检测项 | 结果 | 详情 |
|--------|------|------|
| 依赖漏洞（npm audit） | ✅/❌ | high: {N}, critical: {N} |
| XSS 检测 | ✅/❌ | {检测数} 个 payload，{通过数} 个拦截 |
| CSRF 检测 | ✅/❌ | {检测数} 个请求，{拒绝数} 个正确拒绝 |
| SQL 注入 | ✅/❌ | {检测数} 个参数，{拦截数} 个正确拦截 |
| 越权访问 | ✅/❌ | 无Token/伪造/过期/越权共 {N} 场景 |
| 敏感信息泄露 | ✅/❌ | {扫描接口数} 个接口，{泄露数} 处泄露 |

**手动测试建议执行情况：** {已执行 N 项 / 全部跳过}

### 可访问性测试

| 页面 | WCAG 级别 | Critical | Serious | Moderate | Minor | 状态 |
|------|----------|----------|---------|----------|-------|------|
| {页面路径} | AA | {N} | {N} | {N} | {N} | ✅/❌ |

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
| L3 网络异常脚本 | `tests/e2e/network/*.spec.ts` | 弱网/离线/超时/中断测试 |
| L4 UI 视觉脚本 | `tests/visual/*.spec.ts` | Midscene + Playwright 脚本 |
| 兼容性测试配置 | `tests/playwright.config.ts` | 多浏览器 + 多设备项目配置 |
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
  L3 网络异常：{N} 个，通过率 {%}
  兼容性测试：{浏览器数} 浏览器 × {设备数} 设备，特有问题 {N} 个
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

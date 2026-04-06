# 测试阶段一：用例生成 + 自动化脚本编写

> 本文件是 `testing/SKILL.md` 的子文件。进入阶段一时由主文件指引加载。
> 跨阶段共享规则（防虚假通过、描述质量标准、脚本归因流程等）在主文件 SKILL.md 中，此处不重复。

---

## 阶段一：测试用例生成 + 自动化脚本编写（L2-L5）

### 核心原则

**每个功能点的测试用例必须从 PRD 验收标准和边界场景中推导，不是从代码反推。每个用例必须附带可执行的自动化脚本。**

用例生成前，逐条读取以下三类来源：

**来源 1：PRD 碎片文件（`feat-*.md`）**
- `## 功能点明细` 表格中每一行的验收标准
- `## 边界场景` 中列出的每一个边界情况
- `## UI 设计要求` 中的视觉规范（如有）
- `## 数据字典` 中的字段定义
- 需求精粹卡中的关键验收标准（DIRECTIVES.md）

**来源 2：技术方案（`mod-*.md` + `api-*.md`）**
- 每个 API 端点的错误码和异常处理（如 401/403/404/409/422 各自的触发条件和返回格式）
- 每个设计决策中的可测试行为（如"缓存 TTL 5 分钟"→ 5 分钟后缓存应失效；"密码错误 5 次锁定"→ 第 6 次应返回锁定提示）
- 中间件/拦截器的行为（如鉴权中间件对无 token/过期 token/无效 token 的处理）
- 数据一致性约束（如唯一性约束触发时的错误返回）

**来源 3：实际代码（Grep 扫描）**
- 代码中实现但 PRD/技术方案未提及的 API 端点
- 核心业务逻辑中的条件分支（辅助发现遗漏场景）

**三类来源的优先级：** PRD 验收标准 > 技术方案设计决策 > 代码分支扫描。PRD 和技术方案来源的用例为必须生成，代码分支来源的用例为建议生成。

### 隐性需求推导规则

**PRD 不可能穷举所有测试场景。以下常见的隐性需求必须主动推导并生成对应用例，即使 PRD 未明确提到。**

#### 必须推导的隐性场景

| 隐性场景 | 触发条件（代码中存在即推导） | 必须生成的用例 |
|---------|------------------------|-------------|
| **下拉框/选择器数据加载** | 页面有 `<select>`、`Dropdown`、`Combobox` 等组件 | ① 数据是否正确加载（不为空）② 选中后值是否正确传递 ③ 搜索过滤是否生效（如有）④ 无数据时的空状态展示 |
| **弹窗/抽屉完整生命周期** | 页面有 `Modal`、`Dialog`、`Drawer` 组件 | ① 打开→填写→提交→关闭→数据刷新的完整流程 ② 取消/ESC/点遮罩关闭不保存 ③ 表单回显（编辑场景）④ 校验拦截 |
| **业务线/租户隔离** | 系统有多业务线、多租户、多角色概念 | ① 用户只能看到自己业务线的数据 ② 跨业务线 ID 直接访问被拒绝 ③ 切换业务线后数据正确更新 |
| **分页列表标准行为** | 页面有分页列表 | ① 分页切换数据正确 ② 每页数量切换 ③ 排序切换 ④ 搜索+分页联动（搜索后回到第 1 页）⑤ 空结果展示 |
| **CRUD 完整闭环** | 有创建/编辑/删除操作的功能 | ① 创建→列表可见 ② 编辑→数据更新 ③ 删除→确认→列表消失 ④ 创建后立即编辑 ⑤ 创建后立即删除 |
| **异步操作反馈** | 有 API 调用的用户操作 | ① Loading 状态展示 ② 成功反馈（Toast/跳转）③ 失败反馈（错误提示）④ 防重复提交（按钮禁用） |
| **URL 直接访问** | 有详情页、编辑页等带 ID 的路由 | ① 直接访问合法 URL 正常展示 ② 访问不存在的 ID → 404 ③ 访问无权限的 ID → 403 |
| **时间/日期相关** | 有日期选择、时间显示、倒计时等 | ① 时区显示正确 ② 跨日/跨月边界 ③ 日期格式一致性 |

**推导流程：**
1. 读取代码文件列表和技术方案，识别项目中使用的 UI 组件类型
2. 对照上表逐项检查：项目中是否存在该组件/场景
3. 存在的场景 → 无论 PRD 是否提到，都必须生成对应用例
4. 在用例中标注 `[隐性推导]`，说明推导来源（如"项目使用了 Select 组件，推导下拉框数据加载测试"）

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

### 断言模式规范（黑名单 + 白名单）

**测试脚本的断言质量决定了测试结果的可信度。** 断言写得差等于没测 — 脚本"通过"了但什么都没验证。以下规范在编写 L2/L3 脚本时必须严格遵守。

#### 禁止断言模式黑名单

**以下断言模式严格禁止使用，无论在任何测试层级。这些模式的共同特征是"恒为真"或"验证了不该验证的东西"。**

| 禁止模式 | 为什么禁止 | 示例（禁止写出这样的代码） |
|---------|---------|------------------------|
| **HTML 全文关键词匹配** | 页面 HTML 中 label/属性名/注释都可能包含关键词，永远为 true | `expect(await page.content()).toContain('商机')` — 匹配到的是 label 文案不是下拉数据 |
| **`page.content()` + includes/match** | 同上，HTML 全文搜索无法验证具体元素的状态 | `const has = (await page.content()).includes('筛选')` |
| **恒为真的断言** | 数学上永远成立，不可能失败 | `expect(await locator.count()).toBeGreaterThanOrEqual(0)` — count ≥ 0 恒为真 |
| **硬编码通过** | 跳过了实际验证 | `expect(true).toBe(true)` 或直接写 `// 已通过代码 Review` |
| **只截图不断言** | 截图不等于验证，没有机器断言就没有自动化价值 | 只调用 `screenshot()` 后标注"需人工核查" |
| **操作后不验证状态变化** | 无法证明操作生效 | 点击了提交按钮，但没检查 URL 变化/toast/列表更新 |
| **只验证元素存在** | `toBeVisible()` 只证明元素在 DOM 中，不证明内容/布局/交互正确 | 整个用例只有 `expect(button).toBeVisible()` 没有后续操作和验证 |

#### 正确断言模式白名单

**编写断言时，必须从以下白名单中选择对应场景的模式。不在白名单中的断言方式需要说明理由。**

| 验证场景 | 必须使用的断言模式 | 代码示例 |
|---------|-----------------|---------|
| **下拉框有数据** | 点击展开 → 等待选项出现 → 计数 → 大于 0 | `await trigger.click(); await page.waitForSelector('[role=option]'); expect(await page.locator('[role=option]').count()).toBeGreaterThan(0);` |
| **列表有数据** | 等待行渲染 → 计数 tbody tr → 大于 0 | `await page.waitForSelector('tbody tr'); expect(await page.locator('tbody tr').count()).toBeGreaterThan(0);` |
| **筛选/搜索生效** | 操作前 count → 执行筛选 → 操作后 count → 不相等或减少 | `const before = await rows.count(); await filterInput.fill('test'); await page.waitForTimeout(500); const after = await rows.count(); expect(after).not.toBe(before);` |
| **表单提交成功** | 填写 → 提交 → 等待成功标志（URL 变化/toast/跳转） | `await submitBtn.click(); await expect(page).toHaveURL(/\/list/); // 或 await expect(page.locator('.toast-success')).toBeVisible();` |
| **布局结构（行数）** | 查询特定容器内的行/列数 → 精确断言 | `expect(await page.locator('thead tr').count()).toBe(1); // 表头应为 1 行` |
| **文案内容** | 定位到具体元素 → 验证 textContent → 精确匹配 | `expect(await page.locator('[data-testid="submit-btn"]').textContent()).toBe('立即注册');` |
| **数值计算** | 获取页面显示值 → 与预期计算结果精确比较 | `const total = await page.locator('.total').textContent(); expect(total).toBe('89.70');` |
| **状态切换** | 操作前状态 → 执行操作 → 操作后状态 → 两者不同 | `expect(await btn.isDisabled()).toBe(false); await btn.click(); expect(await btn.isDisabled()).toBe(true);` |
| **删除生效** | 操作前 count → 删除 → 确认 → 操作后 count = 前 - 1 | `const before = await rows.count(); await deleteBtn.click(); await confirmBtn.click(); expect(await rows.count()).toBe(before - 1);` |
| **弹窗/抽屉关闭** | 关闭操作 → 等待动画 → 断言不可见 | `await closeBtn.click(); await expect(page.locator('.modal')).not.toBeVisible();` |
| **权限控制** | 以无权限角色访问 → 断言看不到/被拦截 | `expect(await page.locator('[data-testid="admin-panel"]').count()).toBe(0);` |

**白名单使用规则：**
- 编写断言时，先判断当前验证场景属于上表哪一类
- 按对应的断言模式编写，可调整选择器但不改变断言逻辑
- 如果场景不在白名单中，需要在用例注释中说明断言逻辑的合理性
- **白名单的核心原则：每个断言必须「操作 → 等待 → 验证具体值/状态变化」，不允许只验证存在性或用全文搜索**

### E2E 选择器优先级规范

**编写 Playwright E2E 脚本时，元素定位必须按以下优先级选择选择器，优先使用稳定性最高的方式：**

| 优先级 | 选择器类型 | 稳定性 | 示例 |
|--------|---------|--------|------|
| **1（优先）** | `data-testid` | 最高 — 改文案/改样式不影响 | `page.locator('[data-testid="user-register-btn"]')` |
| **2** | ARIA role + name | 高 — 语义化，改样式不影响 | `page.getByRole('button', { name: '立即注册' })` |
| **3** | label 关联 | 高 — 表单场景最合适 | `page.getByLabel('邮箱')` |
| **4（最后）** | 文本内容 | 低 — 改文案就挂 | `page.getByText('立即注册')` |
| **禁止** | CSS 类名/样式选择器 | 极低 — 改样式就挂 | ~~`page.locator('.btn-primary.mt-4')` ~~ |

**规则：**
- 如果代码中有 `data-testid` → 必须用 `data-testid`，不用其他方式
- 如果没有 `data-testid` → 用 `getByRole` 或 `getByLabel`
- 只有以上都不可用时才用 `getByText`
- **严禁使用 CSS 类名选择器**（`.btn-primary`、`.form-control` 等），样式重构会导致测试全挂
- 如果发现关键交互元素缺少 `data-testid`，在测试报告中标注为建议项：「建议前端为 {元素} 添加 `data-testid="{命名}"`」

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

#### ⚠️ 强制前置：UI 探索（写脚本前必须先看实际页面）

**严禁直接基于 PRD 文档假设编写 E2E 脚本。** 必须先通过 Playwright 实际打开页面，观察真实 UI 结构，再基于实际观察编写测试脚本。

**为什么：** PRD 描述的是设计意图，实际实现可能与文档存在差异（如按钮在折叠菜单内、功能需要先切换 Tab、弹窗结构与文档不同）。基于假设写的脚本本身就有 bug，会导致测试结果完全不可信——把脚本 bug 误报为产品 bug，或把产品 bug 误判为脚本问题。

**强制执行步骤：**

```
写 E2E 脚本前，必须先执行 UI 探索：

1. 启动开发服务器（如未启动）
2. 用 Playwright 打开目标页面，截图记录实际 UI：
   ┌─────────────────────────────────────────────┐
   │  const page = await browser.newPage();      │
   │  await page.goto('{目标URL}');               │
   │  await page.screenshot({                     │
   │    path: 'tests/screenshots/explore-{页面}.png', │
   │    fullPage: true                            │
   │  });                                         │
   └─────────────────────────────────────────────┘
3. 观察并记录实际 UI 结构：
   - 页面上实际存在哪些元素（按钮、输入框、标签页、弹窗等）
   - 元素的实际文案（按钮写的是"Submit"还是"提交"？）
   - 元素的实际位置和层级关系（是否在折叠菜单/Tab/弹窗内？）
   - 需要哪些前置操作才能看到目标元素（是否需要先登录/切换Tab/展开面板？）
4. 将实际 UI 结构与 PRD 对比，记录差异：
   - 一致 → 基于实际观察编写脚本
   - 不一致 → 记录为疑似问题，但脚本仍基于实际 UI 编写（避免脚本本身报错）
```

**禁止行为：**
- ❌ 读完 PRD 后直接写 `page.click('button:has-text("下载")')` — 你怎么知道按钮文案是"下载"而不是"Download"？
- ❌ 假设弹窗打开后就能看到某个按钮 — 也许需要先切换到某个 Tab 才能看到
- ❌ 假设页面结构和 PRD ASCII 原型图完全一致 — 实现可能与设计有偏差

**正确做法：**
- ✅ 先打开页面截图，确认按钮文案实际是什么
- ✅ 先手动走一遍流程，确认操作路径（是否需要先点击某个 Tab、展开某个面板）
- ✅ 用 `page.locator('{选择器}').count()` 先确认元素存在，再写断言

---

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

#### 组件类型标准化验证模板

**以下常见 UI 组件在 E2E 测试中有标准化的验证流程。凡是页面中出现这些组件，都必须按模板覆盖，不得只验证"组件可见"。**

##### 下拉框/选择器（Select / Dropdown / Combobox）

```typescript
// 标准验证流程
test('下拉框完整验证', async ({ page }) => {
  // ① 数据加载：下拉选项不为空
  await page.click('[data-testid="status-select"]');
  const options = page.locator('[data-testid="status-select"] option, [role="option"]');
  expect(await options.count()).toBeGreaterThan(0);

  // ② 选中传值：选择后值正确
  await page.selectOption('[data-testid="status-select"]', 'active');
  await expect(page.locator('[data-testid="status-select"]')).toHaveValue('active');

  // ③ 搜索过滤（如有搜索功能）
  await page.fill('[data-testid="status-search"]', '活跃');
  const filtered = page.locator('[role="option"]:visible');
  expect(await filtered.count()).toBeGreaterThan(0);
  for (const opt of await filtered.all()) {
    await expect(opt).toContainText('活跃');
  }

  // ④ 关联数据正确（如选择客户后加载该客户的联系人）
  await page.selectOption('[data-testid="customer-select"]', 'customer-001');
  await page.waitForTimeout(500); // 等待联动加载
  const contacts = page.locator('[data-testid="contact-select"] option, [role="option"]');
  expect(await contacts.count()).toBeGreaterThan(0);

  // ⑤ 空状态（无匹配时的提示）
  await page.fill('[data-testid="status-search"]', '不存在的选项xxxxx');
  await expect(page.locator('[data-testid="no-results"]')).toBeVisible();
});
```

##### 列表页（Table / List）

```typescript
// 标准验证流程
test('列表页完整验证', async ({ page }) => {
  await page.goto('/tasks');

  // ① 数据加载：列表有内容
  await expect(page.locator('[data-testid="list-item"], tr[data-testid]').first()).toBeVisible();

  // ② 列头/字段完整性：对照 PRD 确认列头正确
  const headers = await page.locator('th, [data-testid="column-header"]').allTextContents();
  expect(headers).toEqual(expect.arrayContaining(['名称', '状态', '创建时间', '操作']));

  // ③ 排序：点击列头排序
  await page.click('th:has-text("创建时间")');
  // 验证排序方向指示器
  await expect(page.locator('th:has-text("创建时间") [data-testid="sort-icon"]')).toBeVisible();

  // ④ 搜索筛选：输入关键词 → 列表过滤
  await page.fill('[data-testid="search-input"]', '测试');
  await page.waitForTimeout(500);
  for (const item of await page.locator('[data-testid="list-item"]').all()) {
    await expect(item).toContainText('测试');
  }

  // ⑤ 分页：切换页码
  await page.fill('[data-testid="search-input"]', ''); // 清空搜索
  await page.click('[data-testid="page-2"], [data-testid="next-page"]');
  await expect(page.locator('[data-testid="list-item"]').first()).toBeVisible();

  // ⑥ 空状态
  await page.fill('[data-testid="search-input"]', '绝对不存在的内容zzzzz');
  await page.waitForTimeout(500);
  await expect(page.locator('[data-testid="empty-state"]')).toBeVisible();

  // ⑦ 行操作：点击行进入详情 / 点击操作按钮
  await page.fill('[data-testid="search-input"]', '');
  await page.waitForTimeout(500);
  await page.locator('[data-testid="list-item"]').first().click();
  // 验证跳转到详情页或打开抽屉
});
```

##### 表单（Form）

```typescript
// 标准验证流程
test('表单完整验证', async ({ page }) => {
  await page.goto('/tasks/create');

  // ① 初始状态：必填标记可见、提交按钮状态正确
  await expect(page.locator('[data-testid="name-required-mark"]')).toBeVisible();

  // ② 校验拦截：空提交 → 显示错误提示
  await page.click('[data-testid="submit-btn"]');
  await expect(page.locator('[data-testid="name-error"]')).toBeVisible();

  // ③ 逐字段填写：验证实时校验反馈
  await page.fill('[data-testid="name-input"]', 'a'); // 太短
  await expect(page.locator('[data-testid="name-error"]')).toContainText('至少');
  await page.fill('[data-testid="name-input"]', '正常任务名称');
  await expect(page.locator('[data-testid="name-error"]')).not.toBeVisible();

  // ④ 完整填写 → 提交成功
  await page.fill('[data-testid="desc-input"]', '任务描述');
  await page.selectOption('[data-testid="priority-select"]', 'high');
  await page.click('[data-testid="submit-btn"]');

  // ⑤ 提交过程：Loading → 成功反馈
  await expect(page.locator('[data-testid="submit-btn"]')).toBeDisabled();
  await expect(page.locator('[data-testid="success-toast"]')).toBeVisible({ timeout: 10000 });

  // ⑥ 提交后：跳转或刷新 + 数据可见
  await expect(page).toHaveURL(/\/tasks/);
  await expect(page.locator('[data-testid="list-item"]').first()).toContainText('正常任务名称');
});

// 编辑表单额外验证
test('编辑表单回显和更新', async ({ page }) => {
  await page.goto('/tasks/1/edit');

  // ① 数据回显：字段有值（不是空表单）
  await expect(page.locator('[data-testid="name-input"]')).not.toHaveValue('');

  // ② 修改 → 保存 → 验证更新
  const originalName = await page.locator('[data-testid="name-input"]').inputValue();
  await page.fill('[data-testid="name-input"]', '修改后的名称');
  await page.click('[data-testid="submit-btn"]');
  await expect(page.locator('[data-testid="success-toast"]')).toBeVisible({ timeout: 10000 });

  // ③ 返回列表验证更新
  await page.goto('/tasks');
  await expect(page.locator('[data-testid="list-item"]').first()).toContainText('修改后的名称');
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

### Step 5: 用例质量自动校验（输出总表前必须完成）

**在输出用例规划总表给用户确认之前，必须先执行以下三项自动校验。有任何 ❌ 项必须先修复再输出总表，不得带着问题让用户确认。**

#### 校验 A：完整性校验 — 每个功能点是否有完整流程用例

**逐条检查 PRD 功能点明细中的每一行验收标准，确认其对应的 E2E 用例是否覆盖了完整的操作流程（不只是"元素存在"）。**

检查规则：
- 每条验收标准（Given-When-Then）的 **When**（用户操作）必须在 E2E 脚本中体现为实际操作（`click` / `fill` / `goto`）
- 每条验收标准的 **Then**（预期结果）必须在 E2E 脚本中体现为断言
- 涉及 CRUD 操作的功能点必须有「创建 → 查看 → 编辑 → 删除」中至少「创建 → 查看」的完整流程用例

输出格式：
```
【完整性校验】
✅ F001.1 用户注册 — TC-F001-L3-01 覆盖完整流程（填写→提交→跳转→验证）
✅ F001.2 邮箱校验 — TC-F001-L3-02 覆盖完整流程（输入非法值→触发校验→显示错误）
❌ F003.1 创建拜访记录 — 缺少完整流程用例！现有用例 TC-F003-L3-01 仅验证元素存在（toBeVisible），
   未覆盖"点击新增 → 打开弹窗 → 填写表单 → 选择关联商机 → 提交 → 验证创建成功"
   → 需补充完整流程用例
❌ F004.2 编辑商机 — 缺少编辑流程，只有查看用例
   → 需补充"打开详情 → 点编辑 → 修改字段 → 保存 → 验证更新"用例

完整性：{通过数}/{总数}（{通过率}%）
需补充：{N} 个功能点的完整流程用例
```

**有 ❌ 项时：先自动补充缺失的完整流程用例，再继续。**

#### 校验 B：用例深度检测 — 识别"浅测试"

**自动分析生成的 Playwright 脚本，检测是否存在"只验证元素存在、不做实际操作"的浅测试用例。**

检测规则：
- 如果一个 L3 用例的脚本中**只有** `toBeVisible()` / `toContainText()` 等断言，**没有** `click()` / `fill()` / `selectOption()` / `goto()` 等操作动词 → 标记为 `⚠️ 疑似浅测试`
- 如果一个 L3 用例的脚本中操作步骤少于 2 步 → 标记为 `⚠️ 操作步骤过少`
- 如果 PRD 验收标准描述了多步交互但用例只验证最终状态 → 标记为 `⚠️ 跳过中间状态`

输出格式：
```
【用例深度检测】
✅ TC-F001-L3-01: 操作 5 步 + 断言 4 个 — 深度合格
✅ TC-F001-L3-02: 操作 3 步 + 断言 3 个 — 深度合格
⚠️ TC-F003-L3-01: 操作 0 步 + 断言 2 个（仅 toBeVisible）— 疑似浅测试
   PRD 验收标准："用户点击新增按钮，打开拜访记录弹窗，填写后提交"
   但用例只验证了"日历组件可见"，未操作"新增→弹窗→填写→提交"
   → 需重写为完整操作流程
⚠️ TC-F004-L3-03: 操作 1 步 + 断言 1 个 — 操作步骤过少
   → 需补充完整交互步骤

浅测试风险：{N} 个用例需重写或加深
```

**有 ⚠️ 项时：先自动重写疑似浅测试的用例，再继续。**

#### 校验 C：覆盖率前置校验 — 在用户确认前拦截遗漏

**将覆盖率矩阵检查从"测试完成后"提前到"用例生成后"执行，在用户确认用例之前就发现遗漏。**

检查规则（文档来源）：
- 每条 PRD 验收标准 → 是否有对应的 L3 E2E 用例？
- 每个 PRD 边界场景 → 是否有对应的 L2b 或 L3 用例？
- 每条 DIRECTIVES.md 精粹卡关键验收标准 → 是否有 E2E 覆盖？
- 每个 API 接口（来自 api-*.md）→ 是否有 L2b 用例（含格式校验）？
- 每个技术方案设计决策（来自 mod-*.md）→ 是否有对应测试用例覆盖？（见下方校验 D）

**校验 C-extra：代码扫描交叉比对（机械化，不靠 AI 判断）**

**除了对照文档，还必须用 Grep 扫描实际代码，发现"实现了但文档没提到、因此没有测试"的接口和逻辑：**

```
操作：
1. 用 Grep 扫描代码中的路由定义，提取所有实际 API 端点：
   搜索模式（根据技术栈调整）：
   - Express: app.get|app.post|router.get|router.post 等
   - FastAPI: @app.get|@app.post|@router.get 等
   - Spring: @GetMapping|@PostMapping|@RequestMapping 等
   - Go: HandleFunc|r.GET|r.POST 等

2. 将扫描结果与测试用例中的请求 URL 比对：
   从测试文件中 Grep 所有 api.get|api.post|fetch|axios 调用的 URL

3. 产出 diff：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
API 覆盖交叉比对（代码实际路由 vs 测试覆盖）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
代码中的 API 端点（Grep 扫描）：
  ✅ POST /api/auth/register — 有 L2b 用例 TC-F001-L2-01
  ✅ POST /api/auth/login — 有 L2b 用例 TC-F001-L2-02
  ❌ DELETE /api/auth/logout — 无任何测试用例
  ❌ GET /api/users/export — 无任何测试用例（api 文档中也未定义）

测试中请求但代码中不存在的 URL：
  ⚠️ GET /api/users/search — 测试引用但代码中无此路由（可能是旧接口/脚本bug）

需补充：{N} 个实际存在但无测试的 API 端点
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

输出格式（合并文档来源 + 代码扫描）：
```
【覆盖率前置校验】
PRD 验收标准覆盖率：{M}/{N}（{%}）
  ❌ 未覆盖：F003.1 "创建拜访记录" — 无对应 E2E 用例
  ❌ 未覆盖：F003.2 "编辑拜访记录" — 无对应 E2E 用例

边界场景覆盖率：{M}/{N}（{%}）
  ✅ 全部覆盖

API 接口覆盖率（文档）：{M}/{N}（{%}）
  ❌ 未覆盖：POST /api/visits — 无 L2b 用例

API 接口覆盖率（代码扫描）：{M}/{N}（{%}）
  ❌ 代码中存在但无测试：DELETE /api/auth/logout, GET /api/users/export

精粹卡验收标准：{M}/{N}（{%}）
  ✅ 全部覆盖

需补充：{N} 条验收标准的用例 + {N} 个接口的用例（含代码扫描发现的）
```

**有 ❌ 项时：先自动补充缺失用例，再继续。**

#### 校验 D：技术方案设计决策覆盖

**除 PRD 外，还必须检查技术方案中的关键设计决策是否有对应测试覆盖。技术方案中定义的行为如果没有测试，可能在后续重构中被意外破坏。**

检查规则：
- 读取 `mod-*.md` 中的设计决策（缓存策略、鉴权逻辑、业务规则、错误处理等）
- 每个可测试的设计决策 → 是否有对应的 L2b 或 L3 用例？

```
【技术方案覆盖校验】
| 设计决策 | 来源 | 对应用例 | 状态 |
|---------|------|---------|------|
| JWT 过期后返回 401 | mod-auth.md §鉴权 | TC-F001-L2-05 | ✅ |
| Redis 缓存命中时不查 DB | mod-product.md §性能 | ❌ 无对应用例 | ❌ |
| 并发下单幂等性 | mod-order.md §核心逻辑 | TC-F005-L2-08 | ✅ |
| 密码错误 5 次锁定 30 分钟 | mod-auth.md §安全 | ❌ 无对应用例 | ❌ |

覆盖率：{N}/{M}（{%}）
需补充：{N} 个设计决策的测试用例
```

**有 ❌ 项时：先自动补充缺失用例，再继续。**

#### 校验 E：代码分支覆盖辅助

**对核心业务逻辑文件进行分支扫描，检查条件分支是否有对应的测试用例。**

```
操作：
1. 读取核心业务文件（Service/Controller 层），识别：
   - if/else 条件分支
   - switch/case 分支
   - try/catch 错误处理分支
   - 三元表达式中的条件
2. 对照已生成的测试用例，检查每个分支是否有触发该分支的用例

输出：
【代码分支覆盖分析】
文件：src/services/order.ts
  L42: if (order.status === 'paid') → ✅ TC-F005-L2-03 覆盖
  L42: else (order.status !== 'paid') → ❌ 无用例触发此分支
  L67: switch(payment.method) case 'credit_card' → ✅ TC-F005-L2-04
  L68: case 'wechat_pay' → ❌ 无用例覆盖
  L69: case 'alipay' → ❌ 无用例覆盖
  L78: catch (PaymentTimeoutError) → ❌ 无用例覆盖

需补充：{N} 个未覆盖的代码分支
```

**注意：此分析仅作为辅助建议，不强制要求 100% 分支覆盖。优先补充业务关键分支（支付、权限、状态流转等），纯防御性分支（如框架级错误处理）可标注跳过原因。**

---

**五项校验全部通过后（无 ❌、无 ⚠️），才输出用例规划总表：**

### Step 6: 输出用例规划总表并确认

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
```

#### Step 6b: 验收标准理解确认（拦截 AI 理解偏差）

**输出用例规划总表后、用户确认前，必须额外输出「验收标准理解确认表」。**

**为什么：** AI 可能对 PRD 验收标准的理解有偏差。如果理解错了，代码和测试会"一致地错" — 测试全部通过但功能实际不对。必须在执行前让用户确认 AI 的理解是否正确。

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
验收标准理解确认 — 请逐条核对
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
以下是我对每条关键验收标准的理解和验证方式。
如果我的理解有误，请指出，我将修正用例后重新确认。

F001.1 验收标准原文："用户注册成功后跳转到 Dashboard 页面"
  我的理解：用户填写表单 → 提交 → 页面 URL 变为 /dashboard
  验证方式：Playwright 填写表单 → 点击提交 → expect(page).toHaveURL('/dashboard')
  ⬜ 理解正确？

F001.2 验收标准原文："邮箱已存在时显示错误提示"
  我的理解：使用已注册邮箱提交 → 表单下方显示"该邮箱已被注册"提示
  验证方式：先注册一个邮箱 → 再次用同一邮箱注册 → expect 错误提示可见且包含"已被注册"
  ⬜ 理解正确？

F002.1 验收标准原文："管理员可以查看所有用户列表"
  我的理解：以 admin 角色登录 → 访问 /users → 页面显示用户表格且包含所有角色的用户
  验证方式：以 admin 登录 → 检查列表是否包含 user 角色和 admin 角色的记录
  ⬜ 理解正确？

{...对每条关键验收标准都输出理解 + 验证方式...}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
请逐条确认后继续。如有理解偏差请指出。
```

**确认规则：**
- 用户确认全部理解正确 → 写入测试用例文档和脚本
- 用户指出理解偏差 → 修正对应的用例和脚本 → 重新输出修正后的理解确认
- **范围：** 对所有 PRD 验收标准和精粹卡关键验收标准逐条输出（边界场景和隐性推导用例可不逐条确认，只确认核心验收标准）

确认后写入测试用例文档和自动化脚本。

### Step 7: 写入测试用例文档和自动化脚本

用户确认后：
1. 为每个功能点写入 `.codeman/docs/tests/test-{功能名}.md`
2. 生成所有自动化脚本到项目 `tests/` 目录
3. 更新 `.codeman/docs/tests/INDEX.md`

---

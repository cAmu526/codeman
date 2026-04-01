# 测试用例：{{功能点名称}}

> PRD 来源：F{{ID}} | 创建：{{YYYY-MM-DD}}

---

## TC-{{ID}}-L2-{{NN}}: {{测试场景名称（集成测试）}}

**测试层级：** L2 集成测试

**PRD 来源：** F{{ID}}.{{子ID}} — {{验收标准原文}}

**自动化脚本：** `tests/integration/{{文件名}}.test.js` → TC-{{ID}}-L2-{{NN}}

**测试数据：** 引用 `tests/fixtures/seed.js` 中的 TEST_DATA

**前置条件：**
- 测试数据库已 seed（自动，通过 setup.sh）

**测试步骤：**
1. {{操作步骤1，如：POST /api/register 发送注册请求}}
2. {{操作步骤2，如：验证响应体包含 user_id 和 token}}
3. {{操作步骤3，如：查询数据库确认用户记录已创建}}

**预期结果：** {{预期的系统响应}}

**断言要点（自动化）：**
- [ ] `expect(res.status).toBe({{N}})`
- [ ] `expect(res.body).toHaveProperty('{{field}}')`

**执行状态：** ⬜ 未执行 / ✅ 通过 / ❌ 失败

---

## TC-{{ID}}-L3-{{NN}}: {{测试场景名称（E2E 端到端）}}

**测试层级：** L3 E2E 端到端

**PRD 来源：** F{{ID}}.{{子ID}} — {{验收标准原文}}

**自动化脚本：** `tests/e2e/{{文件名}}.spec.ts` → TC-{{ID}}-L3-{{NN}}

**前置条件：**
- 测试服务器已启动（自动）
- 测试数据已 seed（自动）

**Playwright 脚本：**
```typescript
// 直接附带可执行的测试代码
```

**预期结果：** {{预期的系统响应}}

**断言要点（自动化）：**
- [ ] `await expect(page.locator(...)).toBeVisible()`
- [ ] `await expect(page).toHaveURL(...)`

**执行状态：** ⬜ 未执行 / ✅ 通过 / ❌ 失败

---

## TC-{{ID}}-L4-{{NN}}: {{测试场景名称（UI 视觉）}}

**测试层级：** L4 UI 视觉测试

**PRD 来源：** F{{ID}} — {{UI 设计要求原文}}

**自动化脚本：** `tests/visual/{{文件名}}.spec.ts` → TC-{{ID}}-L4-{{NN}}

**设计截图：** {{截图路径，如：.codeman/assets/design/register.png，无则标注"无设计稿"}}

**Midscene.js 断言（自动化）：**
```typescript
await agent.aiAssert('{{自然语言描述的 UI 断言，直接对应 PRD UI 要求}}');
```

**Playwright 截图对比（自动化）：**
```typescript
await expect(page).toHaveScreenshot('{{基准截图}}', { maxDiffPixelRatio: 0.05 });
```

**断言要点（自动化）：**
- [ ] Midscene.js 自然语言断言通过
- [ ] Playwright 截图对比差异 ≤ 5%

**执行状态：** ⬜ 未执行 / ✅ 通过 / ❌ 失败

---

## TC-{{ID}}-L5-{{NN}}: {{测试场景名称（非功能）}}

**测试层级：** L5 非功能测试

**测试类型：** 性能 / 安全 / 可访问性

**PRD 来源：** {{相关 PRD 约束原文，如：API 响应时间 < 200ms}}

**自动化脚本：** `tests/nonfunctional/{{脚本名}}`

**执行命令（自动化）：**
```bash
{{测试命令，如：npx lighthouse http://localhost:3000 --output=json}}
```

**阈值：**
- {{具体阈值，如：API 响应时间 P95 < 200ms}}

**断言要点（自动化）：**
- [ ] 自动化脚本输出结果与阈值对比

**执行状态：** ⬜ 未执行 / ✅ 通过 / ❌ 失败

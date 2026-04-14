# STATUS - 项目进度状态

> 严格控制在 100 行以内
> 最后更新：{{YYYY-MM-DDTHH:MM:SS}}

## 当前状态

- phase: {{init|requirements|design|development|testing|fixing|deploy-ready|completed}}
- current_module: {{当前模块名，如 user-auth}}
- current_step: {{当前步骤描述，如 coding (module 2/3)}}
- current_task: {{当前原子任务 ID，如 T3，无任务粒度时填 -}}
- task_progress: {{任务进度，如 3/7，无任务粒度时填 -}}
- last_task_done: {{最近完成的任务 ID，如 T2，未开始时填 -}}
- last_updated: {{YYYY-MM-DDTHH:MM:SS}}
- session_id: {{当前会话标识，用于断点续做}}

> `current_task` / `task_progress` / `last_task_done` 仅在 development 阶段使用，
> 由 development Skill 在每个原子任务开始/完成时实时更新；
> 其他阶段保持为 `-`。任务清单详情见 `docs/dev/tasks-{当前模块}.md`。

## 功能点进度

| ID | 功能点 | PRD | 设计 | 编码 | 单测 | 集成 | E2E | UI | 总状态 |
|----|--------|-----|------|------|------|------|-----|-----|--------|
| F001 | {{功能点名称}} | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | 待开始 |

> 图例：✅ 完成 | 🔄 进行中 | ⬜ 待开始 | ❌ 失败

## 待处理事项

- [ ] {{待处理事项1}}
- [ ] {{待处理事项2（如有）}}

## 遗留问题

- {{遗留问题1（如有，格式：[需人工确认] 描述）}}

## Git Checkpoints

| 时间 | Commit Hash | 说明 |
|------|-------------|------|
| {{时间}} | {{hash}} | {{说明}} |

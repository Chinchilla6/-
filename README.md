# 康复 / 健身 App 数据层

当前仓库为康复 / 体态 / 健身 App 提供以下基础能力：

- **wger**：动作、动作翻译、肌肉、器械、图片与视频等通用健身数据
- **Z-Anatomy**：TA2 解剖术语、可点击 3D 人体结构以及与 wger 肌肉的映射
- **Evidence Layer**：PubMed / ACSM 等训练科学证据与 App 自有内容分层
- **Exercise Knowledge Graph**：经过人工审核后才能进入真实用户推荐的动作关系图

App 自己维护康复语义与教学内容，不会在上游同步时被覆盖。

## 当前线上状态

Supabase 已完成自动化同步，不需要在手机或 GitHub 中配置 `DATABASE_URL`。

### wger

当前 live 数据库已同步 **934 个动作**。早期文档中的约 861 个是旧同步时点的数量；上游后来新增了动作，现有 exercise ID 没有重建或替换。

基础数据还包括：

- 15 个 wger 肌肉分类
- 12 类器械
- 多语言动作说明
- 图片 / 视频媒体记录

`sync-wger` Supabase Edge Function 负责更新，Supabase Cron 每周自动执行。

### Exercise Knowledge Graph · Phase 1

第一阶段只处理 **GLUTE + HIP**，没有批量处理全部动作。

当前完成：

- 934 个 `rehab_exercise_metadata` 占位行，与现有 wger ID 一一对应
- 60 个 GLUTE/HIP 动作完成第一版多维分类，状态均为 `AUTO_SUGGESTED`
- 77 条候选关系：28 progression、22 regression、11 alternative、4 preparation、4 activation、6 mobility、2 release
- 77 条关系全部为 `AUTO_SUGGESTED`
- 0 条由 AI 自动标记 `REVIEWED`
- `evaluate_exercise_progression(...)` 保留原 API 形状，但现在只读取 `REVIEWED` 图关系
- 新增 `decide_exercise_progression(...)`，优先 KEEP / REPS_UP / LOAD_UP / SETS_UP / tempo-ROM，再考虑换动作
- sharp pain、麻木、刺痛、放射痛、关节疼痛恶化会阻断自动 progression，不进行伤病诊断

核心原则：

> Exercise progression is a reviewed graph, not an inferred ranking.

动作名相似、embedding、相同肌肉、difficulty 等只能用于候选生成，不能直接产生 approved progression。

实现与测试说明：`docs/EXERCISE_KNOWLEDGE_GRAPH.md`

数据库 smoke tests：`database/tests/exercise_knowledge_graph_smoke.sql`

内部审核页面由 `supabase/functions/progression-admin/index.ts` 提供，支持：

- FROM / TO 动作对比
- movement family / pattern
- primary muscles / equipment
- 多维 difficulty vector
- relationship type / progression dimensions
- AI reason / confidence / evidence level
- APPROVE / REJECT / EDIT
- graph view
- graph validation

管理员 POST API 必须使用有效 Supabase session，并且 `app_metadata.role = admin` 或 `is_admin = true`；service key 不发送到浏览器。

## App 自有康复与分类字段

`rehab_exercise_metadata` 与 wger 上游数据分开，支持 plain text：

- `activation`
- `release`
- `mobility`
- `animation`
- `progression`
- `regression`
- `posture_tags_text`
- `difficulty_text`
- `common_mistakes_text`
- `contraindications_text`

同时保留结构化字段，并已扩展 Knowledge Graph 分类：

- `movement_family`
- `movement_pattern`
- `training_intents`
- `primary_training_intent`
- `strength_demand`
- `stability_demand`
- `coordination_demand`
- `balance_demand`
- `rom_demand`
- `mobility_demand`
- `load_potential`
- `support_level`
- `laterality`
- `kinetic_chain`
- `equipment_level`
- `skill_level`
- `strength_level`
- `mobility_requirement`

primary / secondary muscles 与 equipment 继续复用 wger 的规范化关联表，不在 metadata 重复保存，通过 `exercise_knowledge_view` 统一读取。

## 3D 人体图的数据链

```text
GLB node click
  ↓
z_anatomy_meshes
  ↓
z_anatomy_wger_muscle_map
  ↓
wger_muscles
  ↓
wger_exercise_muscles
  ↓
wger_exercises + translations + media
  ↓
rehab_exercise_metadata
  ↓
exercise_relationships (REVIEWED only for runtime recommendation)
```

## Z-Anatomy

当前数据库已同步：

- 7297 条 TA2 解剖术语 / 原始 code
- 7 个移动端 / Web 可加载的 GLB 人体系统层
- 2914 个独立可点击 3D mesh
- 2806 个 mesh 已通过唯一英文名称精确映射到 TA2
- 15 个 wger 肌肉分类均已连接到对应可点击 Z-Anatomy 肌肉 mesh

GLB 位于本项目 Supabase Storage 的公开 `anatomy-assets` bucket。

相关 SQL：

- `database/z_anatomy_integration.sql`
- `database/z_anatomy_wger_seed.sql`

## Exercise Knowledge Graph 相关 migration

- `database/migrations/20261001063845_phase1_exercise_knowledge_graph.sql`
- `database/migrations/20261001064222_seed_glute_hip_phase1_profiles.sql`
- `database/migrations/20261001064343_seed_glute_hip_phase1_relationship_candidates.sql`
- `database/migrations/20261001064740_harden_reviewed_relationship_edit_guard.sql`
- `database/migrations/20261001065150_enforce_ai_candidate_insert_status.sql`

## 安全

- 客户端可访问数据表启用 RLS
- 普通 App 用户只能直接读取 `REVIEWED` exercise relationships
- `AUTO_SUGGESTED` candidate 不通过 App-facing RLS 暴露
- 用户训练反馈按 `auth.uid()` 做 row ownership
- 审核审计表和同步配置表不对普通客户端开放
- service / secret key 不写入前端、README 或公开文件
- AI 新建关系时数据库 trigger 强制 `AUTO_SUGGESTED`
- REVIEWED 关系禁止直接修改，必须显式进入 review workflow

## 第三方许可证

Z-Anatomy、BodyParts3D、wger 与 GLB 派生资产的来源及署名要求记录在 `THIRD_PARTY_NOTICES.md`。

## 当前产品层仍缺少的部分

仓库目前仍没有正式移动端主 App 前端。Exercise Knowledge Graph 的内部审核页已经单独部署，但用户侧 Homepage、训练页、3D 人体交互、训练日历等仍需要在后续正式前端工程中接入。

# 康复 / 健身 App 数据层

当前仓库为康复 / 体态 / 健身 App 提供两层基础数据：

- **wger**：动作、动作翻译、肌肉、器械、图片与视频等通用健身数据
- **Z-Anatomy**：TA2 解剖术语、可点击 3D 人体结构以及与 wger 肌肉的映射

App 自己维护康复语义与教学内容，不会在上游同步时被覆盖。

## 当前线上状态

Supabase 已完成自动化同步，不需要在手机或 GitHub 中配置 `DATABASE_URL`。

### wger

当前数据库已同步：

- 861 个动作
- 15 个 wger 肌肉分类
- 12 类器械
- 3324 条多语言动作说明
- 443 个图片 / 视频媒体记录

`sync-wger` Supabase Edge Function 负责更新，Supabase Cron 每周自动执行。

### Z-Anatomy

当前数据库已同步：

- 7297 条 TA2 解剖术语 / 原始 code
- 7 个移动端 / Web 可加载的 GLB 人体系统层
- 2914 个独立可点击 3D mesh
- 2806 个 mesh 已通过唯一英文名称精确映射到 TA2
- 当前 15 个 wger 肌肉分类全部已经连接到对应的可点击 Z-Anatomy 肌肉 mesh

七个 3D 系统层：

- muscular
- skeletal
- joints
- cardiovascular
- nervous
- lymphatic
- visceral / internal organs

GLB 已复制进本项目 Supabase Storage 的公开 `anatomy-assets` bucket，App 不需要运行 Blender，也不依赖运行时从第三方 GitHub 加载模型。

## App 自有康复字段

`rehab_exercise_metadata` 与 wger 上游数据分开，现支持用户自己撰写的 plain text：

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

同时保留结构化字段用于搜索、筛选和排序：

- `posture_tags TEXT[]`
- `difficulty SMALLINT`
- `common_mistakes TEXT[]`
- `contraindications TEXT[]`
- `training_types TEXT[]`
- `body_regions TEXT[]`
- `activation_targets TEXT[]`
- `release_targets TEXT[]`

这样可以既写自然语言康复说明，又能让 App 做诸如“骨盆前倾 + 初级 + 激活”这样的结构化查询。

## 3D 人体图的数据链

前端人体图应按以下关系工作：

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
```

因此用户点击一个 3D 肌肉 mesh 后，可以继续显示：

- 目标肌肉 / 解剖名称
- activation
- release
- mobility
- posture tags
- difficulty
- animation
- common mistakes
- contraindications
- progression
- regression
- 对应训练动作、图片与视频

## Z-Anatomy 相关表

- `z_anatomy_terms`：保留原始 TA2 code，包括 `911*18`、`1140*1` 这类复合编号
- `z_anatomy_assets`：3D 资产来源、版本、Storage URL、许可证和署名
- `z_anatomy_meshes`：GLB 中的独立可点击节点、左右侧、TA2 映射
- `z_anatomy_wger_muscle_map`：Z-Anatomy mesh / TA2 与 wger 肌肉之间的桥接
- `z_anatomy_sync_state`：后台同步状态，客户端不可访问
- `z_anatomy_sync_config`：后台同步凭据，客户端不可访问

相关 SQL：

- `database/z_anatomy_integration.sql`
- `database/z_anatomy_wger_seed.sql`

## wger 相关表

- `wger_muscles`
- `wger_equipment`
- `wger_exercises`
- `wger_exercise_translations`
- `wger_exercise_muscles`
- `wger_exercise_equipment`
- `wger_exercise_media`
- `rehab_exercise_metadata`
- `wger_sync_state`

相关 SQL：

- `database/wger_schema.sql`
- `database/wger_security.sql`

## 安全

- 所有客户端可访问的数据表均启用 RLS
- App 端只读取基础动作 / 解剖 / 康复内容
- 同步 token、同步配置和同步状态不对 `anon` / `authenticated` 暴露
- 后台 Edge Function 使用服务器侧密钥写入数据库
- 不在前端、README 或公开代码里保存 secret / service key / 数据库密码

## 第三方许可证

Z-Anatomy、BodyParts3D、wger 与 GLB 派生资产的来源及署名要求记录在：

`THIRD_PARTY_NOTICES.md`

第三方模型资产与 App 自有康复文本保持分层。发布或重新分发新的第三方资产前，应检查对应资产的具体来源与许可信息。

## 当前缺少的部分

这个 GitHub 仓库目前主要是**数据层**，还没有正式的移动端 / Web App 前端代码。因此 3D 数据和动作数据已经可以查询，但“旋转人体、点击肌肉、高亮、弹出动作卡片”等交互需要在实际 App 前端代码进入仓库后接上渲染器。

建议的页面实现顺序：

1. 3D 人体图加载 `muscular.glb`
2. 点击 mesh 并高亮
3. 根据 mesh 查询对应 wger 肌肉与动作
4. 动作详情读取康复 plain text 字段
5. 增加 activation / release / mobility 分类
6. 将动作加入今日训练与训练日历

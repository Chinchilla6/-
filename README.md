# 康复 / 健身 App 数据层

当前仓库已加入 **wger 公共运动数据接入层**，用于为 App 提供动作、肌肉、器械、动作图片、动作视频和多语言动作说明等基础数据。

## 已加入的内容

- `database/wger_schema.sql`
  - wger 动作
  - 动作翻译
  - 肌肉
  - 器械
  - 动作-肌肉关联
  - 动作-器械关联
  - 图片 / 视频媒体
  - App 自有康复字段 `rehab_exercise_metadata`
  - 同步状态记录
- `scripts/sync_wger.py`
  - 从 wger `/api/v2/` 公共 API 分页同步数据
  - 使用 `exerciseinfo` 一次获取动作及其肌肉、器械、翻译、图片和视频
  - 使用 upsert，重复运行不会创建重复动作
  - 不覆盖 App 自己维护的康复标签
- `.env.example`
  - 数据库与 wger API 配置
- `requirements-wger.txt`
  - PostgreSQL 驱动

## 数据结构思路

wger 负责通用健身数据，App 自己负责康复语义。这样以后可以在同一个动作上增加：

- 激活 / 松解 / 强化 / 拉伸
- 身体区域
- 圆肩、头前伸、骨盆前倾等体态标签
- 常见错误
- 禁忌与注意事项
- 推荐组数 / 次数
- App 自有中文名称
- App 自有动图或视频

这些字段都存放在 `rehab_exercise_metadata`，同步 wger 时不会被覆盖。

## PostgreSQL / Supabase 安装

1. 创建 PostgreSQL 或 Supabase 数据库。
2. 执行：

```bash
psql "$DATABASE_URL" -f database/wger_schema.sql
```

3. 安装同步依赖：

```bash
pip install -r requirements-wger.txt
```

4. 设置环境变量：

```bash
export DATABASE_URL='postgresql://USER:PASSWORD@HOST:5432/DATABASE'
export WGER_BASE_URL='https://wger.de'
```

5. 可以先只检查 wger API：

```bash
python scripts/sync_wger.py --dry-run
```

6. 正式写入数据库：

```bash
python scripts/sync_wger.py
```

## App 查询示例

查某块肌肉对应的动作：

```sql
SELECT
    e.id,
    t.name,
    em.role
FROM wger_exercises e
JOIN wger_exercise_muscles em ON em.exercise_id = e.id
JOIN wger_muscles m ON m.id = em.muscle_id
JOIN wger_exercise_translations t ON t.exercise_id = e.id
WHERE m.id = $1;
```

查某种体态问题对应的 App 康复动作：

```sql
SELECT
    e.id,
    r.name_zh_override,
    r.training_types,
    r.posture_tags
FROM rehab_exercise_metadata r
JOIN wger_exercises e ON e.id = r.exercise_id
WHERE '骨盆前倾' = ANY(r.posture_tags);
```

## 下一步

当 App 主体代码进入本仓库后，可以继续把这些表接到：

1. 人体肌肉图点击交互
2. 动作详情页
3. 今日训练计划
4. 激活 / 松解 / 强化筛选
5. App 自有动图与动作纠错内容

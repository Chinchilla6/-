# 内容与证据政策

本项目将“科学依据”“讲解方式研究”和“最终产品内容”严格分开。

## 1. 科学依据层

训练、活动度、放松、康复与 Progression / Regression 的科学主张优先来自：

- ACSM position stands / consensus / guidance
- PubMed 收录的系统综述、Meta-analysis、RCT 与高质量康复研究

数据库中的 `training_evidence_sources` 保存 PMID、DOI、来源、适用人群、证据等级、App takeaway 与限制；`training_evidence_claims` 保存我们自己撰写的简短科学结论，不复制论文摘要或正文。

每个动作如果包含具体训练主张，应尽量通过 `exercise_evidence_links` 连接到相应 evidence claim。

## 2. 内容风格研究层

欧阳春晓、体态大师以及其他运动康复视频，仅用于研究：

- 用户喜欢什么节奏
- 一次讲几个要点更容易理解
- 镜头如何展示动作
- 如何提示常见错误
- 初学者如何被引导
- 信息层级与交互顺序

这些属于抽象 UX / 教学方式研究。

禁止：

- 直接搬运视频
- 截取或重剪视频作为 App 素材
- 转录或近似改写原文案
- 复制独特口令、脚本结构、图形资产或品牌术语
- 将第三方视频伪装成 App 原创动画

`guidance_style_references` 只保存研究边界，不保存第三方脚本、字幕或视频内容。

## 3. App 原创内容层

最终给用户展示的内容由项目自己重新制作：

- 动作动画
- 中文动作说明
- activation / release / mobility 文案
- common mistakes
- contraindications
- progression / regression
- 肌肉映射
- 体态映射
- 教学口令与镜头设计

原创资产通过 `app_exercise_assets` 管理版本、语言、审核状态和 Storage URL。生产内容默认标记为 `original_app_content`。

## 4. Progression Engine

`exercise_progression_rules` 保存动作之间经过审核的 progression / regression 关系。

规则可以使用：

- completed sessions
- completion rate
- movement quality score
- pain / discomfort score
- RPE
- 额外 JSON 条件

只有 `reviewed = true` 且 `is_active = true` 的规则才能被 `evaluate_exercise_progression()` 返回。

如果没有合格规则，函数返回空结果。系统不得为了“给用户一个答案”而自动猜测下一阶动作。

## 5. 证据表述原则

- “有证据支持”不等于“对所有人都适用”。
- 健康成人 ACSM 建议不能直接当成术后、急性疼痛或疾病康复处方。
- 对泡沫轴 / release，避免使用“打散粘连”“把筋膜滚开”等未经充分支持的机制性表述。
- 对体态问题，避免把静态姿势直接等同于疾病诊断。
- 当证据不确定时，产品应明确表达不确定性，而不是制造精确数字。

## 6. 发布审核

动作内容进入 `approved` 或 `clinically_reviewed` 状态前，应确认：

1. 动作本身与目标肌肉映射合理。
2. 文案为 App 原创。
3. 训练主张有可追溯 evidence claim，或明确标记为低/间接证据。
4. contraindications / safety 信息经过审核。
5. progression / regression 不会仅依据“难度更高/更低”自动生成。

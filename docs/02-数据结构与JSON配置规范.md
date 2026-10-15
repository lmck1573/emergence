# 02 · 数据结构与 JSON 配置规范

> 职责：定义 `res://data/` 下全部剧情数据文件的结构。**schema 锁定**——AI 只能按本规范录入数据，禁止增删字段、禁止改结构。所有文本从 `docs/story/` 原样复制。
> 通用：UTF-8 无 BOM；ID 一律 `snake_case`；`ContentDB` 启动时全量校验（§10），校验失败直接报错拒绝启动并指明文件与字段。

## 1. 数据文件清单

| 文件 | 内容 |
|---|---|
| scenes.json | 区域/场景定义 |
| objects.json | 交互物体与调查步骤 |
| contents.json | 内容碎片 |
| topics.json | 话题 |
| dialogues.json | 对话（含选择） |
| fulltexts.json | 全屏文本（独白/叙述/协议） |
| events.json | 剧情事件 |
| puzzles.json | 解谜 |

## 2. ID 前缀约定（全项目统一，禁止发明新 ID）

| 类型 | 前缀/格式 | 示例 |
|---|---|---|
| 区域 | 无前缀 | `livingroom`、`computer_desk` |
| 物体 | `{region}_{name}` | `livingroom_tv`、`computer_folder_games` |
| 内容 | `hobby_` / `exp_` / `work_` / `clue_` | `hobby_movie`、`exp_lalaland` |
| 话题 | `topic_` | `topic_movie` |
| 对话 | `dlg_` | `dlg_topic_movie` |
| 全屏文本 | `ft_` | `ft_opening_agreement` |
| 事件 | `event_` | `event_diary_password_hint` |
| 解谜 | `puzzle_` | `puzzle_diary_password` |

## 3. scenes.json

```json
{
  "regions": [
    {
      "region_id": "livingroom",
      "display_name": "客厅",
      "scene_path": "res://scenes/explore/livingroom.tscn",
      "parent": "house_overview",
      "unlock_event": null,
      "phase": 1
    }
  ]
}
```

| 字段 | 说明 |
|---|---|
| `parent` | 上一级场景（返回目标）；`house_overview` 为根 |
| `unlock_event` | 解锁事件 ID；`null` = 初始开放 |
| `phase` | 所属阶段（1/2） |

## 4. objects.json

```json
{
  "object_id": "kitchen_couple_bowls",
  "region_id": "kitchen",
  "display_name": "情侣餐具",
  "click_area": { "x": 100, "y": 200, "w": 120, "h": 80 },
  "click_feedback": "sfx_none",
  "conditions": [],
  "steps": [
    {
      "step_id": "look",
      "text_ref": "ft_bowls_look",
      "operation_label": null,
      "grants": []
    },
    {
      "step_id": "flip",
      "text_ref": "ft_bowls_flip",
      "operation_label": "翻面",
      "grants": ["exp_couple_bowls", "clue_cohabitation"]
    }
  ],
  "repeat_text_policy": "last_step"
}
```

| 字段 | 说明 |
|---|---|
| `click_area` | 相对场景原点矩形坐标（美术后补真实值，开发期占位） |
| `click_feedback` | 点击音效/动画 cue（`sfx_none`/`sfx_window_creak`…，枚举见 docs/10） |
| `conditions` | 可交互前置条件（条件结构同 §9，可为空数组） |
| `steps` | 调查步骤序列；单步物体只有一个元素 |
| `steps[].operation_label` | 进入该步骤的二级操作按钮文字；首步为 `null`（直接点击进入） |
| `steps[].grants` | 该步骤首次完成发放的内容/话题 ID；去重发放 |
| `repeat_text_policy` | 完成后重复点击重播：`last_step`=重播末步文本 / `first_step`=从头重播 |

## 5. contents.json

```json
{
  "content_id": "hobby_movie",
  "type": "hobby",
  "display_name": "看电影",
  "phase": 1,
  "feedable": true,
  "feed_dialogue": "dlg_feed_hobby_movie",
  "completeness_bonus": 3.96
}
```

| 字段 | 说明 |
|---|---|
| `type` | `hobby` / `exp` / `work` / `clue` 四选一（话题不在本表） |
| `feedable` | 线索默认 `false`；投喂入口与结算规则见 docs/04 |
| `feed_dialogue` | 投喂回应对话 ID；`null` = 不可投喂 |
| `completeness_bonus` | 投喂结算时累加的完整度（docs/07；不可投喂为 0） |
| `feed_conditions` | **可选**，投喂前置条件（结构同 §9，默认空数组）；不满足时投喂列表点选后 toast"暂时无法投喂"（docs/04 §3 第 4 步） |

## 6. topics.json

```json
{
  "topic_id": "topic_movie",
  "display_name": "电影",
  "phase": 1,
  "dialogue": "dlg_topic_movie",
  "unlocked_by": "livingroom_tv"
}
```

| 字段 | 说明 |
|---|---|
| `dialogue` | 话题对话 ID；`null` = 无对话内容（列表不显示，D14） |
| `unlocked_by` | 解锁来源（物体/事件 ID），仅注释用途，实际解锁靠 grants/effect |

## 7. dialogues.json 与 fulltexts.json

```json
{
  "dialogue_id": "dlg_topic_movie",
  "speaker_scene": "ai_interface",
  "lines": [
    { "speaker": "ai", "text": "喜欢 什么 电影？", "effects": [] },
    { "speaker": "protagonist", "text": "具体的类型不记得了…只记得有一次她怎么样都要拉着我看一遍爱乐之城的首映，那部电影我至今印象深刻……", "effects": [] }
  ],
  "on_complete_grants": ["exp_lalaland"],
  "choice": null
}
```

| 字段 | 说明 |
|---|---|
| `speaker` | `protagonist`（男主，左下角）/ `ai`（女主/AI，右上角）/ `system`（提示，右上角）——封闭枚举（D20） |
| `effects` | 行播放时的演出指令（§9 效果枚举中 `play_effect` 类） |
| `on_complete_grants` | 对话首次完成时发放的内容 ID |
| `choice` | 对话末尾的选择块（见下），无则 `null` |

选择块：

```json
"choice": {
  "style": "truth",
  "prompt": "要说出真相吗？",
  "selectable": true,
  "locked_show_duration": 3.0,
  "options": [
    { "label": "是", "result": "yes", "effects": ["add_truth_1"], "branch_dialogue": "dlg_usb_truth_yes" },
    { "label": "否", "result": "no", "effects": [], "branch_dialogue": "dlg_usb_truth_no" }
  ]
}
```

fulltexts.json（全屏文本，独白/叙述/协议）：

```json
{
  "text_id": "ft_opening_agreement",
  "pages": ["（第一页文本…）", "（第二页文本…）"]
}
```

## 8. puzzles.json

```json
{
  "puzzle_id": "puzzle_diary_password",
  "type": "number_wheel",
  "digits": 4,
  "answer": "1224",
  "unlock_event": "event_diary_password_hint",
  "on_complete_fulltext": "ft_computer_unlocked",
  "on_complete_effects": ["mark_event:event_computer_unlocked"],
  "diary_entries": [
    { "date": "03.22", "text": "正式住进了我们买的房子里……" }
  ]
}
```

（diary_entries 六条完整文本见 docs/story 第二阶段清单。）

## 9. events.json — 条件与效果（封闭枚举）

```json
{
  "event_id": "event_diary_password_hint",
  "trigger": "on_game_state_changed",
  "priority": 100,
  "once": true,
  "phase": 2,
  "conditions": {
    "all": [
      { "type": "content_fed", "id": "work_diary" },
      { "type": "content_fed", "id": "hobby_travel" },
      { "type": "content_fed", "id": "hobby_plush" },
      { "type": "topic_completed", "id": "topic_locked_computer" }
    ]
  },
  "effects": ["play_dialogue:dlg_diary_hint", "unlock_puzzle:puzzle_diary_password"]
}
```

**条件类型（封闭，禁止新增）**：

| type | 参数 | 判定 |
|---|---|---|
| `content_obtained` | id | 已获得内容 |
| `content_fed` | id | 已投喂内容 |
| `topic_completed` | id | 话题对话已完成 |
| `topic_unlocked` | id | 话题已解锁 |
| `object_investigated` | id | 物体全部步骤完成 |
| `object_step_completed` | id, step_id | 物体指定步骤完成 |
| `puzzle_completed` | id | 解谜完成 |
| `event_completed` | id | 事件完成 |
| `player_choice` | id, result | 玩家在事件 id 选择了 result（yes/no） |
| `truth_revealed_gte` | value | truth_revealed ≥ value |
| `opening_read` | key | 开场协议/指南已读 |
| `phase_is` | value | 当前阶段 |

**触发时机 `trigger`（封闭）**：`on_game_state_changed` / `on_enter_ai_interface`

**效果类型（封闭，禁止新增）**：`play_dialogue:` / `play_fulltext:` / `grant_content:` / `unlock_topic:` / `unlock_region:` / `unlock_puzzle:` / `mark_event:` / `add_truth_1` / `advance_phase:` / `play_effect:` / `show_choice_locked:`

**演出指令 `play_effect`（封闭）**：`black_flash` / `red_heartbeat` / `tinnitus` / `red_flood` / `portrait_eye` / `portrait_upper_body` / `portrait_smile` / `portrait_reset`

## 10. 启动校验规则（ContentDB）

1. 所有 JSON 可解析、字段名与类型符合本规范。
2. 所有 `text_ref` / `dialogue` / `branch_dialogue` / `feed_dialogue` 引用的 ID 存在。
3. 所有条件/效果引用的 ID（内容/话题/物体/事件/谜题/全屏文本）存在。
4. 枚举值（speaker/type/trigger/效果/演出）均在封闭集合内。
5. 步骤 `grants` 引用的 ID 在 contents.json 或 topics.json 中存在。
6. 任一校验失败：`push_error` 指明文件、字段、期望值，游戏拒绝进入主循环。

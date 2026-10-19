# 剧情 JSON 批量生成提示词

将本文末尾的提示词与项目数据规范、目标阶段的交互点与内容清单、对话与事件文本一起交给 AI。AI 应一次生成该阶段所需的全部 JSON 文件，并逐个输出完整文件内容，便于复制到 `res://data/`。

建议提供的输入文档：

- `docs/02-数据结构与JSON配置规范.md`
- 目标阶段的 `docs/story/` 交互点与内容清单
- 目标阶段的 `docs/story/` 对话与事件文本
- 其他被上述文档明确引用且影响本次配置的系统文档

若分批生成不同阶段，应同时提供已有 `data/` 文件或已有 ID 清单，避免重写、覆盖或重复已有数据。

## 可直接复制的提示词

```text
你是 Godot 项目《涌现》的剧情数据录入助手。请阅读我提供的项目 JSON 数据规范和目标阶段剧情文档，根据文档一次生成该阶段需要新增或更新的全部 JSON 文件。

目标文件位于 res://data/，可涉及：
- scenes.json：区域与场景
- objects.json：交互物体、调查步骤、文本引用和奖励
- contents.json：内容碎片
- topics.json：话题
- dialogues.json：角色对话
- fulltexts.json：独白、叙述、协议和调查文本
- events.json：事件条件与效果
- puzzles.json：谜题

只输出本阶段文档实际要求的数据。没有要求变更的文件不要重写；本阶段没有谜题时不要输出 puzzles.json。若输入包含已有 JSON 或已有 ID 清单，保留已有数据，只合并文档明确要求的新增/变更数据，不得删除或改写范围外内容。

【文档优先级和冲突】
项目中人类策划的明确指示优先于 AGENTS.md，AGENTS.md 优先于 docs/story/ 剧情数据文档，剧情数据文档优先于 docs/ 系统文档。若同优先级文档冲突，或无法确认某项实现值，停止生成受影响部分，报告文件名、章节/行文位置和冲突原文；不得自行裁决或猜测。可以继续输出不受冲突影响且能确定的数据。

【硬性录入规则】
1. 只实现文档明确写出的内容。禁止补写对话、物体、内容、话题、谜题、条件、奖励、效果或玩法。
2. 剧情文本从 docs/story/ 原样复制，逐字保留空格、标点、错别字、括号、特殊写法和段落顺序。不得改写、润色、纠错、删节或合并台词。
3. 所有 ID 必须来自清单或已存在数据；禁止发明 ID。ID 使用项目规范规定的命名和前缀。
4. 严格遵守 docs/02 的 schema：不得新增、删除、改名字段，不得改变字段类型或顶层结构。
5. 不得把待定项当成已定需求。缺值不能从文档和现有数据确认时，列为待确认项，不要猜值或生成占位剧情。
6. 输出合法 JSON，编码按 UTF-8 无 BOM。JSON 文件内部不写注释。

【各文件结构与规则】

1. scenes.json
顶层为对象，包含 regions 数组。每个区域包含：region_id、display_name、scene_path、parent、unlock_event、phase。区域 ID 不带类型前缀；parent、scene_path、unlock_event 及阶段值按文档和现有数据填写。不要虚构场景路径。

2. objects.json
顶层为对象，包含 objects 数组。每个物体包含：object_id、region_id、display_name、click_area、click_feedback、conditions、steps、repeat_text_policy。
每个 step 包含：step_id、text_ref、operation_label、grants。步骤顺序严格遵从清单；首步 operation_label 为 null；其余按钮文字按文档原文。text_ref 必须引用 fulltexts.json 中存在的 ID。grants 只能引用已定义的内容或话题 ID。conditions 按规范填写；无条件时用空数组。click_area 按文档坐标；文档未给真实坐标时仅使用项目规定的开发期占位约定，不要因此创造交互规则。

3. contents.json
顶层为对象，包含 contents 数组。每项包含：content_id、type、display_name、phase、feedable、feed_dialogue、completeness_bonus；仅在规范允许且项目数据采用时填写可选 feed_conditions。type 只能是 hobby、exp、work、clue。话题不能放进此文件。投喂属性与完整度按系统文档和清单填写；不可投喂项按规范设置。

4. topics.json
顶层为对象，包含 topics 数组。每项包含：topic_id、display_name、phase、dialogue、unlocked_by。dialogue 必须引用已定义对话，或按规范使用 null；unlocked_by 使用清单指定的物体/事件 ID。该字段不得被擅自解释为新增解锁逻辑。

5. dialogues.json
顶层为以 dialogue ID 为键的对象。每个对话项包含：speaker_scene、lines、on_complete_grants、choice。
每条 line 包含：speaker、text、effects。speaker 只允许 protagonist、ai、system。按剧本逐句录入，不能把多个角色/句子合并成一条，也不能改变顺序。effects 使用文档明确要求的演出；没有则为 []。on_complete_grants 只填文档明确要求的奖励；没有则为 []。无选择时 choice 为 null。
若文档明确要求选择，严格使用 docs/02 的 choice schema；不可自行补选项、选择效果或分支对话。分支对话必须在数据中存在。

6. fulltexts.json
顶层为对象，包含 fulltexts 数组。每项包含 text_id、pages。全屏文本、独白、协议、叙述和调查文本按系统规范放在此处。text_id 必须使用文档 ID。分页按文档要求；未说明时沿用项目既有约定，不要人为拆分或合并文本。文本逐字复制。

7. events.json
顶层为对象，包含 events 数组。事件项包含 event_id、trigger、priority、once、phase、conditions、effects。仅使用文档指定的条件与效果，并保持要求的执行顺序。
条件类型为封闭集合：content_obtained(id)、content_fed(id)、topic_completed(id)、topic_unlocked(id)、object_investigated(id)、object_step_completed(id, step_id)、puzzle_completed(id)、event_completed(id)、player_choice(id, result)、truth_revealed_gte(value)、opening_read(key)、phase_is(value)。
trigger 只允许 on_game_state_changed、on_enter_ai_interface。
效果只允许 play_dialogue:ID、play_fulltext:ID、grant_content:ID、unlock_topic:ID、unlock_region:ID、unlock_puzzle:ID、mark_event:ID、add_truth_1、advance_phase:值、play_effect:ID、show_choice_locked:ID。play_effect 的 ID 只允许 black_flash、red_heartbeat、tinnitus、red_flood、portrait_eye、portrait_upper_body、portrait_smile、portrait_reset。

8. puzzles.json
仅在文档明确要求谜题时输出。顶层为对象，包含 puzzles 数组。谜题字段严格采用 docs/02 的结构：puzzle_id、type、digits、answer、unlock_event、on_complete_fulltext、on_complete_effects、diary_entries。所有谜题参数及日记内容必须能在文档中找到依据；答案、日期、文本不得猜测。

【ID 与引用检查】
生成前先从文档整理实体、ID、文本、归属关系、前置条件、奖励、事件顺序和引用。完成后检查：
- 所有 ID 拼写、前缀正确且无重复。
- 每个 text_ref、dialogue、feed_dialogue、branch_dialogue、grant、事件条件/效果、unlock_event、谜题引用都指向有效数据或文档允许的外部 ID。
- speaker、type、trigger、condition、effect 和演出指令均属于规范封闭枚举。
- 对话和全屏文本均与剧本原文逐字一致。
- 顶层结构、字段名、字段类型符合 docs/02；没有 schema 外字段。
- 输出 JSON 可解析，且没有文档外设计或待定项实现。

【输出格式】
按文件分别输出，每个文件一个独立代码块。代码块前单独写文件名，例如：

scenes.json
```json
完整文件内容
```

objects.json
```json
完整文件内容
```

依此类推。每个代码块必须是可直接复制保存的完整 JSON 文件，不得用省略号代替内容，不得把多个文件放进同一个 JSON。不要输出无关说明。

若遇到冲突、缺项、无效引用或待确认值，先列出问题和文档位置；不得为了凑齐文件而猜测。未受影响且已有充分依据的文件可以继续输出。
```

import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / 'docs/剧本.md').read_text(encoding='utf-8-sig').split('第三幕', 1)[1]
zero, positive = source.split('分歧：当真相暴露度为0时', 1)[1].split('分歧：当真相暴露度>0时', 1)
ref = 'res://artassests/女主眨眼动画/眨眼1.jpg'
data = {'cg_images': {}, 'routes': {}, 'ending_titles': {
    'love': 'GOOD ENDING？——堪称执念的爱', 'life': 'Ending——新的生命', 'truth': 'TRUE ENDING——沉默的真相'}}
dialogues_path = ROOT / 'data/dialogues.json'
dialogues = json.loads(dialogues_path.read_text(encoding='utf-8-sig'))

def lines(text):
    result = []
    for raw in text.splitlines():
        match = re.match(r'^\s*(男主|男人|女主|AI|Ai|AI；|男主；)[:：](.*)$', raw)
        if match:
            speaker, value = match.groups()
            result.append({'speaker': 'protagonist' if speaker.startswith(('男主', '男人')) else 'ai', 'text': value})
        elif raw.startswith('旁白：'):
            result.append({'speaker': 'system', 'text': raw[3:]})
    return result

def say(route, key, text):
    parsed = lines(text)
    if parsed:
        dialogue_id = 'dlg_act3_' + key
        dialogues[dialogue_id] = {'lines': parsed}
        route.append({'action': 'dialogue', 'id': dialogue_id})

def cg(route, key):
    data['cg_images'][key] = ref
    route.append({'action': 'cg', 'id': key})

def room(route, name):
    route.append({'action': 'room', 'id': name})

def tour(text, prefix):
    route = []
    chunks = re.split(r'来到[：:]?(厨房|阳台|主卧|客厅)[：:]?', text)
    for i in range(1, len(chunks), 2):
        name, body = chunks[i:i+2]
        if name == '客厅':
            return route, body
        room(route, name)
        route.append({'action': 'click', 'label': '女主'})
        say(route, prefix + '_' + name, body)
        route.append({'action': 'leave'})
    raise ValueError('Missing living room')

zroute, zbody = tour(zero, 'zero')
room(zroute, '客厅')
zroute.append({'action': 'click', 'label': '女主'})
before, after = zbody.split('黑屏闪现：女主消失，切回正常的客厅', 1)
say(zroute, 'zero_livingroom', before)
room(zroute, '客厅')
monologue, fire = after.split('来到：女主的房间', 1)
say(zroute, 'zero_wait', monologue)
cg(zroute, 'burning_room')
zroute.append({'action': 'audio', 'id': 'sfx_fire', 'stop_bgm': True})
say(zroute, 'zero_wife_room', fire)
zroute.append({'action': 'ending', 'id': 'love'})
data['routes']['zero'] = zroute

proute, pbody = tour(positive, 'truth')
room(proute, '客厅')
proute.append({'action': 'click', 'label': '女主'})
question, rest = pbody.split('选择：否（当真相暴露度不为2时，强制选择）', 1)
say(proute, 'truth_livingroom', question)
proute.append({'action': 'choice', 'prompt': '要让她独自进去吗？', 'yes': 'alone', 'no': 'refuse'})
data['routes']['positive'] = proute

refuse, alone = rest.split('分支：是', 1)
nroute = []
intro, body = refuse.split('场景转变为没有女主的厨房', 1)
say(nroute, 'refuse', intro)
room(nroute, '厨房')
tools, body = body.split('黑屏转变，来到女主的房间', 1)
say(nroute, 'tools', tools)
room(nroute, '女主的房间')
apology, body = body.split('黑屏转变，来到女主的桌子特写', 1)
say(nroute, 'forced_room', apology)
cg(nroute, 'break_journal_lock')
cg(nroute, 'break_drawer_lock')
cg(nroute, 'opened_journal')
nroute.append({'action': 'click', 'label': '笔记本'})
journal, after = body.split('点击笔记本，展现文件日志:', 1)[1].split('退出UI，回到之前的特写', 1)
pages = journal.split('第二页：', 1)
dialogues['dlg_act3_hidden_journal'] = {'lines': [{'speaker': 'protagonist', 'text': p.strip()} for page in pages for p in page.strip().split('\n\n') if p.strip()]}
nroute.append({'action': 'dialogue', 'id': 'dlg_act3_hidden_journal'})
nroute.append({'action': 'audio', 'id': 'sfx_door_open'})
room(nroute, '女主的房间')
part1, part2 = after.split('黑屏渐变，只剩下男主的对话框', 1)
say(nroute, 'after_journal', part1)
nroute.append({'action': 'black'})
say(nroute, 'child_decision', part2)
nroute.append({'action': 'ending', 'id': 'life'})
data['routes']['refuse'] = nroute

aroute = []
accepted, body = alone.split('黑屏闪现，切换到没有女主的客厅拆分。', 1)
say(aroute, 'allow_alone', accepted)
room(aroute, '客厅')
aroute.append({'action': 'wait', 'seconds': 5.0})
waiting, body = body.split('点击：离开，切换到女主房间', 1)
say(aroute, 'waiting_alone', waiting)
aroute.append({'action': 'leave'})
room(aroute, '女主的房间')
question, memory = body.split('黑屏渐变 出现字幕（四年前）：转变为手机图片', 1)
aroute.append({'action': 'click', 'label': '女主'})
say(aroute, 'missing_submission', question)
aroute.append({'action': 'caption', 'text': '四年前', 'seconds': 1.0})
markers = [
    ('黑屏渐变，黑屏出现字幕：第二年三月，一秒后再次黑屏渐变，转变为手机图片', 'phone_year4'),
    ('黑屏渐变：在一个公园里', 'phone_march'),
    ('cg切换为女主转了一半的头', 'park_lake'),
    ('播放飞鸟振翅的音效', 'park_turn'),
    ('音效结束，cg变化，显示出女主的脸', 'park_birds'),
    ('黑屏渐变：在一家餐厅', 'park_face'),
    ('黑屏渐变：场景转变为：半夜的酒店房间', 'restaurant'),
    ('黑屏：渐变为白天的酒店房间', 'hotel_night'),
    ('黑屏渐变：又回到那家餐厅', 'hotel_day'),
    ('黑屏闪现，回到现实', 'restaurant_usb')]
for index, (marker, key) in enumerate(markers):
    section, memory = memory.split(marker, 1)
    cg(aroute, key)
    if key == 'phone_march':
        aroute.insert(len(aroute)-1, {'action': 'caption', 'text': '第二年三月', 'seconds': 1.0})
    if key == 'park_lake': aroute.append({'action': 'audio', 'id': 'sfx_park'})
    if key == 'park_birds': aroute.append({'action': 'audio', 'id': 'sfx_birds'})
    if key == 'restaurant': aroute.append({'action': 'audio', 'id': 'sfx_restaurant'})
    if key == 'hotel_night':
        aroute.extend([{'action': 'audio', 'id': 'sfx_phone_ring'}, {'action': 'wait', 'seconds': 3.0}, {'action': 'audio', 'id': 'sfx_phone_answer'}])
    if key == 'hotel_day': aroute.append({'action': 'audio', 'id': 'sfx_knock'})
    say(aroute, 'memory_' + key, section)
reality, confession = memory.split('黑屏并且保持黑屏：', 1)
room(aroute, '女主的房间')
say(aroute, 'usb_question', reality)
aroute.append({'action': 'black'})
say(aroute, 'truth_confession', confession.split('转为普通调查女主的房间', 1)[0])
room(aroute, '女主的房间')
aroute.append({'action': 'click', 'label': '电脑'})
room(aroute, '电脑特写')
aroute.append({'action': 'click', 'label': '抽屉'})
aroute.append({'action': 'puzzle', 'id': 'puzzle_act3_drawer_password'})
cg(aroute, 'divorce_drawer')
aroute.append({'action': 'wait', 'seconds': 3.0})
aroute.append({'action': 'ending', 'id': 'truth'})
data['routes']['alone'] = aroute
data['cg_images']['reunion'] = ref
(ROOT / 'data/act3_flow.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
dialogues_path.write_text(json.dumps(dialogues, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print({key: len(value) for key, value in data['routes'].items()})

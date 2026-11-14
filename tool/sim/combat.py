"""Valebound combat rules, reference model (integer math only). The Dart in
lib/rules/combat.dart is a line-for-line port; tool/sim vectors tie them."""
MASK = 0xFFFFFFFF

def roll(seed, turn, slot):
    h = (seed ^ ((turn * 0x9E3779B1) & MASK) ^ ((slot * 0x85EBCA6B) & MASK)) & MASK
    h ^= h >> 16; h = (h * 0x7FEB352D) & MASK
    h ^= h >> 15; h = (h * 0x846CA68B) & MASK
    h ^= h >> 16
    return h % 20 + 1

def pct(x, p): return (x * p) // 100
def hits(r, chance): return r > (100 - chance) // 5

CLASSES = ['ranger', 'warden', 'sage', 'artificer']
TYPES = ['swift', 'armoured', 'brute', 'swarm', 'arcane']
# knobs -----------------------------------------------------------------
K = dict(
    # every stat grows as (4 + level), so a fight is as hard at level 1 as at 20
    hero_hp=(24, 6), hero_atk=(8, 2), comp_hp=(16, 4), comp_atk=(6, 3, 2),  # 6 + 3C/2
    enemy_hp=(52, 13), enemy_atk=(8, 2),
    e=(3, 1, 2, 4),  # the creature's level: (3 x hero + companion + 2) // 4
    cls_hp=dict(ranger=100, warden=115, sage=90, artificer=100),
    cls_atk=dict(ranger=95, warden=105, sage=115, artificer=100),
    type_hp=dict(swift=90, armoured=85, brute=110, swarm=105, arcane=65),
    type_atk=dict(swift=90, armoured=95, brute=115, swarm=110, arcane=140),
    base=2, cap=8, cost=3,
    strike=90, strike_swift=75, comp=85, comp_swift=75,
    crit=19, crit_pct=150,
    armour=80, big=280, heavy=260, swarm_hit=45, swarm_all=105, bodies=3, aoe=50,
    fortify=8, volley=220, riposte=150, firm=25, firm_turns=2, guard_shield=2,  # percent of max HP for each Guard
    exploit=(45, 25), trap=100, trap_turns=3, salve=45, bomb=(12, 3),
    heroic_hp=126, heroic_atk=110, turn_cap=12,
    boss_hp=260, boss_atk=85, boss_turns=7, boss_debuff=75, boss_shield=40,
)
MATRIX = {  # class -> enemy type -> percent
    'swift':    dict(ranger=150, warden=67, sage=100, artificer=150),
    'armoured': dict(ranger=67, warden=100, sage=100, artificer=150),
    'brute':    dict(ranger=100, warden=150, sage=150, artificer=100),
    'swarm':    dict(ranger=150, warden=67, sage=100, artificer=150),
    'arcane':   dict(ranger=100, warden=100, sage=150, artificer=67),
}
INTENTS = dict(
    swift=['hit', 'hitc', 'heavy', 'hit'],
    armoured=['hit', 'fortify', 'heavy', 'hitc'],
    brute=['hit', 'charge', 'big', 'hitc'],
    swarm=['swarm', 'swarmc', 'swarmall', 'swarm'],
    arcane=['hex', 'hit', 'ward', 'heavy', 'hitc'],
)
BOSS_PHASES = [['hit', 'charge', 'big', 'hitc'], ['heavy', 'hex', 'hit', 'ward'], ['charge', 'big', 'heavy']]

class Fight:
    def __init__(s, cls, level, comp_level, bond, etype, seed, resource, heroic=False, items=None,
                 boss=False, boss_hp=None, advantage=None):
        s.cls, s.etype, s.seed, s.boss = cls, etype, seed, boss
        s.turn = 1
        s.hero_max = pct(K['hero_hp'][0] + K['hero_hp'][1] * level, K['cls_hp'][cls])
        s.hero_hp = s.hero_max
        s.atk = pct(K['hero_atk'][0] + K['hero_atk'][1] * level, K['cls_atk'][cls])
        s.item_level = level
        s.comp_max = K['comp_hp'][0] + K['comp_hp'][1] * comp_level
        s.comp_hp = s.comp_max
        s.comp_atk = K['comp_atk'][0] + (K['comp_atk'][1] * comp_level) // K['comp_atk'][2] + bond // 25
        e = (K['e'][0] * level + K['e'][1] * comp_level + K['e'][2]) // K['e'][3]
        hp = pct(K['enemy_hp'][0] + K['enemy_hp'][1] * e, K['type_hp'][etype])
        ea = pct(K['enemy_atk'][0] + K['enemy_atk'][1] * e, K['type_atk'][etype])
        if not boss:
            # no two days' creatures are quite the same size
            hp = pct(hp, 90 + 5 * (roll(seed, 0, 7) % 6)); ea = pct(ea, 90 + 5 * (roll(seed, 0, 8) % 5))
        if heroic: hp = pct(hp, K['heroic_hp']); ea = pct(ea, K['heroic_atk'])
        if boss:
            hp = pct(K['enemy_hp'][0] + K['enemy_hp'][1] * e, K['boss_hp'])
            ea = pct(K['enemy_atk'][0] + K['enemy_atk'][1] * e, K['boss_atk'])
        s.enemy_atk = ea
        n = K['bodies'] if (etype == 'swarm' and not boss) else 1
        s.enemy_max = hp
        if boss and boss_hp is not None: hp = boss_hp
        s.bodies = [hp // n] * n
        if n > 1: s.enemy_max = (hp // n) * n
        s.start_hp = sum(s.bodies)
        s.res = min(K['cap'], resource)
        s.shield = pct(s.hero_max, K['guard_shield'] * s.res) if cls == 'warden' else 0
        s.armoured = etype == 'armoured'
        s.ward = False; s.dimmed = False; s.taunt = 0; s.trap = 0; s.charging = False
        s.items = dict(items or {})
        s.outcome = None; s.step = 0
        s.log = []
        if advantage == 'debuff': s.enemy_atk = pct(s.enemy_atk, K['boss_debuff'])
        if advantage == 'shield': s.shield += pct(s.hero_max, K['boss_shield'])
        if advantage == 'item': s.items['bomb'] = s.items.get('bomb', 0) + 1

    # ---- what the enemy will do this turn
    def enemy_hp(s): return sum(s.bodies)
    def pattern(s):
        if not s.boss: return INTENTS[s.etype]
        left = s.enemy_hp() * 3
        ph = 0 if left > s.enemy_max * 2 else (1 if left > s.enemy_max else 2)
        return BOSS_PHASES[ph]
    def intent(s):
        if s.charging: return 'big'
        p = s.pattern(); it = p[s.step % len(p)]
        if it == 'big': return 'hit'      # a big hit only ever follows its charge
        return it
    def comp_ready(s):
        if s.comp_hp <= 0: return False
        return True if s.cls == 'ranger' else s.turn % 2 == 0
    def can_ability(s):
        if s.cls == 'sage': return s.res >= 2
        if s.cls == 'ranger' and s.comp_hp <= 0: return False
        return s.res >= K['cost']

    # ---- damage to the enemy
    def _hurt(s, dmg, all_bodies=False, pierce=False):
        if dmg <= 0: return 0
        if s.ward:
            s.ward = False; return 0
        if s.armoured and not pierce: dmg = pct(dmg, K['armour'])
        done = 0
        if all_bodies and len(s.bodies) > 1:
            each = pct(dmg, K['aoe'])
            for i in range(len(s.bodies)):
                if s.bodies[i] > 0:
                    d = min(each, s.bodies[i]); s.bodies[i] -= d; done += d
        else:
            for i in range(len(s.bodies)):
                if s.bodies[i] > 0:
                    d = min(dmg, s.bodies[i]); s.bodies[i] -= d; done += d; break
        return done
    def _class_dmg(s, base):
        d = pct(base, MATRIX[s.etype][s.cls])
        if s.dimmed: d = pct(d, 50); s.dimmed = False
        return d
    def _take(s, dmg, defended):
        if defended: dmg = pct(dmg, 50)
        if s.shield > 0:
            a = min(s.shield, dmg); s.shield -= a; dmg -= a
            # a Warden standing firm answers every blow the shield takes
            if s.cls == 'warden' and s.taunt > 0 and a > 0:
                s._hurt(pct(pct(s.atk, K['riposte']), MATRIX[s.etype][s.cls]))
        s.hero_hp -= dmg
        return dmg

    # ---- one turn: action in strike/defend/ability/salve/trap/bomb/smoke
    def act(s, action, companion=False):
        assert s.outcome is None
        strong = MATRIX[s.etype][s.cls] == 150
        defended = False; skip = False
        if companion and s.comp_ready():
            r = roll(s.seed, s.turn, 1)
            if hits(r, K['comp_swift'] if s.etype == 'swift' else K['comp']):
                d = s.comp_atk
                if r >= K['crit']: d = pct(d, K['crit_pct'])
                s._hurt(d, pierce=True)
        if action == 'strike':
            r = roll(s.seed, s.turn, 0)
            ch = 100 if strong else (K['strike_swift'] if s.etype == 'swift' else K['strike'])
            if hits(r, ch):
                d = s._class_dmg(s.atk)
                if r >= K['crit']: d = pct(d, K['crit_pct'])
                s._hurt(d, pierce=s.cls == 'sage')
        elif action == 'defend':
            defended = True; s.res = min(K['cap'], s.res + 1)
        elif action == 'ability':
            assert s.can_ability()
            if s.cls == 'ranger':
                s.res -= K['cost']
                s._hurt(s._class_dmg(pct(s.comp_atk, K['volley'])), all_bodies=True)
            elif s.cls == 'warden':
                s.res -= K['cost']
                s.shield += pct(s.hero_max, K['firm']); s.taunt = K['firm_turns']
            elif s.cls == 'sage':
                spent = s.res; s.res = 0
                s._hurt(s._class_dmg(pct(s.atk, K['exploit'][0] + K['exploit'][1] * spent)), pierce=True)
                skip = True
                s.charging = False
            else:
                s.res -= K['cost']
                s.armoured = False; s.trap = K['trap_turns']
        elif action == 'salve':
            assert s.items.get('salve', 0) > 0; s.items['salve'] -= 1
            s.hero_hp = min(s.hero_max, s.hero_hp + pct(s.hero_max, K['salve']))
        elif action == 'trap':
            assert s.items.get('trap', 0) > 0; s.items['trap'] -= 1
            s.armoured = False; s.trap = K['trap_turns']
        elif action == 'bomb':
            assert s.items.get('bomb', 0) > 0; s.items['bomb'] -= 1
            s._hurt(K['bomb'][0] + K['bomb'][1] * s.item_level, all_bodies=True)
        elif action == 'smoke':
            assert s.items.get('smoke', 0) > 0; s.items['smoke'] -= 1
            skip = True
        else:
            raise ValueError(action)
        # the trap bites before the enemy moves
        if s.trap > 0 and s.enemy_hp() > 0:
            s._hurt(pct(pct(s.atk, K['trap']), MATRIX[s.etype][s.cls] if s.cls == 'artificer' else 100), pierce=True)
            s.trap -= 1
        if s.enemy_hp() <= 0:
            s.outcome = 'won'; return s.outcome
        # ---- the enemy's move
        it = s.intent()
        if not skip:
            to_comp = it in ('hitc', 'swarmc') and s.comp_hp > 0 and s.taunt == 0
            if it == 'hit' or (it == 'hitc' and not to_comp):
                s._take(s.enemy_atk, defended)
            elif it == 'hitc':
                s.comp_hp -= s.enemy_atk
            elif it == 'charge':
                s.charging = True
            elif it == 'big':
                s._take(pct(s.enemy_atk, K['big']), defended); s.charging = False
            elif it == 'heavy':
                s._take(pct(s.enemy_atk, K['heavy']), defended)
            elif it in ('swarm', 'swarmc', 'swarmall'):
                each = pct(s.enemy_atk, K['swarm_all'] if it == 'swarmall' else K['swarm_hit'])
                alive = [i for i in range(len(s.bodies)) if s.bodies[i] > 0]
                for k in range(len(alive)):
                    if to_comp and k == 0: s.comp_hp -= each
                    else: s._take(each, defended)
            elif it == 'fortify':
                heal = pct(s.enemy_max, K['fortify'])
                s.bodies[0] = min(s.enemy_max, s.bodies[0] + heal)
            elif it == 'hex':
                if not defended and s.cls != 'sage':
                    s.dimmed = True; s.res = max(0, s.res - 1)
            elif it == 'ward':
                s.ward = True
        elif it == 'big':
            s.charging = False
        if s.comp_hp < 0: s.comp_hp = 0
        if s.taunt > 0: s.taunt -= 1
        if s.enemy_hp() <= 0:      # a Warden's answering blow can end it
            s.outcome = 'won'; return s.outcome
        s.step += 1
        s.turn += 1
        if s.hero_hp <= 0:
            s.hero_hp = 0; s.outcome = 'lost'
        elif s.turn > (K['boss_turns'] if s.boss else K['turn_cap']):
            s.outcome = 'lost'
        return s.outcome

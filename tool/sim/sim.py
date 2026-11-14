import sys, itertools
from combat import *

def smart(f):
    it = f.intent()
    if it in ('hex', 'ward') and f.cls != 'sage': it = 'veiled'
    comp = f.comp_ready()
    c = f.cls
    low = f.hero_hp * 100 <= f.hero_max * 35
    if low and f.items.get('salve', 0) > 0 and it not in ('big', 'heavy', 'swarmall'): return 'salve', comp
    if it in ('big', 'heavy', 'swarmall'):
        if c == 'sage' and f.can_ability(): return 'ability', comp
        if c == 'warden' and f.can_ability() and f.shield < pct(f.enemy_atk, K['heavy']): return 'ability', comp
        if c == 'warden' and f.shield >= pct(f.enemy_atk, K['heavy']): return 'strike', comp
        if f.items.get('smoke', 0) > 0: return 'smoke', comp
        return 'defend', comp
    if f.ward and not comp and it != 'veiled': return 'defend', comp
    if c == 'ranger':
        if f.can_ability() and not f.ward: return 'ability', comp
        return 'strike', comp
    if c == 'warden':
        if f.can_ability() and f.taunt == 0: return 'ability', comp
        return 'strike', comp
    if c == 'sage':
        if it == 'charge' and f.res < 2: return 'defend', comp
        if it == 'charge': return 'strike', comp
        if it == 'hex': return 'defend', comp
        if f.can_ability() and f.res >= 5 and f.etype != 'brute' and not f.boss: return 'ability', comp
        if f.can_ability() and f.res >= 6: return 'ability', comp
        return 'strike', comp
    if c == 'artificer':
        if f.trap == 0 and f.can_ability(): return 'ability', comp
        if len(f.bodies) > 1 and f.items.get('bomb', 0) > 0: return 'bomb', comp
        return 'strike', comp

def strike_only(f): return 'strike', f.comp_ready()
def greedy(f): return ('ability' if f.can_ability() else 'strike'), f.comp_ready()

def run(policy, **kw):
    f = Fight(**kw)
    while f.outcome is None:
        a, comp = policy(f)
        f.act(a, comp)
    return f

LEVELS = [(1, 1), (2, 2), (3, 3), (5, 4), (8, 6), (12, 9), (20, 12)]
def rate(policy, cls, resource, heroic=False, items=None, levels=LEVELS, n=400, etypes=TYPES):
    w = t = tot = 0; per = {}
    for et in etypes:
        ww = nn = 0
        for (L, C) in levels:
            for d in range(n):
                seed = (d * 2654435761 + 12345) & MASK
                f = run(policy, cls=cls, level=L, comp_level=C, bond=8 * C, etype=et, seed=seed,
                        resource=resource, heroic=heroic, items=items)
                nn += 1; tot += 1
                if f.outcome == 'won': ww += 1; w += 1; t += f.turn - 0
        per[et] = 100 * ww // nn
    return 100 * w / tot, (t / w if w else 0), per

def table(n=300):
    print('class      policy        res  win%  turns  ' + ' '.join(f'{x[:5]:>5}' for x in TYPES))
    for cls in CLASSES:
        for name, pol, res, heroic in [('smart', smart, 7, False), ('smart', smart, 2, False),
                                       ('greedy', greedy, 7, False), ('strike', strike_only, 7, False),
                                       ('smartHERO', smart, 7, True)]:
            r, t, per = rate(pol, cls, res, heroic, n=n)
            print(f'{cls:10} {name:12} {res:4} {r:5.1f} {t:6.2f}  ' + ' '.join(f'{per[x]:5d}' for x in TYPES))

if __name__ == '__main__' and False:
    print('class      policy        res  win%  turns  ' + ' '.join(f'{x[:5]:>5}' for x in TYPES))
    for cls in CLASSES:
        for name, pol, res, heroic in [('smart', smart, 7, False), ('smart', smart, 4, False), ('smart', smart, 2, False),
                                       ('greedy', greedy, 7, False), ('strike', strike_only, 7, False), ('strike', strike_only, 2, False),
                                       ('smartHERO', smart, 7, True)]:
            r, t, per = rate(pol, cls, res, heroic)
            print(f'{cls:10} {name:12} {res:4} {r:5.1f} {t:6.2f}  ' + ' '.join(f'{per[x]:5d}' for x in TYPES))

def by_level(n=100):
    print('quests done and reading intents, by party level (hero/companion)')
    print('class      ' + ' '.join(f'{L:>3}/{C:<2}' for (L, C) in LEVELS))
    for cls in CLASSES:
        print(f'{cls:10} ' + ' '.join(f'{rate(smart, cls, 7, levels=[lv], n=n)[0]:5.0f}%' for lv in LEVELS))
    print('the same, by creature type at each level')
    for cls in CLASSES:
        for et in TYPES:
            row = [rate(smart, cls, 7, levels=[lv], n=n, etypes=[et])[0] for lv in LEVELS]
            print(f'{cls:10} {et:9} {MATRIX[et][cls]:3}  ' + ' '.join(f'{x:5.0f}%' for x in row))

if __name__ == '__main__':
    import json
    for kv in sys.argv[1:]:
        k, v = kv.split('=', 1); K[k] = json.loads(v)
    print('Reference model, the numbers of app version 0.7.1. 3,500 fights a row (5 types x 7 party levels x 100 days),')
    print('empty pouch. Regenerate from tool/sim with: python3 sim.py > balance.txt')
    table(n=100)
    by_level()

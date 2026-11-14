"""Writes test/rules/combat_vectors.json: dice rolls and 96 whole fights played
by this model with random legal moves. The Dart engine replays them move for
move (test/rules/combat_test.dart). Run from the repository root after any
change to the rules:  python3 tool/sim/vectors.py"""
import json, os, random, sys
sys.path.insert(0, os.path.dirname(__file__))
from combat import CLASSES, TYPES, K, Fight, roll

ROLLS = [(0, 1, 0), (1, 1, 0), (123456789, 3, 1), (4294967295, 12, 8), (2654435761, 7, 7), (99, 0, 7), (99, 0, 8)]
ITEMS = ['salve', 'trap', 'bomb', 'smoke']

def legal(f):
    acts = ['strike'] * 5 + ['defend'] * 2
    if f.can_ability(): acts += ['ability'] * 3
    for it in ITEMS:
        if f.items.get(it, 0) > 0: acts += [it]
    return acts

def one(rng, i):
    boss = i >= 64
    v = dict(cls=CLASSES[i % 4], level=rng.choice([1, 1, 2, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20]),
             comp_level=rng.choice([1, 1, 2, 3, 4, 6, 9, 12]), bond=rng.choice([0, 8, 20, 33, 60, 100]),
             etype=TYPES[(i // 4) % 5], seed=rng.getrandbits(32), resource=rng.randint(2, 9),
             heroic=(not boss) and rng.random() < 0.25,
             items={it: rng.randint(1, 2) for it in ITEMS if rng.random() < 0.3})
    kw = dict(v)
    if boss:
        v['boss'] = True; kw['boss'] = True
        if rng.random() < 0.5:
            full = Fight(**kw).enemy_max
            v['boss_hp'] = kw['boss_hp'] = rng.randint(max(1, full // 6), full)
        adv = rng.choice([None, 'debuff', 'shield', 'item'])
        if adv: v['advantage'] = kw['advantage'] = adv
    f = Fight(**kw); actions = []
    while f.outcome is None:
        a = rng.choice(legal(f)); c = 1 if rng.random() < 0.7 else 0
        actions.append([a, c]); f.act(a, bool(c))
    v['actions'] = actions
    v['out'] = dict(outcome=f.outcome, turn=f.turn, hero=f.hero_hp, enemy=f.enemy_hp(), comp=f.comp_hp,
                    res=f.res, shield=f.shield)
    return v

def build():
    rng = random.Random(20261114)
    return dict(rolls=[[s, t, sl, roll(s, t, sl)] for (s, t, sl) in ROLLS], fights=[one(rng, i) for i in range(96)])

if __name__ == '__main__':
    out = build()
    path = os.path.join(os.path.dirname(__file__), '..', '..', 'test', 'rules', 'combat_vectors.json')
    json.dump(out, open(path, 'w'), separators=(',', ':'))
    won = sum(1 for f in out['fights'] if f['out']['outcome'] == 'won')
    print(len(out['fights']), 'fights,', won, 'won; written to', os.path.normpath(path))

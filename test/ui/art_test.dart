import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/gear.dart';
import 'package:habit_adventure/rules/journey.dart';
import 'package:habit_adventure/rules/narrator.dart';
import 'package:habit_adventure/rules/still.dart';
import 'package:habit_adventure/rules/world.dart';
import 'package:habit_adventure/ui/art/painted.dart';

// The illustrated set (ASSETS.md sections 6 and 7): every drafted place,
// villager, Still creature, piece of gear, Discovery and story page has a
// picture, under the key the rules use for it, and the file is really there.

void expectPicture(String? asset, String what) {
  expect(asset, isNotNull, reason: '$what has no picture listed');
  expect(File(asset!).existsSync(), isTrue, reason: '$asset is not there');
}

void main() {
  test('every place and its villager has a picture', () {
    for (final target in restorationTargets) {
      expectPicture(placeArt(target.key), target.name);
      final villager = target.villager;
      if (villager != null) {
        expectPicture(villagerArt(villager.key), villager.name);
      }
    }
  });

  test('every Still creature has a picture', () {
    for (final creature in stillCreatures) {
      expectPicture(stillArt(creature.key), creature.name);
    }
  });

  test('every piece of companion gear has a picture', () {
    for (final gear in companionGear) {
      expectPicture(gearArt(gear.key), gear.name);
    }
  });

  test('every Discovery has its card painting', () {
    for (final scene in discoveryScenes) {
      expectPicture(discoveryArt[scene.key], scene.title);
    }
  });

  test('every page of the story has its painting', () {
    for (final page in prologuePages('Babs')) {
      expectPicture(storyArt[page.scene.name], 'the prologue, ${page.scene}');
    }
    for (final chapter in chapters) {
      expectPicture(
        storyArt['${chapter.region}_asleep'],
        '${chapter.regionName} asleep',
      );
      expectPicture(
        storyArt['${chapter.region}_awake'],
        '${chapter.regionName} awake',
      );
    }
  });

  test('the valley is painted for every part of the day', () {
    for (final part in PartOfDay.values) {
      expectPicture(dawnArt(part), 'the valley, ${part.name}');
    }
    expectPicture(campfireArt, 'the camp');
  });

  test('small and large pictures together are the whole set', () {
    expect(
      <String>{...smallPaintedAssets, ...largePaintedAssets},
      allPaintedAssets.toSet(),
    );
    expect(allPaintedAssets.toSet().length, allPaintedAssets.length);
    expect(largePaintedAssets, hasLength(20 + 15 + 4 + 1));
  });

  test('a lantern past the drafted places keeps its coded roundel', () {
    expect(placeArt(targetAt(restorationTargets.length + 2).key), isNull);
  });

  test('every picture that is listed is on disk', () {
    for (final asset in allPaintedAssets) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });
}

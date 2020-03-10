import 'dart:async';
import 'dart:ui';

import 'package:darkness_dungeon/core/enemy/enemy.dart';
import 'package:darkness_dungeon/core/flying_attack_object.dart';
import 'package:darkness_dungeon/core/player/player.dart';
import 'package:darkness_dungeon/core/util/Direction.dart';
import 'package:darkness_dungeon/core/util/animated_object_once.dart';
import 'package:flame/animation.dart' as FlameAnimation;
import 'package:flame/position.dart';
import 'package:flutter/widgets.dart';

extension EnemyExtensions on Enemy {
  void seePlayer(
      {Function(Player) observed,
      Function() notObserved,
      int visionCells = 3}) {
    Player player = gameRef.player;
    if (player.isDie || !isVisibleInMap()) return;

    double visionWidth = position.width * visionCells * 2;
    double visionHeight = position.height * visionCells * 2;

    Rect fieldOfVision = Rect.fromLTWH(
      position.left - (visionWidth / 2),
      position.top - (visionHeight / 2),
      visionWidth,
      visionHeight,
    );

    if (fieldOfVision.overlaps(player.position)) {
      if (observed != null) observed(player);
    } else {
      if (notObserved != null) notObserved();
    }
  }

  void seeAndMoveToPlayer({Function(Player) closePlayer, int visionCells = 3}) {
    if (!isVisibleInMap() || isDie) return;
    idle();
    seePlayer(
        visionCells: visionCells,
        observed: (player) {
          double centerXPlayer = player.position.center.dx;
          double centerYPlayer = player.position.center.dy;

          double translateX = 0;
          double translateY = 0;

          translateX =
              position.center.dx > centerXPlayer ? (-1 * speed) : speed;
          translateY =
              position.center.dy > centerYPlayer ? (-1 * speed) : speed;

          if ((translateX < 0 && translateX > -0.1) ||
              (translateX > 0 && translateX < 0.1)) {
            translateX = 0;
          }

          if ((translateY < 0 && translateY > -0.1) ||
              (translateY > 0 && translateY < 0.1)) {
            translateY = 0;
          }

          if (translateX == 0 && translateY == 0) {
            idle();
            return;
          }

          if (position.overlaps(player.position)) {
            if (closePlayer != null) closePlayer(player);
            return;
          }

          if (translateX > 0) {
            moveRight(moveSpeed: translateX);
          } else {
            moveLeft(moveSpeed: (translateX * -1));
          }
          if (translateY > 0) {
            moveBottom(moveSpeed: translateY);
          } else {
            moveTop(moveSpeed: (translateY * -1));
          }
        });
  }

  void simpleAttackMelee({
    @required double damage,
    @required double heightArea,
    @required double widthArea,
    int interval = 1000,
    FlameAnimation.Animation attackEffectRightAnim,
    FlameAnimation.Animation attackEffectBottomAnim,
    FlameAnimation.Animation attackEffectLeftAnim,
    FlameAnimation.Animation attackEffectTopAnim,
  }) {
    if (this.timers['attackMelee'] == null) {
      this.timers['attackMelee'] = Timer(
        Duration(milliseconds: interval),
        () {
          this.timers['attackMelee'] = null;
        },
      );
    } else {
      return;
    }
    Player player = gameRef.player;

    if (player.isDie || !isVisibleInMap() || isDie) return;

    Rect positionAttack;
    FlameAnimation.Animation anim = attackEffectRightAnim;

    Direction playerDirection;

    double centerXPlayer = player.position.center.dx;
    double centerYPlayer = player.position.center.dy;

    double centerYEnemy = position.center.dy;
    double centerXEnemy = position.center.dx;

    double diffX = centerXEnemy - centerXPlayer;
    double diffY = centerYEnemy - centerYPlayer;

    double positiveDiffX = diffX > 0 ? diffX : diffX * -1;
    double positiveDiffY = diffY > 0 ? diffY : diffY * -1;
    if (positiveDiffX > positiveDiffY) {
      playerDirection = diffX > 0 ? Direction.left : Direction.right;
    } else {
      playerDirection = diffY > 0 ? Direction.top : Direction.bottom;
    }

    switch (playerDirection) {
      case Direction.top:
        positionAttack = Rect.fromLTWH(
          position.left + (this.width - widthArea) / 2,
          position.top - this.height,
          widthArea,
          heightArea,
        );
        if (attackEffectTopAnim != null) anim = attackEffectTopAnim;
        break;
      case Direction.right:
        positionAttack = Rect.fromLTWH(
          position.right,
          position.top + (this.height - heightArea) / 2,
          widthArea,
          heightArea,
        );
        if (attackEffectRightAnim != null) anim = attackEffectRightAnim;
        break;
      case Direction.bottom:
        positionAttack = Rect.fromLTWH(
          position.left + (this.width - widthArea) / 2,
          position.bottom,
          widthArea,
          heightArea,
        );
        if (attackEffectBottomAnim != null) anim = attackEffectBottomAnim;
        break;
      case Direction.left:
        positionAttack = Rect.fromLTWH(
          position.left - this.width,
          position.top + (this.height - heightArea) / 2,
          widthArea,
          heightArea,
        );
        if (attackEffectLeftAnim != null) anim = attackEffectLeftAnim;
        break;
    }

    gameRef.add(AnimatedObjectOnce(animation: anim, position: positionAttack));

    player.receiveDamage(damage);
  }

  void simpleAttackRange({
    @required FlameAnimation.Animation animationRight,
    @required FlameAnimation.Animation animationLeft,
    @required FlameAnimation.Animation animationTop,
    @required FlameAnimation.Animation animationBottom,
    @required FlameAnimation.Animation animationDestroy,
    @required double width,
    @required double height,
    double speed = 1.5,
    double damage = 1,
    Direction direction,
    int interval = 1000,
  }) {
    if (this.timers['attackRange'] == null) {
      this.timers['attackRange'] = Timer(
        Duration(milliseconds: interval),
        () {
          this.timers['attackRange'] = null;
        },
      );
    } else {
      return;
    }

    Player player = this.gameRef.player;

    if (player.isDie || !isVisibleInMap() || isDie) return;

    Position startPosition;
    FlameAnimation.Animation attackRangeAnimation;

    Direction ballDirection;

    var diffX = position.center.dx - player.position.center.dx;
    var diffPositiveX = diffX < 0 ? diffX *= -1 : diffX;
    var diffY = position.center.dy - player.position.center.dy;
    var diffPositiveY = diffY < 0 ? diffY *= -1 : diffY;

    if (diffPositiveX > diffPositiveY) {
      if (player.position.center.dx > position.center.dx) {
        ballDirection = Direction.right;
      } else if (player.position.center.dx < position.center.dx) {
        ballDirection = Direction.left;
      }
    } else {
      if (player.position.center.dy > position.center.dy) {
        ballDirection = Direction.bottom;
      } else if (player.position.center.dy < position.center.dy) {
        ballDirection = Direction.top;
      }
    }

    Direction finalDirection = direction != null ? direction : ballDirection;

    switch (finalDirection) {
      case Direction.left:
        if (animationLeft != null) attackRangeAnimation = animationLeft;
        startPosition = Position(
          this.position.left - width,
          (this.position.top + (this.position.height - height) / 2),
        );
        break;
      case Direction.right:
        if (animationRight != null) attackRangeAnimation = animationRight;
        startPosition = Position(
          this.position.right,
          (this.position.top + (this.position.height - height) / 2),
        );
        break;
      case Direction.top:
        if (animationTop != null) attackRangeAnimation = animationTop;
        startPosition = Position(
          (this.position.left + (this.position.width - width) / 2),
          this.position.top - height,
        );
        break;
      case Direction.bottom:
        if (animationBottom != null) attackRangeAnimation = animationBottom;
        startPosition = Position(
          (this.position.left + (this.position.width - width) / 2),
          this.position.bottom,
        );
        break;
    }

    this.lastDirection = finalDirection;
    if (finalDirection == Direction.right || finalDirection == Direction.left) {
      this.lastDirectionHorizontal = finalDirection;
    }

    gameRef.add(
      FlyingAttackObject(
        direction: finalDirection,
        flyAnimation: attackRangeAnimation,
        destroyAnimation: animationDestroy,
        initPosition: startPosition,
        height: height,
        width: width,
        damage: damage,
        speed: speed,
        damageInEnemy: false,
      ),
    );
  }

  void seeAndMoveToAttackRange(
      {Function(Player) positioned, int visionCells = 5}) {
    if (!isVisibleInMap() || isDie) return;

    seePlayer(
        visionCells: visionCells,
        observed: (player) {
          double centerXPlayer = player.position.center.dx;
          double centerYPlayer = player.position.center.dy;

          double translateX = 0;
          double translateY = 0;

          translateX =
              position.center.dx > centerXPlayer ? (-1 * speed) : speed;
          if (translateX > 0) {
            double diffX = centerXPlayer - position.center.dx;
            if (diffX < this.speed) {
              translateX = diffX;
            }
          } else if (translateX < 0) {
            double diffX = centerXPlayer - position.center.dx;
            if (diffX > (this.speed * -1)) {
              translateX = diffX;
            }
          }

          translateY =
              position.center.dy > centerYPlayer ? (-1 * speed) : speed;
          if (translateY > 0) {
            double diffY = centerYPlayer - position.center.dy;
            if (diffY < this.speed) {
              translateY = diffY;
            }
          } else if (translateY < 0) {
            double diffY = centerYPlayer - position.center.dx;
            if (diffY > (this.speed * -1)) {
              translateY = diffY;
            }
          }

          if ((translateX < 0 && translateX > -0.1) ||
              (translateX > 0 && translateX < 0.1)) {
            translateX = 0;
          }

          if ((translateY < 0 && translateY > -0.1) ||
              (translateY > 0 && translateY < 0.1)) {
            translateY = 0;
          }

          if (translateX == 0 && translateY == 0) {
            idle();
            return;
          }

          double translateXPositive =
              this.position.center.dx - player.position.center.dx;
          translateXPositive = translateXPositive >= 0
              ? translateXPositive
              : translateXPositive * -1;
          double translateYPositive =
              this.position.center.dy - player.position.center.dy;
          translateYPositive = translateYPositive >= 0
              ? translateYPositive
              : translateYPositive * -1;

          if (translateXPositive > translateYPositive) {
            if (translateY > 0) {
              moveBottom(moveSpeed: translateY);
            } else if (translateY < 0) {
              moveTop(moveSpeed: (translateY * -1));
            } else {
              positioned(player);
              this.idle();
            }
          } else {
            if (translateX > 0) {
              moveRight(moveSpeed: translateX);
            } else if (translateX < 0) {
              moveLeft(moveSpeed: (translateX * -1));
            } else {
              positioned(player);
              this.idle();
            }
          }
        },
        notObserved: () {
          this.idle();
        });
  }
}

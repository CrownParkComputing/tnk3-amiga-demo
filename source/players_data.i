PlayerStateRanges:
    dc.l GameProgress
    dc.w EnemiesKilled+2-GameProgress
    dc.l DeathTimer
    dc.w Invincible+2-DeathTimer
    dc.l FireDelay
    dc.w RotateDelay+2-FireDelay
    dc.l MotionFrac
    dc.w 2
    dc.l Entities
    dc.w EntitiesActive-Entities
    dc.l EntitiesActive
    dc.w AmmoReserve+2-EntitiesActive
    dc.l EntitiesSpawned
    dc.w BulletsHitTerrain+4-EntitiesSpawned
    dc.l NativeTypesSeen
    dc.w EnemyNavBlocked+4-NativeTypesSeen
    dc.l 0
ScoreHeader: dc.b "PL 1  L         HI SCORE      PL 2  L",0
UIPlayerOne: dc.b "PLAYER 1",0
UIPlayerTwo: dc.b "PLAYER 2",0
UIReady: dc.b "READY",0
UIReadyHelp: dc.b "PRESS FIRE OR START TO PLAY",0
UIUnusedScore: dc.b "------",0
UINextPlayerHelp: dc.b "A/START/B: NEXT PLAYER",0
    even

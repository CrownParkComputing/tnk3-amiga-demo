DosName: dc.b "dos.library",0
MusicBankPath: dc.b "PROGDIR:ikari_music.bin",0
ScorePath: dc.b "PROGDIR:tnk3.scores",0
ScoreTempPath: dc.b "PROGDIR:tnk3.scores.tmp",0
ScoreBackupPath: dc.b "PROGDIR:tnk3.scores.bak",0
SaveFailedText: dc.b "TNK III: high scores/settings could not be saved.",10
SaveFailedEnd:
    even
DefaultHighScores:
    dc.l 9000
    dc.b "SNK",0
    dc.l 8000
    dc.b "SNK",0
    dc.l 7000
    dc.b "SNK",0
    dc.l 6000
    dc.b "SNK",0
    dc.l 5000
    dc.b "SNK",0
    dc.l 4000
    dc.b "SNK",0
    dc.l 3000
    dc.b "SNK",0
    dc.l 2000
    dc.b "SNK",0
    dc.l 1000
    dc.b "SNK",0
    dc.l 0
    dc.b "AAA",0
TitleMenuPointers:
    dc.l UIStartText,UIScoresText,UIOptionsText,UIDemoText,UIQuitText
OptionPointers:
    dc.l UIFPSText,UIMusicText,UIEffectsText,UIPlayersText,UIBackText
UIStartText: dc.b "START DEMO",0
UIScoresText: dc.b "HIGH SCORES",0
UIOptionsText: dc.b "OPTIONS",0
UIDemoText: dc.b "WATCH DEMO",0
UIQuitText: dc.b "SAVE & QUIT",0
UITitleCredit: dc.b "5 MIN DEMO - SNK / WHITTYAPPS",0
UIArrow: dc.b ">",0
UIOn: dc.b "ON",0
UIOff: dc.b "OFF",0
UIFPSWait: dc.b "FPS --",0
UIFPSPrefix: dc.b "FPS ",0
UIFPSText: dc.b "FPS DISPLAY",0
UIMusicText: dc.b "MUSIC",0
UIMusicNative: dc.b "TNK III",0
UIMusicIkari: dc.b "IKARI",0
UIMusicGate: dc.b "IKARI GATE",0
UIEffectsText: dc.b "SOUND EFFECTS",0
UIBackText: dc.b "BACK",0
UIPlayersText: dc.b "PLAYERS",0
UIOnePlayer: dc.b "1",0
UITwoPlayers: dc.b "2 ALTERNATE",0
UIPlayersNext: dc.b "PLAYERS SETTING: NEXT GAME",0
UIOptionsHeading: dc.b "OPTIONS",0
UIOptionsHelp: dc.b "A/START: CHANGE   B/ESC: BACK",0
UIStockProfile: dc.b "STOCK A1200 - VARIABLE FPS",0
UIFullProfile: dc.b "ACCELERATED A1200",0
UIScoresHeading: dc.b "TNK III HIGH SCORES",0
UIScoresColumns: dc.b "RANK   NAME     SCORE",0
UIScoresHelp: dc.b "A/START/B: TITLE",0
UISaveHint: dc.b "SCORES AND OPTIONS SAVE ON QUIT",0
UIEntryHeading: dc.b "NEW HIGH SCORE",0
UIEntryName: dc.b "ENTER YOUR INITIALS",0
UIEntryHelp1: dc.b "UP/DOWN: LETTER  L/R: POSITION",0
UIEntryHelp2: dc.b "A: NEXT/DONE  START: DONE  B: BACK",0
UIEntryHelp3: dc.b "OR TYPE INITIALS AND PRESS RETURN",0
UIGameOver: dc.b "GAME OVER",0
UIVictory: dc.b "DEMO COMPLETE",0
UIYourScore: dc.b "YOUR SCORE",0
UIResultHelp: dc.b "A/START: HIGH SCORES",0
UIAlphabet: dc.b "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ",0
UIKeyMap:
    dc.b $20,'A',$35,'B',$33,'C',$22,'D',$12,'E',$23,'F'
    dc.b $24,'G',$25,'H',$17,'I',$26,'J',$27,'K',$28,'L'
    dc.b $37,'M',$36,'N',$18,'O',$19,'P',$10,'Q',$13,'R'
    dc.b $21,'S',$14,'T',$16,'U',$34,'V',$11,'W',$32,'X'
    dc.b $15,'Y',$31,'Z',$0a,'0',$01,'1',$02,'2',$03,'3'
    dc.b $04,'4',$05,'5',$06,'6',$07,'7',$08,'8',$09,'9'
    dc.b $40,' ',0,0
    even

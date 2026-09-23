"""Hand-assigned names, filled in during reverse engineering."""
# (segment, offset) -> name  (THINK Pascal runtime library routines in CODE 1)
FUNCS = {
    (1, 0x0000): 'RT_Concat',          # Concat(s1..sn) -> string
    (1, 0x0048): 'RT_Halt',            # run exit proc, ExitToShell
    (1, 0x0054): 'RT_InitGlobals',     # runtime startup: A5 world, heap setup
    (1, 0x009C): 'RT_InitSANE',        # FP68K SetEnvironment
    (1, 0x00B2): 'RT_InitToolbox',     # InitGraf..InitDialogs, MoreMasters
    (1, 0x0DCE): 'RT_SetLoad',         # expand a set constant into a 32-byte temp
    (1, 0x0E1A): 'RT_SetIn',           # element IN set -> Z flag clear if member
    (1, 0x0E46): 'RT_IOEnd',           # end of write/writeln statement
    (1, 0x0E52): 'RT_IOBegin',         # begin write/writeln to file var (Output)
    (1, 0x0E8C): 'RT_WriteInt',        # write(i:w)
    (1, 0x0EA8): 'RT_Writeln',
    (1, 0x0FD8): 'RT_WriteStr',        # write(s:w)
    (1, 0x15AC): 'RT_NewHandle',
    (1, 0x15B8): 'RT_HLock',
    (1, 0x15C2): 'RT_HUnlock',
    (1, 0x15CC): 'RT_NGetTrapAddress',
    (1, 0x15E6): 'RT_PBClose',
    (1, 0x15F8): 'RT_PBSetVol',
    (1, 0x160A): 'RT_PBDelete',
    (1, 0x1666): 'RT_PostEvent',
    (1, 0x1672): 'RT_StringToNum',
    (1, 0x1686): 'RT_NumToString',
    (1, 0x1698): 'RT_SysEnvirons',     # SysEnvirons glue (with pre-System-4.1 fallback)
    (2, 0x1048): 'MAIN_ENTRY',         # runtime init calls, falls into BEASTIE
    (2, 0x1054): 'BEASTIE',            # main program body (name follows the code)
}
# A5-relative globals: offset -> name
GLOBALS = {
    # QuickDraw globals (InitGraf(@thePort) with thePort at -$34)
    -0x34: 'qd.thePort', -0xB2: 'qd.randSeed', -0xA8: 'qd.screenBits.bounds',
    # program globals
    -0x10E: 'gWindow', -0x10A: 'gMenus[1]', -0x106: 'gMenus[2]', -0x102: 'gMenus[3]',
    -0x112: 'gWhichWindow',
    -0x1BE: 'gEvent.what', -0x1BC: 'gEvent.message', -0x1B8: 'gEvent.when',
    -0x1B4: 'gEvent.where', -0x1B0: 'gEvent.modifiers',
    -0x1BF: 'gDone', -0x1CA: 'gInForeground', -0x1C9: 'gHasWNE',
    -0x408: 'gPics[0]', -0x404: 'gPics[1]', -0x400: 'gPics[2]',
    -0x40C: 'gMan.v', -0x40A: 'gMan.h',
    -0x436: 'gBeasts[0].h', -0x438: 'gTimers[1]', -0x43C: 'gTimers[0]',
    -0x43E: 'gClock', -0x43F: 'gPlaying', -0x440: 'gPaused',
    -0x442: 'gBeastDelay', -0x444: 'gNumBeasts', -0x446: 'gDensity',
    -0x452: 'gSettings.numBeasts', -0x450: 'gSettings.numBeasts+2',
    -0x44E: 'gSettings.delay', -0x44C: 'gSettings.delay+2',
    -0x44A: 'gSettings.density', -0x448: 'gSettings.density+2',
    -0x60C: 'Output',
}
# (segment, offset) -> comment
COMMENTS = {
    (2, 0x010E): 'Board[x,y] at A5-$40B + x*18 + y   (Board: array[1..31,1..18] of 0..3)',
    (2, 0x04D4): 'set constant [1..31]',
    (2, 0x04F0): 'set constant [1..18]',
    (2, 0x0676): "set constant ['I'..'L']",
    (2, 0x0930): 'set constant [0, 3]  (man or empty)',
}
# Immediate values added to an index to form an A5-relative array address
ARRAY_BASES = {
    -0x40B: 'gBoard[x,y]  (x*18 + y)', -0x40A: 'gBoard[x,1]  (x*18)', -0x3F9: 'gBoard[x,18] (x*18) / gBoard[1,y]',
    -0x1DD: 'gBoard[31,y]', -0x408: 'gPics[cell]  (cell*4)', -0x438: 'gBeasts[i].v (i*4)',
    -0x436: 'gBeasts[i].h (i*4)', -0x43C: 'gTimers[t]   (t*4)', -0x452: 'gSettings[i] (i*4)',
    -0x10E: 'gMenus[i]    (i*4)',
}

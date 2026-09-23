"""Mac Toolbox / OS A-line trap names (subset relevant to 1989 apps)."""
_OS = {
 0x00:'Open',0x01:'Close',0x02:'Read',0x03:'Write',0x04:'Control',0x05:'Status',
 0x06:'KillIO',0x07:'GetVolInfo',0x08:'Create',0x09:'Delete',0x0A:'OpenRF',
 0x0B:'Rename',0x0C:'GetFileInfo',0x0D:'SetFileInfo',0x0E:'UnmountVol',
 0x0F:'MountVol',0x10:'Allocate',0x11:'GetEOF',0x12:'SetEOF',0x13:'FlushVol',
 0x14:'GetVol',0x15:'SetVol',0x16:'InitQueue',0x17:'Eject',0x18:'GetFPos',
 0x19:'InitZone',0x1B:'SetZone',0x1C:'FreeMem',0x1E:'NewPtr',0x1F:'DisposPtr',
 0x20:'SetPtrSize',0x21:'GetPtrSize',0x22:'NewHandle',0x23:'DisposHandle',
 0x24:'SetHandleSize',0x25:'GetHandleSize',0x26:'HandleZone',0x27:'ReallocHandle',
 0x28:'RecoverHandle',0x29:'HLock',0x2A:'HUnlock',0x2B:'EmptyHandle',
 0x2C:'InitApplZone',0x2D:'SetApplLimit',0x2E:'BlockMove',0x2F:'PostEvent',
 0x30:'OSEventAvail',0x31:'GetOSEvent',0x32:'FlushEvents',0x33:'VInstall',
 0x34:'VRemove',0x35:'OffLine',0x36:'MoreMasters',0x38:'WriteParam',
 0x39:'ReadDateTime',0x3A:'SetDateTime',0x3B:'Delay',0x3C:'CmpString',
 0x3D:'DrvrInstall',0x3E:'DrvrRemove',0x3F:'InitUtil',0x40:'ResrvMem',
 0x41:'SetFilLock',0x42:'RstFilLock',0x43:'SetFilType',0x44:'SetFPos',
 0x45:'FlushFile',0x46:'GetTrapAddress',0x47:'SetTrapAddress',0x48:'PtrZone',
 0x49:'HPurge',0x4A:'HNoPurge',0x4B:'SetGrowZone',0x4C:'CompactMem',
 0x4D:'PurgeMem',0x60:'FSDispatch',0x61:'MaxBlock',0x62:'PurgeSpace',
 0x63:'MaxApplZone',0x64:'MoveHHi',0x65:'StackSpace',0x66:'NewEmptyHandle',
 0x69:'HGetState',0x6A:'HSetState',0x90:'SysEnvirons',
}
_TB = dict(enumerate(start=0x50, iterable="""InitCursor SetCursor HideCursor ShowCursor - ShieldCursor ObscureCursor -
BitAnd BitXor BitNot BitOr BitShift BitTst BitSet BitClr
WaitNextEvent Random ForeColor BackColor ColorBit GetPixel StuffHex LongMul
FixMul FixRatio HiWord LoWord FixRound InitPort InitGraf OpenPort
LocalToGlobal GlobalToLocal GrafDevice SetPort GetPort SetPBits PortSize MovePortTo
SetOrigin SetClip GetClip ClipRect BackPat ClosePort AddPt SubPt
SetPt EqualPt StdText DrawChar DrawString DrawText TextWidth TextFont
TextFace TextMode TextSize GetFontInfo StringWidth CharWidth SpaceExtra -
StdLine LineTo Line MoveTo Move ShutDown HidePen ShowPen
GetPenState SetPenState GetPen PenSize PenMode PenPat PenNormal -
StdRect FrameRect PaintRect EraseRect InverRect FillRect EqualRect SetRect
OffsetRect InsetRect SectRect UnionRect Pt2Rect PtInRect EmptyRect StdRRect
FrameRoundRect PaintRoundRect EraseRoundRect InverRoundRect FillRoundRect - StdOval FrameOval
PaintOval EraseOval InvertOval FillOval SlopeFromAngle AngleFromSlope StdArc FrameArc
PaintArc EraseArc InvertArc FillArc PtToAngle - StdPoly FramePoly
PaintPoly ErasePoly InvertPoly FillPoly OpenPoly ClosePgon KillPoly OffsetPoly
PackBits UnpackBits StdRgn FrameRgn PaintRgn EraseRgn InverRgn FillRgn
NewRgn DisposRgn OpenRgn CloseRgn CopyRgn SetEmptyRgn SetRecRgn RectRgn
OffsetRgn InsetRgn EmptyRgn EqualRgn SectRgn UnionRgn DiffRgn XorRgn
PtInRgn RectInRgn SetStdProcs StdBits CopyBits StdTxMeas StdGetPic ScrollRect
StdPutPic StdComment PicComment OpenPicture ClosePicture KillPicture DrawPicture -
ScalePt MapPt MapRect MapRgn MapPoly - InitFonts GetFName
GetFNum FMSwapFont RealFont SetFontLock DrawGrowIcon DragGrayRgn NewString SetString
ShowHide CalcVis CalcVBehind ClipAbove PaintOne PaintBehind SaveOld DrawNew
GetWMgrPort CheckUpDate InitWindows NewWindow DisposWindow ShowWindow HideWindow GetWRefCon
SetWRefCon GetWTitle SetWTitle MoveWindow HiliteWindow SizeWindow TrackGoAway SelectWindow
BringToFront SendBehind BeginUpdate EndUpdate FrontWindow DragWindow DragTheRgn InvalRgn
InvalRect ValidRgn ValidRect GrowWindow FindWindow CloseWindow SetWindowPic GetWindowPic
InitMenus NewMenu DisposMenu AppendMenu ClearMenuBar InsertMenu DeleteMenu DrawMenuBar
HiliteMenu EnableItem DisableItem GetMenuBar SetMenuBar MenuSelect MenuKey GetItmIcon
SetItmIcon GetItmStyle SetItmStyle GetItmMark SetItmMark CheckItem GetItem SetItem
CalcMenuSize GetMHandle SetMFlash PlotIcon FlashMenuBar AddResMenu PinRect DeltaPoint
CountMItems InsertResMenu DelMenuItem UpdtControl NewControl DisposControl KillControls ShowControl
HideControl MoveControl GetCRefCon SetCRefCon SizeControl HiliteControl GetCTitle SetCTitle
GetCtlValue GetMinCtl GetMaxCtl SetCtlValue SetMinCtl SetMaxCtl TestControl DragControl
TrackControl DrawControls GetCtlAction SetCtlAction FindControl Draw1Control Dequeue Enqueue
GetNextEvent EventAvail GetMouse StillDown Button TickCount GetKeys WaitMouseUp
UpdtDialog CouldDialog FreeDialog InitDialogs GetNewDialog NewDialog SelIText IsDialogEvent
DialogSelect DrawDialog CloseDialog DisposDialog FindDItem Alert StopAlert NoteAlert
CautionAlert CouldAlert FreeAlert ParamText ErrorSound GetDItem SetDItem SetIText
GetIText ModalDialog DetachResource SetResPurge CurResFile InitResources RsrcZoneInit OpenResFile
UseResFile UpdateResFile CloseResFile SetResLoad CountResources GetIndResource CountTypes GetIndType
GetResource GetNamedResource LoadResource ReleaseResource HomeResFile SizeRsrc GetResAttrs SetResAttrs
GetResInfo SetResInfo ChangedResource AddResource AddReference RmveResource RmveReference ResError
WriteResource CreateResFile SystemEvent SystemClick SystemTask SystemMenu OpenDeskAcc CloseDeskAcc
GetPattern GetCursor GetString GetIcon GetPicture GetNewWindow GetNewControl GetMenu
GetNewMBar UniqueID SysEdit KeyTrans OpenRFPerm RsrcMapEntry Secs2Date Date2Secs
SysBeep SysError PutIcon TEGetText TEInit TEDispose TextBox TESetText
TECalText TESetSelect TENew TEUpdate TEClick TECopy TECut TEDelete
TEActivate TEDeactivate TEIdle TEPaste TEKey TEScroll TEInsert TESetJust
Munger HandToHand PtrToXHand PtrToHand HandAndHand InitPack InitAllPacks Pack0
Pack1 Pack2 Pack3 FP68K Pack5 Pack6 Pack7 PtrAndHand
LoadSeg UnLoadSeg Launch Chain ExitToShell GetAppParms GetResFileAttrs SetResFileAttrs""".split()))

def name(w):
    if w == 0xABFF: return 'DebugStr'
    if w == 0xA9FF: return 'Debugger'
    if w & 0x0800:                      # Toolbox trap
        n = _TB.get(w & 0x3FF)
        return n if n and n != '-' else None
    base = _OS.get(w & 0xFF)
    if base is None: return None
    if w == 0xA207: return 'HGetVInfo'
    if w == 0xA260: return 'HFSDispatch'
    if w == 0xA346: return 'GetOSTrapAddress'
    if w == 0xA746: return 'GetToolTrapAddress'
    flags = []
    if w & 0x0400: flags.append('SYS' if base.startswith(('New','Reall')) else 'ASYNC')
    if w & 0x0200: flags.append('CLEAR' if base.startswith(('New','Reall')) else 'HFS')
    return base + (',' + ','.join(flags) if flags else '')

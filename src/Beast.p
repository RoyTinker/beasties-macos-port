{ ============================================================================
  Beast 1.0  (c) 1989 Chuck Shotton / BIAP Systems
  Reconstructed Lightspeed (THINK) Pascal source — main program, CODE segment 2.

  Decompiled by hand from the 68000 object code.  Every routine carries the
  CODE-2 offset of its entry point so it can be checked against
  disasm/CODE_2.s.  Procedure names are the original MacsBug symbols (THINK
  truncates them to 8 characters; the full names are a best guess and the
  8-char original is given in brackets).  Local variable names are invented.

  Where the original code does something odd, that is preserved and flagged
  with  "NOTE:".
  ============================================================================ }

program Beastie;                                   { [BEASTIE] — name after main body }

uses
	BeastSettings;                                   { CODE 1: GetBeastSettings, SaveBeastSettings,
	                                                   DoSettings, gSettings }

const
	kMaxX = 31;                   { board columns 1..31 (x, 16 px each -> 496 px) }
	kMaxY = 18;                   { board rows    1..18 (y, 16 px each -> 288 px) }
	kCell = 16;
	kMaxBeasts = 10;

	{ cell contents — also the index into gPics }
	cMan = 0;                     { PICT 200 }
	cBlock = 1;                   { PICT 201 }
	cBeast = 2;                   { PICT 202 }
	cEmpty = 3;                   { never drawn; erased instead }

	{ menus (MENU resources 128/129/130 carry menu IDs 1/2/3) }
	mApple = 1;
	mFile = 2;
	iNewGame = 1;   { cmd-N }
	iSettings = 2;  { cmd-S }
	iPause = 3;     { cmd-P }
	iQuit = 4;      { cmd-Q }
	mEdit = 3;

type
	CellType = 0..3;

var
	{ A5-relative addresses are given for cross-reference with the disassembly }
	gPics: array[0..3] of PicHandle;                         { -$408 .. -$3FC }
	gBoard: packed array[1..kMaxX, 1..kMaxY] of CellType;    { -$3F8, one byte per cell }
	gMan: Point;                                             { -$40C  (v = y, h = x) }
	gBeasts: array[1..kMaxBeasts] of Point;                  { -$434 }
	gTimers: array[0..1] of LongInt;                         { -$43C  0 = beasts, 1 = clock }
	gClock: Integer;                                         { -$43E  seconds of play }
	gPlaying: Boolean;                                       { -$43F }
	gPaused: Boolean;                                        { -$440 }
	gBeastDelay: Integer;                                    { -$442  ticks between beast moves }
	gNumBeasts: Integer;                                     { -$444 }
	gDensity: Integer;                                       { -$446  1-in-N chance of a block }

	gWindow: WindowPtr;                                      { -$10E }
	gMenus: array[1..3] of MenuHandle;                       { -$10A }
	gWhichWindow: WindowPtr;                                 { -$112 }
	gEvent: EventRecord;                                     { -$1BE }
	gDone: Boolean;                                          { -$1BF }
	gHasWNE: Boolean;                                        { -$1C9 }
	gInForeground: Boolean;                                  { -$1CA }


{ ---------------------------------------------------------------- $0000 }
procedure Error (msg: Str255);                            { [ERROR] }
{ Shows ALRT 129 ("^0" + OK).  Used for errors AND for "Dead Meat" / "You Win". }
	var
		item: Integer;
begin
	ParamText(msg, '', '', '');
	item := Alert(129, nil);
end;


{ ---------------------------------------------------------------- $0048 }
function Rand (n: Integer): Integer;                     { [RAND] }
{ Returns 0..n }
begin
	Rand := Abs(Random mod (n + 1));
end;


{ ---------------------------------------------------------------- $00C0 }
procedure GetPictures;                                   { [GETPICTU] }

	{ ------------------------------------------------------------ $0078 }
	procedure GetPict (var thePic: PicHandle; id: Integer);    { [GETPICT], nested }
	begin
		thePic := PicHandle(GetResource('PICT', id));
		if thePic = nil then
			Error('PICT is nil.');
	end;

begin
	GetPict(gPics[cMan], 200);
	GetPict(gPics[cBeast], 202);
	GetPict(gPics[cBlock], 201);
end;


{ ---------------------------------------------------------------- $00FA }
procedure InitMatrix;                                    { [INITMATR] }
{ Empty board surrounded by a wall of blocks. }
	var
		x, y: Integer;
begin
	for x := 1 to kMaxX do
		for y := 1 to kMaxY do
			gBoard[x, y] := cEmpty;
	for x := 1 to kMaxX do
		begin
			gBoard[x, 1] := cBlock;
			gBoard[x, kMaxY] := cBlock;
		end;
	for y := 1 to kMaxY do
		begin
			gBoard[1, y] := cBlock;
			gBoard[kMaxX, y] := cBlock;
		end;
end;


{ ---------------------------------------------------------------- $0180 }
procedure RandomMatrix (density: Integer);               { [RANDOMMA] }
	var
		i, x, y, count: Integer;
begin
	randSeed := TickCount;
	count := 558 div density;                  { 558 = 31 * 18 }
	for i := 1 to count do
		begin
			repeat
				x := Rand(28) + 2;               { 2..30 }
				y := Rand(15) + 2;               { 2..17 }
			until gBoard[x, y] = cEmpty;
			gBoard[x, y] := cBlock;
		end;

	count := gNumBeasts;
	for i := 1 to count do
		begin
			repeat
				x := Rand(28) + 2;
				y := Rand(15) + 2;
			until gBoard[x, y] <> cBeast;        { NOTE: may land on (and replace) a block }
			SetPt(gBeasts[i], x, y);
			gBoard[x, y] := cBeast;
		end;

	repeat
		x := Rand(28) + 2;
		y := Rand(15) + 2;
	until gBoard[x, y] <> cBeast;                { NOTE: may land on a block too }
	SetPt(gMan, x, y);
	gBoard[x, y] := cMan;
end;


{ ---------------------------------------------------------------- $02B4 }
procedure DrawMatrix;                                    { [DRAWMATR] }
	var
		x, y: Integer;
		r: Rect;
begin
	SetPort(gWindow);
	for y := 1 to kMaxY do
		for x := 1 to kMaxX do
			if gBoard[x, y] <> cEmpty then
				begin
					SetRect(r, (x - 1) * kCell, (y - 1) * kCell, x * kCell, y * kCell);
					DrawPicture(gPics[gBoard[x, y]], r);
				end;
end;


{ ---------------------------------------------------------------- $033E }
procedure DrawClock;                                     { [DRAWCLOC] }
	var
		r: Rect;
		numStr: Str255;
		s: Str255;
begin
	SetPort(gWindow);
	SetRect(r, 420, 283, 485, 295);            { overlaps the bottom wall row }
	EraseRect(r);
	NumToString(gClock, numStr);
	MoveTo(422, 293);
	s := Concat('Time: ', numStr);
	DrawString(s);
	FrameRect(r);
end;


{ ---------------------------------------------------------------- $03B4 }
procedure DrawCell (x, y: Integer);                      { [DRAWCELL] }
	var
		r: Rect;
begin
	SetRect(r, (x - 1) * kCell, (y - 1) * kCell, x * kCell, y * kCell);
	if gBoard[x, y] = cEmpty then
		EraseRect(r)
	else
		DrawPicture(gPics[gBoard[x, y]], r);
end;


{ ---------------------------------------------------------------- $0598 }
procedure MoveManTo (dx, dy: Integer);                   { [MOVEMANT] }
	var
		newX, newY: Integer;                   { -$12, -$14 — used by the nested procs }

	{ ------------------------------------------------------------ $0436 }
	procedure ManMove (x, y: Integer);                  { [MANMOVE], nested }
	{ NOTE: the parameters are pushed by callers but never read; the body uses
	  the enclosing procedure's newX/newY through the static link. }
	begin
		gBoard[gMan.h, gMan.v] := cEmpty;
		gBoard[newX, newY] := cMan;
		DrawCell(gMan.h, gMan.v);
		DrawCell(newX, newY);
		SetPt(gMan, newX, newY);
	end;

	{ ------------------------------------------------------------ $04A6 }
	procedure PushBlock (dx, dy: Integer);              { [PUSHBLOC], nested }
	{ Slide the whole row of blocks in front of the man one cell, if there is
	  an empty cell at the end of the row.  A beast or the board edge stops it. }
		var
			x, y: Integer;
			horiz, foundSpace, blocked: Boolean;
	begin
		x := gMan.h + dx;
		y := gMan.v + dy;
		horiz := dx <> 0;                        { NOTE: computed but never used }
		foundSpace := false;
		blocked := false;
		repeat
			if (x in [1..kMaxX]) and (y in [1..kMaxY]) then
				begin
					if gBoard[x, y] = cBlock then
						begin
							x := x + dx;
							y := y + dy;
						end
					else if gBoard[x, y] = cBeast then
						blocked := true
					else
						foundSpace := true
				end
			else
				blocked := true;
		until foundSpace or blocked;
		if foundSpace then
			begin
				gBoard[x, y] := cBlock;
				DrawCell(x, y);
				ManMove(newX, newY);             { the man steps into the first block's cell }
			end;
	end;

begin { MoveManTo }
	newX := gMan.h + dx;
	newY := gMan.v + dy;
	if (newX in [1..kMaxX]) and (newY in [1..kMaxY]) then
		case gBoard[newX, newY] of
			cBlock:
				PushBlock(dx, dy);
			cBeast:
				begin
					Error('Dead Meat !!!');
					gPlaying := false;
				end;
			cEmpty:
				ManMove(newX, newY);
			otherwise
				;
		end;
end;


{ ---------------------------------------------------------------- $066A }
procedure DoMoveMan (key: Integer);                      { [DOMOVEMA] }
	var
		dx, dy: Integer;
begin
	if key in [ord('I')..ord('L')] then
		begin
			case key - ord('I') of
				0: { I = up }
					begin
						dx := 0;
						dy := -1;
					end;
				1: { J = left }
					begin
						dx := -1;
						dy := 0;
					end;
				2: { K = down }
					begin
						dx := 0;
						dy := 1;
					end;
				3: { L = right }
					begin
						dx := 1;
						dy := 0;
					end;
			end;
			MoveManTo(dx, dy);
		end
	else
		SysBeep(2);
end;


{ ---------------------------------------------------------------- $078C }
procedure MoveBeast (i, dx, dy: Integer);                { [MOVEBEAS] }
	var
		x, y: Integer;
		killsMan: Boolean;

	{ ------------------------------------------------------------ $06F0 }
	procedure BeastMove (i, x, y: Integer);             { [BEASTMOV], nested }
	begin
		gBoard[gBeasts[i].h, gBeasts[i].v] := cEmpty;
		gBoard[x, y] := cBeast;
		DrawCell(gBeasts[i].h, gBeasts[i].v);
		DrawCell(x, y);
		SetPt(gBeasts[i], x, y);
	end;

begin
	x := gBeasts[i].h + dx;
	y := gBeasts[i].v + dy;
	if (x in [1..kMaxX]) and (y in [1..kMaxY]) then
		case gBoard[x, y] of
			cMan, cEmpty:
				begin
					killsMan := gBoard[x, y] = cMan;
					BeastMove(i, x, y);
					if killsMan then
						begin
							Error('Dead Meat!!!');
							gPlaying := false;
						end;
				end;
			cBlock:
				begin
					{ blocked: try one random direction instead (dx, dy in -1..1) }
					dx := Rand(2) - 1;
					dy := Rand(2) - 1;
					x := gBeasts[i].h + dx;
					y := gBeasts[i].v + dy;
					if gBoard[x, y] = cEmpty then
						BeastMove(i, x, y);
				end;
			otherwise    { cBeast: another beast is in the way — stay put }
				;
		end;
end;


{ ---------------------------------------------------------------- $097A }
procedure DoMoveBeasts;                                  { [DOMOVEBE] }
	var
		i, count: Integer;
		dx, dy: Integer;
		allTrapped: Boolean;

	{ ------------------------------------------------------------ $08EA }
	function OpenSpace (x, y: Integer): Boolean;        { [OPENSPAC], nested }
	{ True if any of the 9 cells centred on (x, y) is empty or holds the man. }
		var
			i, j: Integer;
			found: Boolean;
	begin
		found := false;
		for i := x - 1 to x + 1 do
			for j := y - 1 to y + 1 do
				if gBoard[i, j] in [cMan, cEmpty] then
					found := true;
		OpenSpace := found;
	end;

begin
	allTrapped := true;
	count := gNumBeasts;
	for i := 1 to count do
		if OpenSpace(gBeasts[i].h, gBeasts[i].v) then
			begin
				allTrapped := false;
				dx := Rand(2) - 1;                 { NOTE: both overwritten below }
				dy := Rand(2) - 1;
				with gBeasts[i] do
					begin
						{ head straight for the man, diagonals allowed }
						if v > gMan.v then
							dy := -1
						else if v < gMan.v then
							dy := 1
						else
							dy := 0;
						if h > gMan.h then
							dx := -1
						else if h < gMan.h then
							dx := 1
						else
							dx := 0;
					end;
				MoveBeast(i, dx, dy);
			end;
	if allTrapped then
		begin
			Error('You Win!!!');
			gPlaying := false;
		end;
end;


{ ---------------------------------------------------------------- $0A5A }
procedure CheckTime;                                     { [CHECKTIM] }
	var
		t: 0..1;
		delay: LongInt;
begin
	for t := 0 to 1 do
		if TickCount > gTimers[t] then
			begin
				case t of
					0:
						begin
							DoMoveBeasts;
							delay := gBeastDelay;
						end;
					1:
						begin
							gClock := gClock + 1;
							DrawClock;
							delay := 60;
						end;
				end;
				gTimers[t] := TickCount + delay;
			end;
end;


{ ---------------------------------------------------------------- $0AD4 }
procedure CheckMultiFinder;                              { [CHECKMUL] }
const
	_WaitNextEvent = $60;
	_Unimplemented = $9F;
begin
	gHasWNE := NGetTrapAddress(_WaitNextEvent, ToolTrap) <> NGetTrapAddress(_Unimplemented, ToolTrap);
	gInForeground := true;
end;


{ ---------------------------------------------------------------- $0B18 }
procedure SetUpMenus;                                    { [SETUPMEN] }
	var
		i: 1..3;
begin
	gMenus[1] := GetMenu(128);
	AddResMenu(gMenus[1], 'DRVR');
	gMenus[2] := GetMenu(129);
	gMenus[3] := GetMenu(130);
	for i := 1 to 3 do
		InsertMenu(gMenus[i], 0);
	DrawMenuBar;
end;


{ ---------------------------------------------------------------- $0B7A }
procedure SetUpWindow;                                   { [SETUPWIN] }
	var
		style: Style;
begin
	gWindow := GetNewWindow(128, nil, WindowPtr(-1));
	SetPort(gWindow);
	TextSize(9);
	style := [bold];
	TextFace(style);
end;


{ ---------------------------------------------------------------- $0BB8 }
procedure Redrum;                                        { [REDRUM] — "murder" backwards }
{ Resume procedure handed to InitDialogs: after a system error, just quit. }
begin
	ExitToShell;
end;


{ ---------------------------------------------------------------- $0BCA }
procedure Init;                                          { [INIT] }
begin
	InitGraf(@thePort);
	InitWindows;
	InitFonts;
	InitMenus;
	InitCursor;
	TEInit;
	InitDialogs(@Redrum);
	FlushEvents(everyEvent, 0);
	CheckMultiFinder;
	SetUpMenus;
	SetUpWindow;
	gDone := false;
end;


{ ---------------------------------------------------------------- $0C0C }
procedure MDeskAbout;                                    { [MDESKABO] }
	var
		item: Integer;
begin
	ParamText('1.0', ' 3/4/89', '', '');     { "Beast ^0,^1." -> "Beast 1.0, 3/4/89." }
	item := Alert(128, nil);                 { About: OK / Help! (4) / Info (5) }
	if item = 4 then
		item := Alert(130, nil)                { PICT 130: how to play }
	else if item = 5 then
		item := Alert(131, nil);               { PICT 131: shareware info }
end;


{ ---------------------------------------------------------------- $0C76 }
procedure DoMenuBar (menuResult: LongInt);               { [DOMENUBA] }
	var
		theMenu, theItem: Integer;
		daName: Str255;
		savePort: GrafPtr;
		refNum: Integer;
		handled: Boolean;
begin
	theMenu := HiWord(menuResult);
	theItem := LoWord(menuResult);
	case theMenu of
		mApple:
			if theItem <= 2 then
				MDeskAbout
			else
				begin
					GetItem(gMenus[1], theItem, daName);
					GetPort(savePort);
					refNum := OpenDeskAcc(daName);
					SetPort(savePort);
				end;

		mFile:
			case theItem of
				iNewGame:
					begin
						InitMatrix;
						RandomMatrix(gDensity);
						EraseRect(gWindow^.portRect);
						DrawMatrix;
						gClock := 0;
						gTimers[0] := 0;
						gTimers[1] := 0;
						gPlaying := true;
						gPaused := true;               { play starts on first key/click }
					end;
				iSettings:
					begin
						DoSettings;                    { CODE 1 }
						{ NOTE: applied immediately, even mid-game }
						gBeastDelay := gSettings.delay;
						gNumBeasts := gSettings.numBeasts;
						gDensity := gSettings.density;
					end;
				iPause:
					gPaused := true;
				iQuit:
					gDone := true;
			end;

		mEdit:
			if FrontWindow = gWindow then
				Error('Edit commands are currently for DAs only.')
			else
				handled := SystemEdit(theItem - 1);
	end;
	HiliteMenu(0);
end;


{ ---------------------------------------------------------------- $0DB0 }
procedure DoMouseDown;                                   { [DOMOUSED] }
begin
	if gPaused then
		gPaused := false;
	case FindWindow(gEvent.where, gWhichWindow) of
		inMenuBar:
			DoMenuBar(MenuSelect(gEvent.where));
		inSysWindow:
			SystemClick(gEvent, gWhichWindow);
		inContent:
			SysBeep(1);
		inDrag:
			DragWindow(gWhichWindow, gEvent.where, screenBits.bounds);
		inGoAway:
			if gWhichWindow = gWindow then
				if TrackGoAway(gWhichWindow, gEvent.where) then
					gDone := true;
		otherwise
			;
	end;
end;


{ ---------------------------------------------------------------- $0E44 }
procedure DoKeyDown;                                     { [DOKEYDOW] }
	var
		key: Integer;
begin
	if BitAnd(gEvent.modifiers, cmdKey) <> 0 then
		begin
			DoMenuBar(MenuKey(chr(BitAnd(gEvent.message, charCodeMask))));
			HiliteMenu(0);
		end
	else if gPlaying then
		begin
			key := BitAnd(gEvent.message, charCodeMask);
			if key > ord('Z') then
				key := key - ord('a') + ord('A');      { crude upcase }
			DoMoveMan(key);
			if gPaused then
				gPaused := false;
		end;
end;


{ ---------------------------------------------------------------- $0EAC }
procedure DoUpdate;                                      { [DOUPDATE] }
	var
		w: WindowPtr;
		savePort: GrafPtr;
begin
	w := WindowPtr(gEvent.message);
	GetPort(savePort);
	SetPort(w);
	BeginUpdate(w);
	if w = gWindow then
		begin
			DrawMatrix;
			DrawClock;
		end;
	EndUpdate(w);
	SetPort(savePort);
end;


{ ---------------------------------------------------------------- $0EEC }
procedure DoMulti (event: EventRecord);                  { [DOMULTI] }
{ app4Evt handler (MultiFinder suspend/resume). }
	var
		msgType: Integer;
begin
	{ NOTE: the object code also stores an unused constant $1F into a local
	  here; the exact source expression for the high byte is uncertain. }
	msgType := BitAnd(BitShift(event.message, -24), $FF);   { high byte of message }
	if msgType = $FA then                           { mouseMovedMessage }
		SysBeep(1);                                   { NOTE: leftover debug beep }
	{ NOTE: suspend vs. resume is decided from bit 0 alone, for any app4Evt }
	if BitAnd(event.message, 1) <> 0 then
		gInForeground := true
	else
		gInForeground := false;
end;


{ ---------------------------------------------------------------- $0F46 }
procedure CheckEvents (inDialog: Boolean);               { [CHECKEVE] }
	var
		sleep: LongInt;
		gotEvent: Boolean;
begin
	if gInForeground then
		sleep := 0
	else
		sleep := 20;
	if gHasWNE then
		gotEvent := WaitNextEvent(everyEvent, gEvent, sleep, nil)
	else
		begin
			SystemTask;
			gotEvent := GetNextEvent(everyEvent, gEvent);
		end;
	if gotEvent then
		case gEvent.what of
			mouseDown:
				if not inDialog then
					DoMouseDown;
			keyDown, autoKey:
				if not inDialog then
					DoKeyDown;
			updateEvt:
				DoUpdate;
			app4Evt:
				DoMulti(gEvent);
			otherwise
				;
		end;
	{ beasts keep moving while in the background — see the instructions }
	if not gPaused and gPlaying then
		CheckTime;
end;


{ ---------------------------------------------------------------- $0FF4 }
procedure InitBeast;                                     { [INITBEAS] }
begin
	GetBeastSettings;                                    { CODE 1 }
	gBeastDelay := gSettings.delay;
	gNumBeasts := gSettings.numBeasts;
	gDensity := gSettings.density;
	GetPictures;
	InitMatrix;
	gPlaying := false;
	gPaused := false;
	gClock := 0;
end;


{ ---------------------------------------------------------------- $102E }
procedure ShutDown;                                      { [SHUTDOWN] }
begin
	SaveBeastSettings;                                   { CODE 1 }
	DisposeWindow(gWindow);
end;


{ ---------------------------------------------------------------- $1054 }
begin { Beastie }
	{ $1048: THINK runtime start-up (RT_InitGlobals, RT_InitSANE, RT_InitToolbox) }
	Init;
	InitBeast;
	repeat
		CheckEvents(false);
	until gDone;
	ShutDown;
	{ $1072: RT_Halt -> ExitToShell }
end.

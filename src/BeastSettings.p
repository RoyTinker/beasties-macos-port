{ ============================================================================
  Beast 1.0 — reconstructed "settings" unit, CODE segment 1 ($1802..$1C79).

  The rest of CODE 1 ($0000..$1801) is the Lightspeed Pascal runtime library
  (string concat, set ops, text-file I/O for writeln, trap glue, start-up).
  See NOTES.md for the list of runtime entry points.

  Settings live in a file "Beast Game Settings" in the System Folder, as
  resource 'BSet' 128 (named "Settings"): three LongInts, 12 bytes, big-endian.
  ============================================================================ }

unit BeastSettings;

interface

	type
		BeastSettingsRec = record
				numBeasts: LongInt;           { A5-$452   1..10,  default 5  }
				delay: LongInt;               { A5-$44E   1..360, default 45 (ticks) }
				density: LongInt;             { A5-$44A   2..10,  default 5  }
			end;

	var
		gSettings: BeastSettingsRec;

	procedure GetBeastSettings;                      { [GETBEAST]  JT $2A }
	procedure SaveBeastSettings;                     { [SAVEBEAS]  JT $32 }
	procedure DoSettings;                            { [DOSETTIN]  JT $3A }

implementation

	const
		kSettingsFile = 'Beast Game Settings';
		kSettingsType = 'BSet';
		kSettingsID = 128;
		kSettingsDlog = 129;                           { DITL: 1 OK, 5/6/7 edit fields }

	type
		SettingsArray = array[0..2] of LongInt;        { same storage as gSettings }


{ ---------------------------------------------------------------- $1802 }
	procedure SetBlessedVol;                         { [SETBLESS] }
	{ Make the System Folder (the "blessed" folder) the default volume. }
		var
			err: OSErr;
			env: SysEnvRec;
			pb: ParamBlockRec;
	begin
		err := SysEnvirons(1, env);
		pb.ioNamePtr := nil;
		pb.ioVRefNum := env.sysVRefNum;
		pb.ioCompletion := nil;
		err := PBSetVol(@pb, false);
		if err <> noErr then
			writeln('Setvol err:', err : 1);
	end;


{ ---------------------------------------------------------------- $187C }
	procedure OpenSettingsFile (var refNum: Integer);  { [OPENSETT] }
		var
			tries: Integer;
			err: OSErr;
	begin
		tries := 1;
		repeat
			refNum := OpenResFile(kSettingsFile);
			if refNum = -1 then
				begin
					err := ResError;
					writeln('reserr:', err : 1);
					CreateResFile(kSettingsFile);
				end
			else
				UseResFile(refNum);
			tries := tries + 1;
		until (refNum <> -1) or (tries > 10);
		if tries > 10 then
			writeln('Unable to Open Settings file');
	end;


{ ---------------------------------------------------------------- $196A }
	procedure GetBeastSettings;
		var
			refNum: Integer;
			h: Handle;
	begin
		h := nil;
		SetBlessedVol;
		OpenSettingsFile(refNum);
		if refNum <> -1 then
			h := GetResource(kSettingsType, kSettingsID);
		if (h <> nil) and (refNum <> -1) then
			BlockMove(h^, @gSettings, SizeOf(gSettings))      { compiled as a 12-byte record copy }
		else
			begin
				writeln('no resource file');
				gSettings.numBeasts := 5;
				gSettings.delay := 45;
				gSettings.density := 5;
				if (h = nil) and (refNum <> -1) then
					begin
						h := NewHandle(SizeOf(gSettings));
						HLock(h);
						BlockMove(@gSettings, h^, SizeOf(gSettings));
						HUnlock(h);
						AddResource(h, kSettingsType, kSettingsID, 'Settings');
					end;
			end;
		if refNum <> -1 then
			CloseResFile(refNum);
	end;


{ ---------------------------------------------------------------- $1A62 }
	procedure SaveBeastSettings;
		var
			refNum: Integer;
			h: Handle;
	begin
		SetBlessedVol;
		OpenSettingsFile(refNum);
		h := GetResource(kSettingsType, kSettingsID);
		if h <> nil then
			begin
				BlockMove(@gSettings, h^, SizeOf(gSettings));
				ChangedResource(h);
			end
		else
			writeln('settings was nil');
		CloseResFile(refNum);
		if h <> nil then
			ReleaseResource(h);           { NOTE: h was already freed by CloseResFile }
	end;


{ ---------------------------------------------------------------- $1C0C }
	procedure VerifySettings;                        { [VERIFYSE] }
	begin
		with gSettings do
			begin
				if numBeasts < 1 then
					numBeasts := 1
				else if numBeasts > 10 then
					numBeasts := 10;
				if delay < 1 then
					delay := 1
				else if delay > 360 then
					delay := 360;
				if density < 2 then
					density := 2
				else if density > 10 then
					density := 10;
			end;
	end;


{ ---------------------------------------------------------------- $1AE6 }
	procedure DoSettings;
		var
			dlg: DialogPtr;
			item, itemType: Integer;
			itemHandle: Handle;
			box: Rect;
			s: Str255;
	begin
		dlg := GetNewDialog(kSettingsDlog, nil, WindowPtr(-1));
		if dlg <> nil then
			begin
				for item := 5 to 7 do
					begin
						GetDItem(dlg, item, itemType, itemHandle, box);
						NumToString(SettingsArray(gSettings)[item - 5], s);
						SetIText(itemHandle, s);
					end;
				DrawDialog(dlg);
				repeat
					ModalDialog(nil, item);
					case item of
						1:    { OK }
							begin
								VerifySettings;
								SaveBeastSettings;
							end;
						5, 6, 7:
							begin
								GetDItem(dlg, item, itemType, itemHandle, box);
								GetIText(itemHandle, s);
								StringToNum(s, SettingsArray(gSettings)[item - 5]);
							end;
						otherwise
							;
					end;
				until item = 1;
				DisposDialog(dlg);
			end
		else
			writeln('Missing Settings Dialog...');
	end;

end.

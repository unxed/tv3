# API names: tv3 and tvision

The reference of the names of tv3 is magiblot/tvision at commit b4831e2, its public headers `include/tvision/*.h`: the
classes, their bases, methods, fields and constants, and the free functions keep their C++ names, written with a capital
first letter (`TView::handleEvent` is `TView.HandleEvent`, `messageBox` is `MessageBox`, `cstrlen` is `CStrLen`).
Pascal compares names without regard to case, so the spelling of the rest of a name does not matter to the compiler.

This file lists where tv3 differs: (1) the forms that cannot be written in Pascal, with the reason; (2) the names changed
to the tvision form (2026-10-09), with the old tv3 name; (3) the differences that are still open, with their size;
(4) what tv3 adds to the tvision classes; (5) the units of tv3 that have no tvision counterpart (new APIs).

## 1. Forms that cannot be written in Pascal

| tvision | tv3 | reason |
|---|---|---|
| constructor `TView(const TRect &bounds)` (the class name) | `constructor Create(const Bounds: TRect)` | a Pascal constructor has a name of its own; `Create` is the name the RTL uses |
| destructor `~TView()` | `destructor Destroy; override` (called through `Free`) | the same: a destructor has a name; `Destroy` is virtual in the root class of the RTL |
| a value type constructor `TRect(ax, ay, bx, by)`, `TRect(p1, p2)` | `TRect.Create(AX, AY, BX, BY)`, `TRect.Create(P1, P2)` (record constructors) | as above; `R := TRect.Create(...)` is the Pascal form of `TRect r(...)` |
| the brace initializer `TPoint {x, y}` | `Point(X, Y)` | Pascal has no record literal in an expression (only in a typed constant) |
| the default constructor of a value type (`TColor()`) | `Default(TColor)` | a record cannot have a constructor without parameters |
| `class TObject` (`destroy`, `shutDown`) as the root | the RTL root class `System.TObject` (`Free`) | `TObject` is the root of every Pascal class; a second `TObject` would hide it |
| multiple inheritance: `TView : TObject, TStreamable`; `TCollection : TNSCollection, TStreamable`; `TSortedCollection : TNSSortedCollection, TCollection`; `TProgram : TGroup, TProgInit`; `TApplication : TAppInit, TProgram`; `TDeskTop : TGroup, TDeskInit`; `TWindow : TGroup, TWindowInit`; `THistoryWindow : TWindow, THistInit`; `THelpFile`, `THelpIndex`, `THelpTopic`, `TValidator : TObject, TStreamable` | one base: `TView`, `TCollection`, `TValidator`, `THelpIndex`, `THelpTopic` descend from `TStreamable`; `TNSCollection` and `TNSSortedCollection` are merged into `TCollection` and `TSortedCollection`; `TApplication` descends from `TProgram` only | a Pascal class has one base class |
| the `T...Init` classes (`TProgInit`, `TDeskInit`, `TWindowInit`, `THistInit`) and the static `initStatusLine(TRect)`, `initMenuBar(TRect)`, `initDeskTop(TRect)`, `initBackground(TRect)`, `initFrame(TRect)`, `initViewer(...)` passed to them | the virtual methods `InitStatusLine`, `InitMenuBar`, `InitDeskTop`, `InitBackground`, `InitFrame`, `InitViewer` called from the constructor | the `Init` classes are bases of the multiple inheritance above (they exist so that a C++ constructor can reach code of a derived class); a Pascal constructor can call a virtual method |
| the operators `<<` and `>>` of `opstream` and `ipstream` (`os << p`, `is >> p`, `os << i`) | the methods `WriteObject`/`ReadObject` (an object), `WritePointer`/`ReadPointer` (a pointer to an object); a number goes through `WriteBytes(I, SizeOf(I))`/`ReadBytes` (`os << i` writes its bytes in tvision too) | Free Pascal declares an operator only outside a class and an operator cannot change its operand (`>>` stores into its right side); the methods of tvision (`writeByte`, `writeWord`, `writeString`, `writeBytes`, `readByte` ...) keep their names |
| `iopstream : ipstream, opstream`; `ifpstream : fpbase, ipstream`, `ofpstream`, `fpstream` | `iopstream` is an `ipstream` with an `opstream` (`Op`, and the operator `:=` converts an `iopstream` to an `opstream`); `ifpstream`, `ofpstream` and `fpstream` have the members of `fpbase` (`Open`, `Close`, `RdBuf`; there is no `setbuf`, a `TBufStream` has its own buffer) | a Pascal class has one base class |
| `streambuf`, `filebuf`, `ios::openmode`, `ios::seekdir` | the byte streams of `TvObjs`: a `TStream` is the buffer of a `pstream`, a `TBufStream` the buffer of a file stream; the open modes of `TDosStream` (`stOpenRead`, `stCreate` ...), the directions of `FileSeek` (`fsFromBeginning`, `fsFromCurrent`, `fsFromEnd`) | Pascal has no C++ library streams |
| the static member `name` of every streamable class (`TView::name`), the protected constructor `TView(StreamableInit)` | the virtual function `StreamableName` returns the name; the registration gives it as text (`TStreamableClass.Create('TView', @TView.Build)`); the protected constructor `Create(streamableInit)` | in the mode `objfpc` a descendant cannot declare again an identifier of its base class, so each class cannot have a constant `Name`; a constructor has a name of its own |
| the objects `RView` ... of type `TStreamableClass` made by the static constructors of `nm*.cpp` | the variables `RView: TStreamableClass` ... set in the `initialization` of the unit | Pascal has no static constructors of objects; a unit initialization runs before the program |
| `TTextDevice : TScroller, streambuf` (`overflow`, `xsputn`, `do_sputn`), `otstream` | `TTextDevice : TScroller` with `Do_sputn` and `PutStr`, `PutLine`, `PutChar`; no `otstream` | Pascal has no `streambuf` and no C++ streams; text goes to a device through `Do_sputn` |
| operators `TPoint +=`, `-=`, `+`, `-`, `==`, `!=`; `TRect ==`, `!=` | `+`, `-`, `=`, `<>` of `TPoint`; `=`, `<>` of `TRect` (`P := P + Q` for `+=`) | Pascal operators are `+`, `-`, `=`, `<>`; there are no compound assignment operators to declare |
| `TCommandSet` operators `+=`, `-=` (a command or a set), `&`, `|`, `&=`, `|=`, `==`, `!=` | `+`, `-`, `and`, `or`, `=`, `<>` (`S := S + cmQuit` for `S += cmQuit`, `S := S and T` for `S &= T`) | as for `TPoint`; Pascal has no operators `&` and `|`, its `and` and `or` are their counterparts |
| a constructor with one parameter and a conversion operator (`TColorRGB(uint32_t)`, `operator uint32_t()`, `TColor(char)`, `TColor(int)`, `TColor(TColorBIOS)`, `TColorAttr(int)`, `operator uchar()`, `TAttrPair(int)`, `operator ushort()`, `TScreenCharacter(char)`, `TScreenCell(ushort)`) | the implicit operators `:=` of the record (`C := $7F00BB`, `B := Byte(Attr)`) | a Pascal record converts only through its operators `:=`; an explicit cast (`TColorAttr(LongInt($1F))`) uses them too |
| `TColorAttr::operator<<(int)` (it returns a `TAttrPair`), `TColorAttr(const TAttrPair &)` | the operator `shl` of the unit `TvColors`; the operator `:=` of `TAttrPair` | `TAttrPair` is declared after `TColorAttr` and Free Pascal has no forward declaration of a record, so `TColorAttr` cannot name it |
| `TAttrPair` as an array (`operator ArrayRef`, `attrs[0]`), `operator>>`, `operator|=` | the default property `P[0]`, `P[1]`; `shr`; `or` (`P := P or A`) | Pascal has no conversion to an array reference; a default array property gives the same indexing |
| the private member `TColor::type()` | `TColor.&Type` | `type` is a reserved word of Pascal (`&` escapes it) |
| the union of `TMenuItem` (`param`, `subMenu`) | two fields `Param` and `SubMenu` | a Pascal class cannot have a variant part |
| the `operator +` of `TSubMenu`, `TMenuItem`, `TStatusDef`, `TStatusItem` (functions outside the classes) | the operators `+` of the unit `TvMenus` | Free Pascal declares operators of classes only in a unit (a class cannot declare an operator) |
| a null `name` or `text` (`TMenuItem(0, ...)`, `TStatusItem(0, ...)`) | an empty `ShortString` gives a nil `Name` or `Text` | a `ShortString` has no null value |
| static data members and static methods (`TView::commandEnabled`, `TProgram::deskTop`, `TScreen::screenWidth`, `MsgBoxText::yesText`) | `class var` and `class ...; static;` of the same class, with the same names (`TView.CommandEnabled`, `TProgram.DeskTop`, `TScreen.ScreenWidth`, `MsgBoxText.YesText`) | the same members; outside the class Pascal names them with the class (`TProgram.DeskTop`), as C++ does with `::` |
| enumerations inside a class (`TDisplay::smCO80`) | constants inside the class (`TDisplay.smCO80`, also `TScreen.smCO80`) | the same names |
| a member of an enumeration type nested in a class, named with the class (`TView::phPostProcess`) | `TView.PhaseType.phPostProcess` outside `TView` and its descendants (inside them `phPostProcess`) | Free Pascal puts the members of a nested enumeration in the scope of the type, not of the class: `TView.phPostProcess` does not compile |
| `TPalette::data` (`TColorAttr *`, copied by the copy constructor and `operator=`, freed by the destructor); `TView::getPalette()` returns `TPalette &` | `TPalette.Data: array of TColorAttr` (an assignment shares it, `Copy(P.Data)` copies it); `GetPalette: TPalette` returns the record by value | a Pascal function cannot return a reference; the memory of a record is managed only through a managed field (the management operators of Free Pascal 3.2 are not called for the result of a record constructor) |
| `TStringView`, `TSpan<T>` arguments | `ShortString`, or a pointer and a length (`PByte` + `Integer`, `PScreenCell` + count) | Pascal strings are values; there is no generic span type in the RTL |
| `char *` buffers filled by a function (`formatStr`, `newStr`, `historyStr`) | `ShortString` results, `PStr = ^ShortString` (`NewStr`, `DisposeStr`) | the strings of the API are `ShortString` |
| `formatStr(const char *format, ...)` (printf) | `FormatStr(const Fmt: ShortString; const Args: array of const): ShortString` (a format of `SysUtils.Format`) | Pascal has no C varargs; `array of const` is its form of a variable argument list |
| `messageBox(unsigned aOptions, const char *msg, ...)`, `messageBoxRect(r, aOptions, msg, ...)` | the overloads `MessageBox(AOptions, Fmt, Args)` and `MessageBoxRect(R, AOptions, Fmt, Args)` | the same: `array of const` |
| templates and callbacks taking any callable (`TText::drawCharEx(cells, c, Func &&)`, `drawStrEx`) | `TText.DrawChar`/`DrawStr` with an attribute (`PColorAttr`, nil keeps the attributes) | Pascal generics cannot take a C++ callable; the one use (set or keep the attribute) is a parameter |
| a parameter named as a member (`TText::scroll(text, count, includeIncomplete, length, width)`) | `TText.Scroll(Text, Len, Count, IncludeIncomplete, ALength, AWidth)` | in a Pascal class a parameter may not have the name of a method of the class (`Width`) |
| union members of `KeyDownEvent` and `MessageEvent` | variant parts of the records (`KeyDown.KeyCode` or `KeyDown.CharScan`, `Message.InfoPtr` ... `Message.InfoChar`) | the same names; in `KeyDownEvent` and `MessageEvent` tv3 adds padding so that `KeyCode` does not overlap a 64-bit `InfoPtr` and `ControlKeyState` keeps its place in a command made of a key |

## 2. Names changed to the tvision form (2026-10-09)

dn, fpide (in sp) and tve were changed with them.

| tvision | old tv3 name | tv3 now |
|---|---|---|
| `formatStr` | `TvFormat.FormatSlots(var Result; Format; var Params)` and `TvMsgBox.FormatStr` (private) | `TvFormat.FormatStr(Fmt, Args)`; the slot form of the Pascal Drivers API is in the Drivers shims of dn and fpide, on top of it |
| `messageBox(aOptions, fmt, ...)`, `messageBoxRect(r, aOptions, fmt, ...)` | `MessageBoxFmt`, `MessageBoxRectFmt` | `MessageBox`, `MessageBoxRect` (overloads) |
| `MsgBoxText::yesText` ... `confirmText` | `MsgYesText`, `MsgNoText`, `MsgOKText`, `MsgCancelText`, `MsgWarningText`, `MsgErrorText`, `MsgInformationText`, `MsgConfirmText` | `MsgBoxText.YesText` ... `MsgBoxText.ConfirmText` |
| `TMenu::deflt` | `TMenu.Default` | `TMenu.Deflt` |
| `TMenuItem::keyCode`, `TStatusItem::keyCode` | `Key` | `KeyCode` |
| `TListBox::items`, `TListBox::list()`, `TListBoxRec::items` | the field `TListBox.List`, `TListBoxRec.List` | the field `Items`, the function `List`; `TListBoxRec.Items` |
| `TRect::isEmpty` | `TRect.Empty` | `TRect.IsEmpty` |
| `TTextDevice::do_sputn` | `DoSputn` | `Do_sputn` |
| `TNSCollection::atRemove`, `remove`, `removeAll` | `AtDelete`, `Delete`, `DeleteAll` | `AtRemove`, `Remove`, `RemoveAll` |
| `TView::commandEnabled`, `enableCommands`, `disableCommands`, `enableCommand`, `disableCommand`, `getCommands`, `setCommands`, `setCmdState`, `curCommandSet`, `commandSetChanged`, `showMarkers`, `errorAttr` (static) | unit routines and variables of `TvViews` (and instance methods that called them) | class members of `TView` |
| `TProgram::application`, `statusLine`, `menuBar`, `deskTop`, `appPalette`, `eventTimeoutMs`, `pending` (static) | unit variables of `TvApp` | class variables of `TProgram` |
| `TEvent::mouse`, `keyDown`, `message`; `MouseEventType`, `KeyDownEvent`, `CharScanType`, `MessageEvent` | one flat record (`Event.Where`, `Event.KeyCode`, `Event.CharCode`, `Event.Command`, `Event.InfoPtr` ...) | `Event.Mouse.Where`, `Event.KeyDown.KeyCode`, `Event.KeyDown.CharScan.CharCode`, `Event.Message.Command`, `Event.Message.InfoPtr` ... |
| `TView::writeBuf(..., const TDrawBuffer &)`, `writeLine(..., const TDrawBuffer &)` | `WriteBufD`, `WriteLineD` | `WriteBuf`, `WriteLine` (overloads) |
| `TView::getBounds()`, `getExtent()`, `getClipRect()`, `makeLocal(p)`, `makeGlobal(p)` | also the procedures `GetBounds(var R)`, `GetExtent(var R)`, `GetClipRect(var R)`, `MakeLocal(Source, var Dest)`, `MakeGlobal(Source, var Dest)` | the functions only (`R := GetExtent`) |
| `TText::width`, `next`, `prev`, `scroll`, `drawOne`, `drawStr`, `drawChar`, `toCodePage` (static) | `TextWidth`, `TextWidthS`, `TextNext`, `TextPrev`, `TextScroll`, `TextDrawOne`, `TextDrawStr`, `TextDrawStrS`, `TextDrawChar`, `TextToCodePage` | `TText.Width`, `TText.Next`, `TText.Prev`, `TText.Scroll`, `TText.DrawOne`, `TText.DrawStr`, `TText.DrawChar`, `TText.ToCodePage` |
| `TRect(ax, ay, bx, by)`, `TRect(p1, p2)`, `TRect ==`, `TPoint +`, `-`, `==` | `TRect.Assign`, `TRect.Copy`, `TRect.Equals`, `TPoint.Assign`, `TPoint.Equals`, `TPoint.EqualsXY`, `TPoint.isLE`, `TPoint.isGE`, `PointAdd`, `PointSub`, `PointEq` | `TRect.Create`, assignment, `=`, `<>`, `+`, `-`, `Point(X, Y)` |
| `TScreen::screenWidth`, `screenHeight`, `screenBuffer`, `cursorLines`, `screenMode` (static); `TDisplay::smBW80`, `smCO80`, `smMono`, `smFont8x8`, `smUpdate` | unit variables of `TvScreen` and `TvSys`, constants of `TvSys` | class variables of `TScreen`, constants of `TDisplay` (in `TvScreen`) |
| `TView::phaseType`, `TView::selectMode` | the unit types `TPhaseType`, `TSelectMode` of `TvViews` | the nested types `TView.PhaseType`, `TView.SelectMode` |
| `TSItem(value, next)` (a class) | the record `TSItem`, `PSItem`, `NewSItem` | the class `TSItem` with `TSItem.Create(Value, Next)` |
| `class TCommandSet` (`has`, `enableCmd`, `disableCmd`, `isEmpty`, the operators) | `TCommandSet = set of Byte` | the record `TCommandSet` with the methods and operators of tvision; the Pascal set form (`[cmA, cmB]`) is in the shims of dn and fpide (`CommandSetOf`) |
| `TColorRGB`, `TColorBIOS`, `TColorXTerm`, `TColorDefault`, `TColor`, `TColorAttr`, `TAttrPair` (classes with methods and operators), `TColorConversion` (static) | plain types and unit functions (`RGB`, `ColorBIOS`, `ColorIsRGB`, `ColorAsBIOS`, `ColorToBIOS`, `AttrMake`, `AttrFromBIOS`, `AttrFg`, `AttrSetStyle`, `AttrReversed`, `AttrToBIOS`, `AttrAsBIOSByte`, `AttrEq`, `AttrPair`, `BIOSToXTerm16` ...; `TAttrPair.Lo`/`Hi`) | records with the methods and operators of tvision (`TColorAttr.Create(Fg, Bg, Style)`, `A.GetForeground`, `A.Reversed`, `A.ToBIOS`, `Byte(A)`, `C.IsRGB`, `TColorConversion.BIOStoXTerm16`, `P[0]`) |
| `TScreenCharacter` (`initWithChar`, `initWithMultiByteChar`, `initAsWideCharTrail`, `isWide`, `isWideCharTrail`, `appendZeroWidthChar`, `getText`), `TScreenCell(ch, attr)`, `TScreenCell(ushort)`, `==` | unit functions of `TvCell` (`ScInitChar`, `ScInitText`, `ScInitCodePoint`, `ScInitWideTrail`, `ScIsWide`, `ScIsWideTrail`, `ScLength`, `ScText`, `ScAppendZeroWidth`, `CellMake`, `CellFromBIOS`, `CellEq`); the public fields `Text` and `Meta` | the methods of the records (`C.InitWithChar`, `C.GetText` ...), `TScreenCell.Create`, `TScreenCell(Word(...))`, `=`; the text and the flags are private |
| `class TPalette` (`TPalette(const char *, ushort)`, `TPalette(const TColorAttr *, ushort)`, `TPalette(const TColorAttr (&)[N])`, `operator[]`, `data`) | `TPalette = array of TColorAttr`, `MakePalette`, `PaletteSize` | the record `TPalette` (`TPalette.Create(cpX, Len)`, `P[I]`, `P.Data`); `MakePalette` and `PaletteSize` of the Pascal API are in the shims of dn and fpide |
| `TKey(keyCode, shiftState)`, `TKey ==`, `!=` | `KeyMake(KeyCode, ShiftState)`, `KeyEq(A, B)` | `TKey.Create(KeyCode, ShiftState)`, the conversion of a key code (`K := kbF3`), `=`, `<>` |
| `TMenuItem(name, command, keyCode, helpCtx, param, next)`, `TMenuItem(name, keyCode, subMenu, helpCtx, next)`, `append`, `TSubMenu(name, keyCode, helpCtx)`, `TMenu()`, `TMenu(itemList)`, `TMenu(itemList, deflt)`, `newLine()`, `TStatusItem(text, keyCode, command, next)`, `TStatusDef(min, max, items, next)`, `operator +` | records built by the functions `NewItem`, `NewSubMenu`, `NewMenu`, `NewLine(Next)`, `NewStatusDef`, `NewStatusKey`, `DisposeMenu`; `PMenu`, `PMenuItem`, `PStatusItem`, `PStatusDef` | the classes with their constructors, `NewLine`, the operators `+` of `TvMenus`, `Free`; the functions of the Pascal API are in the Menus shim of fpide |

## 3. Open differences

Each is a rename or a new form that needs the callers in dn, fpide and tve changed with it; the counts are the uses
outside tv3 (dn / fpide / tve) at the time of writing.

| tvision | tv3 | what is open |
|---|---|---|
| the streams of `THelpTopic` and `THelpIndex` (`read`, `write`, `build`, `readParagraphs`, `writeParagraphs` ...) and of `THelpFile` (`ipstream`/`fpstream`), and of the compiler `tvhc` | `THelpTopic.Load`/`Store`, `THelpIndex.Load`/`Store`, `THelpFile` over a `TStream`; the byte streams `TStream`, `TDosStream`, `TBufStream`, `TMemoryStream` and the registry `RegisterType`/`TStreamRec` stay in `TvObjs` for them | the translation of `THelpTopic::readParagraphs` and `writeParagraphs` was refused by the audit (`raw` 24 and 38 tokens in common with `HELPFILE.PAS` of Borland Pascal Turbo Vision); waits for the owner |
| `TEventQueue` (`doubleDelay`, `mouseReverse`, `getMouseEvent`, `getKeyEvent`, `setPasteText` ...), `THWMouse`, `TMouse`, `THardwareInfo` (`setCaretSize`, `screenWrite` ...), `TClipboard` (`setText`, `requestText`), `TSystemError` | the backend of tv3: `TvSys` (`PollEvent`, `PollKeyEvent`), `TvMouse` (`DoubleDelayMs` in ms, `MouseReverse`), `TvScreen` (`SetCaretSize`, `SetCaretPosition`, `ScreenWrite`), `TvClip` (`ClipboardSetText`, `ClipboardGetText`) | classes with the static members of tvision over the backend (`TEventQueue.DoubleDelay` counts in ticks of 55 ms in tvision); waits for the owner: in tvision these classes are the platform layer (`THardwareInfo::getKeyEvent`, `waitForEvents`, `interruptEventWait`, `getPlatform`, the key tables, the console set-up), which the backend of tv3 replaces; most members have no counterpart in the backend, so a facade would invent their behaviour |
| `inputBox`, `inputBoxRect` (msgbox.h) | `InputBox`, `InputBoxRect` in `TvInput` | names are the same; the unit differs (it needs the input line) |
| absent in tv3: `TParamText`, `TOutline`, `TOutlineViewer`, `TNode`, `TResourceFile`, `TResourceCollection`, `TStringList`, `TStrListMaker`, `TStringView`, `TTextMetrics` and `TText::measure`, `fromCodePage`, `setCodePageTranslation`, `TVMemMgr`, `TDrawSurface`, `TSurfaceView`, `TIndicator`, `TEditor`, `TMemo`, `TFileEditor`, `TEditWindow` (the editor is tve), `popupMenu`, `historyAdd` ..., `getHomeDir`, `lowMemory`, `printKeyCode` ... (debug output), the C string helpers of util.h (`strnzcpy`, `itoa` ...: Pascal strings) | - | not translated |

## 4. What tv3 adds to the tvision classes

Members that tvision has as `private` or `protected` are not additions (`TCluster.Column`, `TScrollBar.GetPartCode`,
`TFrame.FrameLine` ...); tv3 makes some of them public. The additions:

| class | members | why |
|---|---|---|
| `TView` | `WriteBufW`, `WriteLineW`, `WriteBufC`, `WriteLineC`, `GetColorW`, `WriteView` | the 16-bit cells and BIOS attributes of programs written for the Pascal API (dn, fpide) |
| `TView` | `MenuEnabled` (and `CommandHiddenHook`), `ResizeBalance`, `ClearPositionalEvents`, `Update`, `UpdTicks`, `UpTmr` | features of dn (commands hidden for good, background updates, resize of the panels) |
| `TView`, `TGroup` | `FirstThat`, `ForEach`, `LastThat` with a nested routine (`TNestedViewTest`, `TNestedViewAction`) besides the forms with a function and `void *args` | a routine declared inside the caller, the form the Pascal programs use |
| `TGroup` | `Delete` | the name of the Pascal API for `remove` |
| `TDeskTop` | `SwitcherStep`, `SwitcherActive`, `SwitcherEnd`, `SwitcherIdle` | the window switcher (Ctrl+Tab) |
| `TDialog` | `DirectLink` | dn: a label linked to a view outside the dialog |
| `TInputLine` | `Validator` (public), `KeepVertical`, `LC`, `RC`, `C` | the validator of the input line (protected in tvision); the frame characters and the arrows |
| `TButton` | `AnimationTimer` | the press of a button is shown for a moment |
| `TCluster` | `UxClusterKey` | the keys of the UX guidelines |
| `TListBox` | `GetFocusedItem`, `SetFocusedItem` | dn |
| `TScrollBar`, `TScroller` | `Step`, `ForceScroll`, `ShowSBar` | dn |
| `TMenuView` | `SubClosedByEsc` | the menus of the UX guidelines |
| `TDrawBuffer` | `MoveStrS`, `MoveCStrS`, `MoveGlyph`, `PutGlyph` | the `ShortString` forms; the glyphs of `TvGlyphs` |
| `TCollection` | `AtReplace` | dn |
| `TText` | `DrawStrUtf8` | draws text that is UTF-8 whatever `Utf8Enabled` is (tve inside a code-page program) |
| `TTimerQueue` | `First`, `Clock` | the tests |
| `KeyDownEvent` | `VirtualKey`, `RepeatCount`, `Win32State`, `KeyFlags` | the win32 input mode of terminals (far2l, Windows Terminal) |
| `THelpWindow`, `TChDirDialog`, `TFileDialog`, `TFileList` | `Viewer`, `GotoContext`; `DirList`, `DirInput`, `OKButton`, `ChDirButton`, `SetUpDialog`; `ReadDirectory`; `ReadDirectoryMask` | protected or private parts of tvision made public, and dn |
| unit level | `ShadowSize`, `ShadowAttr` (`TvScreen`); `TheTopView`, `ModalCount`, `UxWheelUnderCursor` (`TvViews`); `ListBoxOwnsList` (`TvList`); `HotKeyAlt`, `UpCaseCp` (`TvUtil`); the texts of the dialogs as variables (`TvChDir`, `TvFileDlg`, `TvColorSel`, `TvHelp`) | variables of tvision's sources, dn, the streams of the Pascal API, translations |

## 5. Units without a tvision counterpart (new APIs)

They stay as they are (owner, 2026-10-09):

`TvActions` (the actions: commands, keys, texts), `TvAnsi` (terminal colors), `TvAppDir` (configuration directories),
`TvAscii` (the ASCII table), `TvCharset` (character sets), `TvClipCmd` (clipboard through commands), `TvCodePg` (code
pages), `TvCrc`, `TvCStr`, `TvDos` and `TvDosNames` (the DOS backend), `TvFar2l` (the far2l terminal extensions),
`TvGadgets` (the clock and the heap view), `TvGlyphs`, `TvIni`, `TvKeyName`, `TvLocale`, `TvMem` (the test backend),
`TvMouse`, `TvPath`, `TvProc`, `TvPty`, `TvTermIO`, `TvTermOS*`, `TvUnix` (the terminal backend), `TvUstr`, `TvUtf8`,
`TvVt`, `TvVtExt`, `TvVtKeys`, `TvVtRun`, `TvVtView` (the terminal emulator), `TvWild`, `TvWordNav`, `TvXlat`; and in
the units that do have a counterpart, the routines of the backend (`TvSys` hooks, `TvScreen.ScreenCreate`, `TvClip`).

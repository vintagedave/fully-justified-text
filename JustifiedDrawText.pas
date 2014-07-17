unit JustifiedDrawText;

(* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is DrawTextJustified, a method (and supporting methods) to draw fully-
 * justified text on a canvas.
 *
 * The Initial Developer of the Original Code is David Millington.
 *
 * Portions created by the Initial Developer are Copyright (C) 2013
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s): David Millington
 *
 * ***** END LICENSE BLOCK ***** *)

interface

uses
  Vcl.Graphics, System.Types;

type
  TDrawTextJustifiedOptions = set of (
    tjJustifyTrailingLines, // Is the last line of a paragraph fully justified too? Normally only
      // left-justified
    tjJustifySingleWords, // A line of a single word (trailing or otherwise) will stretch the word
      // out, spaces between characters
    tjMeasureOnly, // Like DT_CALCRECT: doesn't draw anything, just adjusts the rect
    tjForceManual // Always use the alternative, non-Windows text output method. Not necessary to
      // specify; it is automatically used when required regardless of this setting
  );

  procedure DrawTextJustified(const Canvas : TCanvas; const Text : string; var Rect : TRect;
    const Options : TDrawTextJustifiedOptions);

implementation

uses
  Winapi.Windows, Generics.Collections, System.SysUtils, System.Math, System.StrUtils;

type
  TLine = record
  private
    FText : string;
    FLengthPx,
    FNumBreakChars : Integer;
    FJustifyThisLine : Boolean; // False for, eg, the last line of a paragraph
    FIsTrailingLine : Boolean;
    FIsSingleWord : Boolean;

    function GetWordWithZeroWidthSpaces : string;
  public
    constructor Create(const Text : string; const LengthPx : Integer; const BreakChar : Char;
      const IsTrailingLine, Justify : Boolean);

    property Text : string read FText;
    property WordWithZeroWidthSpaces : string read GetWordWithZeroWidthSpaces;
    property LengthPx : Integer read FLengthPx;
    property NumBreakChars : Integer read FNumBreakChars;
    property Justify : Boolean read FJustifyThisLine;
    property IsTrailingLine : Boolean read FIsTrailingLine;
    property IsSingleWord : Boolean read FIsSingleWord;
  end;

const
  ZeroWidthSpace = #8203; // $200B; http://www.fileformat.info/info/unicode/char/200B/index.htm

// http://stackoverflow.com/questions/15294501/how-to-count-number-of-occurrences-of-a-certain-char-in-string
function OccurrencesOfChar(const S: string; const C: char): integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) do
    if S[I] = C then
      Inc(Result);
end;

{ TLine }

constructor TLine.Create(const Text: string; const LengthPx: Integer; const BreakChar : Char;
  const IsTrailingLine, Justify : Boolean);
begin
  FText := Text;
  FLengthPx := LengthPx;
  FIsTrailingLine := IsTrailingLine;
  // Setting the justification requires knowing how many 'break characters' there are - usually
  // spaces.  See http://msdn.microsoft.com/en-us/library/windows/desktop/dd145094(v=vs.85).aspx
  // Find a font's break character using GetTextMetrics (passed in here.)
  FNumBreakChars := OccurrencesOfChar(Text, BreakChar);
  FIsSingleWord := FNumBreakChars = 0;
  // If it's (eg) the last line of a paragraph then it should not be justified (this is always true
  // including for last lines if DrawTextJustified is called with JustifyTrailingLines = true.)
  FJustifyThisLine := Justify;
end;

function TLine.GetWordWithZeroWidthSpaces: string;
var
  Loop : Integer;
begin
  // This is used when justifying the trailing lines of paragraphs, and justifying single words
  // It splits a word with zero-width spaces (so pritning it should print it the same as without
  // spaces) and returns that, and that in turn will be split into "words" of one char each

  assert(FIsSingleWord); // Otherwise should not call
  if not FIsSingleWord then
    Result := Text
  else begin
    for Loop := 1 to Length(FText) do begin
      Result := Result + FText[Loop];
      if Loop <> Length(FText) then  // don't add the space after the last character
        Result := Result + ZeroWidthSpace;
    end;
  end;
end;

{ Other }

function GetBreakChar(const Canvas : TCanvas; PFontSupportsJustification : PBoolean) : Char;
var
  Metrics : TTextMetric;
  SupportsJustification : Boolean;
begin
  SupportsJustification := true; // assume it can normally
  GetTextMetrics(Canvas.Handle, Metrics);
  Result := Metrics.tmBreakChar;
  // "tmBreakChar: The value of the character that will be used to define word breaks for text justification."
  // - http://msdn.microsoft.com/en-us/library/windows/desktop/dd145132(v=vs.85).aspx
  // But some fonts, such as Segoe UI (!), define this as #13 - a line break.
  // Check if it is a character that takes up space onscreen, and if not return the space char
  if Canvas.TextWidth(Result) = 0 then begin
    Result := ' ';
    SupportsJustification := false;
  end;

  if Assigned(PFontSupportsJustification) then
    PFontSupportsJustification^ := SupportsJustification;
end;

function EndsWithLineBreaks(const Text : string) : Boolean;
var
  EndChar : Char;
begin
  // A line can end with #10 or #13 (or both)
  if Length(Text) = 0 then Exit(False);
  EndChar := Text[Length(Text)];
  Result := (EndChar = #10) or (EndChar = #13);
end;

procedure ManualJustifyTextOut(const Canvas : TCanvas; const X, Y : Integer; const Line : TLine;
  const SpaceToFill : Integer; BreakChar : Char; const JustifySingleWords : Boolean);
var
  Words : TStringDynArray;
  BreakSize : Integer;
  BreakAddition : Single;
  BreakAdditionInt : Integer;
  BreakFraction : Single;
  AmountOff : Single;
  AmountOffInt : Integer;
  Index : Integer;
  CurrentX : Integer;
  Space : Integer;
  OrigRounding : TRoundingMode;
  LineText : string;
begin
  // Manual implementation! Break the string up at each BreakChar (probably a space) and draw
  // each word separately. The gap in between should be increased by a fraction of the space.
  // Problem is, the fraction won't be integer. Suppose Space = 4px and there are 8 words, so
  // 7 spaces. Each space should be increased by 4/7 = 0.57 pixels.
  // Keep a running count of the amount "off" we are, rounding the fraction. So, space + round(0.57)
  // and the amount off will be +- 0.something. Add a rounded version of that to the space too:
  // space + round(0.57); space + round(amountoff); amountoff = desired-actual.
  // Rounding mode affects this - you get different behaviour in the middle of the line if it
  // truncates, rounds to nearest, etc. IMO rounding to nearest looks best. Nothing quite mimics
  // the inbuilt Windows method; toggling between manual and inbuilt will shift mid-line words by
  // one pixel no matter what, and the rounding just affects which words.

  // Normally a single word is left-justified. But if the option is on to justify it, do so by
  // (a) using this manual method - Windows doesn't support this - and (b) faking it by inserting
  // zero-width spaces and using those as the break char
  if Line.FIsSingleWord and JustifySingleWords then begin
    BreakChar := ZeroWidthSpace;
    LineText := Line.WordWithZeroWidthSpaces;
  end else begin
    LineText := Line.Text;
    // If it's not a single line we need to justify, and then ask the line if it needs to be justified
    // (this is either a normal line, or a trailing line when justify trailing lines is turned on.)
    // If possible, draw normally and exit early
    if not Line.Justify then begin
      TextOut(Canvas.Handle, X, Y, PChar(LineText), Length(LineText));
      Exit;
    end;
  end;

  BreakSize := Canvas.TextWidth(BreakChar);
  OrigRounding := System.Math.GetRoundMode;
  try
    System.Math.SetRoundMode(rmNearest); // You can change this, but nearest (default rounding) looks best to me
    Words := SplitString(LineText, BreakChar);
    if Length(Words) <= 1 then begin
      TextOut(Canvas.Handle, X, Y, PChar(LineText), Length(LineText));
    end else begin
      BreakAddition := SpaceToFill / Pred(Length(Words)); // Amount to add to each space/breakchar
      BreakAdditionInt := Round(BreakAddition);
      BreakFraction := (BreakAddition - BreakAdditionInt);

      AmountOff := 0;
      CurrentX := 0;
      for Index := Low(Words) to High(Words) do begin
        TextOut(Canvas.Handle, CurrentX, Y, PChar(Words[Index]), Length(Words[Index]));
        CurrentX := CurrentX + Canvas.TextWidth(Words[Index]);

        Space := BreakSize + BreakAdditionInt;
        // How far off where this should be is it?
        AmountOff := AmountOff + BreakFraction;
        // Maybe some of this can be added to the space for the next word
        AmountOffInt := Round(AmountOff);
        Space := Space + AmountOffInt;
        // Adjust for how much this changed the amount off (may have gone too far, eg if rounded up)
        AmountOff := AmountOff - AmountOffInt;

        // Finally, shift by the width (space is the break char width plus adjustment amount)
        CurrentX := CurrentX + Space;
      end;
    end;
  finally
    SetLength(Words, 0);
    System.Math.SetRoundMode(OrigRounding);
  end;
end;

procedure SplitLines(const Canvas : TCanvas; const Text : string; const Rect : TRect;
  const JustifyTrailingLines : Boolean; var Lines : TList<TLine>);
var
  LineText,
  RemainingText : string;
  Params : TDrawTextParams;
  LineRect : TRect;
  BreakChar : Char;
  IsTrailingLine : Boolean;
begin
  // Usually space, but depends on the font - see
  // http://msdn.microsoft.com/en-us/library/windows/desktop/dd145094(v=vs.85).aspx
  BreakChar := GetBreakChar(Canvas, nil);

  Params.cbSize := SizeOf(Params);
  Params.iTabLength := 8;
  Params.iLeftMargin := 0;
  Params.iRightMargin := 0;
  Params.uiLengthDrawn := 0;

  // Figure out how much of the text can be drawn as a single line, and the size in pixels it takes
  // to do so (drawing normally, ie left-aligned.) Repeat in sections until the string is fully
  // split. This gives each line, and the width of each line to add to the spaces in the line to
  // justify (that is, is the destination rect width minus how long the line would normally take up.)
  RemainingText := Text;
  while Length(RemainingText) > 0 do begin
    // So it can only fit a single line (don't use DT_SINGLELINE for this purpose - it draws the
    // whole thing, and doesn't break paragraphs)
    LineRect := Rect;
    LineRect.Height := 1;

    // Params.uiLengthDrawn is the number of characters it drew
    DrawTextEx(Canvas.Handle, PChar(RemainingText), Length(RemainingText), LineRect,
      DT_TOP or DT_LEFT or DT_WORDBREAK, @Params);

    // Justify all lines bar the last ones in a pragraph, unless JustifyTrailingLines = true in
    // which case just justify everything.
    LineText := Copy(RemainingText, 1, Params.uiLengthDrawn);
    // It's a trailing line if there's #13#10 (etc) at the end, or if it's the last line of the text
    // (ok to test that with length of line and remaining, not equality.)
    IsTrailingLine := EndsWithLineBreaks(LineText) or (Length(LineText) = Length(RemainingText));

    // Trim trailing spaces to the right of the text, because the width returned doesn't count
    // these and if they're left in the text, the justification breaks because space is added to them
    LineText := TrimRight(LineText);

    // Add this line. Justify unless it is a trailing line, or it is and have to justify everything
    // Use TextWidth to know how wide it is without justification (or could redraw a second time
    // using DT_CALCRECT, cannot modify LineRect in the call asking for the number of characters
    // and get the expected results. Interestingly TextWidth gives better results, DrawText can be
    // off by up to 2 pixels.)
    Lines.Add(TLine.Create(LineText, Canvas.TextWidth(LineText), BreakChar, IsTrailingLine,
      (not IsTrailingLine) or JustifyTrailingLines));

    // Update the remaining text for the next loop iteration
    RemainingText := Copy(RemainingText, Params.uiLengthDrawn+1, Length(RemainingText));
  end;
end;

procedure DrawLines(const Canvas : TCanvas; var Rect : TRect; const Lines : TList<TLine>;
  const MeasureOnly : Boolean; const ForceManual : Boolean; const JustifySingleWords : Boolean);
var
  LineHeight,
  Index : Integer;
  SupportsJustification : Boolean;
  BreakChar : Char;
  OrigBrushStyle : TBrushStyle;
begin
  LineHeight := Canvas.TextHeight('X');
  // See GetBreakChar - sometimes a font doesn't correctly specify the character it uses to separate
  // words. Segoe UI does this. In this case, GetBreakChar returns ' ' (space) but SetTextJustification
  // doesn't work, so have to use a manual method
  BreakChar := GetBreakChar(Canvas, @SupportsJustification);

  OrigBrushStyle := Canvas.Brush.Style;
  try
    // Don't let characters overlay other characters, eg when spacing out a single word
    Canvas.Brush.Style := bsClear;

    // Like DrawTextEx, can update the rect. Otherwise draw each line
    if MeasureOnly then
      Rect.Bottom := Rect.Top + Lines.Count * LineHeight
    else begin
      if SupportsJustification and not ForceManual then begin
        try
          for Index := 0 to Pred(Lines.Count) do begin
            // Use normal justification, but if it's a single word and need to justify single words
            // then for this line only, use the alternative method
            if Lines[Index].FIsSingleWord and JustifySingleWords then begin // Ignore .Justify, only aware of trailing line justification
              SetTextJustification(Canvas.Handle, 0, 0);
              ManualJustifyTextOut(Canvas, Rect.Left, Rect.Top + Index * LineHeight, Lines[Index],
                Rect.Width - Lines[Index].FLengthPx, BreakChar, JustifySingleWords);
            end else begin
              if Lines[Index].Justify then
                SetTextJustification(Canvas.Handle, Rect.Width - Lines[Index].FLengthPx,
                  Lines[Index].NumBreakChars)
              else
                SetTextJustification(Canvas.Handle, 0, 0);
              // TextOut uses the spacing set by SetTextJustification
              TextOut(Canvas.Handle, Rect.Left, Rect.Top + Index * LineHeight, PChar(Lines[Index].Text),
                Length(Lines[Index].Text));
            end;
          end;
        finally
          SetTextJustification(Canvas.Handle, 0, 0);
        end;
      end else begin
        // Font doesn't support justification (or ForceManual is true) - use a homebrewed method
        for Index := 0 to Pred(Lines.Count) do begin
          ManualJustifyTextOut(Canvas, Rect.Left, Rect.Top + Index * LineHeight, Lines[Index],
            Rect.Width - Lines[Index].FLengthPx, BreakChar, JustifySingleWords);
        end;
      end;
    end;
  finally
    Canvas.Brush.Style := OrigBrushStyle;
  end;
end;

procedure DrawTextJustified(const Canvas : TCanvas; const Text : string; var Rect : TRect;
  const Options : TDrawTextJustifiedOptions);
  //const JustifyTrailingLines : Boolean; const MeasureOnly : Boolean; const ForceManual : Boolean);
var
  Lines : TList<TLine>;
begin
  // To draw justified text, need to split into lines, each one of which can be drawn justified
  // SplitLines is paragraph-aware and tags the trailing lines of each paragraph, if JustifyTrailingLines
  // is false.
  Lines := TList<TLine>.Create;
  try
    SplitLines(Canvas, Text, Rect, (tjJustifyTrailingLines in Options), Lines);
    DrawLines(Canvas, Rect, Lines, (tjMeasureOnly in Options), (tjForceManual in Options),
      (tjJustifySingleWords in Options));
  finally
    Lines.Free;
  end;
end;

end.

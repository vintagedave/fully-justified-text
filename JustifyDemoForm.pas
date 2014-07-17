unit JustifyDemoForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls;

type
  TForm1 = class(TForm)
    memoTyping: TMemo;
    Panel1: TPanel;
    paintJustification: TPaintBox;
    chkJustifyTrailing: TCheckBox;
    lblRectHeight: TLabel;
    chkDrawRect: TCheckBox;
    btnFont: TButton;
    dlgFont: TFontDialog;
    chkManual: TCheckBox;
    lblTypeHeading: TLabel;
    lblPreviewHeading: TLabel;
    lblManualExplanation: TLabel;
    lblManualUsed: TLabel;
    procedure memoTypingChange(Sender: TObject);
    procedure paintJustificationPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure chkInvalidateClick(Sender: TObject);
    procedure btnFontClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  JustifiedDrawText;

function SupportsJustification(const Canvas : TCanvas) : Boolean;
var
  Metrics : TTextMetric;
  SupportsJustification : Boolean;
begin
  // This is actually decided inside the JustifiedDrawText unit, but to keep encapsulation for
  // demo UI purposes it's rewritten here. Normally there is no need to know which method the
  // unit internally decides to use.
  GetTextMetrics(Canvas.Handle, Metrics);
  // "tmBreakChar: The value of the character that will be used to define word breaks for text justification."
  // - http://msdn.microsoft.com/en-us/library/windows/desktop/dd145132(v=vs.85).aspx
  // But some fonts, such as Segoe UI (!), define this as #13 - a line break.
  // Check if it is a character that takes up space onscreen, and if not return the space char
  Result := Canvas.TextWidth(Metrics.tmBreakChar) > 0;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  // If set in the VCL designer, adds line breaks in the middle of paragraphs.
  memoTyping.Lines.Text := 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod '
    + 'tempor incididunt ut labore et dolore magna aliqua.'
    + #13#10
    + 'Ut enim ad minim veniam, quis nostrud '
    + 'exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.'
    + #13#10
    + 'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla '
    + 'pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt '
    + 'mollit anim id est laborum.';

  Panel1.DoubleBuffered := true; // Otherwise paintbox flickers sometimes
end;

procedure TForm1.memoTypingChange(Sender: TObject);
begin
  paintJustification.Invalidate; // user has typed; repaint the preview
end;

procedure TForm1.btnFontClick(Sender: TObject);
begin
  dlgFont.Font.Assign(memoTyping.Font);
  if dlgFont.Execute then begin
    memoTyping.Font.Assign(dlgFont.Font);
    paintJustification.Invalidate; // Pepaint to update preview
  end;
end;

procedure TForm1.chkInvalidateClick(Sender: TObject);
begin
  paintJustification.Invalidate; // Repaint to show result of this setting
end;

procedure TForm1.paintJustificationPaint(Sender: TObject);
var
  Rect : TRect;
  Options : TDrawTextJustifiedOptions;
begin
  paintJustification.Canvas.Font.Assign(memoTyping.Font);
  paintJustification.Canvas.Brush.Color := clWindow;
  paintJustification.Canvas.Brush.Style := bsSolid;
  paintJustification.Canvas.FillRect(paintJustification.ClientRect);

  Options := [];
  if chkJustifyTrailing.Checked then
    Options := Options + [tjJustifyTrailingLines];
  if chkManual.Checked then
    Options := Options + [tjForceManual];

  // Paint
  Rect := paintJustification.ClientRect;
  DrawTextJustified(paintJustification.Canvas, memoTyping.Lines.Text, Rect, Options);
  // And measure, to update the label and draw a faint rectangle to indicate
  DrawTextJustified(paintJustification.Canvas, memoTyping.Lines.Text, Rect, Options + [tjMeasureOnly]);

  lblRectHeight.Caption := 'Rect height: ' + IntToStr(Rect.Height) + 'px';
  if chkDrawRect.Checked then begin // Draw an outline indicating the returned rect
    paintJustification.Canvas.Pen.Color := clSkyBlue;
    paintJustification.Canvas.Pen.Width := 1;
    paintJustification.Canvas.Pen.Style := psSolid;
    paintJustification.Canvas.Brush.Style := bsClear;
    paintJustification.Canvas.Rectangle(Rect);
  end;

  lblManualUsed.Caption := 'Automatically used for this font: ' +
    BoolToStr(not SupportsJustification(paintJustification.Canvas), true);
end;

end.

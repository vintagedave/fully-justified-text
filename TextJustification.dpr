program TextJustification;

uses
  Vcl.Forms,
  JustifyDemoForm in 'JustifyDemoForm.pas' {Form1},
  JustifiedDrawText in 'JustifiedDrawText.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

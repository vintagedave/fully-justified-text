object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Full text justification in Delphi'
  ClientHeight = 441
  ClientWidth = 570
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object lblRectHeight: TLabel
    Left = 24
    Top = 359
    Width = 62
    Height = 13
    Caption = 'Rect height: '
  end
  object lblTypeHeading: TLabel
    Left = 8
    Top = 6
    Width = 60
    Height = 13
    Caption = 'Type here:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblPreviewHeading: TLabel
    Left = 287
    Top = 6
    Width = 204
    Height = 13
    Caption = '...and see fully-justified output here:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblManualExplanation: TLabel
    Left = 24
    Top = 393
    Width = 535
    Height = 26
    Caption = 
      'This is always automatically used in some circumstances: for som' +
      'e fonts, including Segoe UI; and in some cases for individual li' +
      'nes, such as when justifying single words (which is not supporte' +
      'd by the Windows API method.)'
    WordWrap = True
  end
  object lblManualUsed: TLabel
    Left = 24
    Top = 422
    Width = 140
    Height = 13
    Caption = 'Always used for this font: No'
  end
  object memoTyping: TMemo
    Left = 8
    Top = 22
    Width = 273
    Height = 243
    TabOrder = 0
    OnChange = memoTypingChange
  end
  object Panel1: TPanel
    Left = 287
    Top = 22
    Width = 277
    Height = 243
    BevelOuter = bvNone
    Color = clWindow
    ParentBackground = False
    TabOrder = 1
    object paintJustification: TPaintBox
      AlignWithMargins = True
      Left = 8
      Top = 4
      Width = 261
      Height = 235
      Margins.Left = 8
      Margins.Top = 4
      Margins.Right = 8
      Margins.Bottom = 4
      Align = alClient
      OnPaint = paintJustificationPaint
      ExplicitLeft = 88
      ExplicitTop = 80
      ExplicitWidth = 105
      ExplicitHeight = 105
    end
  end
  object chkJustifyTrailing: TCheckBox
    Left = 8
    Top = 302
    Width = 193
    Height = 17
    Caption = 'Justify trailing lines of paragraphs'
    TabOrder = 2
    OnClick = chkInvalidateClick
  end
  object chkDrawRect: TCheckBox
    Left = 8
    Top = 340
    Width = 122
    Height = 17
    Caption = 'Draw bounding rect'
    TabOrder = 3
    OnClick = chkInvalidateClick
  end
  object btnFont: TButton
    Left = 8
    Top = 271
    Width = 75
    Height = 25
    Caption = 'Font...'
    TabOrder = 4
    OnClick = btnFontClick
  end
  object chkManual: TCheckBox
    Left = 8
    Top = 375
    Width = 217
    Height = 17
    Caption = 'Always use manual justification method'
    TabOrder = 5
    OnClick = chkInvalidateClick
  end
  object chkJustifySingleWords: TCheckBox
    Left = 8
    Top = 321
    Width = 169
    Height = 17
    Caption = 'Justify (stretch) single words'
    TabOrder = 6
    OnClick = chkInvalidateClick
  end
  object dlgFont: TFontDialog
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    Left = 8
    Top = 216
  end
end

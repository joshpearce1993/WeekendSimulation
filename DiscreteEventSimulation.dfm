object FormSimulation: TFormSimulation
  Left = 0
  Top = 0
  Caption = 'Simulation'
  ClientHeight = 393
  ClientWidth = 617
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object LabelMaxBeds: TLabel
    Left = 115
    Top = 20
    Width = 127
    Height = 13
    Caption = 'Maximum Number of Beds:'
  end
  object LabelStartOccupation: TLabel
    Left = 11
    Top = 46
    Width = 231
    Height = 13
    Caption = 'Number of Occupied Beds at Start of Simulation:'
  end
  object LabelStartDischarge: TLabel
    Left = 73
    Top = 73
    Width = 169
    Height = 13
    Caption = 'Start of Discharge Interval (0..23):'
  end
  object LabelEndDischarge: TLabel
    Left = 79
    Top = 102
    Width = 163
    Height = 13
    Caption = 'End of Discharge Interval (1..24):'
  end
  object LabelReplications: TLabel
    Left = 128
    Top = 128
    Width = 114
    Height = 13
    Caption = 'Number of Replications:'
  end
  object EditMaxBeds: TEdit
    Left = 248
    Top = 17
    Width = 41
    Height = 21
    TabOrder = 0
    Text = '140'
  end
  object EditStartOccupation: TEdit
    Left = 248
    Top = 44
    Width = 41
    Height = 21
    TabOrder = 1
    Text = '120'
  end
  object EditStartDischarge: TEdit
    Left = 248
    Top = 71
    Width = 41
    Height = 21
    TabOrder = 2
    Text = '9'
  end
  object EditEndDischarge: TEdit
    Left = 248
    Top = 98
    Width = 41
    Height = 21
    TabOrder = 3
    Text = '17'
  end
  object ButtonLoadEdits: TButton
    Left = 129
    Top = 169
    Width = 161
    Height = 25
    Caption = 'Load Input Fields'
    TabOrder = 5
    OnClick = ButtonLoadEditsClick
  end
  object ButtonLoadFromFile: TButton
    Left = 129
    Top = 201
    Width = 161
    Height = 25
    Caption = 'Load Patient Data'
    TabOrder = 6
    OnClick = ButtonLoadFromFileClick
  end
  object ButtonRunSimulation: TButton
    Left = 128
    Top = 232
    Width = 161
    Height = 25
    Caption = 'Run the Simulation'
    TabOrder = 7
    OnClick = ButtonRunSimulationClick
  end
  object ButtonPlotOccupancy: TButton
    Left = 128
    Top = 263
    Width = 161
    Height = 25
    Caption = 'Plot Bed Occupancy'
    TabOrder = 8
    OnClick = ButtonPlotOccupancyClick
  end
  object ButtonReset: TBitBtn
    Left = 128
    Top = 294
    Width = 75
    Height = 25
    Caption = '&Reset'
    Kind = bkRetry
    NumGlyphs = 2
    TabOrder = 9
    OnClick = ButtonResetClick
  end
  object ButtonClose: TBitBtn
    Left = 214
    Top = 294
    Width = 75
    Height = 25
    Kind = bkClose
    NumGlyphs = 2
    TabOrder = 10
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 374
    Width = 617
    Height = 19
    Panels = <
      item
        Width = 50
      end
      item
        Width = 50
      end>
  end
  object CheckBoxSelectFile: TCheckBox
    Left = 9
    Top = 201
    Width = 114
    Height = 25
    Alignment = taLeftJustify
    Caption = 'Manually Select File'
    TabOrder = 12
  end
  object Memo: TMemo
    Left = 302
    Top = 0
    Width = 315
    Height = 374
    Align = alRight
    PopupMenu = PopupMenu
    ScrollBars = ssVertical
    TabOrder = 13
  end
  object EditReplications: TEdit
    Left = 248
    Top = 125
    Width = 41
    Height = 21
    TabOrder = 4
    Text = '1000'
  end
  object OpenDialogPatientData: TOpenDialog
    Left = 233
    Top = 325
  end
  object SaveDialogPerformanceData: TSaveDialog
    Left = 41
    Top = 157
  end
  object PopupMenu: TPopupMenu
    Left = 552
    Top = 184
    object Saveas1: TMenuItem
      Caption = '&Save as...'
      ShortCut = 16467
      OnClick = Saveas1Click
    end
  end
  object SaveDialogBlockedData: TSaveDialog
    Left = 40
    Top = 240
  end
  object SaveDialogDepartureData: TSaveDialog
    Left = 40
    Top = 288
  end
  object SaveDialogArrivalData: TSaveDialog
    Left = 120
    Top = 328
  end
end

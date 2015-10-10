unit DiscreteEventSimulation;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  AMRandom, MRNG, AMRandomRS, DataTypes, Vcl.StdCtrls, System.AnsiStrings,
  Math, Vcl.Buttons, Vcl.ComCtrls, Vcl.Menus;

type
  TFormSimulation = class(TForm)
    LabelMaxBeds: TLabel;
    LabelStartOccupation: TLabel;
    LabelStartDischarge: TLabel;
    LabelEndDischarge: TLabel;
    EditMaxBeds: TEdit;
    EditStartOccupation: TEdit;
    EditStartDischarge: TEdit;
    EditEndDischarge: TEdit;
    ButtonLoadEdits: TButton;
    ButtonLoadFromFile: TButton;
    ButtonRunSimulation: TButton;
    ButtonPlotOccupancy: TButton;
    OpenDialogPatientData: TOpenDialog;
    SaveDialogPerformanceData: TSaveDialog;
    ButtonReset: TBitBtn;
    ButtonClose: TBitBtn;
    StatusBar1: TStatusBar;
    CheckBoxSelectFile: TCheckBox;
    Memo: TMemo;
    PopupMenu: TPopupMenu;
    Saveas1: TMenuItem;
    EditReplications: TEdit;
    LabelReplications: TLabel;
    SaveDialogBlockedData: TSaveDialog;
    SaveDialogDepartureData: TSaveDialog;
    SaveDialogArrivalData: TSaveDialog;
    procedure ButtonLoadEditsClick(Sender: TObject);
    procedure ButtonLoadFromFileClick(Sender: TObject);
    procedure ButtonPlotOccupancyClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ButtonRunSimulationClick(Sender: TObject);
    procedure ButtonResetClick(Sender: TObject);
    procedure Saveas1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

  TStringArray = array of string;

procedure LoadInputFields;
function LoadDataFromFile(InputFile: TFileName): boolean;
function Explode(s, Border: string): TStringArray; // uses System.AnsiStrings
function GetNumberDays(a, b: integer): integer;
procedure MainSimulation;
procedure CreateStartingEvents;
procedure InitialPerformance;
procedure InitialScenario;
procedure SaveSimulationData;
procedure ClearSimulationData;
function CheckBedAvailability: boolean;
procedure AddPatient(Event: PEvent);
procedure RejectPatient(Event: PEvent);
function GetIntegerHour(Time: double): integer; // uses System.Math
procedure RemovePatient(Event: PEvent);
function CheckDeparture(AnEvent: PEvent): boolean;
function GetTimeDischargeStart(Event: PEvent): double;
procedure PerformanceCheck(Event: PEvent);
function CheckArrivalProbability(Event: PEvent): boolean;
procedure MutationOccupancy (Event: PEvent; MutationType: TMutationType);
function SaveDataToFile(InputFile: TFileName): boolean;
procedure ExportSimulationOutput;
procedure CullMutationArray;
function SaveRejectedAdmissionsToFile(InputFile: TFileName): boolean;
procedure ExportRejectedAdmissionsData;

var
  FormSimulation: TFormSimulation;

  {InputFieldsLoaded is a booelean variable, where:
  True = The input fields have sucessfully loaded (only accepts integer values)
  False = The input file has not yet been successfully loaded}
  InputFieldsLoaded: boolean;

  {InputFileLoaded is a booelean variable, where:
  True = The input file has been successfully loaded
  False = The input file has not yet been successfully loaded}
  InputFileLoaded: boolean;

  {RunSimulation is a boolean variable, where:
  True = Simulation has successfully run;
  False = Simulation has not yet successfuly run.}
  RunSimulation: boolean;

  {DischargePeriod is a boolean variable, where:
  True = Currently within the discharge period;
  False = Currently not within the discharge period.}
  DischargePeriod: boolean;

  AggregatePerformance: array of TPerformanceData;
  NumberOfReplications: integer;

implementation

{$R *.dfm}

uses GraphOccupation;

function SaveDataToFile(InputFile: TFileName): boolean;
{
This function saves the performance to an external file.
}
var
  F: TextFile;
  i, j, OccupationCounter: integer;
begin
  Result := false;
  // AssignFile initialises file F and names it InputFile
  AssignFile(F, InputFile);
  try
    ReWrite(F);
  except
    ShowMessage('File is in use by another program');
    exit;
  end;

  for i := 0 to High(AggregatePerformance) do
  begin
    // Write indexes for every mutation during the simulation
    for j := 0 to High(AggregatePerformance[i].MutationArray) do
    begin
      // Check if the entry is zero
      if (AggregatePerformance[i].MutationArray[j] = 0) then
        break;
      // Check for departure
      if (AggregatePerformance[i].MutationArray[j] < 0) then
      begin
        Write(F, FloatToStr(-1 * AggregatePerformance[i].MutationArray[j])
        + ';');
      end
      else
      // Check for arrival
      begin
        Write(F, FloatToStr(AggregatePerformance[i].MutationArray[j]) + ';');
      end;
    end;
    WriteLn(F); // Next line
    // Obtain the starting value of occupied beds
    OccupationCounter := Scenario.NumberStartOccupation;

    //  Write occupation for every mutation during the simulation
    for j := 0 to High(AggregatePerformance[i].MutationArray) do
    begin
      // Check if entry is zero
      if (AggregatePerformance[i].MutationArray[j]= 0) then
        break;
      // Check for departure
      if (AggregatePerformance[i].MutationArray[j] < 0) then
      begin
        OccupationCounter := OccupationCounter -1;
        Write(F, IntToStr(OccupationCounter + 1) + ';');
      end
      else
      // Check for arrival
      begin
        OccupationCounter := OccupationCounter + 1;
        Write(F, IntToStr(OccupationCounter - 1) + ';');
      end;
    end;
    WriteLn(F);
  end;

  // Close the file
  CloseFile(F);

  // Prompt when completed
  FormSimulation.StatusBar1.Panels[1].Text := 'File Saved!';
  //ShowMessage('File Saved!');
  Result := True;
end;

function SaveRejectedAdmissionsToFile(InputFile: TFileName): boolean;
{
This function saves the rejected admissions data to an external file.
}
var
  F: TextFile;
  i, j: integer;
begin
  Result := False;
  // AssignFile initialises file F and names it InputFile
  AssignFile(F, InputFile);
  try
    ReWrite(F);
  except
    ShowMessage('File is in use by another program');
    exit;
  end;

  // Write the rejected admission data to a file
  for i := 0 to High(AggregatePerformance) do
  begin
    for j := 0 to High(AggregatePerformance[i].BlockedDayHour) do
    begin
      write(F, IntToStr(AggregatePerformance[i].BlockedDayHour[j]) + ';');
    end;
    WriteLn(F);
  end;

  // Close the file
  CloseFile(F);
  Result := True;
end;

procedure TFormSimulation.ButtonResetClick(Sender: TObject);
{
This procedure sets the edits back to the default values when the
reset button is clicked.
}
begin
  EditMaxBeds.Text := '140';
  EditStartOccupation.Text := '120';
  EditStartDischarge.Text := '9';
  EditEndDischarge.Text := '17';
  EditReplications.Text := '1000';
  // Set the focus to the MaxBeds edit after the reset button is clicked
  EditMaxBeds.SetFocus;
  // Clear the content of the memo once the reset button is clicked
  Memo.Clear;
end;

procedure TFormSimulation.ButtonPlotOccupancyClick(Sender: TObject);
{
Creates a graph of the occuation when ButtonPlotOccupancy is clicked.
}
var
  PictureForm: TFormGraphOccupation; // Form that displays a graph of results
begin
  try
    PictureForm := TFormGraphOccupation.Create(self); // Create an object
    PictureForm.ShowModal; // Shows the form
  finally
    FreeAndNil(PictureForm); // Free the form on closure
  end;

  // Add some statistical results to the memo
  Memo.Lines.Add('Descriptive statistics:');
  Memo.Lines.Add('The mean bed occupation of this simulation = ' +
  FloatToStr(mean(MeanOccupancyArray)));
  Memo.Lines.Add('The minimum bed occupation during this simulation = ' +
  FloatToStr(MinValue(MeanOccupancyArray)));
  Memo.Lines.Add('The maximum bed occupation during this simulation = ' +
  FloatToStr(MaxValue(MeanOccupancyArray)));
  Memo.Lines.Add('The standard deviation of the mean occupation = ' +
  FloatToStr(StdDev(MeanOccupancyArray)));

  // Add a blank line to the memo so the text is spread out
  Memo.Lines.Add('');

end;


procedure TFormSimulation.ButtonLoadEditsClick(Sender: TObject);
{
Call the LoadInputFields procedure when the "Load Input Fields" button
is clicked.
}
begin
  // Call the LoadInputFields procedure
  LoadInputFields;

  // Once the button is clicked, write the input fields to the memo
  Memo.Lines.Add('The following input fields were loaded:');
  Memo.Lines.Add('The maximum number of beds is ' + EditMaxBeds.Text);
  Memo.Lines.Add('The starting occupation is ' + EditStartOccupation.Text);
  Memo.Lines.Add('The discharge period is between ' + EditStartDischarge.Text +
  ':00' + ' and ' + EditEndDischarge.Text + ':00');
  Memo.Lines.Add('The number of replications is ' + EditReplications.Text);

  // Add a blank line to the memo so the text is spread out
  Memo.Lines.Add('');
end;

procedure LoadInputFields;
{
Loads the data that the user inputs into the edit boxes
}
begin
  InputFieldsLoaded := True; // Set global variable to true

  // Produce error message if NumberReplications is not an integer
  if not (TryStrToInt(FormSimulation.EditReplications.Text,
  Scenario.NumberReplications)) then
  begin
    ShowMessage('Number of replications is invalid, please use an integer');
    InputFieldsLoaded := False;
  end;

  // Produce error message if NumberStartOccupation is not an integer
  if not(TryStrToInt(FormSimulation.EditStartOccupation.Text,
    Scenario.NumberStartOccupation)) then
  begin
    ShowMessage
      ('Occupied number of beds input is not valid, please use an integer');
    InputFieldsLoaded := False;
  end;

  // Produce error message if MaxBeds is not an integer
  if not(TryStrToInt(FormSimulation.EditMaxBeds.Text, Scenario.MaxBeds)) then
  begin
    ShowMessage
      ('Maximum number of beds input is not valid, please use an integer');
    InputFieldsLoaded := False;
  end;

  // Produce error message if StartDischargePeriod is not an integer
  if not(TryStrToInt(FormSimulation.EditStartDischarge.Text,
    Scenario.StartDischargePeriod)) then
  begin
    ShowMessage
      ('Starting hour of discharge period is not valid, please use an integer');
    InputFieldsLoaded := False;
  end;

  // Produce error message if StopDischargePeriod is not an integer
  if not(TryStrToInt(FormSimulation.EditEndDischarge.Text,
    Scenario.StopDischargePeriod)) then
  begin
    ShowMessage
      ('Stopping hour of discharge period is not valid, please use an integer');
    InputFieldsLoaded := False;
  end;
  {
  // Produce error message if StopDischargePeriod is not an integer
  if not(TryStrToInt(FormSimulation.EditDischargeTime.Text,
    Scenario.TimeNeededForDischarge)) then
  begin
    ShowMessage
      ('Time taken to discharge a patient is not valid, please use an integer');
    InputFieldsLoaded := False;
  end;
  }
end;

function ImportDischargeTime(InputFile: TFileName): boolean;
var
  F: TextFile;
  line, section: string;
  cells: TStringArray;
  i: integer;
begin
 // AssignFile initialises file F and names it InputFile
  AssignFile(F, InputFile);
  section := '';

  // Result=True if the file can be used, Result=False if already in use
  Result := True;
  try
    Reset(F);
  except
    Showmessage('File is in use by another program');
    Result := False;
    exit;
  end;

 while not EoF(F) do // End of File (EoF)
  begin
    Readln(F, line);
    cells := explode(line, ';');

    // Check information from the input csv file
    if (Length(cells) > 0) then
    begin
      SetLength(Scenario.DischargeTimeArray, Length(cells));
      for i := 0 to High(cells) do
      begin
        Scenario.DischargeTimeArray[i] := StrToInt(cells[i]);
      end;
    end;
end;
end;

function GetNumberDays(a, b: integer): integer;
{
Returns the number of days in the simulation (maximum is a week, i.e. 7 days),
a is the start day.
}
begin
  if (a < b) then
    Result := b - (a - 1)
  else if (a = b) then
    Result := 1
  else
    Result := (b + 7) - (a - 1);
end;

procedure TFormSimulation.ButtonLoadFromFileClick(Sender: TObject);
{
When the "Load Patient Data" button is clicked, this procedure loads an
external excel file consisting of the patient data. However, if the input
fields have not yet been loaded, an error message will appear.
}
var FileDirectory: string;
begin

  // Specify the file directory
  FileDirectory := ExtractFilePath(Application.ExeName);

  // Set the default patient data which is located in the file directory
  FormSimulation.OpenDialogPatientData.FileName :=
  FileDirectory + 'InputBaseModel.csv';

  // If the input fields have been successfuly loaded, begin
  if (InputFieldsLoaded) then
  begin
    if NOT(CheckBoxSelectFile.Checked) OR
    (FormSimulation.OpenDialogPatientData.Execute) then
      LoadDataFromFile(FormSimulation.OpenDialogPatientData.FileName);
  end
  // Else, display a message promtping the input fields to be loaded
  else
    Showmessage('First load the input fields, then load the patient data');

  // Write to the memo whether a manual or defualt input file was loaded
  if CheckBoxSelectFile.Checked then
  begin
    Memo.Lines.Add('A manually selected input file was loaded');
  end
  else
  begin
    Memo.Lines.Add('The default input file was loaded');
  end;

  // Add a blank line to the memo so the text is spread out
  Memo.Lines.Add('');

end;

procedure TFormSimulation.ButtonRunSimulationClick(Sender: TObject);
{
Runs the main simulation procedure when ButtonRunSimulation is clicked.
}
begin
  // If the patient data is loaded, run the simualtion
  if InputFileLoaded then
  begin
    // Call the MainSimulation procedure
    MainSimulation;
    // Set the boolean variable to true if the simulation is run
    RunSimulation := True;
  end
  // Else, display a message prompting the patient data to be loaded
  else
    ShowMessage('First load the patient data, then run the simulation');
end;

procedure CreateStartingEvents;
{
This procedure creates the seed events.
}
var
   i, j, ArrivalType: integer;
   Time1, Time2, RandomNumber: double;
begin
  // Determine the time, and subtract by one minute
  Time1 := Scenario.StartTime - (1/1440); // 24 x 60 = 1440

  // Add StopSimulation to event list
  AddEvent(GetEvent(Scenario.StopTime, StopSimulation));

  // Fill beds and draw LoS for every patient
  // Add departure to event list for every patient
  for i := 1 to Scenario.NumberStartOccupation do
  begin
    // Initialise
    RandomNumber := random();
    ArrivalType := -1;

    for j := 0 to high(Scenario.PatientTypes) do
    begin
      if (RandomNumber < ((j + 1) / Length(Scenario.PatientTypes))) then
      begin
        ArrivalType := j;
        break;
      end;
    end;
    Time2 := random();

    // Now we know the type of arrival, get the LoS distribution

    // If Gamma distribution
    if (Scenario.PatientTypes[ArrivalType].LOSDistName = 'gamma') then
    begin
      Time1 := (Scenario.PatientTypes[ArrivalType].scale *
      Random_Gamma(Scenario.PatientTypes[ArrivalType].shape));
      // Random_Gamma declared in AMRandom
      // LoS is in hours, so multiply by 60
    end
    // Else, if Exponential distribution
    else if (Scenario.PatientTypes[ArrivalType].LOSDistName = 'exponential')
    then
    begin
      Time1 := Random_Exponential / (Scenario.PatientTypes[ArrivalType].shape);
      // Random_Exponential declared in AMRandom
    end
    else
    // Produce an error message if not gamma or exponential distribution
    begin
      Showmessage
        ('LOS distribution not defined, only gamma and exp is implemented');
      asm int 3
      end;
    end;

    {
    // If discharge has a gamma distribution
    if (Scenario.PatientTypes[ArrivalType].DischargeDistName = 'gamma') then
    begin
      Time3 := (Scenario.PatientTypes[ArrivalType].DischargeScale *
      Random_Gamma(Scenario.PatientTypes[ArrivalType].DischargeShape));
    end
    // Else, produce an error message if not gamma distribution
    else
    begin
      ShowMessage
        ('Discharge distribution is not defined, only gamma is implemented');
      asm int 3
      end;
    end;
    }

    // Determine the reamining time
    Time1 := Time1 * Time2;

    // Add the event
    AddEvent(GetEvent(Scenario.StartTime + Time1, PatientTreated));
  end;
end;

procedure InitialPerformance;
{
Determine the initial values for the following parameters:
MutationArray, NumberMutations, PatientsReadyToLeave, WardOccupation,
ArrivalsDayHour, BlockedDayHour, DepartureDayHour.
}
begin
  // Clear the performance data
  PerformanceData.Clear;
  SetLength(PerformanceData.MutationArray, 1);

  // Set the initial values for the number of mutuations
  PerformanceData.NumberMutations := 0;

  // Set the initial value for the number of patients ready to leave
  PerformanceData.PatientsReadyToLeave := 0;

  // Define the initial ward occupation
  PerformanceData.CurrentWardOccupation := Scenario.NumberStartOccupation;

  // Dimension the performance data
  SetLength(PerformanceData.WardOccupation,
  1 + GetIntegerHour(Scenario.StopTime));
  SetLength(PerformanceData.ArrivalsDayHour,
  1 + GetIntegerHour(Scenario.StopTime));
  SetLength(PerformanceData.BlockedDayHour,
  1 + GetIntegerHour(Scenario.StopTime));
  SetLength(PerformanceData.DepartureDayHour,
  1 + GetIntegerHour(Scenario.StopTime));
end;

procedure InitialScenario;
{
Determine the following initial parameters: StartTime, StopTime,
PoissonHourlyArrivalRates, MaxPossionRate and TimeNeededForDischarge.
}
var
  i, j: integer;
begin
  // Set the start time of the simulation at 12pm
  Scenario.StartTime := 0.5;

  // Determine the stop time
  Scenario.StopTime := Scenario.StartTime
  + (Length(Scenario.PoissonHourlyArrivalRates) / 24);

  // Determine the total hourly arrival rates
  for i := 0 to High(Scenario.PoissonHourlyArrivalRates) do
    for j := 0 to High(Scenario.PatientTypes) do
      Scenario.PoissonHourlyArrivalRates[i] :=
      Scenario.PoissonHourlyArrivalRates[i]
      + Scenario.PatientTypes[j].lambda[i];

  // Determine the maximum arrival rate variable
  Scenario.MaxPoissonRate := -1;
  for i := 0 to High(Scenario.PoissonHourlyArrivalRates) do
    if (Scenario.MaxPoissonRate < Scenario.PoissonHourlyArrivalRates[i]) then
      Scenario.MaxPoissonRate := Scenario.PoissonHourlyArrivalRates[i];

  // Set the time needed for discharge as the mean time taken to discharge
  Scenario.TimeNeededForDischarge
  := Scenario.PatientTypes[0].DischargeMean / 24;

end;

procedure MainSimulation;
{
This is the main discrete event simulation procedure.
}
var
  AnEvent: PEvent;
  NextArrival, NextTime: double;
  NumberReplications, TimeInteger, i: integer;
begin
  // Assuming data is loaded, call initial scenario and performance procedures
  InitialScenario;
  InitialPerformance;

  // For the number of replications, do the simulation
  for NumberReplications := 1 to Scenario.NumberReplications do
  begin
    // Set the seed
    // MRandSeed declared in MRNG
    MRandSeed(12345 + NumberReplications);

    // Seed the CreateStartingEvents event
    AddEvent(GetEvent(Scenario.StartTime, StartSimulation));

    // Add the first arrival event (self referencing)
    AddEvent(GetEvent(Scenario.StartTime, PatientArrival));

    // While not at the end of time, do simulation
    while True do
    begin
      AnEvent := NextEvent;

      // Temporary check
      if (AnEvent.Time > AnEvent.Next.Time) then
        asm int 3
        end;

      case AnEvent.EventType of

        // Start the simulation
        StartSimulation:
          begin
            // Create the seed events
            CreateStartingEvents;
          end;

        // Stop the simulation
        StopSimulation:
          begin
            // Save the simulation data
            SaveSimulationData;
            // Clear all memory
            ClearSimulationData;
            // Break the while loop
            break;
          end;

        // When a patient arrives
        PatientArrival:
          begin
            // Check if the arrival is accepted
            // Account for modified arrival rate in simulation
            if (CheckArrivalProbability(AnEvent)) then
            begin
              // Check the bed occupancy
              if (CheckBedAvailability) then
              // If there is space available, then begin
              begin
                // Add a patient to the system
                AddPatient(AnEvent);
                // Save the arrival time
                MutationOccupancy(AnEvent, Arrival);
              end
              else
              // Else, if there is no space available, begin
              begin
                // Reject patient and update performance
                RejectPatient(AnEvent);
              end;
            end;

            NextArrival := Random_Exponential;
            NextArrival := NextArrival / Scenario.MaxPoissonRate;
            NextArrival := NextArrival / 24;

            // Create a follow up event
            AddEvent(GetEvent(NextArrival
            + AnEvent.Time, PatientArrival));
          end;

        // When a patient is treated
        PatientTreated:
          begin
            // Check if patient is ready to depart
            if (CheckDeparture(AnEvent)) then
            // If no patient is ready to depart at the moment
            begin
              if (PerformanceData.PatientsReadyToLeave = 0) then
              begin
                // RemovePatient(AnEvent); // If yes
                // MutationOccupancy(AnEvent, Departure);
                // Increment counter
                PerformanceData.PatientsReadyToLeave := 1;
                // Get earliest time patient is ready to be discharged
                NextTime := AnEvent.Time + (Scenario.TimeNeededForDischarge);
                // Add event to the event list
                AddEvent(GetEvent(NextTime, PatientDeparture));
              end
              else
              begin
                // Patient may depart, but others already queued
                PerformanceData.PatientsReadyToLeave :=
                  PerformanceData.PatientsReadyToLeave + 1;
              end;
            end
            else
            begin // If no patients are ready to leave
              if (PerformanceData.PatientsReadyToLeave = 0) then
              begin
                // Increment counter
                PerformanceData.PatientsReadyToLeave := 1;
                // Get earliest time patient is ready to be discharged
                NextTime := GetTimeDischargeStart(AnEvent);
                // Add event to the event list
                AddEvent(GetEvent(NextTime, PatientDeparture));
              end
              else
              // Else, if there are patients that are ready to depart
              begin
                // Increment counter
                PerformanceData.PatientsReadyToLeave :=
                PerformanceData.PatientsReadyToLeave + 1;
              end;
            end;
          end;

        // When a patient is discharged
        PatientDeparture:
          begin
            // Discharge a patient
            RemovePatient(AnEvent);
            MutationOccupancy(AnEvent, Departure);

            // Remove one patient from the ready to leave counter
            PerformanceData.PatientsReadyToLeave :=
            PerformanceData.PatientsReadyToLeave - 1;

            if (PerformanceData.PatientsReadyToLeave < 0) then
              asm int 3
              end;

            TimeInteger := GetIntegerHour(AnEvent.Time);

            if (PerformanceData.PatientsReadyToLeave > 0) then
            begin
              // Check if future patient may still depart
              if (AnEvent.Time + (Scenario.TimeNeededForDischarge) -
                Floor(AnEvent.Time)) < (Scenario.StopDischargePeriod / 24) then
              begin
                AddEvent(GetEvent(AnEvent.Time +
                Scenario.TimeNeededForDischarge, PatientDeparture));
              end
              else
              // Else, add event tomorrow at start of discharge period
              begin
                  if (StrToInt(FormSimulation.EditStartDischarge.Text) <> 0)
                  and (StrToInt(FormSimulation.EditEndDischarge.Text) <> 0) then
                  begin
                    // Add event at time today + 1 + start of discharge period
                    AddEvent(GetEvent(Floor(AnEvent.Time) + 1 +
                    (Scenario.StartDischargePeriod / 24), PatientDeparture));
                  end
                  else
                    for i := TimeInteger to High(Scenario.DischargeTimeArray) do
                    begin
                      if Scenario.DischargeTimeArray[GetIntegerHour(AnEvent.Time)] = 1 then
                      begin
                        Scenario.StartDischargePeriod := i;
                        break;
                      end;
                    AddEvent(GetEvent(GetIntegerHour(AnEvent.Time) +
                    (Scenario.StartDischargePeriod / 24), PatientDeparture));
                    end;
              end;
            end;
          end;


        // Update the performance
        UpdatePerformance:
          begin
            // Check the occupation
            PerformanceCheck(AnEvent);
          end;

      end; // End of case AnEvent.EventType

      // Remove event
      RemoveEvent(AnEvent);
    end; // End of while loop

    // Clean up performance data and restart
    InitialPerformance;

  end; // end for NumberofReplications

  // Export the output of the simulation to a csv file
  ExportSimulationOutput;

  // Export the rejected admissions data to a csv file
  ExportRejectedAdmissionsData;

  // Dispose of all the deleted events
  ClearMemory(DeletedEventList);

end;

procedure MutationOccupancy(Event: PEvent; MutationType: TMutationType);
{
If there is an arrival or departure, save the time into performance array.
}
begin
  // Increment number of mutations
  PerformanceData.NumberMutations := PerformanceData.NumberMutations + 1;

  // Last entry contains data, so increase size and save data
  if (length(PerformanceData.MutationArray)
  < PerformanceData.NumberMutations) then
  begin
    // Double the length and round down
    SetLength(PerformanceData.MutationArray,
    Floor(Length(PerformanceData.MutationArray) * 2));
    // Save the time
    if (MutationType = Arrival) then
      PerformanceData.MutationArray[PerformanceData.NumberMutations - 1]
      := Event.Time
    else
      PerformanceData.MutationArray[PerformanceData.NumberMutations - 1]
      := Event.Time * -1;
    end
  // If length is sufficient
  else
  begin
    // Save the time
    if (MutationType = Arrival) then
      PerformanceData.MutationArray[PerformanceData.NumberMutations - 1]
      := Event.Time
    else
      PerformanceData.MutationArray[PerformanceData.NumberMutations - 1]
      := Event.Time * -1
  end;
end;

function CheckArrivalProbability(Event: PEvent): boolean;
{
This function checks if there is an arrival,
used as NextArrival uses highest arrival.
}
var
  TimeInteger: integer;
  RandomNumber, AcceptanceProbability: double;
begin
  // Determine the integer time
  TimeInteger := GetIntegerHour(Event.Time);

  // Obtain a random number
  RandomNumber := random();

  // Obtain the acceptance probability
  AcceptanceProbability := Scenario.PoissonHourlyArrivalRates[TimeInteger] /
  Scenario.MaxPoissonRate;

  if (RandomNumber <= AcceptanceProbability) then
    Result := True
  else
    Result := False;
end;

procedure PerformanceCheck(Event: PEvent);
{
This procedure writes the performance data.
}
var
  TimeInteger: integer;
begin
  // Determine the integer time
  TimeInteger := GetIntegerHour(Event.Time);

  // Sets ward occupation as the curent occupation
  PerformanceData.WardOccupation[TimeInteger]
  := PerformanceData.CurrentWardOccupation;
end;

function GetTimeDischargeStart(Event: PEvent): double;
{
This function obtains the time of the next starting discharge period
}
var
  StartTime, StopTime, Time: double;
begin
  // Determine start and stop time
  StartTime := Scenario.StartDischargePeriod / 24;
  StopTime := Scenario.StopDischargePeriod / 24;

  // Get the remainder, i.e. the time of day
  Time := Event.Time - Floor(Event.Time);

  if (Time < StartTime) then
    Result := Floor(Event.Time) + StartTime
  else if (Time > StopTime) then
    Result := Floor(Event.Time) + 1 + StartTime
  else
  begin
    Result := Event.Time; // Shouldn't happen!
    asm int 3
    end; // Time of event does take place during discharge period
  end;
end;

function CheckDeparture(AnEvent: PEvent): boolean;
{
This function checks whether patient can depart or not.
}
var
  Time, Start, Stop: double;
begin
  // Determine the remainder i.e. the time of day
  Time := AnEvent.Time - Floor(AnEvent.Time);

  // Determine the start time of discharge
  Start := Scenario.StartDischargePeriod / 24;

  // Determine the stop time of discharge
  Stop := Scenario.StopDischargePeriod / 24;

  if (Start < Time)  and (Time < Stop) then
    Result := True
  else
    Result := False;
end;

procedure AddPatient(Event: PEvent);
{
This procedure adds a patient to the data.
}
var
  i, TimeInteger, ArrivalType: integer;
  Time, RandomNumber, counter: double;
begin
  // Determine the integer time
  TimeInteger := GetIntegerHour(Event.Time);

  // Since a patient is added, update the ward occupation
  PerformanceData.CurrentWardOccupation
  := PerformanceData.CurrentWardOccupation + 1;

  // Add arrival to the performance array
  PerformanceData.ArrivalsDayHour[TimeInteger]
  := PerformanceData.ArrivalsDayHour[TimeInteger] + 1;

  // Determine the type of arrival
  RandomNumber := random();
  ArrivalType  := -1;
  counter      := 0;
  for i := 0 to High(Scenario.PatientTypes) do
  begin
    counter := counter + (Scenario.PatientTypes[i].lambda[TimeInteger] /
            Scenario.PoissonHourlyArrivalRates[TimeInteger]);
    if (RandomNumber < counter) then
    begin
      ArrivalType := i;
      break;
    end;
  end;

  // Now we know the type of arrival, get the LoS distribution

  // If gamma distribution
  Time := 0;
  if (Scenario.PatientTypes[ArrivalType].LOSDistName = 'gamma') then
  begin
    Time := (Scenario.PatientTypes[ArrivalType].scale *
    Random_Gamma(Scenario.PatientTypes[ArrivalType].shape));
  end
  // Else if Exponential distribution
  else if (Scenario.PatientTypes[ArrivalType].LOSDistName = 'exponential') then
  begin
    Time := Random_Exponential / (Scenario.PatientTypes[ArrivalType].shape);
  end
  // Else, produce an error message if not gamma or exponential distribution
  else
  begin
    ShowMessage
    ('LoS distribution not defined, only gamma and exp is implemented');
    asm int 3
    end;
  end;

  {
  // If discharge has a gamma distribution
  Time := 0;
  if (Scenario.PatientTypes[ArrivalType].DischargeDistName = 'gamma') then
  begin
    Time := (Scenario.PatientTypes[ArrivalType].DischargeScale *
    Random_Gamma(Scenario.PatientTypes[ArrivalType].DischargeShape));
  end
  // Else, produce an error message if not gamma distribution
  else
  begin
    ShowMessage
    ('Discharge distribution not defined, only gamma is implemented');
    asm int 3
    end;
  end;
  }

  // Use the LoS to add an event to event list at the current time + LoS
  AddEvent(GetEventWithString(Time + Event.Time, PatientTreated,
  Event.PatientSpeciality));

end;

procedure RejectPatient(Event: PEvent);
{
This procedure rejects a patient from being admitted to a ward.
}
var
  TimeInteger: integer;
begin
  // Determine the integer time
  TimeInteger := GetIntegerHour(Event.Time);

  // Add the rejection to the performance array
  PerformanceData.BlockedDayHour[TimeInteger] :=
  PerformanceData.BlockedDayHour[TimeInteger] + 1;
end;

procedure RemovePatient(Event: PEvent);
{
This procedure removes a patient from the data to free a bed.
}
var
  TimeInteger: integer;
begin
  // Determine the integer time
  TimeInteger := GetIntegerHour(Event.Time);

  // Removes one patient so the ward occupation is reduced by 1
  PerformanceData.CurrentWardOccupation
  := PerformanceData.CurrentWardOccupation - 1;

  // Since a patient has been removed, add 1 to the departures
  PerformanceData.DepartureDayHour[TimeInteger] :=
  PerformanceData.DepartureDayHour[TimeInteger] + 1;
end;

function GetIntegerHour(time: double): integer;
{
Takes the time of an event and determines the hour it takes place.
For example, if time is 5.5 hours after the start, this function returns 5.
}
var
  TimeLapsed: double;
begin
  // Determine the time from the start
  TimeLapsed := Time - Scenario.StartTime;
  // TDateTime is measured in days, so convert to hours
  TimeLapsed := TimeLapsed * 24;
  // Return the rounded down integer as the result
  Result := Floor(TimeLapsed);
end;

function CheckBedAvailability: boolean;
{
This function returns whether or not there are available beds, where:
True = At least one bed is available;
False = The beds have reached full capacity.
}
begin
  if (performancedata.CurrentWardOccupation < Scenario.MaxBeds) then
    Result := True
  else
    Result := False;
end;

procedure ClearSimulationData;
{
This procedure frees all of the memory allocation.
}
begin
  while EventList <> nil do
    RemoveEvent(NextEvent);
end;

procedure SaveSimulationData;
{
This procedure saves the data of the simulation run.
}
begin
  // Cull the mutation array of performance data
  CullMutationArray;
  // Increment length
  SetLength(AggregatePerformance, Length(AggregatePerformance) + 1);
  // Copy all performance data
  AggregatePerformance[High(AggregatePerformance)] := PerformanceData;
end;

procedure CullMutationArray;
begin
  SetLength(PerformanceData.MutationArray,PerformanceData.NumberMutations);
end;

procedure TFormSimulation.FormCreate(Sender: TObject);
begin
  InputFieldsLoaded := False;
end;

procedure TFormSimulation.Saveas1Click(Sender: TObject);
begin
  Memo.Lines.SaveToFile(ExtractFilePath(Application.ExeName)+'logfile.txt');
  Memo.Lines.Add('Logfile saved');
end;

function LoadDataFromFile(InputFile: TFileName): boolean;
{
Loads the arrival rates and patient information. Using rates the length of
simulation is also known.
}
var
  F: TextFile; // F is a file variable consiting of text information
  section, line: string;
  cells: TStringArray;
  i, NumberPatientType: integer;
begin
  // AssignFile initialises file F and names it InputFile
  AssignFile(F, InputFile);
  section := '';

  // Result=True if the file can be used, Result=False if already in use
  Result := True;
  try
    Reset(F);
  except
    Showmessage('File is in use by another program');
    Result := False;
    exit;
  end;

  // Initialise
  NumberPatientType := 0;

  // Set the length of the PatientTypes string to 1
  SetLength(Scenario.PatientTypes, 1);

  while not EoF(F) do // End of File (EoF)
  begin
    Readln(F, line);
    cells := explode(line, ';');

    // Check information from the input csv file
    if (Length(cells) > 0) then
    begin
      // Consider the medical speciality, denoted 'type' in the csv file
      if (cells[0] = 'MedicalSpeciality') then
      begin
        Scenario.PatientTypes[NumberPatientType].PatientType := cells[1];
      end
      // Consider the distribution of the LoS, denoted 'dist' in the csv file
      else if (cells[0] = 'LoSDistribution') then
      begin
          Scenario.PatientTypes[NumberPatientType].LOSDistName := cells[1];
      end
      // Consider the mean LoS, denoted 'mean' in the csv file
      else if (cells[0] = 'MeanLoS') then
      begin
        Scenario.PatientTypes[NumberPatientType].mean := StrToFloat(cells[1]);
      end
      // Consider the shape of the LoS, denoted 'shape' in the csv file
      else if ((cells[0] = 'Shape') and (Length(cells) > 1)) then
      begin
        Scenario.PatientTypes[NumberPatientType].shape := StrToFloat(cells[1]);
      end
      // Consider the scale of the LoS, denoted 'scale' in the csv file
      else if ((cells[0] = 'Scale') and (Length(cells) > 1)) then
      begin
        Scenario.PatientTypes[NumberPatientType].scale := StrToFloat(cells[1]);
      end
      else if cells[0] = 'Lambda' then
      // Add the entire entry array
      begin
        SetLength(Scenario.PatientTypes[NumberPatientType].lambda, High(cells));
        for i := 1 to High(cells) do
        begin
          Scenario.PatientTypes[NumberPatientType].lambda[i - 1] :=
          StrToFloat(cells[i]);
        end;
      end
      // Consider the discharge distribution in the csv file
      else if (cells[0] = 'DischargeDistribution') then
      begin
        Scenario.PatientTypes[NumberPatientType].DischargeDistName := cells[1];
      end
      else if (cells[0] = 'DischargeMean') then
      begin
        Scenario.PatientTypes[NumberPatientType].DischargeMean
        := StrToFloat(cells[1]);
      end
      // Consider the shape of the discharge distribution in the csv file
      else if ((cells[0] = 'DischargeShape') and (Length(cells) > 1)) then
      begin
        Scenario.PatientTypes[NumberPatientType].DischargeShape
        := StrToFloat(cells[1]);
      end
      // Consider the scale of the discharge distribution in the csv file
      else if ((cells[0] = 'DischargeScale') and (Length(cells) > 1)) then
      begin
        Scenario.PatientTypes[NumberPatientType].DischargeScale
        := StrToFloat(cells[1]);
      end;
    end
    else if (Length(cells)) = 0 then
    begin
      NumberPatientType := NumberPatientType + 1;
      SetLength(Scenario.PatientTypes, Length(Scenario.PatientTypes) + 1);
    end;
  end; // End of the while loop

  CloseFile(F); // Close the file

  // Check other information such as length of simulation etc
  for i := 0 to High(Scenario.PatientTypes) - 1 do
  begin
    if (Length(Scenario.PatientTypes[i].lambda) <>
      Length(Scenario.PatientTypes[i + 1].lambda)) then
    begin
      Showmessage
        ('Number of arrival rates for different patient types do not match');
      asm int 3
      end;
    end;
  end;

  // Set number of Poisson arrivals as number of lambda values in csv file
  SetLength(Scenario.PoissonHourlyArrivalRates,
  Length(Scenario.PatientTypes[0].lambda));

  // If successfully loaded, set the boolean variable as true
  InputFileLoaded := True;

end;

function Explode(s, Border: string): TStringArray;
{
Split the string s into an array, where the border is the seperator.
}
var
  SubString: string;
  i: integer;
begin
  // Initialising
  s := s + Border;
  SetLength(Result, 0);

  // Split the string S
  repeat
    SubString := Copy(s, 0, Pos(Border, s) - 1);
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := SubString;
    Delete(s, 1, Length(SubString + Border));
  until s = '';

  // Remove the empty cells at the end of the array
  i := High(Result);
  while (Length(Result) > 0) and (Result[i] = '') do
  begin
    SetLength(Result, Length(Result) - 1);
    i := i - 1;
  end;

  // Replace dots with commas
  for i := 0 to High(Result) do
    Result[i] := ReplaceText(Result[i], '.', ',');
end;

procedure ExportSimulationOutput;
{
This procedure exports the result of the simulation, saving it as a csv file.
}
begin
  // Allow .csv file types to be saved
  FormSimulation.SaveDialogPerformanceData.Filter
  := 'Csv file|*.csv';

  // Set the default extension of the saved file as csv
  FormSimulation.SaveDialogPerformanceData.DefaultExt := 'csv';

  {If the file name of the created external file already exists, ask the user
  whether they would like to overwrite the existing file}
  FormSimulation.SaveDialogPerformanceData.Options :=
  FormSimulation.SaveDialogPerformanceData.Options + [ofOverwritePrompt];

  // Save the simulation output file using a timestamp
  FormSimulation.SaveDialogPerformanceData.FileName
  := 'Results ' + FormatDateTime('dd-mm-yyyy hh.nn', Now);

  // Write the data to an external file
  if (FormSimulation.SaveDialogPerformanceData.Execute) then
    SaveDataToFile(FormSimulation.SaveDialogPerformanceData.FileName);
end;

procedure ExportRejectedAdmissionsData;
begin
  // Allow .csv file types to be saved
  FormSimulation.SaveDialogBlockedData.Filter
  := 'Csv file|*.csv';

  // Set the default extension of the saved file as csv
  FormSimulation.SaveDialogBlockedData.DefaultExt := 'csv';

  {If the file name of the created external file already exists, ask the user
  whether they would like to overwrite the existing file}
  FormSimulation.SaveDialogBlockedData.Options :=
  FormSimulation.SaveDialogBlockedData.Options + [ofOverwritePrompt];

  // Save the simulation output file using a timestamp
  FormSimulation.SaveDialogBlockedData.FileName
  := 'Rejected Admissions ' + FormatDateTime('dd-mm-yyyy hh.nn', Now);

  // Write the data to an external file
  if (FormSimulation.SaveDialogBlockedData.Execute) then
    SaveRejectedAdmissionsToFile(FormSimulation.SaveDialogBlockedData.FileName);
end;

initialization

finalization

// Release all memory
  Scenario.Clear;
  Performancedata.Clear;
  SetLength(AggregatePerformance, 0);

  // Clear memory of event list
  ClearMemory(EventList);

end.

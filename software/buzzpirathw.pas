unit buzzpirathw;

// By Dreg, Based from arduinohw

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, basehw, msgstr, utilfunc, Dialogs;

type
  TBhlI2CInit        = function(com_name: pchar; power: integer; pullups: integer; khz: integer; just_i2c_scanner: integer): integer; stdcall;
  TBhlI2CClose       = function:integer; stdcall;
  TBhlI2CGetMemaux   = function:pbyte; stdcall;
  TBhlI2CReadWrite   = function(devaddr: integer; bufflen: integer; buffer: PByteArray; length: integer): integer; stdcall;
  TBhlI2CStart       = function:integer; stdcall;
  TBhlI2CStop        = function:integer; stdcall;
  TBhlI2CReadByte    = function:integer; stdcall;
  TBhlI2CWriteByte   = function(byte_val: integer): integer; stdcall;
{ TBuzzpiratHardware }

TBuzzpiratHardware = class(TBaseHardware)
private
  FDevOpened: boolean;
  FStrError: string;
  BhlI2CInit: TBhlI2CInit;
  BhlI2CClose: TBhlI2CClose;
  BhlI2CGetMemaux: TBhlI2CGetMemaux;
  BhlI2CReadWrite: TBhlI2CReadWrite;
  BhlI2CStart: TBhlI2CStart;
  BhlI2CStop: TBhlI2CStop;
  BhlI2CReadByte: TBhlI2CReadByte;
  BhlI2CWriteByte: TBhlI2CWriteByte;

public
  constructor Create;
  destructor Destroy; override;

  function GetLastError: string; override;
  function DevOpen: boolean; override;
  procedure DevClose; override;

  //spi
  function SPIRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer; override;
  function SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer; override;
  function SPIInit(speed: integer): boolean; override;
  procedure SPIDeinit; override;

  //I2C
  procedure I2CInit; override;
  procedure I2CDeinit; override;
  function I2CReadWrite(DevAddr: byte;
                        WBufferLen: integer; WBuffer: array of byte;
                        RBufferLen: integer; var RBuffer: array of byte): integer; override;
  procedure I2CStart; override;
  procedure I2CStop; override;
  function I2CReadByte(ack: boolean): byte; override;
  function I2CWriteByte(data: byte): boolean; override; //return ack

  //MICROWIRE
  function MWInit(speed: integer): boolean; override;
  procedure MWDeinit; override;
  function MWRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer; override;
  function MWWrite(CS: byte; BitsWrite: byte; buffer: array of byte): integer; override;
  function MWIsBusy: boolean; override;
end;

implementation

uses main;

constructor TBuzzpiratHardware.Create;
begin
  FHardwareName := 'Buzzpirat / Buspirate';
  FHardwareID := CHW_BUZZPIRAT;
end;

destructor TBuzzpiratHardware.Destroy;
begin
  DevClose;
end;

function TBuzzpiratHardware.GetLastError: string;
begin
    result := FStrError;
end;

function TBuzzpiratHardware.DevOpen: boolean;
var Handle: THandle;
  khz: integer;
  pullups: integer;
  power: integer;
  just_i2c_scanner: integer;
  memaux: pbyte;
  i2c_info: string;
  len: integer;
  FCOMPort: string;
begin
  if FDevOpened then DevClose;

  FDevOpened := false;

  if MainForm.RadioI2C.Checked = false then
  begin
    LogPrint('only I2C is supported yet');
    Exit(false);
  end;

  FCOMPort := main.Buzzpirat_COMPort;

  if FCOMPort = '' then
  begin
    FStrError:= 'No port selected!';
    Exit(false);
  end;

  Handle := LoadLibrary('buzzpirathlp.dll');
  if Handle <> 0 then
  begin
    BhlI2CInit           := TBhlI2CInit(GetProcAddress(Handle, 'bhl_asprog_i2c_init'));
    BhlI2CClose          := TBhlI2CClose(GetProcAddress(Handle, 'bhl_asprog_i2c_close'));
    BhlI2CGetMemaux      := TBhlI2CGetMemaux(GetProcAddress(Handle, 'bhl_asprog_i2c_get_memaux'));
    BhlI2CReadWrite      := TBhlI2CReadWrite(GetProcAddress(Handle, 'bhl_asprog_i2c_readwrite'));
    BhlI2CStart          := TBhlI2CStart(GetProcAddress(Handle, 'bhl_asprog_i2c_start'));
    BhlI2CStop           := TBhlI2CStop(GetProcAddress(Handle, 'bhl_asprog_i2c_stop'));
    BhlI2CReadByte       := TBhlI2CReadByte(GetProcAddress(Handle, 'bhl_asprog_i2c_read_byte'));
    BhlI2CWriteByte      := TBhlI2CWriteByte(GetProcAddress(Handle, 'bhl_asprog_i2c_write_byte'));
    if (BhlI2CInit = nil) or (BhlI2CClose = nil) or (BhlI2CGetMemaux = nil) or
    (BhlI2CReadWrite = nil) or (BhlI2CStart = nil) or (BhlI2CStop = nil) or
    (BhlI2CReadByte = nil) or (BhlI2CWriteByte = nil) then
    begin
       FStrError:= 'buzzpirathlp.dll bad symbols';
       Exit(false);
    end;
  end
  else
  begin
       FStrError:= 'buzzpirathlp.dll not found';
       Exit(false);
  end;

  just_i2c_scanner := 0;
  khz := 0;
  pullups := 0;
  power := 0;

  if MainForm.MenuBuzzpiratI2C5KHz.Checked then
  begin
       LogPrint('5khz');
       khz := 5;
  end
  else if MainForm.MenuBuzzpiratI2C50KHz.Checked then
  begin
       LogPrint('50khz');
       khz := 50;
  end
  else if MainForm.MenuBuzzpiratI2C100KHz.Checked then
  begin
       LogPrint('100khz');
       khz := 100;
  end;

  if MainForm.MenuBuzzpiratPower.Checked then
  begin
       LogPrint('Power ON');
       power := 1;
  end;

  if MainForm.MenuBuzzpiratPullups.Checked then
  begin
       LogPrint('Pull-ups ON');
       pullups := 1;
  end;

  if MainForm.MenuBuzzpiratJustI2CScan.Checked then
  begin
       LogPrint('JUST I2C SCANNER');
       just_i2c_scanner := 1;
  end;

  LogPrint('keep pressing ESC key to cancel... keep pressing F1 to relaunch this console... ASProgrammer GUI will be unresponsive while BUS PIRATE is operating. BUS PIRATE is slow, please be (very) patient');

  if BhlI2CInit(PChar(FCOMPort), power, pullups, khz, just_i2c_scanner) <> 1 then
  begin
    LogPrint('I2C Init fail');
    Exit(false);
  end;

  if just_i2c_scanner = 1 then
  begin
    memaux := BhlI2CGetMemaux();

    len := 0;
    while memaux[len] <> 0 do
        Inc(len);
    SetString(i2c_info, PChar(memaux), len);
    ShowMessage(i2c_info);
    LogPrint(i2c_info);
    BhlI2CClose();
    Exit(false);
  end;

  FDevOpened := true;
  Result := true;
end;

procedure TBuzzpiratHardware.DevClose;
begin
  if FDevOpened then BhlI2CClose();
  FDevOpened := false;
end;


//SPI___________________________________________________________________________

function TBuzzpiratHardware.SPIInit(speed: integer): boolean;
var buff: byte;
begin
  if not FDevOpened then Exit(false);

  LogPrint('Not Implemented Yet');
  Exit(false);
end;

procedure TBuzzpiratHardware.SPIDeinit;
var buff: byte;
begin
  if not FDevOpened then Exit;

  LogPrint('Not Implemented Yet');
  Exit;
end;

function TBuzzpiratHardware.SPIRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer;
var buff:  byte;
    bytes: integer;
const chunk = 64;
begin
  if not FDevOpened then Exit(-1);

  LogPrint('Not Implemented Yet');
  Exit(-1);
end;

function TBuzzpiratHardware.SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer;
var buff: byte;
    bytes: integer;
const chunk = 256;
begin
  if not FDevOpened then Exit(-1);

  LogPrint('Not Implemented Yet');
  Exit(-1);
end;

//i2c___________________________________________________________________________

procedure TBuzzpiratHardware.I2CInit;
begin
  if not FDevOpened then Exit;
end;

procedure TBuzzpiratHardware.I2CDeinit;
begin
  if not FDevOpened then Exit;
end;

function TBuzzpiratHardware.I2CReadWrite(DevAddr: byte;
                        WBufferLen: integer; WBuffer: array of byte;
                        RBufferLen: integer; var RBuffer: array of byte): integer;
var
  sMessage: pbyte;
  i: Integer;
begin
  if not FDevOpened then Exit(-1);

  if RBufferLen > 0 then FillChar(RBuffer, RBufferLen - 1, 105);

  if BhlI2CReadWrite(DevAddr, RBufferLen, @WBuffer[0], WBufferLen) <> 1 then
  begin
    LogPrint('Error BhlI2CReadWrite');
    Exit(-1);
  end;

  sMessage := BhlI2CGetMemaux();

  for i := 0 to RBufferLen - 1 do
    RBuffer[i] := sMessage[i];
  result := RBufferLen + WBufferLen;
end;

procedure TBuzzpiratHardware.I2CStart;
begin
  if not FDevOpened then Exit;

  if BhlI2CStart() <> 1 then
  begin
    LogPrint('Error BhlI2CStart');
    Exit;
  end;
end;

procedure TBuzzpiratHardware.I2CStop;
begin
  if not FDevOpened then Exit;

  if BhlI2CStop() <> 1 then
  begin
    LogPrint('Error BhlI2CStop');
    Exit;
  end;
end;

function TBuzzpiratHardware.I2CReadByte(ack: boolean): byte;
var
  Status: byte;
begin
  if not FDevOpened then Exit;

  if BhlI2CReadByte() <> 1 then
  begin
    LogPrint('Error BhlI2CReadByte');
    Exit(0);
  end;

  result := BhlI2CGetmemaux()[0];
end;

function TBuzzpiratHardware.I2CWriteByte(data: byte): boolean;
var
  Status: byte;
begin
  if not FDevOpened then Exit;

  if BhlI2CWriteByte(data) <> 1 then
    begin
      LogPrint('Error BhlI2CWriteByte');
      Exit(false);
    end;

  Exit(true);
end;

//MICROWIRE_____________________________________________________________________

function TBuzzpiratHardware.MWInit(speed: integer): boolean;
var buff: byte;
begin
  if not FDevOpened then Exit(false);

  LogPrint('Not Implemented Yet');
  Exit(false);
end;

procedure TBuzzpiratHardware.MWDeInit;
var buff: byte;
begin
  if not FDevOpened then Exit;

  LogPrint('Not Implemented Yet');
  Exit;
end;

function TBuzzpiratHardware.MWRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer;
var buff:  byte;
    bytes: integer;
const chunk = 64;
begin
  if not FDevOpened then Exit(-1);

  LogPrint('Not Implemented Yet');
  Exit(-1);
end;

function TBuzzpiratHardware.MWWrite(CS: byte; BitsWrite: byte; buffer: array of byte): integer;
var buff: byte;
    bytes: byte;
const chunk = 32;
begin
  if not FDevOpened then Exit(-1);

  LogPrint('Not Implemented Yet');
  Exit(-1);
end;

function TBuzzpiratHardware.MWIsBusy: boolean;
var
  buff: byte;
begin
  LogPrint('Not Implemented Yet');
  Exit(false);
end;




end.


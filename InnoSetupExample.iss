[Files]
Source: "TrackerPlayback.dll"; DestDir: "{tmp}"; Flags: dontcopy
Source: "music\intro.xm"; DestDir: "{tmp}"; Flags: dontcopy

[Code]
#include "InnoSetupTrackerPlayback.iss.inc"

procedure StartInstallerMusic();
var
  ModulePath: String;
begin
  ExtractTemporaryFile('intro.xm');

  ModulePath := ExpandConstant('{tmp}\intro.xm');
  if TrackerPlayback_Inno_PlayFile(ModulePath, 1) = 0 then
  begin
    Log(Format('Tracker playback failed. Error code: %d', [TrackerPlayback_Inno_GetLastErrorCode()]));
  end;
end;

procedure StopInstallerMusic();
begin
  if TrackerPlayback_Inno_GetStatus() <> TRACKER_PLAYBACK_STATUS_STOPPED then
  begin
    TrackerPlayback_Inno_Stop();
  end;
end;

procedure InitializeWizard();
begin
  StartInstallerMusic();
end;

procedure DeinitializeSetup();
begin
  StopInstallerMusic();
end;

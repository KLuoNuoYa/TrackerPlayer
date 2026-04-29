const
  TRACKER_PLAYBACK_STATUS_STOPPED = 0;
  TRACKER_PLAYBACK_STATUS_PLAYING = 1;
  TRACKER_PLAYBACK_STATUS_PAUSED = 2;

  TRACKER_PLAYBACK_INNO_ERROR_NONE = 0;
  TRACKER_PLAYBACK_INNO_ERROR_INVALID_ARGUMENT = 1;
  TRACKER_PLAYBACK_INNO_ERROR_ALREADY_ACTIVE = 2;
  TRACKER_PLAYBACK_INNO_ERROR_OUT_OF_MEMORY = 3;
  TRACKER_PLAYBACK_INNO_ERROR_FILE_OPEN_FAILED = 4;
  TRACKER_PLAYBACK_INNO_ERROR_FILE_TOO_LARGE = 5;
  TRACKER_PLAYBACK_INNO_ERROR_FILE_READ_FAILED = 6;
  TRACKER_PLAYBACK_INNO_ERROR_PLAYBACK_START_FAILED = 7;
  TRACKER_PLAYBACK_INNO_ERROR_INVALID_STATE = 8;
  TRACKER_PLAYBACK_INNO_ERROR_ENGINE_FAILURE = 100;

function TrackerPlayback_Inno_PlayFile(ModulePath: String; LoopForever: Integer): Integer;
  external 'TrackerPlayback_Inno_PlayFile@files:TrackerPlayback.dll stdcall loadwithalteredsearchpath';
function TrackerPlayback_Inno_Stop(): Integer;
  external 'TrackerPlayback_Inno_Stop@files:TrackerPlayback.dll stdcall loadwithalteredsearchpath';
function TrackerPlayback_Inno_Pause(): Integer;
  external 'TrackerPlayback_Inno_Pause@files:TrackerPlayback.dll stdcall loadwithalteredsearchpath';
function TrackerPlayback_Inno_Resume(): Integer;
  external 'TrackerPlayback_Inno_Resume@files:TrackerPlayback.dll stdcall loadwithalteredsearchpath';
function TrackerPlayback_Inno_GetStatus(): Integer;
  external 'TrackerPlayback_Inno_GetStatus@files:TrackerPlayback.dll stdcall loadwithalteredsearchpath';
function TrackerPlayback_Inno_GetLastErrorCode(): Integer;
  external 'TrackerPlayback_Inno_GetLastErrorCode@files:TrackerPlayback.dll stdcall loadwithalteredsearchpath';

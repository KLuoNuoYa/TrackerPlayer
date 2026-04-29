#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(TRACKERPLAYBACK_EXPORTS)
#define TRACKER_PLAYBACK_CALL __cdecl
#define TRACKER_PLAYBACK_API __declspec(dllexport)
#else
#define TRACKER_PLAYBACK_CALL
#define TRACKER_PLAYBACK_API
#endif

#define TRACKER_PLAYBACK_INNO_CALL __stdcall

typedef enum TrackerPlaybackStatus {
    TRACKER_PLAYBACK_STATUS_STOPPED = 0,
    TRACKER_PLAYBACK_STATUS_PLAYING = 1,
    TRACKER_PLAYBACK_STATUS_PAUSED = 2
} TrackerPlaybackStatus;

typedef enum TrackerPlaybackInnoError {
    TRACKER_PLAYBACK_INNO_ERROR_NONE = 0,
    TRACKER_PLAYBACK_INNO_ERROR_INVALID_ARGUMENT = 1,
    TRACKER_PLAYBACK_INNO_ERROR_ALREADY_ACTIVE = 2,
    TRACKER_PLAYBACK_INNO_ERROR_OUT_OF_MEMORY = 3,
    TRACKER_PLAYBACK_INNO_ERROR_FILE_OPEN_FAILED = 4,
    TRACKER_PLAYBACK_INNO_ERROR_FILE_TOO_LARGE = 5,
    TRACKER_PLAYBACK_INNO_ERROR_FILE_READ_FAILED = 6,
    TRACKER_PLAYBACK_INNO_ERROR_PLAYBACK_START_FAILED = 7,
    TRACKER_PLAYBACK_INNO_ERROR_INVALID_STATE = 8,
    TRACKER_PLAYBACK_INNO_ERROR_ENGINE_FAILURE = 100
} TrackerPlaybackInnoError;

typedef void (TRACKER_PLAYBACK_CALL *TrackerPlaybackErrorCallback)(const char* message);
typedef void (TRACKER_PLAYBACK_CALL *TrackerPlaybackStatusCallback)(TrackerPlaybackStatus oldStatus, TrackerPlaybackStatus newStatus);

TRACKER_PLAYBACK_API void TRACKER_PLAYBACK_CALL TrackerPlayback_SetErrorCallback(TrackerPlaybackErrorCallback callback);
TRACKER_PLAYBACK_API void TRACKER_PLAYBACK_CALL TrackerPlayback_SetStatusCallback(TrackerPlaybackStatusCallback callback);
TRACKER_PLAYBACK_API TrackerPlaybackStatus TRACKER_PLAYBACK_CALL TrackerPlayback_GetStatus(void);
TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_CALL TrackerPlayback_Play(const void* xmData, size_t xmDataSize, int loopForever);
TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_CALL TrackerPlayback_Stop(void);
TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_CALL TrackerPlayback_Pause(void);
TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_CALL TrackerPlayback_Resume(void);

TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_PlayFile(const wchar_t* modulePath, int loopForever);
TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_Stop(void);
TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_Pause(void);
TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_Resume(void);
TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_GetStatus(void);
TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_GetLastErrorCode(void);

#ifdef __cplusplus
}
#endif

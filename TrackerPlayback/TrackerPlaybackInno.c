#include "TrackerPlaybackInternal.h"
#include <stdint.h>
#include <strsafe.h>

#if defined(_WIN64)
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_PlayFile")
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_Stop")
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_Pause")
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_Resume")
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_GetStatus")
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_GetLastErrorCode")
#else
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_PlayFile=_TrackerPlayback_Inno_PlayFile@8")
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_Stop=_TrackerPlayback_Inno_Stop@0")
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_Pause=_TrackerPlayback_Inno_Pause@0")
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_Resume=_TrackerPlayback_Inno_Resume@0")
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_GetStatus=_TrackerPlayback_Inno_GetStatus@0")
#pragma comment(linker, "/EXPORT:TrackerPlayback_Inno_GetLastErrorCode=_TrackerPlayback_Inno_GetLastErrorCode@0")
#endif

static void SetInnoErrorState(int errorCode, const char* message) {
    EnsureStateInitialized();
    EnterCriticalSection(&_playbackState.lock);
    _playbackState.lastErrorCode = errorCode;
    if (message && message[0] != '\0') {
        StringCchCopyA(_playbackState.lastErrorMessage, TRACKER_PLAYBACK_LAST_ERROR_MESSAGE_CAPACITY, message);
    } else {
        _playbackState.lastErrorMessage[0] = '\0';
    }
    LeaveCriticalSection(&_playbackState.lock);
}

static void SetInnoErrorFromWin32(int errorCode, DWORD win32Error, const char* prefix) {
    CHAR message[TRACKER_PLAYBACK_LAST_ERROR_MESSAGE_CAPACITY] = { 0 };
    CHAR systemMessage[TRACKER_PLAYBACK_LAST_ERROR_MESSAGE_CAPACITY] = { 0 };
    DWORD formatResult;

    if (!prefix) {
        prefix = "Operation failed";
    }

    formatResult = FormatMessageA(
        FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL,
        win32Error,
        0,
        systemMessage,
        (DWORD) TRACKER_PLAYBACK_LAST_ERROR_MESSAGE_CAPACITY,
        NULL);

    if (formatResult == 0) {
        StringCchPrintfA(
            message,
            TRACKER_PLAYBACK_LAST_ERROR_MESSAGE_CAPACITY,
            "%s. Win32 error %lu.",
            prefix,
            (unsigned long) win32Error);
    } else {
        StringCchPrintfA(
            message,
            TRACKER_PLAYBACK_LAST_ERROR_MESSAGE_CAPACITY,
            "%s. %s",
            prefix,
            systemMessage);
    }

    SetInnoErrorState(errorCode, message);
}

TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_PlayFile(const wchar_t* modulePath, int loopForever) {
    HANDLE fileHandle = INVALID_HANDLE_VALUE;
    LARGE_INTEGER fileSize;
    BYTE* moduleData = NULL;
    DWORD bytesRead = 0;
    size_t moduleSize;
    int playResult;

    if (!modulePath || modulePath[0] == L'\0') {
        SetInnoErrorState(TRACKER_PLAYBACK_INNO_ERROR_INVALID_ARGUMENT, "The module path is empty.");
        return 0;
    }

    fileHandle = CreateFileW(modulePath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (fileHandle == INVALID_HANDLE_VALUE) {
        SetInnoErrorFromWin32(TRACKER_PLAYBACK_INNO_ERROR_FILE_OPEN_FAILED, GetLastError(), "Failed to open the tracker module file");
        return 0;
    }

    if (!GetFileSizeEx(fileHandle, &fileSize)) {
        SetInnoErrorFromWin32(TRACKER_PLAYBACK_INNO_ERROR_FILE_READ_FAILED, GetLastError(), "Failed to query the tracker module file size");
        CloseHandle(fileHandle);
        return 0;
    }

    if (fileSize.QuadPart <= 0) {
        SetInnoErrorState(TRACKER_PLAYBACK_INNO_ERROR_FILE_READ_FAILED, "The tracker module file is empty.");
        CloseHandle(fileHandle);
        return 0;
    }

    if ((ULONGLONG) fileSize.QuadPart > (ULONGLONG) SIZE_MAX || (ULONGLONG) fileSize.QuadPart > (ULONGLONG) UINT32_MAX) {
        SetInnoErrorState(TRACKER_PLAYBACK_INNO_ERROR_FILE_TOO_LARGE, "The tracker module file is too large to load into memory.");
        CloseHandle(fileHandle);
        return 0;
    }

    moduleSize = (size_t) fileSize.QuadPart;
    moduleData = (BYTE*) HeapAlloc(GetProcessHeap(), 0, moduleSize);
    if (!moduleData) {
        SetInnoErrorState(TRACKER_PLAYBACK_INNO_ERROR_OUT_OF_MEMORY, "Failed to allocate memory for the tracker module file.");
        CloseHandle(fileHandle);
        return 0;
    }

    if (!ReadFile(fileHandle, moduleData, (DWORD) moduleSize, &bytesRead, NULL) || bytesRead != (DWORD) moduleSize) {
        DWORD win32Error = GetLastError();
        if (win32Error == ERROR_SUCCESS) {
            SetInnoErrorState(TRACKER_PLAYBACK_INNO_ERROR_FILE_READ_FAILED, "Failed to read the full tracker module file into memory.");
        } else {
            SetInnoErrorFromWin32(TRACKER_PLAYBACK_INNO_ERROR_FILE_READ_FAILED, win32Error, "Failed to read the tracker module file");
        }
        HeapFree(GetProcessHeap(), 0, moduleData);
        CloseHandle(fileHandle);
        return 0;
    }

    CloseHandle(fileHandle);
    playResult = TrackerPlayback_Play(moduleData, moduleSize, loopForever);
    HeapFree(GetProcessHeap(), 0, moduleData);

    if (!playResult) {
        return 0;
    }

    SetInnoErrorState(TRACKER_PLAYBACK_INNO_ERROR_NONE, NULL);
    return 1;
}

TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_Stop(void) {
    return TrackerPlayback_Stop();
}

TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_Pause(void) {
    return TrackerPlayback_Pause();
}

TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_Resume(void) {
    return TrackerPlayback_Resume();
}

TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_GetStatus(void) {
    return (int) TrackerPlayback_GetStatus();
}

TRACKER_PLAYBACK_API int TRACKER_PLAYBACK_INNO_CALL TrackerPlayback_Inno_GetLastErrorCode(void) {
    int errorCode;

    EnsureStateInitialized();
    EnterCriticalSection(&_playbackState.lock);
    errorCode = _playbackState.lastErrorCode;
    LeaveCriticalSection(&_playbackState.lock);

    return errorCode;
}

#pragma once
#include <Windows.h>
#include "TrackerPlayback.h"
#include "libopenmpt.h"
#include "portaudio.h"

#define BUFFER_SIZE 480
#define SAMPLE_RATE 48000
#define TRACKER_PLAYBACK_LAST_ERROR_MESSAGE_CAPACITY 1024

typedef struct PlaybackState {
    CRITICAL_SECTION lock;
    int lockInitialized;
    HANDLE threadHandle;
    DWORD threadId;
    HANDLE stopEvent;
    HANDLE pauseEvent;
    openmpt_module* moduleHandle;
    void* moduleData;
    size_t moduleDataSize;
    PaStream* streamHandle;
    int paInitialized;
    int isInterleaved;
    int loopForever;
    int lastErrorCode;
    CHAR lastErrorMessage[TRACKER_PLAYBACK_LAST_ERROR_MESSAGE_CAPACITY];
    TrackerPlaybackStatus status;
    TrackerPlaybackErrorCallback errorCallback;
    TrackerPlaybackStatusCallback statusCallback;
} PlaybackState;

extern PlaybackState _playbackState;
extern void EnsureStateInitialized(void);

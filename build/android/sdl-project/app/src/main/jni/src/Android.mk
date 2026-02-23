LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := main

SDL_PATH := $(SDL2_SOURCE_DIR)

LOCAL_C_INCLUDES := $(SDL_PATH)/include

LOCAL_SRC_FILES := \
	$(SDL_PATH)/src/main/android/SDL_android_main.c \
	pyrogenesis_wrapper.cpp

LOCAL_SHARED_LIBRARIES := SDL2

LOCAL_LDLIBS := -lGLESv2 -llog -ldl

include $(BUILD_SHARED_LIBRARY)

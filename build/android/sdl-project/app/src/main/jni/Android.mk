LOCAL_PATH := $(call my-dir)
MY_LOCAL_PATH := $(LOCAL_PATH)

ifndef SDL2_SOURCE_DIR
$(error SDL2_SOURCE_DIR is not set. Pass -PSDL2_SOURCE_DIR=/path/to/SDL when invoking Gradle)
endif

SDL_PATH := $(SDL2_SOURCE_DIR)

include $(CLEAR_VARS)
include $(SDL_PATH)/Android.mk
LOCAL_PATH := $(MY_LOCAL_PATH)
include $(LOCAL_PATH)/src/Android.mk

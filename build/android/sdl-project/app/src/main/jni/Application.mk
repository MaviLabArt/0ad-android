APP_PLATFORM := android-24
APP_STL := c++_shared
APP_SUPPORT_FLEXIBLE_PAGE_SIZES := true
APP_LDFLAGS += -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384

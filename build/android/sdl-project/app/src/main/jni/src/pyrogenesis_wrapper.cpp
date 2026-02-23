#include <android/log.h>

#include <cerrno>
#include <cstdlib>
#include <dlfcn.h>
#include <jni.h>
#include <string>
#include <sys/stat.h>

#include "SDL.h" // sets up macro to wrap main()

namespace
{
const char* TAG = "pyrogenesis";
std::string g_AppRoot;

void EnsureDir(const std::string& path)
{
	if (path.empty())
		return;

	if (mkdir(path.c_str(), 0755) == 0 || errno == EEXIST)
		return;

	__android_log_print(ANDROID_LOG_WARN, TAG, "Failed to create directory %s (errno %d)", path.c_str(), errno);
}

void InitializeAppPaths(const std::string& appRoot)
{
	setenv("PYROGENESIS_ROOT", appRoot.c_str(), 1);

	// Keep the directory layout expected by source/ps/GameSetup/Paths.cpp.
	EnsureDir(appRoot);
	EnsureDir(appRoot + "/data");
	EnsureDir(appRoot + "/appdata");
	EnsureDir(appRoot + "/appdata/data");
	EnsureDir(appRoot + "/appdata/config");
	EnsureDir(appRoot + "/appdata/cache");
	EnsureDir(appRoot + "/appdata/logs");
}

void* OpenPyrogenesisLibrary()
{
	const std::string releaseLib = "libpyrogenesis.so";
	const std::string debugLib = "libpyrogenesis_dbg.so";

	std::string localReleaseLib;
	std::string localDebugLib;
	if (!g_AppRoot.empty())
	{
		localReleaseLib = g_AppRoot + "/" + releaseLib;
		localDebugLib = g_AppRoot + "/" + debugLib;
	}

	const char* candidates[] = {
		releaseLib.c_str(),
		debugLib.c_str(),
		localReleaseLib.empty() ? nullptr : localReleaseLib.c_str(),
		localDebugLib.empty() ? nullptr : localDebugLib.c_str()
	};

	for (const char* candidate : candidates)
	{
		if (!candidate)
			continue;

		__android_log_print(ANDROID_LOG_INFO, TAG, "Attempting to open %s", candidate);
		void* library = dlopen(candidate, RTLD_NOW | RTLD_GLOBAL);
		if (library)
			return library;

		__android_log_print(ANDROID_LOG_WARN, TAG, "Could not open %s (dlerror %s)", candidate, dlerror());
	}

	return nullptr;
}

void EnsureLibraryLoaded(const char* soname)
{
	void* library = dlopen(soname, RTLD_NOW | RTLD_GLOBAL);
	if (!library)
	{
		__android_log_print(ANDROID_LOG_WARN, TAG, "Could not open %s (dlerror %s)", soname, dlerror());
		return;
	}

	__android_log_print(ANDROID_LOG_INFO, TAG, "%s loaded", soname);
}
}

extern "C" JNIEXPORT void JNICALL Java_org_libsdl_app_SDLActivity_nativeSetAppRoot(
	JNIEnv* env,
	jclass /*clazz*/,
	jstring appRoot)
{
	if (!appRoot)
		return;

	const char* rootUtf8 = env->GetStringUTFChars(appRoot, nullptr);
	if (!rootUtf8)
		return;

	g_AppRoot = rootUtf8;
	env->ReleaseStringUTFChars(appRoot, rootUtf8);

	InitializeAppPaths(g_AppRoot);
	__android_log_print(ANDROID_LOG_INFO, TAG, "Using game root: %s", g_AppRoot.c_str());
}

int main(int argc, char* argv[])
{
	__android_log_print(ANDROID_LOG_INFO, TAG, "Started wrapper");
	EnsureLibraryLoaded("libSDL2.so");
	EnsureLibraryLoaded("libicudata.so");

	if (g_AppRoot.empty())
	{
		g_AppRoot = "/sdcard/0ad";
		InitializeAppPaths(g_AppRoot);
	}

	void* pyro = OpenPyrogenesisLibrary();
	if (!pyro)
	{
		__android_log_print(ANDROID_LOG_ERROR, TAG, "Failed to locate libpyrogenesis");
		return -1;
	}
	__android_log_print(ANDROID_LOG_INFO, TAG, "Library opened successfully");

	void* pyromain = dlsym(pyro, "pyrogenesis_main");
	if (!pyromain)
	{
		__android_log_print(ANDROID_LOG_ERROR, TAG, "Failed to load entry symbol (dlerror %s)", dlerror());
		return -1;
	}

	__android_log_print(ANDROID_LOG_INFO, TAG, "Launching engine code");
	const int code = ((int(*)(int, char*[]))pyromain)(argc, argv);
	__android_log_print(ANDROID_LOG_WARN, TAG, "Engine code returned with status %d", code);
	return code;
}

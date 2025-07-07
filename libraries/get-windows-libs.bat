rem **Download sources and binaries of libraries**

rem **SVN revision to checkout for windows-libs**
rem **Update this line when you commit an update to windows-libs**
set "svnrev=28256"

svn co https://svn.wildfiregames.com/public/windows-libs/trunk@%svnrev% win32 || ^
svn export --force https://svn.wildfiregames.com/public/windows-libs/trunk@%svnrev% win32

rem **Fixup SpiderMonkey for Windows 7 on Win32**
rem This change is performed separately to allow backporting to A27
set "smrev=28263"
if "%LIBS_PATH%" == "win32" (
    svn up -r %smrev% win32/spidermonkey/bin || ^
    svn export --force https://svn.wildfiregames.com/public/windows-libs/trunk/spidermonkey/bin@%smrev% win32/spidermonkey/bin || ^
    exit /b 1
)

rem **Copy dependencies' binaries to binaries/system/**

set DIR_LIST=boost enet fcollada fmt freetype gloox iconv icu libcurl libpng libsodium libxml2 microsoft miniupnpc nvtt openal sdl2 spidermonkey vorbis wxwidgets zlib
for %%d in (%DIR_LIST%) do (
    if exist win32\%%d\bin\ (
        copy /y win32\%%d\bin\* ..\binaries\system\
    )
)

rem **Copy build tools to build/bin

mkdir ..\build\bin\ 2>nul

set TOOLCHAIN_DIR_LIST=premake-core cxxtest-4.4
for %%d in (%TOOLCHAIN_DIR_LIST%) do (
    if exist win32\%%d\bin\ (
        copy /y win32\%%d\bin\* ..\build\bin\
    )
)

/* Copyright (C) 2025 Wildfire Games.
 * This file is part of 0 A.D.
 *
 * 0 A.D. is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * 0 A.D. is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with 0 A.D.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef INCLUDED_SCRIPTTYPES
#define INCLUDED_SCRIPTTYPES

#define JSGC_GENERATIONAL 1
#define JSGC_USE_EXACT_ROOTING 1

#ifdef DEBUG
#define MOZ_DIAGNOSTIC_ASSERT_ENABLED
#endif

#ifdef _WIN32
# define XP_WIN
# ifndef WIN32
#  define WIN32 // SpiderMonkey expects this
# endif
#endif

#include "jspubtd.h"
#include "jsapi.h"

#if MOZJS_MAJOR_VERSION != 128
#error Your compiler is trying to use an incorrect major version of the \
SpiderMonkey library. The SpiderMonkey API is subject to changes, and the \
game will not build with the selected version of the library. Make sure \
you have got all the right files and include paths.
#endif

class ScriptInterface;

#endif // INCLUDED_SCRIPTTYPES

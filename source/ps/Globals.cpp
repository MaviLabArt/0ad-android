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

#include "precompiled.h"

#include "Globals.h"

#include "lib/code_annotation.h"
#include "lib/external_libraries/libsdl.h"

#include <SDL_events.h>
#include <SDL_log.h>
#include <SDL_timer.h>
#include <SDL_video.h>

#if OS_ANDROID
#include <android/log.h>
#endif
#include <cstddef>

bool g_app_minimized = false;
bool g_app_has_focus = true;

std::unordered_map<int32_t, bool> g_scancodes;

int g_mouse_x = 50, g_mouse_y = 50;
bool g_mouse_active = true;

// g_mouse_buttons[0] is unused. The order of entries is as in KeyName.h for MOUSE_*
bool g_mouse_buttons[MOUSE_LAST - MOUSE_BASE] = {0};

PIFrequencyFilter g_frequencyFilter;

// updates the state of the above; never swallows messages.
InReaction GlobalsInputHandler(const SDL_Event_* ev)
{
	size_t c;

#if OS_ANDROID
	static Uint32 s_lastMouseLog = 0;
	static Uint32 s_lastWheelLog = 0;
#endif

	switch(ev->ev.type)
	{
	case SDL_WINDOWEVENT:
		switch(ev->ev.window.event)
		{
		case SDL_WINDOWEVENT_MINIMIZED:
			g_app_minimized = true;
			break;
		case SDL_WINDOWEVENT_EXPOSED:
		case SDL_WINDOWEVENT_RESTORED:
			g_app_minimized = false;
			break;
		case SDL_WINDOWEVENT_FOCUS_GAINED:
			g_app_has_focus = true;
			break;
		case SDL_WINDOWEVENT_FOCUS_LOST:
			g_app_has_focus = false;
			break;
		case SDL_WINDOWEVENT_ENTER:
			g_mouse_active = true;
			break;
		case SDL_WINDOWEVENT_LEAVE:
			g_mouse_active = false;
			break;
		}
		return IN_PASS;

	case SDL_MOUSEMOTION:
#if OS_ANDROID
		{
			const Uint32 now = SDL_GetTicks();
			if (now - s_lastMouseLog > 250)
			{
				SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
					"Android SDL mouse motion x=%d y=%d", ev->ev.motion.x, ev->ev.motion.y);
				__android_log_print(ANDROID_LOG_ERROR, "0AD",
					"Android SDL mouse motion x=%d y=%d", ev->ev.motion.x, ev->ev.motion.y);
				s_lastMouseLog = now;
			}
		}
#endif
		g_mouse_active = true;
		g_mouse_x = ev->ev.motion.x;
		g_mouse_y = ev->ev.motion.y;
		return IN_PASS;

	case SDL_MOUSEBUTTONDOWN:
	case SDL_MOUSEBUTTONUP:
		c = ev->ev.button.button;
		if(c < ARRAY_SIZE(g_mouse_buttons))
			g_mouse_buttons[c] = (ev->ev.type == SDL_MOUSEBUTTONDOWN);
		else
		{
			// don't complain: just ignore people with too many mouse buttons
			//debug_warn(L"invalid mouse button");
		}
		return IN_PASS;

	case SDL_MOUSEWHEEL:
#if OS_ANDROID
		{
			const Uint32 now = SDL_GetTicks();
			if (now - s_lastWheelLog > 100)
			{
				SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
					"Android SDL mouse wheel x=%d y=%d dir=%d",
					ev->ev.wheel.x, ev->ev.wheel.y, ev->ev.wheel.direction);
				__android_log_print(ANDROID_LOG_ERROR, "0AD",
					"Android SDL mouse wheel x=%d y=%d dir=%d",
					ev->ev.wheel.x, ev->ev.wheel.y, ev->ev.wheel.direction);
				s_lastWheelLog = now;
			}
		}
#endif
		return IN_PASS;

	case SDL_KEYDOWN:
	case SDL_KEYUP:
		g_scancodes[ev->ev.key.keysym.scancode] = (ev->ev.type == SDL_KEYDOWN);
		return IN_PASS;

	default:
		return IN_PASS;
	}

	UNREACHABLE;
}

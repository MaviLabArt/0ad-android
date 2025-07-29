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

#include "OggData.h"

#if CONFIG2_AUDIO

#include "lib/status.h"
#include "lib/types.h"
#include "ps/Filesystem.h"
#include "soundmanager/SoundManager.h"
#include "soundmanager/data/ogg.h"

#include <AL/al.h>
#include <algorithm>
#include <fmt/format.h>
#include <stdexcept>
#include <span>
#include <vector>

/*
* Each buffer holds ~0.56 seconds of audio.
* Bytes per second = sampleRate × channels × bytesPerSample.
* For 44100 Hz, 2 channels, 2 bytes per sample, this is 176400 bytes per second.
* Nice multiple of 4096 (system page size)
*/
constexpr int OGG_DEFAULT_BUFFER_SIZE = 98304;

COggData::COggData(const VfsPath& itemPath)
	: m_Format(0), m_Frequency(0), m_OneShot(false), m_BuffersCount(0)
{
	if (OpenOggNonstream(g_VFS, itemPath, m_Stream) != INFO::OK)
		throw new OggDataError("Can't open Ogg file");

	m_FileFinished = false;

	SetFormatAndFreq(m_Stream->Format(), m_Stream->SamplingRate());
	m_FileName = itemPath;

	AL_CHECK;
	alGenBuffers(m_Buffer.size(), m_Buffer.data());

	ALenum err{alGetError()};
	if (err != AL_NO_ERROR)
		throw new OggDataError(fmt::format("Failed to create initial buffer. OpenAL error: {}", alGetString(err)));

	m_BuffersCount = FetchDataIntoBuffer(m_Buffer.size(), m_Buffer.data());
	if (!m_FileFinished)
		return;

	m_OneShot = true;
	if (m_BuffersCount < OGG_DEFAULT_BUFFER_COUNT)
		alDeleteBuffers(OGG_DEFAULT_BUFFER_COUNT - m_BuffersCount, &m_Buffer.at(m_BuffersCount));

	AL_CHECK;
}

COggData::~COggData()
{
	AL_CHECK;
	if (m_BuffersCount > 0)
		alDeleteBuffers(m_BuffersCount, &m_Buffer.at(0));

	AL_CHECK;
	m_BuffersCount = 0;
}

void COggData::SetFormatAndFreq(ALenum form, ALsizei freq)
{
	m_Format = form;
	m_Frequency = freq;
}

bool COggData::IsStereo()
{
	return m_Format == AL_FORMAT_STEREO16;
}

ALsizei COggData::GetBufferCount()
{
	return m_BuffersCount;
}

bool COggData::IsFileFinished()
{
	return m_FileFinished;
}

void COggData::ResetFile()
{
	m_Stream->ResetFile();
	m_FileFinished = false;
}

bool COggData::IsOneShot()
{
	return m_OneShot;
}

int COggData::FetchDataIntoBuffer(int count, ALuint* buffers)
{
	std::vector<u8> PCMOut(OGG_DEFAULT_BUFFER_SIZE);
	int buffersWritten{0};

	for (int i{0}; i < count && !m_FileFinished; ++i)
	{
		std::fill(PCMOut.begin(), PCMOut.end(), 0);
		const size_t totalRet{m_Stream->GetNextChunk(std::span<u8>(PCMOut))};
		m_FileFinished = m_Stream->AtFileEOF();
		if (totalRet == 0)
			continue;

		++buffersWritten;
		alBufferData(buffers[i], m_Format, PCMOut.data(), static_cast<ALsizei>(totalRet), m_Frequency);
	}
	return buffersWritten;
}


ALuint COggData::GetBuffer()
{
	return m_Buffer.at(0);
}

ALuint* COggData::GetBufferPtr()
{
	return m_Buffer.data();
}
#endif // CONFIG2_AUDIO

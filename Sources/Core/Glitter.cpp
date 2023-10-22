/*
 This piece of Code was written by VierEck. and is based on
 Mile's Glitter (https://github.com/yusufcardinal/glitter) and OpenSpades.

 This file is part of 4 of Spades, a fork of OpenSpades.

 OpenSpades is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 OpenSpades is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with OpenSpades.  If not, see <http://www.gnu.org/licenses/>.

*/

#include "Glitter.h"
#include <Client/GameMap.h>
#include "FileManager.h"
#include "IStream.h"

namespace spades {
	namespace gui {
		Glitter::Glitter() {}
		Glitter::~Glitter() {}

		void Glitter::GlitterMap(const std::string &fileName) {
			SPADES_MARK_FUNCTION();
			if (!FileManager::FileExists(fileName.c_str())) {
				SPLog("Glitter failed. file not found: %s", fileName.c_str());
				return;
			}

			std::string dir;
			for (int i = fileName.size() - 1; i > 0; i--) {
				if (fileName[i] == '/') {
					dir = fileName.substr(0, i + 1);
					break;
				}
				if (i == 0) {
					SPLog("Glitter failed. filename string does not contain directory: %s", fileName.c_str());
					return;
				}
			}
			std::vector<std::string> fileNames = FileManager::EnumFiles(dir.c_str());

			size_t found = fileName.find(".vxl");
			if (found == (int)std::string::npos) {
				SPLog("Glitter failed. file does not contain '.vxl' extension: %s", fileName.c_str());
				return;
			}
			int extensionPos = found;
			std::string extension = fileName.substr(extensionPos, fileName.size() - extensionPos);

			std::string newName = fileName.substr(0, extensionPos) + " - Glitter" + extension;
			int count = 1;
			char bufCopy[16];
			while (FileManager::FileExists(newName.c_str())) {
				sprintf(bufCopy, " - Glitter (%d)", count++);
				newName = fileName.substr(0, extensionPos) + bufCopy + extension;
			}

			GlitterProcess(fileName, newName);
		}

		void Glitter::GlitterProcess(const std::string &fileName, const std::string &newName) {
			SPADES_MARK_FUNCTION();
			if (glitArgs.size() != 29) {
				SPLog("Glitter failed. need 29 arguments. got %d instead", (int)glitArgs.size());
				return;
			}

			int i = 0;

			IntVector3 gradeColor = {glitArgs[i++], glitArgs[i++], glitArgs[i++]};
			bool grade = gradeColor.x >= 0 && gradeColor.y >= 0 && gradeColor.z >= 0;

			IntVector3 shadowColor = {glitArgs[i++], glitArgs[i++], glitArgs[i++]};
			bool shadow = shadowColor.x >= 0 && shadowColor.y >= 0 && shadowColor.z >= 0;

			IntVector3 xRampColor = {glitArgs[i++], glitArgs[i++], glitArgs[i++]};
			bool xRampReverse = glitArgs[i++]; int xRampRange = glitArgs[i++];
			bool xRamp = xRampColor.x >= 0 && xRampColor.y >= 0 && xRampColor.z >= 0 && xRampRange >= 0;

			IntVector3 yRampColor = {glitArgs[i++], glitArgs[i++],glitArgs[i++]};
			bool yRampReverse = glitArgs[i++]; int yRampRange = glitArgs[i++];
			bool yRamp = yRampColor.x >= 0 && yRampColor.y >= 0 && yRampColor.z >= 0 && yRampRange >= 0;

			IntVector3 zRampColor = {glitArgs[i++], glitArgs[i++], glitArgs[i++]};
			bool zRampReverse = glitArgs[i++]; int zRampRange = glitArgs[i++];
			bool zRamp = zRampColor.x >= 0 && zRampColor.y >= 0 && zRampColor.z >= 0 && zRampRange >= 0;

			int noisemono = glitArgs[i++]; int noisecolor = glitArgs[i++]; int rain = glitArgs[i++];

			bool snow = glitArgs[i++]; bool repair = glitArgs[i++]; bool glowComp = glitArgs[i++];
			bool glowClamp = glitArgs[i++]; bool debug = glitArgs[i++];

			glitArgs.clear();

			if (!grade && !shadow && !xRamp && !yRamp && !zRamp
				&& !(noisemono >= 0) && !(noisecolor >= 0) && !(rain >= 0)
				&& !snow && !repair && !glowComp && !glowClamp && !debug) {
				SPLog("Glitter canceled. No Arguments given");
				return;
			}

			SPLog("Doing Glitter");
			auto oldStream = FileManager::OpenForReading(fileName.c_str());
			const Handle<client::GameMap> &loadedMap = client::GameMap::Load(oldStream.get());
			map = loadedMap;
			loadedMap->Release();
			{

				int zCountSolid;
				float randomRainLength;
				bool zFirstSurface;
				bool zRestSurfaces;
				IntVector3 vCol;
				uint32_t iCol;
				uint8_t alpha;
				if (rain >= 0)
					rain = (float)rain * 2.55f;
				for (int x = 0; x < 512; x++)
					for (int y = 0; y < 512; y++) {

						if (rain >= 0)
							randomRainLength = (float)SampleRandomInt(500, 2000) * 0.01f;
						zCountSolid = 0;
						zFirstSurface = true;
						for (int z = 0; z < 64; z++) {
							if (map->IsSolid(x, y, z)) {
								iCol = map->GetColor(x, y, z);
								vCol.x = (uint8_t)(iCol);
								vCol.y = (uint8_t)(iCol >> 8);
								vCol.z = (uint8_t)(iCol >> 16);
								alpha = (uint8_t)(iCol >> 24);

								if (repair)
									alpha = 255;
								if (snow)
									if (zFirstSurface)
										vCol.x = vCol.y = vCol.z = 250 - SampleRandomInt(0, 15);
								if (rain >= 0)
									if (zCountSolid < randomRainLength) {
										float rainFactor = ((float)rain * 0.01f) * 255.f * 0.01f;
										if (zCountSolid != 0)
											rainFactor *= (zCountSolid - randomRainLength) / randomRainLength;
										if (rainFactor < 0)
											rainFactor *= -1;
										vCol.x -= (float)vCol.x * rainFactor;
										vCol.y -= (float)vCol.y * rainFactor;
										vCol.z -= (float)vCol.z * rainFactor;
									}
								if (shadow)
									/*
									* openspades already renders shadows btw
									* but at a 45 degree angle. this here will
									* build shadows at a right angle which may
									* visually clash with rendered shadows
									*/
									if (zRestSurfaces) {
										vCol.x -= shadowColor.x;
										vCol.y -= shadowColor.y;
										vCol.z -= shadowColor.z;
									}
								if (grade) {
									vCol.x *= (float)gradeColor.x / 255.f;
									vCol.y *= (float)gradeColor.y / 255.f;
									vCol.z *= (float)gradeColor.z / 255.f;
								}
								if (xRamp) {
									float rampFactor = xRampReverse
										? (float)std::abs(x - 512) / (float)xRampRange
										: (float)x / (float)xRampRange;
									vCol.x += (float)xRampColor.x * rampFactor;
									vCol.y += (float)xRampColor.y * rampFactor;
									vCol.z += (float)xRampColor.z * rampFactor;
								}
								if (yRamp) {
									float rampFactor = yRampReverse
										? (float)std::abs(y - 512) / (float)yRampRange
										: (float)y / (float)yRampRange;
									vCol.x += (float)yRampColor.x * rampFactor;
									vCol.y += (float)yRampColor.y * rampFactor;
									vCol.z += (float)yRampColor.z * rampFactor;
								}
								if (zRamp) {
									float rampFactor = zRampReverse
										? (float)std::abs(64 - z) / (float)zRampRange
										: (float)(63 - z) / (float)zRampRange;
									vCol.x += (float)zRampColor.x * rampFactor;
									vCol.y += (float)zRampColor.y * rampFactor;
									vCol.z += (float)zRampColor.z * rampFactor;
								}
								if (noisemono >= 0) {
									float randomMono = (float)SampleRandomInt(0, noisemono) * 0.01f;
									vCol.x -= vCol.x * randomMono;
									vCol.y -= vCol.y * randomMono;
									vCol.z -= vCol.z * randomMono;
								}
								if (noisecolor >= 0) {
									vCol.x -= vCol.x * ((float)SampleRandomInt(0, noisecolor) * 0.01f);
									vCol.y -= vCol.y * ((float)SampleRandomInt(0, noisecolor) * 0.01f);
									vCol.z -= vCol.z * ((float)SampleRandomInt(0, noisecolor) * 0.01f);
								}
								if (debug) {
									vCol.x = ((float)x / 512.f) * 255;
									vCol.y = ((float)y / 512.f) * 255;
									vCol.z = ((float)(63 - z) / 64.f) * 255;
								}
								if (glowClamp) {
									vCol.x = std::min(vCol.x, 254);
									vCol.y = std::min(vCol.y, 254);
									vCol.z = std::min(vCol.z, 254);
								}

								vCol.x = std::max(std::min(vCol.x, 255), 0);
								vCol.y = std::max(std::min(vCol.y, 255), 0);
								vCol.z = std::max(std::min(vCol.z, 255), 0);
								zFirstSurface = false;
								++zCountSolid;

								map->Set(x, y, z, true,
									vCol.x | (vCol.y << 8) | (vCol.z << 16) | (alpha << 24), true);
							} else {
								zRestSurfaces = !zFirstSurface;
							}
						}
					}

			}
			auto newStream = FileManager::OpenForWriting(newName.c_str());
			map->Save(newStream.get());
			SPLog("Glitter done");
		}
	}
}

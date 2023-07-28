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
#include <Core/FileManager.h>
#include <Core/IStream.h>

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
			if (glitArgs.size() != 28) {
				SPLog("Glitter failed. need 28 arguments. got %d instead", (int)glitArgs.size());
				return;
			}
			IntVector3 gradeColor = {glitArgs[0], glitArgs[1], glitArgs[2]};
			bool grade = gradeColor.x >= 0 && gradeColor.y >= 0 && gradeColor.z >= 0;

			int shadowRed = glitArgs[3]; int ShadowGreen = glitArgs[4]; int shadowBlue = glitArgs[5];
			bool shadow = shadowRed >= 0 && ShadowGreen >= 0 && shadowBlue >= 0;

			int xRampRed = glitArgs[6]; int xRampGreen = glitArgs[7]; int xRampBlue = glitArgs[8];
			bool xRampReverse = glitArgs[9]; int xRampRange = glitArgs[10];
			bool xRamp = xRampRed >= 0 && xRampGreen >= 0 && xRampBlue >= 0 && xRampRange >= 0;

			int yRampRed = glitArgs[11]; int yRampGreen = glitArgs[12]; int yRampBlue = glitArgs[13];
			bool yRampReverse = glitArgs[14]; int yRampRange = glitArgs[15];
			bool yRamp = yRampRed >= 0 && yRampGreen >= 0 && yRampBlue >= 0 && yRampRange >= 0;

			int zRampRed = glitArgs[16]; int zRampGreen = glitArgs[17]; int zRampBlue = glitArgs[18];
			bool zRampReverse = glitArgs[19]; int zRampRange = glitArgs[20];
			bool zRamp = zRampRed >= 0 && zRampGreen >= 0 && zRampBlue >= 0 && zRampRange >= 0;

			int noisemono = glitArgs[21]; int noisecolor = glitArgs[22]; int rain = glitArgs[23];

			bool snow = glitArgs[24]; bool repair = glitArgs[25]; bool glowComp = glitArgs[26]; bool debug = glitArgs[27];

			glitArgs.clear();

			if (!grade && !shadow && !xRamp && !yRamp && !zRamp
				&& !(noisemono >= 0) && !(noisecolor >= 0) && !(rain >= 0)
				&& !snow && !repair && !glowComp && !debug) {
				SPLog("Glitter canceled. No Arguments given");
				return;
			}

			SPLog("Doing Glitter");
			auto oldStream = FileManager::OpenForReading(fileName.c_str());
			const Handle<client::GameMap> &loadedMap = client::GameMap::Load(oldStream.get());
			map = loadedMap;
			loadedMap->Release();
			{

				bool surface;
				IntVector3 vCol;
				uint32_t iCol;
				if (rain >= 0)
					rain = (float)rain * 2.55f;
				for (int x = 0; x < 512; x++)
					for (int y = 0; y < 512; y++) {
						surface = true;

						for (int z = 0; z < 64; z++) {
							if (map->IsSolid(x, y, z)) {
								iCol = map->GetColor(x, y, z);
								vCol.x = (uint8_t)(iCol);
								vCol.y = (uint8_t)(iCol >> 8);
								vCol.z = (uint8_t)(iCol >> 16);

								//repair
								if (snow)
									if (surface)
										vCol.x = vCol.y = vCol.z = 250 - SampleRandomInt(0, 15);
								//rain
								//shadow
								if (grade) {
									vCol.x *= (float)gradeColor.x / 255.f;
									vCol.y *= (float)gradeColor.y / 255.f;
									vCol.z *= (float)gradeColor.z / 255.f;
								}
								//rampx
								//rampy
								//rampz
								//noisemono
								//noisecolor
								if (debug) {
									vCol.x = ((float)x / 512.f) * 255;
									vCol.y = ((float)y / 512.f) * 255;
									vCol.z = ((float)z / 64.f) * 255;
								}

								if (vCol.x < 0)
									vCol.x = 0;
								if (vCol.y < 0)
									vCol.y = 0;
								if (vCol.z < 0)
									vCol.z = 0;
								if (vCol.x > 255)
									vCol.x = 255;
								if (vCol.y > 255)
									vCol.y = 255;
								if (vCol.z > 255)
									vCol.z = 255;
								surface = false;

								map->Set(x, y, z, true,
									vCol.x | (vCol.y << 8) | (vCol.z << 16) | (100UL << 24), true);
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

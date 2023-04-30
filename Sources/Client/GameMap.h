/*
 Copyright (c) 2013 yvt
 based on code of pysnip (c) Mathias Kaerlev 2011-2012.

 This file is part of OpenSpades.

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

#pragma once

#include <cstdint>
#include <functional>
#include <list>
#include <mutex>

#include <Core/Debug.h>
#include <Core/Math.h>

#include "IGameMapListener.h"
#include <Core/RefCountedObject.h>

namespace spades {
	class IStream;
	namespace client {
		class GameMap : public RefCountedObject {
		protected:
			~GameMap();

		public:
			// fixed for now
			enum {
				DefaultWidth = 512,
				DefaultHeight = 512,
				DefaultDepth = 64 // should be <= 64
			};
			GameMap();

			/**
			 * Construct a `GameMap` from VOXLAP5 terrain data supplied by the specified stream.
			 *
			 * @param onProgress Called whenever a new column (a set of voxels with the same X and Y
			 *                   coordinates) is loaded from the stream. The parameter indicates
			 *					 the number of columns loaded
			 *					 (up to `DefaultWidth * DefaultHeight`).
			 */
			static GameMap *Load(IStream *, std::function<void(int)> onProgress = {});
			static GameMap *LoadLocal(IStream *);

			void Save(IStream *);

			int Width() const { return DefaultWidth; }
			int Height() const { return DefaultHeight; }
			int Depth() const { return DefaultDepth; }
			inline bool IsSolid(int x, int y, int z) const {
				SPAssert(IsValidMapCoord(x, y, z));
				return ((solidMap[x][y] >> (uint64_t)z) & 1ULL) != 0;
			}

			/** @return 0xHHBBGGRR where HH is health (up to 100) */
			inline uint32_t GetColor(int x, int y, int z) const {
				SPAssert(IsValidMapCoord(x, y, z));
				return colorMap[x][y][z];
			}

			inline bool IsValidMapCoord(const int x, const int y, const int z) const {
				return x >= 0 && y >= 0 && z >= 0 && x < Width() && y < Height() && z < Depth();
			}

			inline bool IsValidBuildCoord(const IntVector3 v) const {
				return IsValidMapCoord(v.x, v.y, v.z) && 0 < v.z < DefaultDepth; 
				//fix from zerospades
				//https://github.com/siecvi/zerospades/commit/6606edfd6f929e854205ee8aa20cae8a0ddb74b7
			}

			inline uint64_t GetSolidMapWrapped(int x, int y) const {
				return solidMap[x & (Width() - 1)][y & (Height() - 1)];
			}

			inline bool IsSolidWrapped(int x, int y, int z) const {
				if (z < 0 || z > Depth() || x < 0 || x > (Width() - 1) || y < 0 || y > (Height() - 1))
					return true;
				return ((solidMap[x & (Width() - 1)][y & (Height() - 1)] >> (uint64_t)z) & 1ULL) !=
				       0;
			}

			inline uint32_t GetColorWrapped(int x, int y, int z) const {
				return colorMap[x & (Width() - 1)][y & (Height() - 1)][z & (Depth() - 1)];
			}

			inline void Set(int x, int y, int z, bool solid, uint32_t color, bool unsafe = false) {
				SPAssert(IsValidMapCoord(x, y, z));
				uint64_t mask = 1ULL << z;
				uint64_t value = solidMap[x][y];
				bool changed = false;
				if ((value & mask) != (solid ? mask : 0ULL)) {
					changed = true;
					value &= ~mask;
					if (solid)
						value |= mask;
					solidMap[x][y] = value;
				}
				if (solid) {
					if (color != colorMap[x][y][z]) {
						changed = true;
						colorMap[x][y][z] = color;
					}
				}
				if (!unsafe) {
					if (changed) {
						std::lock_guard<std::mutex> guard{listenersMutex};
						for (auto *l : listeners) {
							l->GameMapChanged(x, y, z, this);
						}
					}
				}
			}

			void AddListener(IGameMapListener *);
			void RemoveListener(IGameMapListener *);

			bool ClipBox(int x, int y, int z) const;
			bool ClipWorld(int x, int y, int z) const;

			bool ClipBox(float x, float y, float z) const;
			bool ClipWorld(float x, float y, float z) const;

			// vanila compat
			bool CastRay(Vector3 v0, Vector3 v1, float length, IntVector3 &vOut) const;

			// accurate and slow ray casting
			struct RayCastResult {
				bool hit;
				bool startSolid;
				Vector3 hitPos;
				IntVector3 hitBlock;
				IntVector3 normal;
			};
			RayCastResult CastRay2(Vector3 v0, Vector3 dir, int maxSteps) const;

		private:
			uint64_t solidMap[DefaultWidth][DefaultHeight];
			uint32_t colorMap[DefaultWidth][DefaultHeight][DefaultDepth];
			std::list<IGameMapListener *> listeners;
			std::mutex listenersMutex;

			bool IsSurface(int x, int y, int z) const;
		};
	} // namespace client
} // namespace spades

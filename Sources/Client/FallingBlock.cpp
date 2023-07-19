/*
 Copyright (c) 2013 yvt

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

#include "FallingBlock.h"
#include "Client.h"
#include "GameMap.h"
#include "IModel.h"
#include "IAudioChunk.h"
#include "IAudioDevice.h"
#include "IRenderer.h"
#include "ParticleSpriteEntity.h"
#include "SmokeSpriteEntity.h"
#include "World.h"
#include <Core/Debug.h>
#include <Core/Exception.h>
#include <Core/Settings.h>
#include <limits.h>

SPADES_SETTING(cg_particles);
DEFINE_SPADES_SETTING(cg_fallingBlocksBounce, "1", "0");

namespace spades {
	namespace client {
		FallingBlock::FallingBlock(Client *client, std::vector<IntVector3> blocks)
		    : client(client) {
			if (blocks.empty())
				SPRaise("No block given");

			// find min/max
			int maxX = -1, maxY = -1, maxZ = -1;
			int minX = INT_MAX, minY = INT_MAX, minZ = INT_MAX;
			uint64_t xSum = 0, ySum = 0, zSum = 0;
			numBlocks = (int)blocks.size();
			for (size_t i = 0; i < blocks.size(); i++) {
				IntVector3 v = blocks[i];
				if (v.x < minX)
					minX = v.x;
				if (v.y < minY)
					minY = v.y;
				if (v.z < minZ)
					minZ = v.z;
				if (v.x > maxX)
					maxX = v.x;
				if (v.y > maxY)
					maxY = v.y;
				if (v.z > maxZ)
					maxZ = v.z;
				xSum += v.x;
				ySum += v.y;
				zSum += v.z;
			}

			const Handle<GameMap> &map = client->GetWorld()->GetMap();
			SPAssert(map);

			// build voxel model
			vmodel = new VoxelModel(maxX - minX + 1, maxY - minY + 1, maxZ - minZ + 1);
			for (size_t i = 0; i < blocks.size(); i++) {
				IntVector3 v = blocks[i];
				uint32_t col = map->GetColor(v.x, v.y, v.z);

				// Use the default material
				col &= 0xffffff;

				vmodel->SetSolid(v.x - minX, v.y - minY, v.z - minZ, col);
			}

			// center of gravity
			Vector3 origin;
			origin.x = (float)minX - (float)xSum / (float)blocks.size();
			origin.y = (float)minY - (float)ySum / (float)blocks.size();
			origin.z = (float)minZ - (float)zSum / (float)blocks.size();
			vmodel->SetOrigin(origin);

			Vector3 matTrans = MakeVector3((float)minX, (float)minY, (float)minZ);
			matTrans += .5f;    // voxelmodel's (0,0,0) origins on block center
			matTrans -= origin; // cancel origin
			matrix = Matrix4::Translate(matTrans);

			// build renderer model
			model = client->GetRenderer().CreateModel(*vmodel).Unmanage();

			time = 0.f;
			isBounce = cg_fallingBlocksBounce;
			if (isBounce) {
				velocity = {0.0F, 0.0F, 0.0F};
				rotation = SampleRandom() & 3;
				divIfBounce = 0.2f;
			} else {
				divIfBounce = 1.0f;
			}
		}

		FallingBlock::~FallingBlock() {
			model->Release();
			vmodel->Release();
		}

		bool FallingBlock::Update(float dt) {
			time += dt * divIfBounce;

			const Handle<GameMap> &map = client->GetWorld()->GetMap();
			Vector3 orig = matrix.GetOrigin();

			SPAssert(map);

			if (time > 1.f) {
				// destroy
				int w = vmodel->GetWidth();
				int h = vmodel->GetHeight();
				int d = vmodel->GetDepth();

				Matrix4 vmat = lastMatrix;
				vmat = vmat * Matrix4::Translate(vmodel->GetOrigin());

				// block center
				Vector3 vmOrigin = vmat.GetOrigin();
				Vector3 vmAxis1 = vmat.GetAxis(0);
				Vector3 vmAxis2 = vmat.GetAxis(1);
				Vector3 vmAxis3 = vmat.GetAxis(2);

				Handle<IImage> img = client->GetRenderer().RegisterImage("Gfx/White.tga");

				bool usePrecisePhysics = false;
				float dist =
				  (client->GetLastSceneDef().viewOrigin - matrix.GetOrigin()).GetLength();
				if (dist < 16.f) {
					if (numBlocks < 1000) {
						usePrecisePhysics = true;
					}
				}

				float impact;
				if (dist > 170.f)
					return false;

				impact = (float)numBlocks / 100.f;

				client->grenadeVibration += impact / (dist + 5.f);
				if (client->grenadeVibration > 1.f)
					client->grenadeVibration = 1.f;

				auto *getRandom = SampleRandomFloat;

				for (int x = 0; x < w; x++) {
					Vector3 p1 = vmOrigin + vmAxis1 * (float)x;
					for (int y = 0; y < h; y++) {
						Vector3 p2 = p1 + vmAxis2 * (float)y;
						for (int z = 0; z < d; z++) {
							if (!vmodel->IsSolid(x, y, z))
								continue;

							// inner voxel?
							if (x > 0 && y > 0 && z > 0 && x < w - 1 && y < h - 1 && z < d - 1 &&
							    vmodel->IsSolid(x - 1, y, z) && vmodel->IsSolid(x + 1, y, z) &&
							    vmodel->IsSolid(x, y - 1, z) && vmodel->IsSolid(x, y + 1, z) &&
							    vmodel->IsSolid(x, y, z - 1) && vmodel->IsSolid(x, y, z + 1))
								continue;
							uint32_t c = vmodel->GetColor(x, y, z);
							Vector4 col;
							col.x = (float)((uint8_t)(c)) / 255.f;
							col.y = (float)((uint8_t)(c >> 8)) / 255.f;
							col.z = (float)((uint8_t)(c >> 16)) / 255.f;
							col.w = 1.;

							Vector3 p3 = p2 + vmAxis3 * (float)z;

							{
								SPLog("spawning dust");
								auto ent = stmp::make_unique<SmokeSpriteEntity>(*client, col, 70.f);
								ent->SetTrajectory(
								  p3,
								  (MakeVector3(getRandom() - getRandom(), getRandom() - getRandom(),
								               getRandom() - getRandom())) *
								    0.2f,
								  1.f, 0.f);
								ent->SetRotation(getRandom() * (float)M_PI * 2.f);
								ent->SetRadius(1.0f, 0.5f);
								ent->SetBlockHitAction(BlockHitAction::Ignore);
								ent->SetLifeTime(1.0f + getRandom() * 0.5f, 0.f, 1.0f);
								client->AddLocalEntity(std::move(ent));
							}

							if (cg_particles) {
								col.w = 1.f;
								for (int i = 0; i < 6; i++) {
									auto ent = stmp::make_unique<ParticleSpriteEntity>(
									  *client, img.GetPointerOrNull(), col);
									ent->SetTrajectory(p3,
													   MakeVector3(getRandom() - getRandom(),
																   getRandom() - getRandom(),
																   getRandom() - getRandom()) *
														 13.f,
													   1.f, .6f);
									ent->SetRotation(getRandom() * (float)M_PI * 2.f);
									ent->SetRadius(0.35f + getRandom() * getRandom() * 0.1f);
									ent->SetLifeTime(2.f, 0.f, 1.f);
									if (usePrecisePhysics)
										ent->SetBlockHitAction(BlockHitAction::BounceWeak);
									client->AddLocalEntity(std::move(ent));
								}

								if ((int)cg_particles >= 2) {
									auto ent = stmp::make_unique<SmokeSpriteEntity>(*client, col, 70.0f);
									ent->SetTrajectory(p3,
													   MakeVector3(getRandom() - getRandom(),
																   getRandom() - getRandom(),
																   getRandom() - getRandom()) *
														 13.f,
													   1.f, .6f);
									ent->SetRotation(getRandom() * (float)M_PI * 2.0f);
									ent->SetRadius(1.0f, 0.5f);
									ent->SetBlockHitAction(BlockHitAction::Ignore);
									ent->SetLifeTime(1.0f + getRandom() * 0.5f, 0.0f, 1.0f);
									client->AddLocalEntity(std::move(ent));
								}
							}
						}
					}
				}
				return false;
			}

			if (isBounce) {
				if (MoveBlock(dt) == 2 && !client->IsMuted()) {
					IAudioDevice& dev = client->GetAudioDevice();
					Handle<IAudioChunk> c = dev.RegisterSound("Sounds/Player/Bounce.opus");
					dev.Play(c.GetPointerOrNull(), orig, AudioParam());
				}
				return true;
			}

			lastMatrix = matrix;

			Matrix4 rot;
			rot = Matrix4::Rotate(MakeVector3(1.f, 1.f, 0.f), time * 1.4f * dt);
			matrix = matrix * rot;

			Matrix4 trans;
			trans = Matrix4::Translate(0, 0, time * dt * 4.f);
			matrix = trans * matrix;

			return true;
		}

		int FallingBlock::MoveBlock(float fsynctics) {
			SPADES_MARK_FUNCTION();

			lastMatrix = matrix;

			matrix = matrix * Matrix4::Rotate(MakeVector3(1, 0, 0),
				((rotation & 1) ? 1 : -1) * fsynctics * 0.785f);
			matrix = matrix * Matrix4::Rotate(MakeVector3(0, 1, 0),
				((rotation & 2) ? 1 : -1) * fsynctics * 0.785f);
			matrix = Matrix4::Translate(velocity * fsynctics) * matrix;
			velocity.z += fsynctics * 32.0f;

			// Collision
			IntVector3 lp = matrix.GetOrigin().Floor();

			const Handle<GameMap>& map = client->GetWorld()->GetMap();
			SPAssert(map);

			int ret = 0;
			if (map->ClipWorld(lp.x, lp.y, lp.z)) {
				ret = 1; // hit a wall
				if (fabsf(velocity.x) > BOUNCE_SOUND_THRESHOLD ||
				    fabsf(velocity.y) > BOUNCE_SOUND_THRESHOLD ||
				    fabsf(velocity.z) > BOUNCE_SOUND_THRESHOLD)
					ret = 2; // play sound

				IntVector3 lp2 = lastMatrix.GetOrigin().Floor();
				if (lp.z != lp2.z && ((lp.x == lp2.x && lp.y == lp2.y)
					|| !map->ClipWorld(lp.x, lp.y, lp2.z)))
					velocity.z = -velocity.z;
				else if (lp.x != lp2.x && ((lp.y == lp2.y && lp.z == lp2.z)
					|| !map->ClipWorld(lp2.x, lp.y, lp.z)))
					velocity.x = -velocity.x;
				else if (lp.y != lp2.y && ((lp.x == lp2.x && lp.z == lp2.z)
					|| !map->ClipWorld(lp.x, lp2.y, lp.z)))
					velocity.y = -velocity.y;

				matrix = lastMatrix; // set back to old position
				velocity *= 0.46f; // lose some velocity due to friction
				rotation++;
				rotation &= 3;
				time += 0.36f;
			}

			if (time <= 0.0f)
				ret = 2; // play sound

			return ret;
		}

		void FallingBlock::Render3D() {
			ModelRenderParam param;
			param.ghost = true;
			param.opacity = std::max(0.25f, 1.f - time);
			param.matrix = matrix;
			client->GetRenderer().RenderModel(*model, param);
		}
	} // namespace client
} // namespace spades

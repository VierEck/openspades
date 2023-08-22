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

#include <cstdarg>
#include <cstdlib>

#include "Client.h"

#include <Core/Bitmap.h>
#include <Core/ConcurrentDispatch.h>
#include <Core/FileManager.h>
#include <Core/Settings.h>
#include <Core/Strings.h>

#include "IAudioChunk.h"
#include "IAudioDevice.h"

#include "CTFGameMode.h"
#include "CenterMessageView.h"
#include "ChatWindow.h"
#include "ClientPlayer.h"
#include "ClientUI.h"
#include "Corpse.h"
#include "FallingBlock.h"
#include "Fonts.h"
#include "HurtRingView.h"
#include "IFont.h"
#include "IGameMode.h"
#include "ILocalEntity.h"
#include "LimboView.h"
#include "MapView.h"
#include "PaletteView.h"
#include "ParticleSpriteEntity.h"
#include "ScoreboardView.h"
#include "SmokeSpriteEntity.h"
#include "TCProgressView.h"
#include "Tracer.h"
#include "HitTestDebugger.h"

#include "GameMap.h"
#include "Grenade.h"
#include "Weapon.h"
#include "World.h"

#include "NetClient.h"

#include "TCGameMode.h"

DEFINE_SPADES_SETTING(cg_hitIndicator, "1");
DEFINE_SPADES_SETTING(cg_debugAim, "0");
SPADES_SETTING(cg_keyReloadWeapon);
SPADES_SETTING(cg_keyJump);
SPADES_SETTING(cg_keyAttack);
SPADES_SETTING(cg_keyAltAttack);
SPADES_SETTING(cg_keyCrouch);
DEFINE_SPADES_SETTING(cg_screenshotFormat, "2");
DEFINE_SPADES_SETTING(cg_stats, "0", "1");
DEFINE_SPADES_SETTING(cg_statsColor, "0");
DEFINE_SPADES_SETTING(cg_statsBackground, "1");
DEFINE_SPADES_SETTING(cg_statsTransparency, "1");
DEFINE_SPADES_SETTING(cg_hideHud, "0");
DEFINE_SPADES_SETTING(cg_playerNames, "4");
DEFINE_SPADES_SETTING(cg_playerNameX, "0");
DEFINE_SPADES_SETTING(cg_playerNameY, "0");
DEFINE_SPADES_SETTING(cg_specNames, "1");
DEFINE_SPADES_SETTING(cg_enemyNames, "0");

SPADES_SETTING(cg_distCalculation);
DEFINE_SPADES_SETTING(cg_hudTransparency, "1", "0.8");
SPADES_SETTING(cg_debugHitTest);
DEFINE_SPADES_SETTING(cg_hitTestSize, "128");
DEFINE_SPADES_SETTING(cg_hitTestTransparency, "1", "0.8");
DEFINE_SPADES_SETTING(cg_playerStats, "1");
DEFINE_SPADES_SETTING(cg_damageIndicators, "1", "0");
SPADES_SETTING(cg_hideFirstPersonModel);
DEFINE_SPADES_SETTING(cg_playerStatsHeight, "84");
DEFINE_SPADES_SETTING(cg_respawnSoundGain, "1");
DEFINE_SPADES_SETTING(cg_screenShotSoundGain, "1");

DEFINE_SPADES_SETTING(cg_DemoProgressBarOnlyInUi, "0");
DEFINE_SPADES_SETTING(cg_DrawDragCursorPos, "1");

namespace spades {
	namespace client {

		enum class ScreenshotFormat { Jpeg, Targa, Png };

		namespace {
			ScreenshotFormat GetScreenshotFormat() {
				if (EqualsIgnoringCase(cg_screenshotFormat, "jpeg")) {
					return ScreenshotFormat::Jpeg;
				} else if (EqualsIgnoringCase(cg_screenshotFormat, "targa")) {
					return ScreenshotFormat::Targa;
				} else if (EqualsIgnoringCase(cg_screenshotFormat, "png")) {
					return ScreenshotFormat::Png;
				} else {
					if (0 <= (int)cg_screenshotFormat <= 2) {
						return ScreenshotFormat((int)cg_screenshotFormat);
					} else {
						SPRaise("Invalid screenshot format: %s", cg_screenshotFormat.CString());
					}
				}
			}

			std::string TranslateKeyName(const std::string &name) {
				if (name == "LeftMouseButton") {
					return "LMB";
				} else if (name == "RightMouseButton") {
					return "RMB";
				} else if (name.empty()) {
					return _Tr("Client", "Unbound");
				} else {
					return name;
				}
			}
		} // namespace

		void Client::TakeScreenShot(bool sceneOnly) {
			SceneDefinition sceneDef = CreateSceneDefinition();
			lastSceneDef = sceneDef;
			UpdateMatrices();

			// render scene
			flashDlights = flashDlightsOld;
			DrawScene();

			// draw 2d
			if (!sceneOnly)
				Draw2D();

			// Well done!
			renderer->FrameDone();

			Handle<Bitmap> bmp = renderer->ReadBitmap();

			// force 100% opacity
			uint32_t *pixels = bmp->GetPixels();
			for (size_t i = bmp->GetWidth() * bmp->GetHeight(); i > 0; i--) {
				*(pixels++) |= 0xff000000UL;
			}

			try {
				std::string name = ScreenShotPath();
				bmp->Save(name);

				std::string msg;
				if (sceneOnly)
					msg = _Tr("Client", "Sceneshot saved: {0}", name);
				else
					msg = _Tr("Client", "Screenshot saved: {0}", name);
				ShowAlert(msg, AlertType::Notice);

				Handle<IAudioChunk> c = audioDevice->RegisterSound("Sounds/Feedback/Screenshot.opus");
				AudioParam param;
				param.volume = cg_screenShotSoundGain;
				audioDevice->PlayLocal(c.GetPointerOrNull(), param);
			} catch (const Exception &ex) {
				std::string msg;
				msg = _Tr("Client", "Screenshot failed: ");
				msg += ex.GetShortMessage();
				ShowAlert(msg, AlertType::Error);
				SPLog("Screenshot failed: %s", ex.what());
			} catch (const std::exception &ex) {
				std::string msg;
				msg = _Tr("Client", "Screenshot failed: ");
				msg += ex.what();
				ShowAlert(msg, AlertType::Error);
				SPLog("Screenshot failed: %s", ex.what());
			}
		}

		std::string Client::ScreenShotPath() {
			char bufJpeg[256];
			char bufTarga[256];
			char bufPng[256];
			for (int i = 0; i < 10000; i++) {
				sprintf(bufJpeg, "Screenshots/shot%04d.jpg", nextScreenShotIndex);
				sprintf(bufTarga, "Screenshots/shot%04d.tga", nextScreenShotIndex);
				sprintf(bufPng, "Screenshots/shot%04d.png", nextScreenShotIndex);
				if (FileManager::FileExists(bufJpeg) || FileManager::FileExists(bufTarga) ||
				    FileManager::FileExists(bufPng)) {
					nextScreenShotIndex++;
					if (nextScreenShotIndex >= 10000)
						nextScreenShotIndex = 0;
					continue;
				}

				switch (GetScreenshotFormat()) {
					case ScreenshotFormat::Jpeg: return bufJpeg;
					case ScreenshotFormat::Targa: return bufTarga;
					case ScreenshotFormat::Png: return bufPng;
				}
				SPAssert(false);
			}

			SPRaise("No free file name");
		}

#pragma mark - HUD Drawings

		void Client::DrawSplash() {
			Handle<IImage> img;
			Vector2 siz;
			Vector2 scrSize = {renderer->ScreenWidth(), renderer->ScreenHeight()};

			renderer->SetColorAlphaPremultiplied(MakeVector4(0, 0, 0, 1));
			img = renderer->RegisterImage("Gfx/White.tga");
			renderer->DrawImage(img, AABB2(0, 0, scrSize.x, scrSize.y));

			renderer->SetColorAlphaPremultiplied(MakeVector4(1, 1, 1, 1.));
			img = renderer->RegisterImage("Gfx/Title/Logo.png");

			siz = MakeVector2(img->GetWidth(), img->GetHeight());
			siz *= std::min(1.f, scrSize.x / siz.x * 0.5f);
			siz *= std::min(1.f, scrSize.y / siz.y);

			renderer->DrawImage(
			  img, AABB2((scrSize.x - siz.x) * .5f, (scrSize.y - siz.y) * .5f, siz.x, siz.y));
		}

		void Client::DrawStartupScreen() {
			Handle<IImage> img;
			Vector2 scrSize = {renderer->ScreenWidth(), renderer->ScreenHeight()};

			renderer->SetColorAlphaPremultiplied(MakeVector4(0, 0, 0, 1.));
			img = renderer->RegisterImage("Gfx/White.tga");
			renderer->DrawImage(img, AABB2(0, 0, scrSize.x, scrSize.y));

			DrawSplash();

			IFont &font = fontManager->GetGuiFont();
			std::string str = _Tr("Client", "NOW LOADING");
			Vector2 size = font.Measure(str);
			Vector2 pos = MakeVector2(scrSize.x - 16.f, scrSize.y - 16.f);
			pos -= size;
			font.DrawShadow(str, pos, 1.f, MakeVector4(1, 1, 1, 1), MakeVector4(0, 0, 0, 0.5));

			renderer->FrameDone();
			renderer->Flip();
		}

		void Client::DrawDisconnectScreen() {}

		void Client::DrawPlayingTime() {
			float sw = renderer->ScreenWidth();

			int now = (int)time;
			int mins = now / 60;
			int secs = now - mins * 60;
			char buf[64];
			sprintf(buf, "%d:%.02d", mins, secs);
			IFont& font = fontManager->GetMediumFont();
			Vector2 size = font.Measure(buf);
			Vector2 pos = MakeVector2((sw - size.x) * 0.5F, 68.0F - size.y);
			font.DrawShadow(buf, pos, 1.0F, MakeVector4(1, 1, 1, 1), MakeVector4(0, 0, 0, 0.5));
		}

		void Client::DrawHurtSprites() {
			float per = (world->GetTime() - lastHurtTime) / 1.5f;
			if (per > 1.f)
				return;
			if (per < 0.f)
				return;
			Handle<IImage> img = renderer->RegisterImage("Gfx/HurtSprite.png");

			Vector2 scrSize = {renderer->ScreenWidth(), renderer->ScreenHeight()};
			Vector2 scrCenter = scrSize * .5f;
			float radius = scrSize.GetLength() * .5f;

			for (size_t i = 0; i < hurtSprites.size(); i++) {
				HurtSprite &spr = hurtSprites[i];
				float alpha = spr.strength - per;
				if (alpha < 0.f)
					continue;
				if (alpha > 1.f)
					alpha = 1.f;

				Vector2 radDir = {cosf(spr.angle), sinf(spr.angle)};
				Vector2 angDir = {-sinf(spr.angle), cosf(spr.angle)};
				float siz = spr.scale * radius;
				Vector2 base = radDir * radius + scrCenter;
				Vector2 centVect = radDir * (-siz);
				Vector2 sideVect1 = angDir * (siz * 4.f * (spr.horzShift));
				Vector2 sideVect2 = angDir * (siz * 4.f * (spr.horzShift - 1.f));

				Vector2 v1 = base + centVect + sideVect1;
				Vector2 v2 = base + centVect + sideVect2;
				Vector2 v3 = base + sideVect1;

				renderer->SetColorAlphaPremultiplied(MakeVector4(0.f, 0.f, 0.f, alpha));
				renderer->DrawImage(img, v1, v2, v3,
				                    AABB2(0, 8.f, img->GetWidth(), img->GetHeight()));
			}
		}

		void Client::DrawHurtScreenEffect() {
			SPADES_MARK_FUNCTION();

			float scrWidth = renderer->ScreenWidth();
			float scrHeight = renderer->ScreenHeight();
			float wTime = world->GetTime();
			Player &p = GetWorld()->GetLocalPlayer().value();
			if (wTime < lastHurtTime + .35f && wTime >= lastHurtTime) {
				float per = (wTime - lastHurtTime) / .35f;
				per = 1.f - per;
				per *= .3f + (1.f - p.GetHealth() / 100.f) * .7f;
				per = std::min(per, 0.9f);
				per = 1.f - per;
				Vector3 color = {1.f, per, per};
				renderer->MultiplyScreenColor(color);
				renderer->SetColorAlphaPremultiplied(
				  MakeVector4((1.f - per) * .1f, 0, 0, (1.f - per) * .1f));
				renderer->DrawImage(renderer->RegisterImage("Gfx/White.tga"),
				                    AABB2(0, 0, scrWidth, scrHeight));
			}
		}

		void Client::DrawHottrackedPlayerName() {
			SPADES_MARK_FUNCTION();

			if ((int)cg_playerNames == 0)
				return;

			Player &p = GetWorld()->GetLocalPlayer().value();

			auto hottracked = HotTrackedPlayer();
			if (hottracked) {
				Player &hottrackedPlayer = std::get<0>(*hottracked);

				Vector3 diff = hottrackedPlayer.GetEye() - p.GetEye();
				float dist2d = sqrtf(diff.x * diff.x + diff.y * diff.y);

				if ((!cg_enemyNames || dist2d > 128) && hottrackedPlayer.GetTeamId() != p.GetTeamId())
					return;

				float dist;
				if (!cg_distCalculation) {
					dist = (hottrackedPlayer.GetEye() - p.GetEye()).GetLength();
				} else {
					dist = dist2d;
				}

				Vector3 posxyz = Project(hottrackedPlayer.GetEye());
				Vector2 pos = {posxyz.x, posxyz.y};
				char buf[64];
				std::string plName;
				sprintf(buf, "%s", hottrackedPlayer.GetName().c_str());
				plName = buf;
				if ((int)cg_playerNames > 1) {
					if ((int)cg_playerNames != 3) {
						int idist = (int)floorf(dist + .5f);
						sprintf(buf, " [%d %s]", idist, cg_distCalculation ? "2D" : "3D");
						plName += buf;
					}
					if ((int)cg_playerNames > 2) {
						switch (std::get<1>(*hottracked)) {
							case hit_Head: sprintf(buf, "[Head]"); break;
							case hit_Arms: sprintf(buf, "[Arms]"); break;
							case hit_Legs: sprintf(buf, "[Legs]"); break;
							default: sprintf(buf, " [Torso]"); //for some reason we get hit_None when aiming at torso aswell
						}
						plName += buf;
					}
				}

				pos.y += (int)cg_playerNameY;
				pos.x += (int)cg_playerNameX;

				IFont &font = fontManager->GetGuiFont();
				Vector2 size = font.Measure(plName);
				pos.x -= size.x * .5f;
				pos.y -= size.y;
				font.DrawShadow(plName, pos, 1.f, MakeVector4(1, 1, 1, 1), MakeVector4(0, 0, 0, 0.5));
			}
		}

		void Client::DrawDebugAim() {
			SPADES_MARK_FUNCTION();

			// float scrWidth = renderer->ScreenWidth();
			// float scrHeight = renderer->ScreenHeight();
			// float wTime = world->GetTime();
			Player &p = GetCameraTargetPlayer();
			// IFont *font;

			Weapon &w = p.GetWeapon();
			float spread = w.GetSpread();

			AABB2 boundary(0, 0, 0, 0);
			for (int i = 0; i < 8; i++) {
				Vector3 vec = p.GetFront();
				if (i & 1)
					vec.x += spread;
				else
					vec.x -= spread;
				if (i & 2)
					vec.y += spread;
				else
					vec.y -= spread;
				if (i & 4)
					vec.z += spread;
				else
					vec.z -= spread;

				Vector3 viewPos;
				viewPos.x = Vector3::Dot(vec, p.GetRight());
				viewPos.y = Vector3::Dot(vec, p.GetUp());
				viewPos.z = Vector3::Dot(vec, p.GetFront());

				Vector2 p;
				p.x = viewPos.x / viewPos.z;
				p.y = viewPos.y / viewPos.z;
				boundary.min.x = std::min(boundary.min.x, p.x);
				boundary.min.y = std::min(boundary.min.y, p.y);
				boundary.max.x = std::max(boundary.max.x, p.x);
				boundary.max.y = std::max(boundary.max.y, p.y);
			}

			Handle<IImage> img = renderer->RegisterImage("Gfx/White.tga");
			boundary.min *= renderer->ScreenHeight() * .5f;
			boundary.max *= renderer->ScreenHeight() * .5f;
			boundary.min /= tanf(lastSceneDef.fovY * .5f);
			boundary.max /= tanf(lastSceneDef.fovY * .5f);
			IntVector3 cent;
			cent.x = (int)(renderer->ScreenWidth() * .5f);
			cent.y = (int)(renderer->ScreenHeight() * .5f);

			IntVector3 p1 = cent;
			IntVector3 p2 = cent;

			p1.x += (int)floorf(boundary.min.x);
			p1.y += (int)floorf(boundary.min.y);
			p2.x += (int)ceilf(boundary.max.x);
			p2.y += (int)ceilf(boundary.max.y);

			renderer->SetColorAlphaPremultiplied(MakeVector4(0, 0, 0, 1));
			renderer->DrawImage(img, AABB2(p1.x - 2, p1.y - 2, p2.x - p1.x + 4, 1));
			renderer->DrawImage(img, AABB2(p1.x - 2, p1.y - 2, 1, p2.y - p1.y + 4));
			renderer->DrawImage(img, AABB2(p1.x - 2, p2.y + 1, p2.x - p1.x + 4, 1));
			renderer->DrawImage(img, AABB2(p2.x + 1, p1.y - 2, 1, p2.y - p1.y + 4));

			renderer->SetColorAlphaPremultiplied(MakeVector4(1, 1, 1, 1));
			renderer->DrawImage(img, AABB2(p1.x - 1, p1.y - 1, p2.x - p1.x + 2, 1));
			renderer->DrawImage(img, AABB2(p1.x - 1, p1.y - 1, 1, p2.y - p1.y + 2));
			renderer->DrawImage(img, AABB2(p1.x - 1, p2.y, p2.x - p1.x + 2, 1));
			renderer->DrawImage(img, AABB2(p2.x, p1.y - 1, 1, p2.y - p1.y + 2));
		}

		void Client::DrawFirstPersonHUD() {
			SPADES_MARK_FUNCTION();

			float scrWidth = renderer->ScreenWidth();
			float scrHeight = renderer->ScreenHeight();

			Player &player = GetCameraTargetPlayer();
			int playerId = GetCameraTargetPlayerId();

			clientPlayers[playerId]->Draw2D();

			if (cg_hitIndicator && hitFeedbackIconState > 0.f && !cg_hideHud) {
				Handle<IImage> img = renderer->RegisterImage("Gfx/HitFeedback.png");
				Vector2 pos = {scrWidth * .5f, scrHeight * .5f};
				pos.x -= img->GetWidth() * .5f;
				pos.y -= img->GetHeight() * .5f;

				float op = hitFeedbackIconState;
				Vector4 color;
				if (hitFeedbackFriendly) {
					color = MakeVector4(0.02f, 1.f, 0.02f, 1.f);
				} else {
					color = MakeVector4(1.f, 0.02f, 0.04f, 1.f);
				}
				color *= op;

				renderer->SetColorAlphaPremultiplied(color);

				renderer->DrawImage(img, pos);
			}

			// If the player has the intel, display an intel icon
			IGameMode &mode = *world->GetMode();
			if (mode.ModeType() == IGameMode::m_CTF) {
				auto &ctfMode = static_cast<CTFGameMode &>(mode);
				if (ctfMode.PlayerHasIntel(*world, player)) {
					Handle<IImage> img = renderer->RegisterImage("Gfx/Intel.png");

					// Strobe
					Vector4 color{1.0f, 1.0f, 1.0f, (float)cg_hudTransparency};
					color *= std::fabs(std::sin(world->GetTime() * 2.0f));

					renderer->SetColorAlphaPremultiplied(color);

					renderer->DrawImage(img, Vector2{scrWidth - 260.f, scrHeight - 64.0f});
				}
			}

			if (cg_debugAim && player.GetTool() == Player::ToolWeapon && player.IsAlive()) {
				DrawDebugAim();
			}

			if ((int)cg_hideFirstPersonModel > 1)
				DrawCurrentToolIcon(player);
		}

		void Client::DrawJoinedAlivePlayerHUD() {
			SPADES_MARK_FUNCTION();
			if (cg_hideHud)
				return;

			float scrWidth = renderer->ScreenWidth();
			float scrHeight = renderer->ScreenHeight();
			Player &p = GetWorld()->GetLocalPlayer().value();

			// Draw damage rings
			hurtRingView->Draw();

			// Draw ammo amount
			// (Note: this cannot be displayed for a spectated player --- the server
			//        does not submit sufficient information)
			Weapon &weap = p.GetWeapon();
			Handle<IImage> ammoIcon;
			float iconWidth, iconHeight;
			float spacing = 2.f;
			int stockNum;
			int warnLevel;

			if (p.IsToolWeapon()) {
				switch (weap.GetWeaponType()) {
					case RIFLE_WEAPON:
						ammoIcon = renderer->RegisterImage("Gfx/Bullet/7.62mm.png");
						iconWidth = 6.f;
						iconHeight = iconWidth * 4.f;
						break;
					case SMG_WEAPON:
						ammoIcon = renderer->RegisterImage("Gfx/Bullet/9mm.png");
						iconWidth = 4.f;
						iconHeight = iconWidth * 4.f;
						break;
					case SHOTGUN_WEAPON:
						ammoIcon = renderer->RegisterImage("Gfx/Bullet/12gauge.png");
						iconWidth = 30.f;
						iconHeight = iconWidth / 4.f;
						spacing = -6.f;
						break;
					default: SPInvalidEnum("weap->GetWeaponType()", weap.GetWeaponType());
				}

				int clipSize = weap.GetClipSize();
				int clip = weap.GetAmmo();

				clipSize = std::max(clipSize, clip);

				for (int i = 0; i < clipSize; i++) {
					float x = scrWidth - 16.f - (float)(i + 1) * (iconWidth + spacing);
					float y = scrHeight - 16.f - iconHeight;

					if (clip >= i + 1) {
						renderer->SetColorAlphaPremultiplied(MakeVector4(1, 1, 1, (float)cg_hudTransparency));
					} else {
						renderer->SetColorAlphaPremultiplied(MakeVector4(0.4, 0.4, 0.4, (float)cg_hudTransparency));
					}

					renderer->DrawImage(ammoIcon, AABB2(x, y, iconWidth, iconHeight));
				}

				stockNum = weap.GetStock();
				warnLevel = weap.GetMaxStock() / 3;
			} else {
				iconHeight = 0.f;
				warnLevel = 0;

				switch (p.GetTool()) {
					case Player::ToolSpade:
					case Player::ToolBlock: stockNum = p.GetNumBlocks(); break;
					case Player::ToolGrenade: stockNum = p.GetNumGrenades(); break;
					default: SPInvalidEnum("p->GetTool()", p.GetTool());
				}
			}

			Vector4 numberColor = {1, 1, 1, (float)cg_hudTransparency};

			if (stockNum == 0) {
				numberColor.y = 0.3f;
				numberColor.z = 0.3f;
			} else if (stockNum <= warnLevel) {
				numberColor.z = 0.3f;
			}

			char buf[64];
			sprintf(buf, "%d", stockNum);
			IFont &font = fontManager->GetSquareDesignFont();
			std::string stockStr = buf;
			Vector2 size = font.Measure(stockStr);
			Vector2 pos = MakeVector2(scrWidth - 16.f, scrHeight - 16.f - iconHeight);
			pos -= size;
			font.DrawShadow(stockStr, pos, 1.f, numberColor, MakeVector4(0, 0, 0, 0.5 * (float)cg_hudTransparency));

			// draw "press ... to reload"
			{
				std::string msg = "";

				switch (p.GetTool()) {
					case Player::ToolBlock:
						if (p.GetNumBlocks() == 0) {
							msg = _Tr("Client", "Out of Block");
						}
						break;
					case Player::ToolGrenade:
						if (p.GetNumGrenades() == 0) {
							msg = _Tr("Client", "Out of Grenade");
						}
						break;
					case Player::ToolWeapon: {
						Weapon &weap = p.GetWeapon();
						if (weap.IsReloading() || p.IsAwaitingReloadCompletion()) {
							msg = _Tr("Client", "Reloading");
						} else if (weap.GetAmmo() == 0 && weap.GetStock() == 0) {
							msg = _Tr("Client", "Out of Ammo");
						} else if (weap.GetStock() > 0 &&
							        weap.GetAmmo() < weap.GetClipSize() / 4) {
							msg = _Tr("Client", "Press [{0}] to Reload",
								        TranslateKeyName(cg_keyReloadWeapon));
						}
					} break;
					default:;
						// no message
				}

				if (!msg.empty()) {
					IFont &font = fontManager->GetGuiFont();
					Vector2 size = font.Measure(msg);
					Vector2 pos = MakeVector2((scrWidth - size.x) * .5f, scrHeight * 2.f / 3.f);
					font.DrawShadow(msg, pos, 1.f, MakeVector4(1, 1, 1, 1),
						            MakeVector4(0, 0, 0, 0.5));
				}
			}

			if (p.GetTool() == Player::ToolBlock) {
				paletteView->Draw();
			}

			// draw map
			mapView->Draw();

			DrawHealth();
		}

		void Client::DrawCurrentToolIcon(Player &p) {
			SPADES_MARK_FUNCTION();

			Handle<IImage> img;
			switch (p.GetTool()) {
				case Player::ToolSpade:
					img = renderer->RegisterImage("Gfx/Tools/Spade.png");
					break;
				case Player::ToolBlock:
					img = renderer->RegisterImage("Gfx/Tools/Block.png");
					break;
				case Player::ToolGrenade:
					img = renderer->RegisterImage("Gfx/Tools/Nade.png");
					break;
				case Player::ToolWeapon:
					switch (p.GetWeaponType()) {
						case RIFLE_WEAPON:
							img = renderer->RegisterImage("Gfx/Tools/Rifle.png");
							break;
						case SMG_WEAPON:
							img = renderer->RegisterImage("Gfx/Tools/SMG.png");
							break;
						case SHOTGUN_WEAPON:
							img = renderer->RegisterImage("Gfx/Tools/Shotgun.png");
							break;
						default: return;
					}
					break;
				default: return;
			}

			float iconX = renderer->ScreenWidth() - 360.f;
			float iconY = renderer->ScreenHeight() - 80.f;

			renderer->SetColorAlphaPremultiplied(MakeVector4(1.f, 1.f, 1.f, (float)cg_hudTransparency));
			renderer->DrawImage(img, MakeVector2(iconX, iconY));
		}

		void Client::DrawHitTestDebugger() {
			SPADES_MARK_FUNCTION();

			auto dbg = world->GetHitTestDebugger();
			if (!dbg)
				return;

			auto bitmap = dbg->GetBitmap();
			if (bitmap) {
				auto img = renderer->CreateImage(*bitmap);
				debugHitTestImage.Set(img.GetPointerOrNull());
			}

			float fade = 1.f * (float)cg_hitTestTransparency;
			if ((int)cg_debugHitTest > 1 && !hitTestSizeToggle)
				fade -= (time - lastShotTime) * 0.2f;

			if (debugHitTestImage && fade > 0) {
				int size = (int)cg_hitTestSize;
				if(hitTestSizeToggle)
					size = renderer->ScreenHeight() - 10;

				float sw = renderer->ScreenWidth();
				float sh = renderer->ScreenHeight();

				AABB2 outRect((sw - size) - 8.0F, (sh - size) - 84.0F, size, size);
				if (hitTestSizeToggle) {
					outRect.min = MakeVector2((sw - size) * 0.5F, (sh - size) * 0.5F);
					outRect.max = MakeVector2((sw + size) * 0.5F, (sh + size) * 0.5F);
				}

				renderer->SetColorAlphaPremultiplied(MakeVector4(fade, fade, fade, fade));
				renderer->DrawImage(debugHitTestImage, outRect, AABB2(128, 512 - 128, 256, 256 - 512)); // flip Y axis

				Handle<IImage> border = renderer->RegisterImage("Gfx/White.tga");
				renderer->DrawImage(border, AABB2(outRect.min.x, outRect.min.y, outRect.max.x - outRect.min.x, 2));
				renderer->DrawImage(border, AABB2(outRect.min.x, outRect.min.y, 2, outRect.max.y - outRect.min.y));
				renderer->DrawImage(border, AABB2(outRect.min.x, outRect.max.y, outRect.max.x - outRect.min.x, 2));
				renderer->DrawImage(border, AABB2(outRect.max.x, outRect.min.y, 2, outRect.max.y - outRect.min.y));
			}
		}

		void Client::DrawPlayerStats() {
			SPADES_MARK_FUNCTION();

			IFont &font = fontManager->GetGuiFont();

			float sh = renderer->ScreenHeight();

			float x = 8.0f;
			float y = sh * 0.5f;
			y -= (float)cg_playerStatsHeight;

			auto addLine = [&](const char* format, ...) {
				char buf[256];
				va_list va;
				va_start(va, format);
				vsnprintf(buf, sizeof(buf), format, va);
				va_end(va);

				Vector2 pos = MakeVector2(x, y);
				y += 16.0f;

				Vector2 size = font.Measure("0Head Spread Acc:  000000");
				size *= 0.8f;

				renderer->SetColorAlphaPremultiplied(Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_hudTransparency));
				renderer->DrawImage(nullptr, AABB2(pos.x, pos.y, size.x, size.y));

				font.DrawShadow(
					buf, pos, 0.8f, MakeVector4(1, 1, 1, (float)cg_hudTransparency),
					MakeVector4(0, 0, 0, (float)cg_hudTransparency)
				);
			};

			addLine(" K/D Ratio:  %.3g", curKills / float(std::max(1, curDeaths)));
			addLine(" Kill Streak:  %d", curStreak);
			addLine(" Best Streak:  %d", bestStreak);
			addLine(" Spade Kills:  %d", meleeKills);
			addLine(" Nade Kills:  %d", nadeKills);
			addLine(" Blocks Placed:  %d", placedBlocks);
			addLine(" Total True Acc:  %.2f", (100 * clicksPlayer) / float(std::max(1, shotsCount)));
			addLine(" Total Spread Acc:  %.2f", (100 * hitsPlayer) / float(std::max(1, shotsCount)));
			addLine(" Head True Acc:  %.2f", (100 * clicksHead) / float(std::max(1, shotsCount)));
			addLine(" Head Spread Acc:  %.2f", (100 * hitsHead) / float(std::max(1, shotsCount)));
		}

		void Client::UpdateDamageIndicators(float dt) {
			for (auto it = damageIndicators.begin();
			     it != damageIndicators.end();) {
				DamageIndicator& ent = *it;
				ent.fade -= dt;
				if (ent.fade < 0) {
					std::list<DamageIndicator>::iterator tmp = it++;
					damageIndicators.erase(tmp);
					continue;
				}

				ent.position.x += ent.velocity.x * dt;
				ent.position.y += ent.velocity.y * dt;
				ent.position.z -= 2.0F * dt;

				++it;
			}
		}

		void Client::DrawDamageIndicators() {
			SPADES_MARK_FUNCTION();

			for (const auto& damages : damageIndicators) {
				float fade = damages.fade;
				if (fade > 1.0F)
					fade = 1.0F;

				Vector3 posxyz = Project(damages.position);
				if (posxyz.z <= 0 || posxyz.z > 1.0004f)
					continue;

				Vector2 pos = {posxyz.x, posxyz.y};

				int damage = damages.damage;

				auto damageStr = "-" + ToString(damage);
				IFont& font = fontManager->GetGuiFont();
				Vector2 size = font.Measure(damageStr);
				pos.x -= size.x * 0.5F;
				pos.y -= size.y;

				float per = 1.0F - (damage / 100.0F);
				font.DrawShadow(
					damageStr, pos, 1.0F, MakeVector4(1, per, per, fade),
					MakeVector4(0, 0, 0, 0.25F * fade)
				);
			}
		}

		void Client::DrawDeadPlayerHUD() {
			SPADES_MARK_FUNCTION();

			Player &p = GetWorld()->GetLocalPlayer().value();
			float scrWidth = renderer->ScreenWidth();
			float scrHeight = renderer->ScreenHeight();

			if (!cg_hideHud) {
				// draw respawn tme
				std::string msg;

				int secs = p.GetRespawnTime() - world->GetTime();

				if (secs > 0) {
					static int lastCount = 0;
					if (lastCount != secs) {
						if (secs <= 3) {
							Handle<IAudioChunk> c = (secs == 1)
								? audioDevice->RegisterSound("Sounds/Feedback/Beep1.opus")
								: audioDevice->RegisterSound("Sounds/Feedback/Beep2.opus");
							AudioParam param;
							param.volume = cg_respawnSoundGain;
							audioDevice->PlayLocal(c.GetPointerOrNull(), param);
						}
						lastCount = secs;
					}

					msg = _Tr("Client", "You will respawn in: {0}", secs);
				} else {
					msg = _Tr("Client", "Waiting for respawn");
				}

				if (!msg.empty()) {
					IFont &font = fontManager->GetGuiFont();
					Vector2 size = font.Measure(msg);
					Vector2 pos = MakeVector2((scrWidth - size.x) * .5f, scrHeight / 3.f);

					font.DrawShadow(msg, pos, 1.f, MakeVector4(1, 1, 1, (float)cg_hudTransparency),
						            MakeVector4(0, 0, 0, 0.5 * (float)cg_hudTransparency));
				}
			}
		}

		void Client::DrawSpectateHUD() {
			SPADES_MARK_FUNCTION();

			if (cg_hideHud) {
				return;
			}

			IFont &font = fontManager->GetGuiFont();
			float scrWidth = renderer->ScreenWidth();

			float textX = scrWidth - 8.0f;
			float textY = 256.0f + 32.0f;

			auto addLine = [&](const std::string &text) {
				Vector2 size = font.Measure(text);
				Vector2 pos = MakeVector2(textX, textY);
				pos.x -= size.x;
				textY += 20.0f;
				font.DrawShadow(text, pos, 1.f, MakeVector4(1, 1, 1, (float)cg_hudTransparency), MakeVector4(0, 0, 0, 0.5 * (float)cg_hudTransparency));
			};

			if (HasTargetPlayer(GetCameraMode())) {
				addLine(_Tr("Client", "Following {0} (#{1})",
				            world->GetPlayerPersistent(GetCameraTargetPlayerId()).name, GetCameraTargetPlayerId()));
			}

			textY += 10.0f;

			// Help messages (make sure to synchronize these with the keyboard input handler)
			if (FollowsNonLocalPlayer(GetCameraMode())) {
				if (GetCameraTargetPlayer().IsAlive()) {
					addLine(_Tr("Client", "[{0}] Cycle camera mode", TranslateKeyName(cg_keyJump)));
				}
				addLine(_Tr("Client", "[{0}/{1}] Next/previous player",
				            TranslateKeyName(cg_keyAttack), TranslateKeyName(cg_keyAltAttack)));

				if (GetWorld()->GetLocalPlayer()->IsSpectator()) {
					addLine(_Tr("Client", "[{0}] Unfollow", TranslateKeyName(cg_keyReloadWeapon)));
				}
			} else {
				addLine(_Tr("Client", "[{0}/{1}] Follow a player", TranslateKeyName(cg_keyAttack),
				            TranslateKeyName(cg_keyAltAttack)));
			}

			if (GetCameraMode() == ClientCameraMode::Free) {
				addLine(_Tr("Client", "[{0}/{1}] Go up/down", TranslateKeyName(cg_keyJump),
				            TranslateKeyName(cg_keyCrouch)));
			}

			mapView->Draw();
		}

		void Client::DrawAllPlayerNames() {
			for (int i = 0; i < world->GetNumPlayerSlots(); ++i) {
				stmp::optional<Player &> p = world->GetPlayer(i);

				if (!p)
					continue;
				if (p->GetTeamId() >= 2)
					continue;

				Vector3 posxyz = Project(p->GetEye());
				if (posxyz.z <= 0 || posxyz.z > 1.0004f)
					continue;

				Vector2 pos = {posxyz.x, posxyz.y};

				Vector4 color;
				if (p->IsAlive()) {
					Vector3 pToLocalDiff = p->GetEye() - lastSceneDef.viewOrigin;
					float dist2dsqr = pToLocalDiff.x * pToLocalDiff.x + pToLocalDiff.y * pToLocalDiff.y;
					if (dist2dsqr <= 128 * 128) {
						color = MakeVector4(1, 1, 1, (float)cg_hudTransparency);
					} else {
						color = MakeVector4(1, 1, 0, (float)cg_hudTransparency);
					}
				} else {
					color = MakeVector4(1, 0, 0, (float)cg_hudTransparency);
				}

				IFont &font = fontManager->GetGuiFont();
				Vector2 size = font.Measure(p->GetName());
				pos.x -= size.x * .5f;
				pos.y -= size.y;
				font.DrawShadow(p->GetName(), pos, 0.85, color,
					MakeVector4(0, 0, 0, 0.5 * (float)cg_hudTransparency));
			}
		}

		void Client::DrawBuilderHUD() {
			if (cg_hideHud)
				return;
			Player &p = GetWorld()->GetLocalPlayer().value();
			paletteView->Draw();
			mapView->Draw();
			DrawBuilderIcons();
			DrawBuilderCursor();
			if (cg_DrawDragCursorPos && p.IsBlockCursorDragging())
				DrawBuilderDragCursor();
			DrawMapObjectPosition();
		}

		void Client::DrawBuilderIcons() {
			Player &p = GetWorld()->GetLocalPlayer().value();

			float iconX = renderer->ScreenWidth() * 0.52f;
			float iconY = renderer->ScreenHeight() * 0.52f;

			Handle<IImage> imgVolume;
			switch (p.GetCurrentVolumeType()) {
				case VolumeSingle: {
					imgVolume = renderer->RegisterImage("Gfx/BuildMode/SingleBlock.png");
				} break;
				case VolumeLine: {
					imgVolume = renderer->RegisterImage("Gfx/BuildMode/BlockLine.png");
				} break;
				case VolumeBox: {
					imgVolume = renderer->RegisterImage("Gfx/BuildMode/Box.png");
				} break;
				case VolumeBall: {
					imgVolume = renderer->RegisterImage("Gfx/BuildMode/Ball.png");
				} break;
				case VolumeCylinderX:
				case VolumeCylinderY:
				case VolumeCylinderZ:{
					imgVolume = renderer->RegisterImage("Gfx/BuildMode/Cylinder.png");
				} break;
				default: return;
			}
			renderer->SetColorAlphaPremultiplied(MakeVector4(1.f, 1.f, 1.f, (float)cg_hudTransparency));
			renderer->DrawImage(imgVolume, MakeVector2(iconX, iconY));

			Handle<IImage> imgTool;
			switch (p.GetCurrentMapTool()) {
				case noMapTool: {
					Handle<IImage> imgDestroy;
					if (p.GetWeaponInput().secondary) {
						imgDestroy = renderer->RegisterImage("Gfx/BuildMode/Destroy.png");
						renderer->DrawImage(imgDestroy, MakeVector2(iconX + imgVolume->GetWidth(), iconY));
					}
				} return;
				case ToolPainting: {
					imgTool = renderer->RegisterImage("Gfx/BuildMode/Paint.png");
				} break;
				case ToolBrushing: {
					imgTool = renderer->RegisterImage("Gfx/BuildMode/Brush.png");
				} break;
				case ToolCopying: {
					imgTool = renderer->RegisterImage("Gfx/BuildMode/Copy.png");
				} break;
				case ToolMapObject: {
					IntVector3 icol;
					switch (p.GetCurrentMapObjectType()) {
						case ObjTentTeam1:
						case ObjTentTeam2:
						case ObjTentNeutral: {
							imgTool = renderer->RegisterImage("Gfx/BuildMode/Tent.png");
							icol = world->GetTeam(p.GetCurrentMapObjectType() - ObjTentTeam1).color;
						} break;
						case ObjIntelTeam1:
						case ObjIntelTeam2: {
							imgTool = renderer->RegisterImage("Gfx/BuildMode/Intel.png");
							icol = world->GetTeam(p.GetCurrentMapObjectType() - ObjIntelTeam1).color;
						} break;
						case ObjSpawnTeam1:
						case ObjSpawnTeam2: {
							imgTool = renderer->RegisterImage("Gfx/BuildMode/Spawn.png");
							icol = world->GetTeam(p.GetCurrentMapObjectType() - ObjSpawnTeam1).color;
						} break;
						default: return;
					}
					Vector4 col;
					col.x = icol.x / 255.f;
					col.y = icol.y / 255.f;
					col.z = icol.z / 255.f;
					col.w = (float)cg_hudTransparency;
					renderer->SetColorAlphaPremultiplied(col);
					float h = imgTool->GetHeight();
					float w = imgTool->GetWidth();
					renderer->DrawImage(imgTool, MakeVector2(iconX, iconY + imgTool->GetHeight()), AABB2(0, h, w, h));

					Handle<IImage> imgDestroy;
					if (p.GetWeaponInput().secondary) {
						imgDestroy = renderer->RegisterImage("Gfx/BuildMode/Destroy.png");
						renderer->SetColorAlphaPremultiplied(MakeVector4(1.f, 1.f, 1.f, (float)cg_hudTransparency));
						renderer->DrawImage(imgDestroy, MakeVector2(iconX + imgVolume->GetWidth(), iconY));
					}
				} return;
				default: return;
			}
			renderer->DrawImage(imgTool, MakeVector2(iconX, iconY + imgVolume->GetHeight()));

			Handle<IImage> imgDestroy;
			if (p.GetWeaponInput().secondary) {
				imgDestroy = renderer->RegisterImage("Gfx/BuildMode/Destroy.png");
				renderer->DrawImage(imgDestroy, MakeVector2(iconX + imgVolume->GetWidth(), iconY));
			}
		}

		void Client::DrawBuilderCursor() {
			Player &p = GetWorld()->GetLocalPlayer().value();

			float curX = renderer->ScreenWidth() * 0.52f;
			float curY = renderer->ScreenHeight() * 0.51f;

			char buf[256];
			sprintf(buf, "%dx %dy %dz", p.GetBlockCursorPos());
			std::string str = buf;

			IFont &font = fontManager->GetGuiFont();
			float margin = 5.f;

			auto size = font.Measure(str);
			size += Vector2(margin * 2.f, margin * 2.f);
			size *= 0.9f;

			auto pos = Vector2(curX, curY - size.y);
			//y - size.y put the "anchor" point at the bottom so cursorpos ui doesnt overlap with build icons 

			renderer->SetColorAlphaPremultiplied(Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_hudTransparency));
			renderer->DrawImage(nullptr, AABB2(pos.x, pos.y, size.x, size.y));
			font.DrawShadow(
				str, pos + Vector2(margin, margin), 0.9f,
				Vector4(1.f, 1.f, 1.f, (float)cg_hudTransparency),
				Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_hudTransparency)
			);
		}

		void Client::DrawBuilderDragCursor() {
			Player &p = GetWorld()->GetLocalPlayer().value();
			IntVector3 IntDragPos = p.GetBlockCursorDragPos();
			Vector3 DragPos;
			DragPos.x = IntDragPos.x;
			DragPos.y = IntDragPos.y;
			DragPos.z = IntDragPos.z;

			Vector3 posxyz = Project(DragPos);
			Vector2 pos = {posxyz.x, posxyz.y};
			if (posxyz.z <= 0 || posxyz.z > 1.0004f)
				return;

			char buf[256];
			sprintf(buf, "%dx %dy %dz", IntDragPos);
			std::string str = buf;

			IFont &font = fontManager->GetGuiFont();
			float margin = 5.f;

			auto size = font.Measure(str);
			size += Vector2(margin * 2.f, margin * 2.f);
			size *= 0.8f;

			renderer->SetColorAlphaPremultiplied(Vector4(0.f, 0.f, 0.f, 0.5f));
			renderer->DrawImage(nullptr, AABB2(pos.x, pos.y, size.x, size.y));
			font.DrawShadow(
				str, pos + Vector2(margin, margin), 0.8f,
				Vector4(1.f, 1.f, 1.f, (float)cg_hudTransparency),
				Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_hudTransparency)
			);
		}

		void Client::DrawMapObjectPosition() {
			if (IGameMode::m_CTF == world->GetMode()->ModeType()) {
				CTFGameMode &mode = dynamic_cast<CTFGameMode &>(world->GetMode().value());

				for (int tId = 0; tId < 2; tId++) {
					//draw base
					Vector3 pos3d = mode.GetTeam(tId).basePos;

					Vector3 posxyz = Project(pos3d);
					if (posxyz.z <= 0 || posxyz.z > 1.0004f)
						continue;
					Vector2 pos = {posxyz.x, posxyz.y};
					char buf[64];
					sprintf(buf, "%.02fx %.02fy %.02fz", pos3d.x, pos3d.y, pos3d.z);

					IFont &font = fontManager->GetGuiFont();
					Vector2 size = font.Measure(buf);
					size *= 0.8f;
					pos.x -= size.x * .5f;
					pos.y -= size.y;
					font.DrawShadow(
						buf, pos, 0.8f, MakeVector4(1, 1, 1, (float)cg_hudTransparency),
						MakeVector4(0, 0, 0, 0.5 * (float)cg_hudTransparency)
					);

					// draw flag
					if (!mode.GetTeam(1 - tId).hasIntel) {
						Vector3 pos3d = mode.GetTeam(tId).flagPos;

						Vector3 posxyz = Project(pos3d);
						if (posxyz.z <= 0 || posxyz.z > 1.0004f)
							continue;
						Vector2 pos = {posxyz.x, posxyz.y};
						char buf[64];
						sprintf(buf, "%.02fx %.02fy %.02fz", pos3d.x, pos3d.y, pos3d.z);

						IFont &font = fontManager->GetGuiFont();
						Vector2 size = font.Measure(buf);
						size *= 0.8f;
						pos.x -= size.x * .5f;
						pos.y -= size.y;
						font.DrawShadow(
							buf, pos, 0.8f, MakeVector4(1, 1, 1, (float)cg_hudTransparency),
							MakeVector4(0, 0, 0, 0.5 * (float)cg_hudTransparency)
						);
					}
				}
			} else if (IGameMode::m_TC == world->GetMode()->ModeType()) {
				TCGameMode &mode = dynamic_cast<TCGameMode &>(world->GetMode().value());
				int cnt = mode.GetNumTerritories();

				for (int tId = 0; tId < cnt; tId++) {
					Vector3 pos3d = mode.GetTerritory(tId).pos;

					Vector3 posxyz = Project(pos3d);
					if (posxyz.z <= 0 || posxyz.z > 1.0004f)
						continue;
					Vector2 pos = {posxyz.x, posxyz.y};
					char buf[64];
					sprintf(buf, "%.02fx %.02fy %.02fz", pos3d.x, pos3d.y, pos3d.z);

					IFont &font = fontManager->GetGuiFont();
					Vector2 size = font.Measure(buf);
					size *= 0.8f;
					pos.x -= size.x * .5f;
					pos.y -= size.y;
					font.DrawShadow(
						buf, pos, 0.8f, MakeVector4(1, 1, 1, (float)cg_hudTransparency),
						MakeVector4(0, 0, 0, 0.5 * (float)cg_hudTransparency)
					);
				}
			}
		}

		void Client::DrawAlert() {
			SPADES_MARK_FUNCTION();

			IFont &font = fontManager->GetGuiFont();
			float scrWidth = renderer->ScreenWidth();
			float scrHeight = renderer->ScreenHeight();
			auto &r = renderer;

			const float fadeOutTime = 1.f;

			float fade = 1.f - (time - alertDisappearTime) / fadeOutTime;
			fade = std::min(fade, 1.f);
			if (fade <= 0.f) {
				return;
			}

			float borderFade = 1.f - (time - alertAppearTime) * 1.5f;
			borderFade = std::max(std::min(borderFade, 1.f), 0.f);
			borderFade *= fade;

			Handle<IImage> alertIcon = renderer->RegisterImage("Gfx/AlertIcon.png");

			Vector2 textSize = font.Measure(alertContents);
			Vector2 contentsSize = textSize;
			contentsSize.y = std::max(contentsSize.y, 16.f);
			if (alertType != AlertType::Notice) {
				contentsSize.x += 22.f;
			}

			// add margin
			const float margin = 8.f;
			contentsSize.x += margin * 2.f;
			contentsSize.y += margin * 2.f;

			contentsSize.x = floorf(contentsSize.x);
			contentsSize.y = floorf(contentsSize.y);

			Vector2 pos = (Vector2(scrWidth, scrHeight) - contentsSize) * Vector2(0.5f, 0.7f);
			pos.y += 40.f;

			pos.x = floorf(pos.x);
			pos.y = floorf(pos.y);

			Vector4 color;

			// draw border
			switch (alertType) {
				case AlertType::Notice: color = Vector4(0.f, 0.f, 0.f, 0.f); break;
				case AlertType::Warning: color = Vector4(1.f, 1.f, 0.f, .7f * (float)cg_hudTransparency); break;
				case AlertType::Error: color = Vector4(1.f, 0.f, 0.f, .7f * (float)cg_hudTransparency); break;
			}
			color *= borderFade;
			r->SetColorAlphaPremultiplied(color);

			const float border = 1.f;
			r->DrawImage(nullptr, AABB2(pos.x - border, pos.y - border,
			                            contentsSize.x + border * 2.f, border));
			r->DrawImage(nullptr, AABB2(pos.x - border, pos.y + contentsSize.y,
			                            contentsSize.x + border * 2.f, border));

			r->DrawImage(nullptr, AABB2(pos.x - border, pos.y, border, contentsSize.y));
			r->DrawImage(nullptr, AABB2(pos.x + contentsSize.x, pos.y, border, contentsSize.y));

			// fill background
			color = Vector4(0.f, 0.f, 0.f, fade * 0.5f * (float)cg_hudTransparency);
			r->SetColorAlphaPremultiplied(color);
			r->DrawImage(nullptr, AABB2(pos.x, pos.y, contentsSize.x, contentsSize.y));

			// draw icon
			switch (alertType) {
				case AlertType::Notice: color = Vector4(0.f, 0.f, 0.f, 0.f); break;
				case AlertType::Warning: color = Vector4(1.f, 1.f, 0.f, (float)cg_hudTransparency); break;
				case AlertType::Error: color = Vector4(1.f, 0.f, 0.f, (float)cg_hudTransparency); break;
			}
			color *= fade;
			r->SetColorAlphaPremultiplied(color);

			r->DrawImage(alertIcon,
			             Vector2(pos.x + margin, pos.y + (contentsSize.y - 16.f) * 0.5f));

			// draw text
			color = Vector4(1.f, 1.f, 1.f, (float)cg_hudTransparency);
			color *= fade;

			font.DrawShadow(alertContents,
			                Vector2(pos.x + contentsSize.x - textSize.x - margin,
			                        pos.y + (contentsSize.y - textSize.y) * 0.5f),
			                1.f, color, Vector4(0.f, 0.f, 0.f, fade * 0.5f * (float)cg_hudTransparency));
		}

		void Client::DrawHealth() {
			SPADES_MARK_FUNCTION();

			Player &p = GetWorld()->GetLocalPlayer().value();
			// float scrWidth = renderer->ScreenWidth();
			float scrHeight = renderer->ScreenHeight();

			std::string str = std::to_string(p.GetHealth());

			Vector4 numberColor = {1, 1, 1, (float)cg_hudTransparency};

			if (p.GetHealth() == 0) {
				numberColor.y = 0.3f;
				numberColor.z = 0.3f;
			} else if (p.GetHealth() <= 50) {
				numberColor.z = 0.3f;
			}

			IFont &font = fontManager->GetSquareDesignFont();
			Vector2 size = font.Measure(str);
			Vector2 pos = MakeVector2(16.f, scrHeight - 16.f);
			pos.y -= size.y;
			font.DrawShadow(str, pos, 1.f, numberColor, MakeVector4(0, 0, 0, 0.5 * (float)cg_hudTransparency));
		}

		void Client::Draw2DWithWorld() {
			SPADES_MARK_FUNCTION();

			for (auto &ent : localEntities) {
				ent->Render2D();
			}

			stmp::optional<Player &> p = GetWorld()->GetLocalPlayer();
			if (p) {
				DrawHurtSprites();
				DrawHurtScreenEffect();
				DrawHottrackedPlayerName();

				if (!cg_hideHud) {
					tcView->Draw();

					if (IsFirstPerson(GetCameraMode())) {
						DrawFirstPersonHUD();
					}
				}

				if (p->GetTeamId() < 2) {
					// player is not spectator
					if (cg_playerStats)
							DrawPlayerStats();
					if (cg_debugHitTest && p->IsToolWeapon() &&
						(float)cg_hitTestTransparency > 0)
						DrawHitTestDebugger();
					if (p->IsAlive()) {
						DrawJoinedAlivePlayerHUD();
						if (cg_damageIndicators)
							DrawDamageIndicators();
					} else {
						DrawDeadPlayerHUD();
						DrawSpectateHUD();
					}
				} else {
					if (!p->IsBuilder()) {
						DrawSpectateHUD();
						if (cg_specNames)
							DrawAllPlayerNames();
					} else {
						DrawBuilderHUD();
					}
				}

				if (!cg_hideHud) {
					DrawAlert();

					chatWindow->Draw();
					killfeedWindow->Draw();

					if (demo.replaying)
						DrawDemoProgress();
				}

				// large map view should come in front
				largeMapView->Draw();

				// --- end "player is there" render
			} else {
				// world exists, but no local player: not joined

				scoreboard->Draw();

				DrawAlert();
			}

			if (!cg_hideHud)
				centerMessageView->Draw();

			if (scoreboardVisible || !p) {
				scoreboard->Draw();
				DrawPlayingTime();
			}

			if (IsLimboViewActive())
				limbo->Draw();
		}

		void Client::Draw2DWithoutWorld() {
			SPADES_MARK_FUNCTION();
			// no world; loading?
			float scrWidth = renderer->ScreenWidth();
			float scrHeight = renderer->ScreenHeight();

			DrawSplash();

			Handle<IImage> img;

			std::string msg = net->GetStatusString();
			IFont &font = fontManager->GetGuiFont();
			Vector2 textSize = font.Measure(msg);
			font.Draw(msg, MakeVector2(scrWidth - 16.f, scrHeight - 24.f) - textSize, 1.f,
			          MakeVector4(1, 1, 1, 0.95f));

			img = renderer->RegisterImage("Gfx/White.tga");

			if (net->GetStatus() == NetClientStatusReceivingMap) {
				// Normal progress bar
				float progress = mapReceivingProgressSmoothed;

				renderer->SetColorAlphaPremultiplied(MakeVector4(0.2f, 0.2f, 0.2f, 0.2f));
				renderer->DrawImage(img, AABB2(scrWidth - 236.f, scrHeight - 18.f, 222.f, 4.f));

				renderer->SetColorAlphaPremultiplied(MakeVector4(1.0f, 1.0f, 1.0f, 1.0f));
				renderer->DrawImage(
				  img, AABB2(scrWidth - 236.f, scrHeight - 18.f, 222.f * progress, 4.f));
			} else {
				// Indeterminate progress bar
				float pos = timeSinceInit / 3.6f;
				pos -= floorf(pos);
				pos = 1.f - pos * 2.0f;
				for (float v = 0; v < 0.6f; v += 0.14f) {
					float p = pos + v;
					if (p < 0.01f || p > .99f)
						continue;
					p = asin(p * 2.f - 1.f);
					p = p / (float)M_PI + 0.5f;

					float op = p * (1.f - p) * 4.f;
					renderer->SetColorAlphaPremultiplied(MakeVector4(op, op, op, op));
					renderer->DrawImage(
					  img, AABB2(scrWidth - 236.f + p * 234.f, scrHeight - 18.f, 4.f, 4.f));
				}
			}

			DrawAlert();
		}

		void Client::DrawStats() {
			SPADES_MARK_FUNCTION();

			if (!cg_stats)
				return;
			if (!scoreboardVisible && (int)cg_stats == 3)
				return;

			char buf[256];
			std::string str;
			std::string fpsStr;
			std::string upsStr;
			std::string pingStr;
			std::string updownStr;

			Vector4 fpsColor;
			Vector4 upsColor;
			Vector4 pingColor;

			{
				auto fps = fpsCounter.GetFps();
				if (fps == 0.0)
					fpsStr += "--.-- fps";
				else {
					sprintf(buf, "%.02f fps", fps);
					fpsStr += buf;
				}
				if (cg_statsColor) {
					if (fps > 60)
						fps = 60.f;
					fps *= 0.016f;
					fpsColor = MakeVector4(1.f - fps, fps, 0.f, (float)cg_statsTransparency);
				}
			}
			{
				// Display world updates per second
				auto ups = upsCounter.GetFps();
				if (ups == 0.0)
					upsStr  += ", --.-- ups";
				else {
					sprintf(buf, ", %.02f ups", ups);
					upsStr  += buf;
				}
				if (cg_statsColor) {
					if (ups > 20) //upperlimit for voxlap
						ups = 20.f;
					ups *= 0.05f;
					upsColor = MakeVector4(1.f - ups, ups, 0.f, (float)cg_statsTransparency);
				}
			}

			if (net && !demo.replaying) {
				float ping = net->GetPing();
				auto upbps = net->GetUplinkBps();
				auto downbps = net->GetDownlinkBps();

				sprintf(buf, ", ping: %dms, ", (int)ping);
				pingStr += buf;
				if (cg_statsColor) {
					if (ping > 300) //this is very generous
						ping = 300;
					ping *= 0.0033f;
					pingColor = MakeVector4(ping, 1.f - ping, 0.f, (float)cg_statsTransparency);
				}

				sprintf(buf, "up/down: %.02f/%.02fkbps", upbps / 1000.0, downbps / 1000.0);
				updownStr += buf;
			}

			str += fpsStr;
			str += upsStr;
			str += pingStr;
			str += updownStr;

			float scrWidth = renderer->ScreenWidth();
			float scrHeight = renderer->ScreenHeight();
			IFont &font = fontManager->GetGuiFont();
			float margin = 5.f;

			auto size = font.Measure(str);
			size += Vector2(margin * 2.f, margin * 2.f);

			auto pos = (Vector2(scrWidth, scrHeight) - size);

			pos *= MakeVector2(0.5F, ((int)cg_stats < 2) ? 1.0F : 0.0F);
			pos.y += ((int)cg_stats < 2) ? (margin * 0.5F) : -(margin * 0.5F);

			if (cg_statsBackground) {
				renderer->SetColorAlphaPremultiplied(Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_statsTransparency));
				renderer->DrawImage(nullptr, AABB2(pos.x, pos.y, size.x, size.y));
			}

			if (cg_statsColor) {
				font.DrawShadow(fpsStr, pos + Vector2(margin, margin), 
				1.f, fpsColor, Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_statsTransparency));
			
				font.DrawShadow(upsStr, pos + Vector2(margin, margin) + 
				Vector2(font.Measure(fpsStr).x, 0.f), 1.f, upsColor, Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_statsTransparency));
			
				font.DrawShadow(pingStr, pos + Vector2(margin, margin) +
				Vector2(font.Measure(fpsStr).x + font.Measure(upsStr).x, 0.f), 
				1.f, pingColor, Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_statsTransparency));
			
				font.DrawShadow(updownStr, pos + Vector2(margin, margin) + Vector2(font.Measure(fpsStr).x + 
				font.Measure(upsStr).x + font.Measure(pingStr).x, 0.f), 1.f, 
				Vector4(1.f, 1.f, 1.f, (float)cg_statsTransparency), Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_statsTransparency));
				return;
			}

			font.DrawShadow(str, pos + Vector2(margin, margin), 1.f, Vector4(1.f, 1.f, 1.f, (float)cg_statsTransparency),
			                Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_statsTransparency));
		}

		void Client::DrawDemoProgress() {
			SPADES_MARK_FUNCTION();

			float scrWidth = renderer->ScreenWidth();
			float scrHeight = renderer->ScreenHeight();
			IFont &font = fontManager->GetGuiFont();
			float margin = 5.f;

			int deltaTime = (int)net->GetDemoDeltaTime();
			int hour = deltaTime / 3600;
			int min  = (deltaTime % 3600) / 60;
			int sec  = deltaTime % 60;
			char buf[64];
			sprintf(buf, "%02d:%02d:%02d / ", hour, min, sec);

			std::string str = "Demo: ";
			str += buf;
			str += net->GetDemoEndTimeStr();

			auto size = font.Measure(str);
			size += Vector2(margin * 2.f, margin * 2.f);

			auto pos = (Vector2(scrWidth, scrHeight - size.y - 4) - size) * Vector2(0.5f, 1.f);

			renderer->SetColorAlphaPremultiplied(Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_hudTransparency));
			renderer->DrawImage(nullptr, AABB2(pos.x, pos.y, size.x, size.y));
			font.DrawShadow(
				str, pos + Vector2(margin, margin), 1.f,
				Vector4(1.f, 1.f, 1.f, (float)cg_hudTransparency),
				Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_hudTransparency)
			);

			if (!(bool)cg_DemoProgressBarOnlyInUi || ((bool)cg_DemoProgressBarOnlyInUi && demo.uiActive)) {
				float sizeBar = scrWidth * 0.5f;
				float sizeBg = sizeBar + 12;
				float sizeP = sizeBar * net->GetDemoDeltaTime() / net->GetDemoEndTime();

				Handle<IImage> img = renderer->RegisterImage("Gfx/White.tga");

				//draw progressbar background
				pos = (Vector2(scrWidth - sizeBg, scrHeight - size.y * 3.f)) * Vector2(0.5f, 1.f);
				renderer->SetColorAlphaPremultiplied(MakeVector4(0.f, 0.f, 0.f, 0.8f * (float)cg_hudTransparency));
				renderer->DrawImage(img, AABB2(pos.x, pos.y, sizeBg, 18.f));

				//draw progressbar
				pos += Vector2(6, 4);
				renderer->SetColorAlphaPremultiplied(MakeVector4(0.6f, 0.6f, 0.6f, 0.4f * (float)cg_hudTransparency));
				renderer->DrawImage(img, AABB2(pos.x, pos.y, sizeP, 10.f));
				
				if (demo.uiActive) {
					//draw cursor
					Handle<IImage> cursor = renderer->RegisterImage("Gfx/Limbo/Cursor.png");
					renderer->SetColorAlphaPremultiplied(MakeVector4(1.f, 1.f, 1.f, 1.f));
					renderer->DrawImage(cursor, AABB2(demo.cursor.x - 8, demo.cursor.y - 8, 32, 32));

					if (demo.skipTo >= 0) {
						//draw delta pos
						pos += Vector2(sizeP - 2, -2);
						renderer->SetColorAlphaPremultiplied(MakeVector4(1.f, 1.f, 1.f, (float)cg_hudTransparency));
						renderer->DrawImage(img, AABB2(pos.x, pos.y, 4, 14.f));

						//draw hovered time
						float hoverTime = demo.skipTo;
						int hour = (int)hoverTime / 3600;
						int min  = ((int)hoverTime % 3600) / 60;
						int sec  = (int)hoverTime % 60;
						sprintf(buf, " %02d:%02d:%02d ", hour, min, sec);
						str = buf;
						auto size = font.Measure(str);
						size += Vector2(margin * 2.f, margin * 2.f);

						pos = Vector2(demo.cursor.x - size.x * 0.5f, pos.y - size.y * 1.2f);
						renderer->SetColorAlphaPremultiplied(Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_hudTransparency));
						renderer->DrawImage(nullptr, AABB2(pos.x, pos.y, size.x, size.y));
						font.DrawShadow(
							str, pos + Vector2(margin, margin), 1.f,
							Vector4(1.f, 1.f, 1.f, (float)cg_hudTransparency),
							Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_hudTransparency)
						);
					}
				}
			}
		}

		void Client::Draw2D() {
			SPADES_MARK_FUNCTION();

			if (GetWorld()) {
				Draw2DWithWorld();
			} else {
				Draw2DWithoutWorld();
			}

			DrawStats();
		}
	} // namespace client
} // namespace spades

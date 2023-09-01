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
#include <ctime>
#include <iomanip>

#include "Client.h"
#include "Fonts.h"
#include <Core/FileManager.h>
#include <Core/IStream.h>
#include <Core/Settings.h>
#include <Core/Strings.h>
#include <Core/ServerAddress.h>

#include "IAudioChunk.h"
#include "IAudioDevice.h"

#include "CenterMessageView.h"
#include "ChatWindow.h"
#include "ClientPlayer.h"
#include "ClientUI.h"
#include "HurtRingView.h"
#include "LimboView.h"
#include "MapView.h"
#include "PaletteView.h"
#include "ScoreboardView.h"
#include "TCProgressView.h"

#include "Corpse.h"
#include "ILocalEntity.h"
#include "SmokeSpriteEntity.h"

#include "GameMap.h"
#include "GameMapWrapper.h"
#include "Weapon.h"
#include "World.h"

#include "NetClient.h"

#include "CTFGameMode.h"
#include "TCGameMode.h"

DEFINE_SPADES_SETTING(cg_chatBeep, "1");
DEFINE_SPADES_SETTING(cg_alertSounds, "1");

DEFINE_SPADES_SETTING(cg_serverAlert, "1");

DEFINE_SPADES_SETTING(cg_skipDeadPlayersWhenDead, "0");

SPADES_SETTING(cg_playerName);
DEFINE_SPADES_SETTING(cg_mentionWord);
DEFINE_SPADES_SETTING(cg_ignoreChatMessages, "0");
DEFINE_SPADES_SETTING(cg_ignorePrivateMessages, "0");
DEFINE_SPADES_SETTING(cg_showTeamMateLocation, "1");

DEFINE_SPADES_SETTING(cg_demoRecord, "1", "0");

namespace spades {
	namespace client {
		Client::Client(
			Handle<IRenderer> r, Handle<IAudioDevice> audioDev,
			const ServerAddress &host, Handle<FontManager> fontManager,
			int mode, std::string map_demo, std::string canvas
		)   : playerName(cg_playerName.operator std::string().substr(0, 15)),
		      logStream(nullptr),
		      hostname(host),
		      renderer(r),
		      audioDevice(audioDev),

		      time(0.f),
		      readyToClose(false),

		      worldSubFrame(0.f),
		      frameToRendererInit(5),
		      timeSinceInit(0.f),
		      lastShotTime(0.f),
		      hasLastTool(false),
		      lastPosSentTime(0.f),
		      lastOriSentTime(0.f),
		      lastAliveTime(0.f),
		      lastKills(0),

		      hasDelayedReload(false),
		      shotsCount(0),
		      clicksPlayer(0),
		      hitsPlayer(0),
		      clicksHead(0),
		      hitsHead(0),
		      curKills(0),
		      meleeKills(0),
		      nadeKills(0),
		      curDeaths(0),
		      curStreak(0),
		      bestStreak(0),
		      placedBlocks(0),

		      localFireVibrationTime(-1.f),
		      grenadeVibration(0.f),
		      grenadeVibrationSlow(0.f),
		      scoreboardVisible(false),
		      flashlightOn(false),
		      hitFeedbackIconState(0.f),
		      hitFeedbackFriendly(false),
		      focalLength(20.f),
		      targetFocalLength(20.f),
		      autoFocusEnabled(true),
		      followedPlayerId(0),

		      inGameLimbo(false),
		      fontManager(fontManager),
		      alertDisappearTime(-10000.f),
		      lastMyCorpse(nullptr),
		      corpseSoftTimeLimit(30.f), // FIXME: this is not used
		      corpseSoftLimit(6),
		      corpseHardLimit(16),
		      nextScreenShotIndex(0),
		      nextMapShotIndex(0),
		      hitTestSizeToggle(false) {
			SPADES_MARK_FUNCTION();
			SPLog("Initializing...");

			demo.speed = 1;
			demo.replaying = false;
			if (mode == isDemo) {
				demo.replaying = true;
				demo.fileName = map_demo;
				demo.Initiate();
			}

			isLocalMapEditor = isMapEditor = false;
			if (mode == isMap) {
				mapFileName = map_demo;
				canvasFileName = canvas;
				isLocalMapEditor = true;
			}

			renderer->SetFogDistance(128.f);
			renderer->SetFogColor(MakeVector3(.8f, 1.f, 1.f));

			chatWindow = stmp::make_unique<ChatWindow>(this, &GetRenderer(),
			                                           &fontManager->GetGuiFont(), false);
			killfeedWindow =
			  stmp::make_unique<ChatWindow>(this, &GetRenderer(), &fontManager->GetGuiFont(), true);

			hurtRingView = stmp::make_unique<HurtRingView>(this);
			centerMessageView =
			  stmp::make_unique<CenterMessageView>(this, &fontManager->GetLargeFont());
			mapView = stmp::make_unique<MapView>(this, false);
			largeMapView = stmp::make_unique<MapView>(this, true);
			scoreboard = stmp::make_unique<ScoreboardView>(this);
			limbo = stmp::make_unique<LimboView>(this);
			paletteView = stmp::make_unique<PaletteView>(this);
			tcView = stmp::make_unique<TCProgressView>(*this);
			scriptedUI =
			  Handle<ClientUI>::New(renderer.GetPointerOrNull(), audioDev.GetPointerOrNull(),
			                        fontManager.GetPointerOrNull(), this);

			renderer->SetGameMap(nullptr);
		}

		void Client::SetWorld(spades::client::World *w) {
			SPADES_MARK_FUNCTION();

			if (world.get() == w) {
				return;
			}

			scriptedUI->CloseUI();

			RemoveAllCorpses();
			RemoveAllLocalEntities();

			lastHealth = 0;
			lastHurtTime = -100.f;
			hurtRingView->ClearAll();
			scoreboardVisible = false;
			flashlightOn = false;

			clientPlayers.clear();

			if (world) {
				world->SetListener(nullptr);
				renderer->SetGameMap(nullptr);
				audioDevice->SetGameMap(nullptr);
				world = nullptr;
				map = nullptr;
			}
			world.reset(w);
			if (world) {
				SPLog("World set");

				// initialize player view objects
				clientPlayers.resize(world->GetNumPlayerSlots());
				for (size_t i = 0; i < world->GetNumPlayerSlots(); i++) {
					auto p = world->GetPlayer(static_cast<unsigned int>(i));
					if (p) {
						clientPlayers[i] = Handle<ClientPlayer>::New(*p, *this);
					} else {
						clientPlayers[i] = nullptr;
					}
				}

				world->SetListener(this);
				map = world->GetMap();
				renderer->SetGameMap(map);
				audioDevice->SetGameMap(map.GetPointerOrNull());
				NetLog("------ World Loaded ------");
			} else {

				SPLog("World removed");
				NetLog("------ World Unloaded ------");
			}

			limbo->SetSelectedTeam(2);
			limbo->SetSelectedWeapon(RIFLE_WEAPON);

			worldSubFrame = 0.f;
			worldSetTime = time;
			inGameLimbo = false;
		}

		Client::~Client() {
			SPADES_MARK_FUNCTION();

			NetLog("Disconnecting");

			DrawDisconnectScreen();

			if (logStream) {
				SPLog("Closing netlog");
				logStream.reset();
			}

			if (net) {
				SPLog("Disconnecting");
				net->Disconnect();
				net.reset();
			}

			SPLog("Disconnected");

			RemoveAllLocalEntities();
			RemoveAllCorpses();

			renderer->SetGameMap(nullptr);
			audioDevice->SetGameMap(nullptr);

			clientPlayers.clear();

			scriptedUI->ClientDestroyed();
			tcView.reset();
			limbo.reset();
			scoreboard.reset();
			mapView.reset();
			largeMapView.reset();
			chatWindow.reset();
			killfeedWindow.reset();
			paletteView.reset();
			centerMessageView.reset();
			hurtRingView.reset();
			world.reset();
		}

		/** Initiate an initialization which likely to take some time */
		void Client::DoInit() {
			renderer->Init();
			SmokeSpriteEntity::Preload(renderer.GetPointerOrNull());

			renderer->RegisterImage("Textures/Fluid.png");
			renderer->RegisterImage("Textures/WaterExpl.png");
			renderer->RegisterImage("Gfx/White.tga");
			audioDevice->RegisterSound("Sounds/Weapons/Block/Build.opus");
			audioDevice->RegisterSound("Sounds/Weapons/Impacts/FleshLocal1.opus");
			audioDevice->RegisterSound("Sounds/Weapons/Impacts/FleshLocal2.opus");
			audioDevice->RegisterSound("Sounds/Weapons/Impacts/FleshLocal3.opus");
			audioDevice->RegisterSound("Sounds/Weapons/Impacts/FleshLocal4.opus");
			audioDevice->RegisterSound("Sounds/Misc/SwitchMapZoom.opus");
			audioDevice->RegisterSound("Sounds/Misc/OpenMap.opus");
			audioDevice->RegisterSound("Sounds/Misc/CloseMap.opus");
			audioDevice->RegisterSound("Sounds/Player/Flashlight.opus");
			audioDevice->RegisterSound("Sounds/Player/Footstep1.opus");
			audioDevice->RegisterSound("Sounds/Player/Footstep2.opus");
			audioDevice->RegisterSound("Sounds/Player/Footstep3.opus");
			audioDevice->RegisterSound("Sounds/Player/Footstep4.opus");
			audioDevice->RegisterSound("Sounds/Player/Footstep5.opus");
			audioDevice->RegisterSound("Sounds/Player/Footstep6.opus");
			audioDevice->RegisterSound("Sounds/Player/Footstep7.opus");
			audioDevice->RegisterSound("Sounds/Player/Footstep8.opus");
			audioDevice->RegisterSound("Sounds/Player/Wade1.opus");
			audioDevice->RegisterSound("Sounds/Player/Wade2.opus");
			audioDevice->RegisterSound("Sounds/Player/Wade3.opus");
			audioDevice->RegisterSound("Sounds/Player/Wade4.opus");
			audioDevice->RegisterSound("Sounds/Player/Wade5.opus");
			audioDevice->RegisterSound("Sounds/Player/Wade6.opus");
			audioDevice->RegisterSound("Sounds/Player/Wade7.opus");
			audioDevice->RegisterSound("Sounds/Player/Wade8.opus");
			audioDevice->RegisterSound("Sounds/Player/Run1.opus");
			audioDevice->RegisterSound("Sounds/Player/Run2.opus");
			audioDevice->RegisterSound("Sounds/Player/Run3.opus");
			audioDevice->RegisterSound("Sounds/Player/Run4.opus");
			audioDevice->RegisterSound("Sounds/Player/Run5.opus");
			audioDevice->RegisterSound("Sounds/Player/Run6.opus");
			audioDevice->RegisterSound("Sounds/Player/Run7.opus");
			audioDevice->RegisterSound("Sounds/Player/Run8.opus");
			audioDevice->RegisterSound("Sounds/Player/Run9.opus");
			audioDevice->RegisterSound("Sounds/Player/Run10.opus");
			audioDevice->RegisterSound("Sounds/Player/Run11.opus");
			audioDevice->RegisterSound("Sounds/Player/Run12.opus");
			audioDevice->RegisterSound("Sounds/Player/Jump.opus");
			audioDevice->RegisterSound("Sounds/Player/Land.opus");
			audioDevice->RegisterSound("Sounds/Player/WaterJump.opus");
			audioDevice->RegisterSound("Sounds/Player/WaterLand.opus");
			audioDevice->RegisterSound("Sounds/Weapons/SwitchLocal.opus");
			audioDevice->RegisterSound("Sounds/Weapons/Switch.opus");
			audioDevice->RegisterSound("Sounds/Weapons/Restock.opus");
			audioDevice->RegisterSound("Sounds/Weapons/RestockLocal.opus");
			audioDevice->RegisterSound("Sounds/Weapons/AimDownSightLocal.opus");
			renderer->RegisterImage("Gfx/Ball.png");
			renderer->RegisterModel("Models/Player/Dead.kv6");
			renderer->RegisterImage("Gfx/Spotlight.jpg");
			renderer->RegisterModel("Models/Weapons/Spade/Spade.kv6");
			renderer->RegisterModel("Models/Weapons/Block/Block2.kv6");
			renderer->RegisterModel("Models/Weapons/Grenade/Grenade.kv6");
			renderer->RegisterModel("Models/Weapons/SMG/Weapon.kv6");
			renderer->RegisterModel("Models/Weapons/SMG/WeaponNoMagazine.kv6");
			renderer->RegisterModel("Models/Weapons/SMG/Magazine.kv6");
			renderer->RegisterModel("Models/Weapons/Rifle/Weapon.kv6");
			renderer->RegisterModel("Models/Weapons/Rifle/WeaponNoMagazine.kv6");
			renderer->RegisterModel("Models/Weapons/Rifle/Magazine.kv6");
			renderer->RegisterModel("Models/Weapons/Shotgun/Weapon.kv6");
			renderer->RegisterModel("Models/Weapons/Shotgun/WeaponNoPump.kv6");
			renderer->RegisterModel("Models/Weapons/Shotgun/Pump.kv6");
			renderer->RegisterModel("Models/Player/Arm.kv6");
			renderer->RegisterModel("Models/Player/UpperArm.kv6");
			renderer->RegisterModel("Models/Player/LegCrouch.kv6");
			renderer->RegisterModel("Models/Player/TorsoCrouch.kv6");
			renderer->RegisterModel("Models/Player/Leg.kv6");
			renderer->RegisterModel("Models/Player/Torso.kv6");
			renderer->RegisterModel("Models/Player/Arms.kv6");
			renderer->RegisterModel("Models/Player/Head.kv6");
			renderer->RegisterModel("Models/MapObjects/Intel.kv6");
			renderer->RegisterModel("Models/MapObjects/CheckPoint.kv6");
			renderer->RegisterModel("Models/MapObjects/BlockCursorLine.kv6");
			renderer->RegisterModel("Models/MapObjects/BlockCursorSingle.kv6");
			renderer->RegisterImage("Gfx/Bullet/7.62mm.png");
			renderer->RegisterImage("Gfx/Bullet/9mm.png");
			renderer->RegisterImage("Gfx/Bullet/12gauge.png");
			renderer->RegisterImage("Gfx/CircleGradient.png");
			renderer->RegisterImage("Gfx/HurtSprite.png");
			renderer->RegisterImage("Gfx/HurtRing2.png");
			renderer->RegisterImage("Gfx/Intel.png");
			renderer->RegisterImage("Gfx/Killfeed/a-Rifle.png");
			renderer->RegisterImage("Gfx/Killfeed/b-SMG.png");
			renderer->RegisterImage("Gfx/Killfeed/c-Shotgun.png");
			renderer->RegisterImage("Gfx/Killfeed/d-Headshot.png");
			renderer->RegisterImage("Gfx/Killfeed/e-Melee.png");
			renderer->RegisterImage("Gfx/Killfeed/f-Grenade.png");
			renderer->RegisterImage("Gfx/Killfeed/g-Falling.png");
			renderer->RegisterImage("Gfx/Killfeed/h-Teamchange.png");
			renderer->RegisterImage("Gfx/Killfeed/i-Classchange.png");
			audioDevice->RegisterSound("Sounds/Feedback/Chat.opus");

			if (mumbleLink.init())
				SPLog("Mumble linked");
			else
				SPLog("Mumble link failed");

			mumbleLink.setContext(hostname.ToString(false));
			mumbleLink.setIdentity(playerName);

			net = stmp::make_unique<NetClient>(this);

			if (isLocalMapEditor) {
				try {
					if (canvasFileName.size() > 0)
						SPLog("Using Canvas Map: '%s'", canvasFileName.c_str());
					LoadLocalMapEditor();
					SPLog("Started local Map Editor. new Map: '%s'", mapFileName.c_str());
				} catch (const std::exception &e) {
					SPLog("MapEditor Error: %s", e.what());
				} catch (...) {
					SPRaise("MapEditor Error: couldnt start local MapEditor");
				}
				return;
			}

			if (demo.replaying) {
				try {
					net->StartDemo(demo.fileName, hostname, demo.replaying);
					SPLog("Demo Replay started: %s", demo.fileName.c_str());
				} catch (...) {
					SPRaise("Demo Replay Error: couldnt start Demo Replay");
				}
				return;
			}

			SPLog("Started connecting to '%s'", hostname.ToString(true).c_str());
			net->Connect(hostname);

			// decide log file name
			std::string fn = hostname.ToString(false);
			std::string fn2;
			{
				time_t t;
				struct tm tm;
				::time(&t);
				tm = *localtime(&t);
				char buf[256];
				snprintf(
					buf, sizeof(buf), "%04d%02d%02d%02d%02d%02d_", tm.tm_year + 1900,
					tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec
				);
				fn2 = buf;
			}

			for (size_t i = 0; i < fn.size(); i++) {
				char c = fn[i];
				if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) {
					fn2 += c;
				} else {
					fn2 += '_';
				}
			}

			if ((bool)cg_demoRecord) {
				try {
					net->StartDemo("", hostname);
				} catch (const std::exception &ex) {
					SPLog("Failed to open new demo file (%s)", ex.what());
				}
			}

			fn2 = "NetLogs/" + fn2 + ".log";

			try {
				logStream = FileManager::OpenForWriting(fn2.c_str());
				SPLog("Netlog Started at '%s'", fn2.c_str());
			} catch (const std::exception &ex) {
				SPLog("Failed to open netlog file '%s' (%s)", fn2.c_str(), ex.what());
			}
		}

		void Client::RunFrame(float dt) {
			SPADES_MARK_FUNCTION();

			fpsCounter.MarkFrame();

			if (frameToRendererInit > 0) {
				// waiting for renderer initialization

				DrawStartupScreen();

				frameToRendererInit--;
				if (frameToRendererInit == 0) {
					DoInit();

				} else {
					return;
				}
			}

			timeSinceInit += std::min(dt, .03f);

			// update network
			try {
				if (net->GetStatus() == NetClientStatusConnected)
					net->DoEvents(0);
				else
					net->DoEvents(10);
			} catch (const std::exception &ex) {
				if (net->GetStatus() == NetClientStatusNotConnected) {
					SPLog("Disconnected because of error:\n%s", ex.what());
					NetLog("Disconnected because of error:\n%s", ex.what());
					throw;
				} else {
					SPLog("Exception while processing network packets (ignored):\n%s", ex.what());
				}
			}

			hurtRingView->Update(dt);
			centerMessageView->Update(dt);
			mapView->Update(dt);
			largeMapView->Update(dt);

			UpdateDamageIndicators(dt);
			UpdateAutoFocus(dt);

			if (world) {
				UpdateWorld(dt);
				mumbleLink.update(world->GetLocalPlayer().get_pointer());
			} else {
				renderer->SetFogColor(MakeVector3(0.f, 0.f, 0.f));
			}

			chatWindow->Update(dt);
			killfeedWindow->Update(dt);
			limbo->Update(dt);

			// The loading screen
			if (net->GetStatus() == NetClientStatusReceivingMap) {
				// Apply temporal smoothing on the progress value
				float progress = net->GetMapReceivingProgress();

				if (mapReceivingProgressSmoothed > progress) {
					mapReceivingProgressSmoothed = progress;
				} else {
					mapReceivingProgressSmoothed +=
					  (progress - mapReceivingProgressSmoothed) * (1.0 - powf(.05f, dt));
				}
			} else {
				mapReceivingProgressSmoothed = 0.0;
			}

			// CreateSceneDefinition also can be used for sounds
			SceneDefinition sceneDef = CreateSceneDefinition();
			lastSceneDef = sceneDef;
			UpdateMatrices();

			// Update sounds
			try {
				audioDevice->Respatialize(sceneDef.viewOrigin, sceneDef.viewAxis[2],
				                          sceneDef.viewAxis[1]);
			} catch (const std::exception &ex) {
				SPLog("Audio subsystem returned error (ignored):\n%s", ex.what());
			}

			// render scene
			DrawScene();

			// draw 2d
			Draw2D();

			// draw scripted GUI
			scriptedUI->RunFrame(dt);
			if (scriptedUI->WantsClientToBeClosed())
				readyToClose = true;

			// reset all "delayed actions" (in case we forget to reset these)
			hasDelayedReload = false;

			time += dt;
		}

		void Client::RunFrameLate(float dt) {
			SPADES_MARK_FUNCTION();

			// Well done!
			renderer->FrameDone();
			renderer->Flip();
		}

		bool Client::IsLimboViewActive() {
			if (demo.replaying)
				return false;

			if (world) {
				if (!world->GetLocalPlayer()) {
					return true;
				} else if (inGameLimbo) {
					return true;
				}
			}
			return false;
		}

		void Client::SpawnPressed() {
			WeaponType weap = limbo->GetSelectedWeapon();
			int team = limbo->GetSelectedTeam();
			inGameLimbo = false;
			if (team == 2)
				team = 255;

			this->nextSpawnConfig.reset();

			if (!world->GetLocalPlayer() || world->GetLocalPlayer()->GetTeamId() >= 2) {
				// join
				if (team == 255) {
					// weaponId doesn't matter for spectators, but
					// NetClient doesn't like invalid weapon ID
					weap = WeaponType::RIFLE_WEAPON;
				}
				net->SendJoin(team, weap, playerName, lastKills);
			} else {
				Player &p = world->GetLocalPlayer().value();
				if (p.GetTeamId() != team) {
					net->SendTeamChange(team);
				}
				if (team != 2 && p.GetWeapon().GetWeaponType() != weap) {
					net->SendWeaponChange(weap);
				}
			}
		}

		void Client::NextSpawnPressed() {
			WeaponType selectedWeapon = limbo->GetSelectedWeapon();
			if (!selectedWeapon)
				selectedWeapon = RIFLE_WEAPON;

			int selectedTeam = limbo->GetSelectedTeam();
			inGameLimbo = false;
			if (selectedTeam == 2)
				selectedTeam = 255;

			nextSpawnConfig = SpawnConfig {selectedTeam, selectedWeapon};

			if (selectedTeam < 2) {
				std::string teamName = world ? world->GetTeam(selectedTeam).name
				                             : "Team " + std::to_string(selectedTeam + 1);
				std::string prefixedWeaponName;
				switch (selectedWeapon) {
					case RIFLE_WEAPON: prefixedWeaponName = "a Rifle"; break;
					case SMG_WEAPON: prefixedWeaponName = "an SMG"; break;
					case SHOTGUN_WEAPON: prefixedWeaponName = "a Shotgun"; break;
				};

				ShowAlert(_Tr("Client", "You will join Team {0} with {1} on your next spawn.", teamName, prefixedWeaponName),
				          AlertType::Notice);
			} else
				ShowAlert(_Tr("Client", "You will join the spectators on your next spawn."),
				          AlertType::Notice);
		}

		void Client::ShowAlert(const std::string &contents, AlertType type) {
			float timeout;
			switch (type) {
				case AlertType::Notice: timeout = 2.5f; break;
				case AlertType::Warning: timeout = 3.f; break;
				case AlertType::Error: timeout = 3.f; break;
			}
			ShowAlert(contents, type, timeout);
		}

		void Client::ShowAlert(const std::string &contents, AlertType type, float timeout,
		                       bool quiet) {
			alertType = type;
			alertContents = contents;
			alertDisappearTime = time + timeout;
			alertAppearTime = time;

			if (type != AlertType::Notice && !quiet) {
				PlayAlertSound();
			}
		}

		void Client::PlayAlertSound() {
			Handle<IAudioChunk> chunk = audioDevice->RegisterSound("Sounds/Feedback/Alert.opus");
			AudioParam params;
			params.volume = (float)cg_alertSounds;
			audioDevice->PlayLocal(chunk.GetPointerOrNull(), params);
		}

		/** Records chat message/game events to the log file. */
		void Client::NetLog(const char *format, ...) {
			if (demo.replaying)
				return;

			char buf[4096];
			va_list va;
			va_start(va, format);
			vsnprintf(buf, sizeof(buf), format, va);
			va_end(va);
			std::string str = buf;

			time_t t;
			struct tm tm;
			::time(&t);
			tm = *localtime(&t);

			std::string timeStr = asctime(&tm);

			// remove '\n' in the end of the result of asctime().
			timeStr.resize(timeStr.size() - 1);

			snprintf(buf, sizeof(buf), "%s %s\n", timeStr.c_str(), str.c_str());
			buf[sizeof(buf) - 1] = 0;

			std::string outStr = EscapeControlCharacters(buf);

			printf("%s", outStr.c_str());

			if (logStream) {
				logStream->Write(outStr);
				logStream->Flush();
			}
		}

#pragma mark - Snapshots

		void Client::TakeMapShot(bool mapEditor) {

			try {
				std::string name;
				if (mapEditor && mapFileName.size() > 0) {
					name = mapFileName;
				} else {
					name = MapShotPath();
				}
				{
					std::unique_ptr<IStream> stream(FileManager::OpenForWriting(name.c_str()));
					try {
						const Handle<GameMap> &map = GetWorld()->GetMap();
						if (!map) {
							SPRaise("No map loaded");
						}
						map->Save(stream.get());
					} catch (...) {
						throw;
					}
				}

				std::string msg;
				msg = _Tr("Client", "Map saved: {0}", name);
				ShowAlert(msg, AlertType::Notice);
				SPLog("Map saved: %s", name.c_str());
			} catch (const Exception &ex) {
				std::string msg;
				msg = _Tr("Client", "Saving map failed: ");
				msg += ex.GetShortMessage();
				ShowAlert(msg, AlertType::Error);
				SPLog("Saving map failed: %s", ex.what());
			} catch (const std::exception &ex) {
				std::string msg;
				msg = _Tr("Client", "Saving map failed: ");
				msg += ex.what();
				ShowAlert(msg, AlertType::Error);
				SPLog("Saving map failed: %s", ex.what());
			}
		}

		std::string Client::MapShotPath() {
			char buf[256];
			for (int i = 0; i < 10000; i++) {
				std::ostringstream oss;
				oss << "Mapshots/shot" << std::setw(4) << std::setfill('0') << nextScreenShotIndex << ".vxl";
				std::string path = oss.str();
				if (FileManager::FileExists(path.c_str())) {
					nextScreenShotIndex++;
					if (nextScreenShotIndex >= 10000)
						nextScreenShotIndex = 0;
					continue;
				}
				return path;
			}


			SPRaise("No free file name");
		}

#pragma mark - MapEditor

		void Client::SetIsMapEditor(bool b) {
			isMapEditor = b;

			//initialise mapeditor stuff. may need to be done multiple times
			if (world)
				world->SetIsMapEditor(b);

			stmp::optional<Player &> p = *world->GetLocalPlayer();
			if (b && p) {
				p->SetTool(Player::ToolBlock);
				p->SetHeldBlockColor({0, 0, 0});
				p->SetVolumeType(VolumeSingle);
				p->SetMapTool(noMapTool);
				p->SetMapObjectType(ObjTentTeam1);
				p->SetBuildDistance(3);
				p->SetBuildAtMaxDistance(false);
				p->SetBrushSize(10);
				p->SetEditBrushSize(false);
				net->switchModeTeam = 0;
				net->localRespawnPos = {255, 255, 30};
			}
		}

		void Client::LoadLocalMapEditor() {
			std::unique_ptr<IStream> stream;
			if (canvasFileName.size() > 0) {
				stream = FileManager::OpenForReading(canvasFileName.c_str());
			} else {
				stream = FileManager::OpenForReading(mapFileName.c_str());
			}
			const Handle<GameMap> &map = GameMap::Load(stream.get());
			SPLog("The game map was decoded successfully.");

			// now initialize world
			makeproperties.reset(new GameProperties(hostname.GetProtocolVersion()));
			World *w = new World(makeproperties);
			w->SetMap(map);
			map->Release();
			SPLog("World initialized.");

			SetWorld(w);
			SPAssert(world);
			SPLog("World set.");

			world->SetIsMapEditor(true);
			{
				World::Team &t1 = world->GetTeam(0);
				World::Team &t2 = world->GetTeam(1);
				World::Team &spec = world->GetTeam(2);
				t1.color = {0, 0, 255};
				t2.color = {0, 255, 0};
				t1.name = "Team1";
				t2.name = "Team2";
				spec.color = {0, 0, 0};

				world->SetFogColor({128, 128, 255});

				auto TC = stmp::make_unique<TCGameMode>(*world);
				world->SetMode(std::move(TC));

				auto CTF = stmp::make_unique<CTFGameMode>();
				CTFGameMode::Team &mt1 = CTF->GetTeam(0);
				CTFGameMode::Team &mt2 = CTF->GetTeam(1);
				mt1.score = mt2.score = 0;
				CTF->SetCaptureLimit(10);
				mt1.hasIntel = mt2.hasIntel = false;
				mt1.flagPos = mt2.flagPos = mt1.basePos = mt2.basePos = {0, 0, 0};
				world->SetMode(std::move(CTF));
			}
			JoinedGame();

			world->SetLocalPlayerIndex(0);
			auto p = stmp::make_unique<Player>(*world, 0, RIFLE_WEAPON, 2, MakeVector3(256, 256, 30), world->GetTeam(2).color);
			world->SetPlayer(0, std::move(p));
			World::PlayerPersistent &pers = world->GetPlayerPersistent(0);
			pers.name = (std::string)cg_playerName;
			pers.kills = 0;

			std::string txtFile = mapFileName.substr(0, mapFileName.size() - 4);
			txtFile += ".txt";
			if (FileManager::FileExists(txtFile.c_str())) {
				LoadMapTxt(txtFile);
			}

			SetIsMapEditor(true);
			SPLog("LocalMapEditor set");
		}

		void Client::LoadMapTxt(std::string txtFile) {
			if (!FileManager::FileExists(txtFile.c_str())) {
				return;
			}
			mapTxtFileName = txtFile;
			std::unique_ptr<IStream> stream = FileManager::OpenForReading(mapTxtFileName.c_str());
			int len = (int)(stream->GetLength() - stream->GetPosition());
			std::string txt = stream->Read(len);

			scriptedUI->LoadMapTxt(txt);

			int find = txt.rfind("fog =");
			if (find < 0) {
				find = txt.rfind("fog=");
			}
			if (find >= 0) {
				int endLine = txt.find('\n', find);

				if (endLine > 0) {
					std::string numString = "";
					IntVector3 fogCol;
					int count = 3;
					for (char c : txt.substr(find, endLine - find)) {
						if (isdigit(c)) {
							numString += c;
							continue;
						}
						if (numString.length() <= 0) {
							continue;
						}
						if (count == 3) {
							fogCol.x = std::stoi(numString);
							numString = "";
							count--;
							continue;
						}
						if (count == 2) {
							fogCol.y = std::stoi(numString);
							numString = "";
							count--;
							continue;
						}
						if (count == 1) {
							fogCol.z = std::stoi(numString);
							net->SendFogColor(fogCol);
							break;
						}
					}
				}
			}

			std::string note = "Map.txt loaded: " + mapTxtFileName;
			ShowAlert(note, Client::AlertType::Notice);
			SPLog("Map.txt loaded: %s", mapTxtFileName.c_str());
		}

		void Client::SaveMapTxt(const std::string &txt) {
			if (mapTxtFileName.size() <= 0) {
				mapTxtFileName = mapFileName.substr(0, mapFileName.length() - 4) + ".txt";
			}
			std::unique_ptr<IStream> stream(FileManager::OpenForWriting(mapTxtFileName.c_str()));

			stream->Write(txt);
			stream->Flush();

			std::string note = "Map.txt saved: " + mapTxtFileName;
			ShowAlert(note, Client::AlertType::Notice);
			SPLog("Map.txt saved: %s", mapTxtFileName.c_str());
		}

		void Client::GenMaptxt() {
			mapTxtFileName = mapFileName.substr(0, mapFileName.length() - 4) + ".txt";
			std::unique_ptr<IStream> stream(FileManager::OpenForWriting(mapTxtFileName.c_str()));
			std::string txt = GenMeta();

			char buf[64];
			IntVector3 fogColor = world->GetFogColor();
			snprintf(buf, sizeof(buf), "fog = (%d, %d, %d)\n", fogColor.x, fogColor.y, fogColor.z);
			buf[sizeof(buf) - 1] = '\0'; // Ensure null-termination
			txt += buf;

			stream->Write(txt);

			std::string note = "Map.txt created: " + mapTxtFileName;
			ShowAlert(note, Client::AlertType::Notice);
			SPLog("Map.txt created: %s", mapTxtFileName.c_str());
		}

		std::string Client::GenMeta() {
			std::string txt = "name = '" + mapTxtFileName.substr(15, (int)mapTxtFileName.length() - 19) + "'\n";
			txt += "version = '0'\n";
			txt += "author = '" + (std::string)cg_playerName + "'\n";
			txt += "description = ('what is this map about?')\n\n";
			txt += "extensions = {\n\n}\n\n";

			return txt;
		}

#pragma mark - Chat Messages

		void Client::PlayerSentChatMessage(Player &p, bool global, const std::string &msg) {
			if (!cg_ignoreChatMessages) {
				std::string s;
				if (global)
					//! Prefix added to global chat messages.
					//!
					//! Example: [Global] playername (Red) blah blah
					//!
					//! Crowdin warns that this string shouldn't be translated,
					//! but it actually can be.
					//! The extra whitespace is not a typo.
					s = _Tr("Client", "[Global] ");
				if (!p.IsAlive())
					s += "*DEAD* ";
				s += ChatWindow::TeamColorMessage(p.GetName(), p.GetTeamId());
				if(cg_showTeamMateLocation && !global && !p.IsLocalPlayer()) {
					s += ' ';
					auto letter = char(int('A') + int(p.GetPosition().x / 64));
					auto number = std::to_string(int(p.GetPosition().y / 64) + 1);
					s += letter + number;
				}
				s += ": ";
				s += msg;

				if (std::string(cg_mentionWord).size() > 0) {
					if (msg.find(std::string(cg_mentionWord)) != std::string::npos)
						s += ChatWindow::ColoredMessage(" -> Mention", MsgColorGreen);
				}

				chatWindow->AddMessage(s);
			}
			{
				std::string s;
				if (global)
					s = "[Global] ";
				if (!p.IsAlive())
					s += "*DEAD* ";
				s += p.GetName();
				s += ": ";
				s += msg;

				auto col = p.GetTeamId() < 2 ? world->GetTeam(p.GetTeamId()).color
				                             : IntVector3::Make(255, 255, 255);

				scriptedUI->RecordChatLog(
				  s, MakeVector4(col.x / 255.f, col.y / 255.f, col.z / 255.f, 0.8f));
			}
			if (global)
				NetLog("[Global] %s (%s): %s", p.GetName().c_str(),
				       world->GetTeam(p.GetTeamId()).name.c_str(), msg.c_str());
			else
				NetLog("[Team] %s (%s): %s", p.GetName().c_str(),
				       world->GetTeam(p.GetTeamId()).name.c_str(), msg.c_str());

			if (!IsMuted() && !cg_ignoreChatMessages) {
				Handle<IAudioChunk> chunk = audioDevice->RegisterSound("Sounds/Feedback/Chat.opus");
				AudioParam params;
				params.volume = (float)cg_chatBeep;
				audioDevice->PlayLocal(chunk.GetPointerOrNull(), params);
			}
		}

		void Client::ServerSentMessage(const std::string &msg) {
			NetLog("%s", msg.c_str());
			scriptedUI->RecordChatLog(msg, Vector4::Make(1.f, 1.f, 1.f, 0.8f));

			if (cg_serverAlert) {
				if (msg.substr(0, 3) == "N% ") {
					ShowAlert(msg.substr(3), AlertType::Notice);
					return;
				}
				if (msg.substr(0, 3) == "!% ") {
					ShowAlert(msg.substr(3), AlertType::Error);
					return;
				}
				if (msg.substr(0, 3) == "%% ") {
					ShowAlert(msg.substr(3), AlertType::Warning);
					return;
				}
				if (msg.substr(0, 3) == "C% ") {
					centerMessageView->AddMessage(msg.substr(3));
					return;
				}
			}

			if (msg.substr(0, 8) == "PM from " && (int)cg_ignoreChatMessages < 2) {
				if (cg_ignorePrivateMessages)
					return;

				std::string s = "PM from " + msg.substr(8);
				chatWindow->AddMessage(ChatWindow::ColoredMessage(s, MsgColorGreen));
				return;
			}

			if (msg == " /g switching gamemode" && isMapEditor) {
				net->CommandSwitchGameMode();
			}

			if ((int)cg_ignoreChatMessages < 2)
				chatWindow->AddMessage(msg);
		}

#pragma mark - Follow / Spectate

		void Client::FollowNextPlayer(bool reverse) {
			SPAssert(world->GetLocalPlayer());

			auto &localPlayer = *world->GetLocalPlayer();
			int myTeam = localPlayer.GetTeamId();

			bool localPlayerIsSpectator = localPlayer.IsSpectator();

			int nextId = FollowsNonLocalPlayer(GetCameraMode())
			               ? followedPlayerId
			               : world->GetLocalPlayerIndex().value();
			do {
				reverse ? --nextId : ++nextId;

				if (nextId >= static_cast<int>(world->GetNumPlayerSlots()))
					nextId = 0;
				if (nextId < 0)
					nextId = static_cast<int>(world->GetNumPlayerSlots() - 1);

				stmp::optional<Player &> p = world->GetPlayer(nextId);
				if (!p || p->IsSpectator()) {
					// Do not follow a non-existent player or spectator
					continue;
				}

				if (!localPlayerIsSpectator && p->GetTeamId() != myTeam) {
					continue;
				}

				if (!localPlayerIsSpectator && cg_skipDeadPlayersWhenDead && !p->IsAlive()) {
					// Skip dead players unless the local player is not a spectator
					continue;
				}

				if (p->GetFront().GetPoweredLength() < .01f) {
					// Do not follow a player with an invalid state
					continue;
				}

				break;
			} while (nextId != followedPlayerId);

			followedPlayerId = nextId;
			if (followedPlayerId == world->GetLocalPlayerIndex()) {
				followCameraState.enabled = false;
			} else {
				followCameraState.enabled = true;
			}
		}

		void Client::FollowSamePlayer() {
			SPADES_MARK_FUNCTION();
			//follow the same player u unfollowed.

			if (GetWorld()->GetNumPlayers() < 2)
				return;

			stmp::optional<Player &> p = GetWorld()->GetPlayer(followedPlayerId);
			if (!p) {
				FollowNextPlayer(false);
				return;
			}
			if (p->IsLocalPlayer() || p->IsSpectator()) {
				FollowNextPlayer(false);
				return;
			}

			followCameraState.enabled = true;
		}
	} // namespace client
} // namespace spades

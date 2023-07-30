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

#include "MainMenu.as"
#include "CreateProfileScreen.as"

namespace spades {

	class MainScreenUI {
		private Renderer @renderer;
		private AudioDevice @audioDevice;
		FontManager @fontManager;
		MainScreenHelper @helper;

		spades::ui::UIManager @manager;

		MainScreenMainMenu @mainMenu;

		bool shouldExit = false;

		private float time = -1.f;
		private float reverseTime = 1.f;
		
		private int sceneState = -1;
		private bool isFadeOut = false;
		private Vector3 camera;
		private Vector3 roll = Vector3(0, 0, -1);
		private Vector3 reverseRoll = Vector3(0, 0, 0);

		private ConfigItem cg_playerName("cg_playerName");
		private ConfigItem cg_playerNameIsSet("cg_playerNameIsSet", "0");

		MainScreenUI(Renderer @renderer, AudioDevice @audioDevice, FontManager @fontManager,
					 MainScreenHelper @helper) {
			@this.renderer = renderer;
			@this.audioDevice = audioDevice;
			@this.fontManager = fontManager;
			@this.helper = helper;

			SetupRenderer();

			@manager = spades::ui::UIManager(renderer, audioDevice);
			@manager.RootElement.Font = fontManager.GuiFont;

			@mainMenu = MainScreenMainMenu(this);
			mainMenu.Bounds = manager.RootElement.Bounds;
			manager.RootElement.AddChild(mainMenu);

			// Let the new player choose their IGN
			if (cg_playerName.StringValue != "" && cg_playerName.StringValue != "Deuce") {
				cg_playerNameIsSet.IntValue = 1;
			}
			if (cg_playerNameIsSet.IntValue == 0) {
				CreateProfileScreen al(mainMenu);
				al.Run();
			}
		}

		void SetupRenderer() {
			// load map
			@renderer.GameMap = GameMap("Maps/TitleHallWeeb.vxl");
			
			sceneState = 0;
			SetupHallScene();

			// returned from the client game, so reload the server list.
			if (mainMenu !is null)
				mainMenu.LoadServerList();

			if (manager !is null)
				manager.KeyPanic();
		}

		void MouseEvent(float x, float y) { manager.MouseEvent(x, y); }

		void WheelEvent(float x, float y) { manager.WheelEvent(x, y); }

		void KeyEvent(string key, bool down) { manager.KeyEvent(key, down); }

		void TextInputEvent(string text) { manager.TextInputEvent(text); }

		void TextEditingEvent(string text, int start, int len) {
			manager.TextEditingEvent(text, start, len);
		}

		bool AcceptsTextInput() { return manager.AcceptsTextInput; }

		AABB2 GetTextInputRect() { return manager.TextInputRect; }

		private SceneDefinition SetupCamera(SceneDefinition sceneDef, Vector3 eye, Vector3 at,
											Vector3 up, float fov) {
			Vector3 dir = (at - eye).Normalized;
			Vector3 side = Cross(dir, up).Normalized;
			up = -Cross(dir, side);
			sceneDef.viewOrigin = eye;
			sceneDef.viewAxisX = side;
			sceneDef.viewAxisY = up;
			sceneDef.viewAxisZ = dir;
			sceneDef.fovY = fov * 3.141592654f / 180.f;
			sceneDef.fovX =
				atan(tan(sceneDef.fovY * 0.5f) * renderer.ScreenWidth / renderer.ScreenHeight) *
				2.f;
			return sceneDef;
		}

		void RunFrame(float dt) {
			if (time < 0.f) {
				time = 0.f;
			}

			SceneDefinition sceneDef;
			switch (sceneState) {
				case 0:
					sceneDef = HallScene(sceneDef, dt);
					break;
				case 1:
					sceneDef = BonfireScene(sceneDef, dt);
					break;
				case 2:
					sceneDef = SkylineScene(sceneDef, dt);
					break;
				case 3:
					sceneDef = AustronautScene(sceneDef, dt);
					break;
				case 4:
					sceneDef = ToriiScene(sceneDef, dt);
					break;
				case 5:
					sceneDef = PlaneScene(sceneDef, dt);
					break;
			}
			sceneDef.zNear = 0.1f;
			sceneDef.zFar = 222.f;
			sceneDef.time = int(time * 1000.f);
			sceneDef.viewportWidth = int(renderer.ScreenWidth);
			sceneDef.viewportHeight = int(renderer.ScreenHeight);
			sceneDef.denyCameraBlur = true;
			sceneDef.depthOfFieldFocalLength = 100.f;
			sceneDef.skipWorld = false;
			sceneDef.allowGlowBlocks = true;

			// fade the map
			float fade = Clamp((time - 1.f) / 2.2f, 0.f, 1.f);
			sceneDef.globalBlur = Clamp((1.f - (time - 1.f) / 2.5f), 0.f, 1.f);
			if (!mainMenu.IsEnabled) {
				sceneDef.globalBlur = Max(sceneDef.globalBlur, 0.5f);
			}

			renderer.StartScene(sceneDef);
			renderer.EndScene();

			// fade the map (draw)
			if (fade < 1.f) {
				renderer.ColorNP = Vector4(0.f, 0.f, 0.f, 1.f - fade);
				renderer.DrawImage(renderer.RegisterImage("Gfx/White.tga"),
								   AABB2(0.f, 0.f, renderer.ScreenWidth, renderer.ScreenHeight));
			}

			// draw title logo
			Image @img = renderer.RegisterImage("Gfx/Title/Logo.png");
			renderer.ColorNP = Vector4(1.f, 1.f, 1.f, 1.f);
			renderer.DrawImage(img, Vector2((renderer.ScreenWidth - img.Width) * 0.5f, 64.f));

			manager.RunFrame(dt);
			manager.Render();

			time += Min(dt, 0.05f) * reverseTime;
			
			if (time <= 0)
				SetupNextScene();
		}

		void RunFrameLate(float dt) {
			renderer.FrameDone();
			renderer.Flip();
		}

		void Closing() { shouldExit = true; }

		bool WantsToBeClosed() { return shouldExit; }
		
		private void FadeOut() { 
			if (isFadeOut)
				return;
			isFadeOut = true;
			reverseTime = -1.f; 
			time = 5.f;
		}
		private void FadeIn() {
			isFadeOut = false;
			time = -1.f;
			reverseTime = 1.f;
		}
		
		void SetupNextScene() {
			if (++sceneState > 5)
				sceneState = 0;
				
			switch (sceneState) {
				case 0:
					SetupHallScene();
					break;
				case 1:
					SetupBonfireScene();
					break;
				case 2:
					SetupSkylineScene();
					break;
				case 3:
					SetupAustronautScene();
					break;
				case 4:
					SetupToriiScene();
					break;
				case 5:
					SetupPlaneScene();
					break;
			}
		}
		
		void SetupHallScene() {//scene 0
			renderer.FogDistance = 128.f;
			renderer.FogColor = Vector3(0.05f, 0.f, 0.1f);
			reverseTime = 1.f;
			camera.x = 400;
			camera.y = 256;
			camera.z = 59.4f;
			roll = Vector3(0, 0, -1);
			reverseRoll = Vector3(0, 0, 0);
			FadeIn();
		}
		private SceneDefinition HallScene(SceneDefinition sceneDef, float dt) {
			float delta = Min(dt, 0.05f);
			camera.x -= delta * 2.f;
			
			if (camera.x <= 160)
				FadeOut();
			
			float rollDelta = delta * 0.005f;
			roll.z += reverseRoll.z == 1 ? -rollDelta : rollDelta;
			roll.y += reverseRoll.y == 1 ? -rollDelta : rollDelta;
			if (roll.z <= -1 || roll.z >= 1)
				reverseRoll.z = 1 - reverseRoll.z;
			if (roll.y <= -1 || roll.y >= 1)
				reverseRoll.y = 1 - reverseRoll.y;
				
			return SetupCamera(sceneDef, camera,
				Vector3(camera.x - .1f, camera.y, camera.z - 0.03f), roll, 90);
		}
		
		void SetupBonfireScene() {//scene 1
			renderer.FogDistance = 128.f;
			renderer.FogColor = Vector3(0.f, 0.f, 0.f);
			reverseTime = 1.f;
			camera.x = 208;
			camera.y = 312;
			camera.z = 59.4f;
			roll = Vector3(0, 0, -1);
			reverseRoll = Vector3(0, 0, 0);
			FadeIn();
		}
		private SceneDefinition BonfireScene(SceneDefinition sceneDef, float dt) {
			float delta = Min(dt, 0.05f);
			camera.x -= delta * 1.75f;
			
			if (camera.x <= 200 && camera.y <= 314)
				camera.y += delta;
			
			if (camera.x <= 195 &&camera.x > 177 && camera.z >= 56.4f)
				camera.z -= delta;
			
			if (camera.x <= 195 && camera.x > 177 && camera.z >= 56.4f)
				camera.z -= delta;
				
			if (camera.x <= 177 && camera.z <= 59.4f)
				camera.z += delta;
			
			
			if (camera.x <= 165)
				FadeOut();
			
			return SetupCamera(sceneDef, camera,
				Vector3(camera.x - .1f, camera.y, camera.z), roll, 68);
		}
		
		void SetupSkylineScene() {//scene 2
			renderer.FogDistance = 128.f;
			renderer.FogColor = Vector3(0.05f, 0.f, 0.1f);
			reverseTime = 1.f;
			camera.x = 100;
			camera.y = 256;
			camera.z = -10.6f;
			roll = Vector3(0, 0, -1);
			reverseRoll = Vector3(0, 0, 0);
			FadeIn();
		}
		private SceneDefinition SkylineScene(SceneDefinition sceneDef, float dt) {
			float delta = Min(dt, 0.05f);
			camera.x += delta * 2.f;
			
			if (camera.x >= 330)
				FadeOut();
			
			return SetupCamera(sceneDef, camera,
				Vector3(camera.x + .1f, camera.y, camera.z + 0.03f), roll, 90);
		}
		
		void SetupAustronautScene() {//scene 3
			renderer.FogDistance = 128.f;
			renderer.FogColor = Vector3(0.05f, 0.f, 0.1f);
			reverseTime = 1.f;
			camera.x = 350;
			camera.y = 325;
			camera.z = 54;
			roll = Vector3(0, 0, -1);
			reverseRoll = Vector3(0, 0, 0);
			FadeIn();
		}
		private SceneDefinition AustronautScene(SceneDefinition sceneDef, float dt) {
			float delta = Min(dt, 0.05f);
			camera.z -= delta * 1.5f;
			
			if (camera.z <= 25)
				FadeOut();
			
			return SetupCamera(sceneDef, camera, Vector3(375, 313, 40), roll, 90);
		}
		
		void SetupToriiScene() {//scene 4
			renderer.FogDistance = 128.f;
			renderer.FogColor = Vector3(0.05f, 0.f, 0.1f);
			reverseTime = 1.f;
			camera.x = 350;
			camera.y = 129;
			camera.z = 31.4f;
			roll = Vector3(0, 0, -1);
			reverseRoll = Vector3(0, 0, 0);
			FadeIn();
		}
		private SceneDefinition ToriiScene(SceneDefinition sceneDef, float dt) {
			float delta = Min(dt, 0.05f);
			camera.x -= delta * 2.f;
			
			if (camera.x <= 170)
				FadeOut();
			
			return SetupCamera(sceneDef, camera,
				Vector3(camera.x - .1f, camera.y, camera.z - 0.03f), roll, 90);
		}
		
		void SetupPlaneScene() {//scene 5
			renderer.FogDistance = 128.f;
			renderer.FogColor = Vector3(0.05f, 0.f, 0.1f);
			reverseTime = 1.f;
			camera.x = 320;
			camera.y = 500;
			camera.z = 0;
			roll = Vector3(0, 0, -1);
			reverseRoll = Vector3(0, 0, 0);
			FadeIn();
		}
		private SceneDefinition PlaneScene(SceneDefinition sceneDef, float dt) {
			float delta = Min(dt, 0.05f);
			camera.x += delta * 2.f;
			
			if (camera.x >= 420)
				FadeOut();
			
			float rollDelta = delta * 0.005f;
			roll.z += reverseRoll.z == 1 ? -rollDelta : rollDelta;
			roll.y += reverseRoll.y == 1 ? -rollDelta : rollDelta;
			if (roll.z <= -1 || roll.z >= 1)
				reverseRoll.z = 1 - reverseRoll.z;
			if (roll.y <= -1 || roll.y >= 1)
				reverseRoll.y = 1 - reverseRoll.y;
				
			return SetupCamera(sceneDef, camera,
				Vector3(camera.x + .1f, camera.y - .1f, camera.z + .1f), roll, 90);
		}
	}

	/**
	 * The entry point of the main screen.
	 */
	MainScreenUI @CreateMainScreenUI(Renderer @renderer, AudioDevice @audioDevice,
									 FontManager @fontManager, MainScreenHelper @helper) {
		return MainScreenUI(renderer, audioDevice, fontManager, helper);
	}

}

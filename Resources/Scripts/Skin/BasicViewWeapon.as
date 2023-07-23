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

namespace spades {

	class ViewWeaponSpring {
		double position = 0;
		double desired = 0;
		double velocity = 0;
		double frequency = 1;
		double damping = 1;

		ViewWeaponSpring() {}

		ViewWeaponSpring(double f, double d) {
			frequency = f;
			damping = d;
		}

		ViewWeaponSpring(double f, double d, double des) {
			frequency = f;
			damping = d;
			desired = des;
		}

		void Update(double updateLength) {
			double timeStep = 1.0 / 240.0;

			// Forces updates into at least 240 fps.
			for (double timeLeft = updateLength; timeLeft > 0; timeLeft -= timeStep) {
				double dt = Min(timeStep, timeLeft);
				double acceleration = (desired - position) * frequency;
				velocity = velocity + acceleration * dt;
				velocity -= velocity * damping * dt;
				position = position + velocity * dt;
			}
		}
	}

	class ViewWeaponEvent {
		bool activated = false;
		bool acknowledged = false;

		void Activate() {
			if (!acknowledged)
				activated = true;
		}

		bool WasActivated() {
			return acknowledged ? false : activated;
		}

		void Acknowledge() {
			acknowledged = true;
		}

		void Reset() {
			activated = false;
			acknowledged = false;
		}
	}
	
	class BasicViewWeapon :
		IToolSkin,
		IViewToolSkin,
		IWeaponSkin,
		IWeaponSkin2,
		IWeaponSkin3
	{
		// IToolSkin
		protected float sprintState;
		protected float raiseState;
		protected Vector3 teamColor;
		protected bool muted;
		protected ConfigItem n_hideDefaultTarget("n_hideDefaultTarget", "0");
		protected ConfigItem n_hideDefaultScope("n_hideDefaultScope", "0");
		protected ConfigItem cg_pngScope("cg_pngScope", "0");
		protected ConfigItem cg_viewWeaponX("cg_viewWeaponX");
		protected ConfigItem cg_viewWeaponY("cg_viewWeaponY");
		protected ConfigItem cg_viewWeaponZ("cg_viewWeaponZ");
		Vector3 cg_viewWeaponOffset 
			= Vector3(cg_viewWeaponX.FloatValue, cg_viewWeaponY.FloatValue, cg_viewWeaponZ.FloatValue);

		float SprintState {
			set { sprintState = value; }
			get { return sprintState; }
		}

		float RaiseState {
			set { raiseState = value; }
			get { return raiseState; }
		}

		Vector3 TeamColor {
			set { teamColor = value; }
			get { return teamColor; }
		}

		bool IsMuted {
			set { muted = value; }
			get { return muted; }
		}

		// IWeaponSkin

		protected float aimDownSightState;
		protected float aimDownSightStateSmooth;
		protected float readyState;
		protected bool reloading;
		protected float reloadProgress;
		protected int ammo, clipSize;
		protected float localFireVibration;

		protected float sprintStateSmooth;

		float AimDownSightState {
			set {
				aimDownSightState = value;
				aimDownSightStateSmooth = SmoothStep(value);
			}
			get { return aimDownSightState; }
		}

		float AimDownSightStateSmooth {
			get { return aimDownSightStateSmooth; }
		}

		bool IsReloading {
			get { return reloading; }
			set { reloading = value; }
		}
		float ReloadProgress {
			get { return reloadProgress; }
			set { reloadProgress = value; }
		}
		int Ammo {
			set { ammo = value; }
			get { return ammo; }
		}
		int ClipSize {
			set { clipSize = value; }
			get { return clipSize; }
		}

		float ReadyState {
			set { readyState = value; }
			get { return readyState; }
		}

		// IViewToolSkin

		protected Matrix4 eyeMatrix;
		protected Vector3 swing;
		protected Vector3 leftHand;
		protected Vector3 rightHand;

		Matrix4 EyeMatrix {
			set { eyeMatrix = value; }
			get { return eyeMatrix; }
		}

		Vector3 Swing {
			set { swing = value; }
			get { return swing; }
		}

		Vector3 LeftHandPosition {
			get { return leftHand; }
			set { leftHand = value; }
		}
		Vector3 RightHandPosition {
			get { return rightHand; }
			set { rightHand = value; }
		}

		// IWeaponSkin2
		protected float environmentRoom;
		protected float environmentSize;

		void SetSoundEnvironment(float room, float size, float distance) {
			environmentRoom = room;
			environmentSize = size;
		}
		// set_SoundOrigin is not called for first-person skin scripts
		Vector3 SoundOrigin {
			set {}
		}

		// IWeaponSkin3
		Vector3 MuzzlePosition {
			get { return eyeMatrix * GetViewWeaponMatrix() * Vector3(0.0, 0.35f, -0.05f); }
		}

		Vector3 CaseEjectPosition {
			get { return eyeMatrix * GetViewWeaponMatrix() * Vector3(0.0, -0.1f, -0.05f); }
		}

		protected Renderer @renderer;
		protected Image @sightImage;
		protected Image @dotSightImage;
		protected Image @scopeImage;

		BasicViewWeapon(Renderer @renderer) {
			@this.renderer = renderer;
			localFireVibration = 0.f;
			@sightImage = renderer.RegisterImage("Gfx/Target.png");
			@dotSightImage = renderer.RegisterImage("Gfx/DotSight.tga");
			@scopeImage = renderer.RegisterImage("Gfx/Rifle.png");
		}

		float GetLocalFireVibration() { return localFireVibration; }

		float GetMotionGain() { return 1.f - AimDownSightStateSmooth * 0.4f; }

		float GetZPos() { return 0.2f - AimDownSightStateSmooth * 0.05f; }

		Vector3 GetLocalFireVibrationOffset() {
			float vib = GetLocalFireVibration();
			float motion = GetMotionGain();
			Vector3 hip =
				Vector3(sin(vib * PiF * 2.f) * 0.008f * motion, vib * (vib - 1.f) * 0.14f * motion,
						vib * (1.f - vib) * 0.03f * motion);
			Vector3 ads = Vector3(0.f, vib * (vib - 1.f) * vib * 0.3f * motion, 0.f);
			return Mix(hip, ads, AimDownSightStateSmooth);
		}
		
		// Creates a rotation matrix from euler angles (in the form of a Vector3) x-y-z
		Matrix4 CreateEulerAnglesMatrix(Vector3 angles) {
			Matrix4 mat = CreateRotateMatrix(Vector3(1, 0, 0), angles.x);
			mat = CreateRotateMatrix(Vector3(0, 1, 0), angles.y) * mat;
			mat = CreateRotateMatrix(Vector3(0, 0, 1), angles.z) * mat;
			return mat;
		}

		// rotates gun matrix to ensure the sight is in the center of screen (0, ?, 0)
		Matrix4 AdjustToAlignSight(Matrix4 mat, Vector3 sightPos, float fade) {
			Vector3 p = mat * sightPos;
			mat = CreateRotateMatrix(Vector3(0, 1, 1), atan(p.x / p.y) * fade) * mat;
			mat = CreateRotateMatrix(Vector3(-1, 0, 0), atan(p.z / p.y) * fade) * mat;
			return mat;
		}

		Matrix4 GetViewWeaponMatrix() {
			Matrix4 mat;
			if (sprintStateSmooth > 0.f) {
				mat = CreateRotateMatrix(Vector3(0.f, 1.f, 0.f), sprintStateSmooth * -0.1f) * mat;
				mat = CreateRotateMatrix(Vector3(1.f, 0.f, 0.f), sprintStateSmooth * 0.3f) * mat;
				mat = CreateRotateMatrix(Vector3(0.f, 0.f, 1.f), sprintStateSmooth * -0.55f) * mat;
				mat =
					CreateTranslateMatrix(Vector3(0.23f, -0.05f, 0.15f) * sprintStateSmooth) * mat;
			}

			if (raiseState < 1.f) {
				float putdown = 1.f - raiseState;
				mat = CreateRotateMatrix(Vector3(0.f, 0.f, 1.f), putdown * -1.3f) * mat;
				mat = CreateRotateMatrix(Vector3(0.f, 1.f, 0.f), putdown * 0.2f) * mat;
				mat = CreateTranslateMatrix(Vector3(0.1f, -0.3f, 0.1f) * putdown) * mat;
			}
			
			float sp = 1.0F - AimDownSightStateSmooth;

			if (readyState < 1.0F) {
				float per = SmoothStep(1.0F - readyState);
				mat = CreateTranslateMatrix(Vector3(-0.25F * sp, -0.5F, 0.25F * sp) * per * 0.1F) * mat;
				mat = CreateRotateMatrix(Vector3(-1, 0, 0), per * 0.05F * sp) * mat;
			}

			Vector3 trans(0.0F, 0.0F, 0.0F);
			trans += Vector3(-0.13F * sp, 0.5F, GetZPos());
			trans += swing * GetMotionGain();
			mat = CreateTranslateMatrix(trans) * mat;

			return mat;
		}

		void Update(float dt) {
			localFireVibration -= dt * 10.f;
			if (localFireVibration < 0.f) {
				localFireVibration = 0.f;
			}

			float sprintStateSS = sprintState * sprintState;
			if (sprintStateSS > sprintStateSmooth) {
				sprintStateSmooth += (sprintStateSS - sprintStateSmooth) * (1.f - pow(0.001, dt));
			} else {
				sprintStateSmooth = sprintStateSS;
			}
		}

		void WeaponFired() { localFireVibration = 1.f; }

		void AddToScene() {}

		void ReloadingWeapon() {}

		void ReloadedWeapon() {}

		void Draw2D() {
			if (AimDownSightState > 0.99f) {
				if (n_hideDefaultScope.IntValue > 0)
					return;
				
				if (cg_pngScope.IntValue > 1) {
					renderer.ColorNP = Vector4(1.0F, 0.0F, 1.0F, 1.0F);
					renderer.DrawImage(
						dotSightImage,
					Vector2((renderer.ScreenWidth - dotSightImage.Width) * 0.5F,
						(renderer.ScreenHeight - dotSightImage.Height) * 0.5F)
					);
				} else if (cg_pngScope.IntValue == 1) {
					Vector2 imgSize = Vector2(scopeImage.Width, scopeImage.Height);
					imgSize *= Max(1.0F, renderer.ScreenWidth / scopeImage.Width);
					imgSize *= Min(1.0F, renderer.ScreenHeight / scopeImage.Height);
					imgSize *= Max(0.25F * (1.0F - readyState) + 1.0F, 1.0F);

					Vector2 scrCenter = (Vector2(renderer.ScreenWidth, renderer.ScreenHeight) - imgSize) * 0.5F;

					renderer.ColorNP = Vector4(1.0F, 1.0F, 1.0F, 1.0F);
					renderer.DrawImage(scopeImage, AABB2(scrCenter.x, scrCenter.y, imgSize.x, imgSize.y));
				}
				return;
			}
			
			if (n_hideDefaultTarget.IntValue > 0)
				return;

			renderer.ColorNP = (Vector4(1.f, 1.f, 1.f, 1.f));
			renderer.DrawImage(sightImage,
							   Vector2((renderer.ScreenWidth - sightImage.Width) * 0.5f,
									   (renderer.ScreenHeight - sightImage.Height) * 0.5f));
		}
	}

}

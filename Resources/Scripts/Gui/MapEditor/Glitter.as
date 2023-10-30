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

namespace spades {
	
	//should work too, but its slower than the one implemented in source.
	//u may use this instead if u want to quickly add and test stuff
	class GlitterScript {
		
		GlitterScript() {}
		
		int DoGlitter(
			GameMap @map,
			IntVector3 gradeColor, IntVector3 shadowColor, 
			IntVector3 xRampColor, int xRampRange,
			IntVector3 yRampColor, int yRampRange,
			IntVector3 zRampColor, int zRampRange,
			int noiseMono, int noiseColor, int rain, 
			bool snow, bool glowClamp, bool glowStay, bool debug, bool repair
		) {
			bool grade = gradeColor.x >= 0 && gradeColor.y >= 0 && gradeColor.z >= 0;
			bool shadow = shadowColor.x >= 0 && shadowColor.y >= 0 && shadowColor.z >= 0;
			bool xRamp = xRampColor.x >= 0 && xRampColor.y >= 0 && xRampColor.z >= 0 && xRampRange != 0;
			bool yRamp = yRampColor.x >= 0 && yRampColor.y >= 0 && yRampColor.z >= 0 && yRampRange != 0;
			bool zRamp = zRampColor.x >= 0 && zRampColor.y >= 0 && zRampColor.z >= 0 && zRampRange != 0;
			
			if (!grade && !shadow && !xRamp && !yRamp && !zRamp
				&& !(noiseMono > 0) && !(noiseColor > 0) && !(rain > 0)
				&& !snow && !repair && !glowStay && !glowClamp && !debug) {
				return -1;
			}
			
			{
				int zCountSolid;
				float randomRainLength;
				bool zFirstSurface;
				bool zRestSurfaces;
				IntVector3 vCol;
				uint32 iCol;
				uint8 alpha;
				if (rain >= 0)
					rain = int(float(rain) * 2.55f);
				for (int x = 0; x < 512; x++)
					for (int y = 0; y < 512; y++) {
						if (rain >= 0)
							randomRainLength = float(GetRandom(500, 2000) * 0.01f);
						zCountSolid = 0;
						zFirstSurface = true;
						for (int z = 0; z < 64; z++) {
							if (map.IsSolid(x, y, z)) {
								iCol = map.GetColor(x, y, z);
								vCol.x = uint8(iCol);
								vCol.y = uint8(iCol >> 8);
								vCol.z = uint8(iCol >> 16);
								alpha = uint8(iCol >> 24);
								
								if (repair)
									alpha = 255;
								if (snow)
									if (zFirstSurface)
										vCol.x = vCol.y = vCol.z = 250 - GetRandom(0, 15);
								if (rain > 0)
									if (zCountSolid < randomRainLength) {
										float rainFactor = (float(rain) * 0.01f) * 255.f * 0.01f;
										if (zCountSolid != 0)
											rainFactor *= (zCountSolid - randomRainLength) / randomRainLength;
										if (rainFactor < 0)
											rainFactor *= -1;
										vCol.x -= int(float(vCol.x) * rainFactor);
										vCol.y -= int(float(vCol.y) * rainFactor);
										vCol.z -= int(float(vCol.z) * rainFactor);
									}
								if (shadow)
									//openspades already renders shadows btw 
									//but at a 45 degree angle
									//this here casts shadow vertically
									//which may visually clash with openspades shadows
									if (zRestSurfaces) {
										vCol.x -= shadowColor.x;
										vCol.y -= shadowColor.y;
										vCol.z -= shadowColor.z;
									}
								if (grade) {
									vCol.x *= int(float(gradeColor.x) / 255.f);
									vCol.y *= int(float(gradeColor.y) / 255.f);
									vCol.z *= int(float(gradeColor.z) / 255.f);
								}
								if (xRamp) {
									float rampFactor = xRampRange < 0
										? float(abs(x - 512)) / float(-xRampRange)
										: float(x) / float(xRampRange);
									vCol.x += int(float(xRampColor.x) * rampFactor);
									vCol.y += int(float(xRampColor.y) * rampFactor);
									vCol.z += int(float(xRampColor.z) * rampFactor);
								}
								if (yRamp) {
									float rampFactor = yRampRange < 0
										? float(abs(y - 512)) / float(-yRampRange)
										: float(y) / float(yRampRange);
									vCol.x += int(float(yRampColor.x) * rampFactor);
									vCol.y += int(float(yRampColor.y) * rampFactor);
									vCol.z += int(float(yRampColor.z) * rampFactor);
								}
								if (zRamp) {
									float rampFactor = zRampRange < 0
										? float(abs(64 - z)) / float(-zRampRange)
										: float(63 - z) / float(zRampRange);
									vCol.x += int(float(zRampColor.x) * rampFactor);
									vCol.y += int(float(zRampColor.y) * rampFactor);
									vCol.z += int(float(zRampColor.z) * rampFactor);
								}
								if (noiseMono > 0) {
									float randomMono = float(GetRandom(0, noiseMono)) * 0.01f;
									vCol.x -= int(float(vCol.x) * randomMono);
									vCol.y -= int(float(vCol.y) * randomMono);
									vCol.z -= int(float(vCol.z) * randomMono);
								}
								if (noiseColor > 0) {
									vCol.x -= int(float(vCol.x) * (float(GetRandom(0, noiseColor)) * 0.01f));
									vCol.y -= int(float(vCol.y) * (float(GetRandom(0, noiseColor)) * 0.01f));
									vCol.z -= int(float(vCol.z) * (float(GetRandom(0, noiseColor)) * 0.01f));
								}
								if (debug) {
									vCol.x = int((float(x) / 512.f) * 255.f);
									vCol.y = int((float(y) / 512.f) * 255.f);
									vCol.z = int((float(63 - z) / 64.f) * 255.f);
								}
								if (glowClamp) {
									vCol.x = Min(vCol.x, 254);
									vCol.y = Min(vCol.y, 254);
									vCol.z = Min(vCol.z, 254);
								}
								
								zFirstSurface = false;
								++zCountSolid;
								
								vCol.x = Max(Min(vCol.x, 255), 0);
								vCol.y = Max(Min(vCol.y, 255), 0);
								vCol.z = Max(Min(vCol.z, 255), 0);
								
								iCol = vCol.x | (vCol.y << 8) | (vCol.z << 16) | (alpha << 24);
								map.SetSolid(x, y, z, iCol);
							} else {
								zRestSurfaces = !zFirstSurface;
							}
						}
					}
			}
			
			return 0;
		}
		
	}

	namespace ui {
		
		class GlitterUI : UIElement {
			bool useGlitterFromSource = true;
		
			private MainScreenMainMenu @owner;
			MainScreenUI @ui;
			private spades::ui::EventHandler @Closed;
			Font @font = ui.fontManager.GuiFont;
			
			private string fileName;
			
			GameMap @map;
			
			private spades::ui::Button @mileButton;
			private bool mileButtonToggled = false;
			
			private GlitterUIColorFields @grade;
			private GlitterUIColorFields @shadow;
			private GlitterUIRampUI @xRamp;
			private GlitterUIRampUI @yRamp;
			private GlitterUIRampUI @zRamp;
			private GlitterUIFieldElement @noiseMono;
			private GlitterUIFieldElement @noiseColor;
			private GlitterUIFieldElement @rain;
			private GlitterUIToggleElement @snow;
			private GlitterUIToggleElement @glowClamp;
			private GlitterUIToggleElement @glowStay;
			private GlitterUIToggleElement @debug;
			private GlitterUIToggleElement @repair;
			
			GlitterUI(MainScreenUI @ui, MainScreenMainMenu @o, string fN) {
				super(ui.manager);
				
				@this.ui = ui;
				@this.owner = o;
				this.Bounds = owner.Bounds;
				
				float ContentsWidth = 800.f;
				float ContentsLeft = (Manager.Renderer.ScreenWidth - ContentsWidth) * 0.5f;
				float ContentsHeight = 550.f;
				float ContentsTop = (Manager.Renderer.ScreenHeight - ContentsHeight) * 0.5f;
				float ContentsMid = ContentsLeft + ContentsWidth * 0.5f;
				
				fileName = fN;
				@map = GameMap("MapEditor/Maps/" + fN);
				
				{ //ui elements
					
					{ //make screen darker
						spades::ui::Label label(Manager);
						label.BackgroundColor = Vector4(0, 0, 0, 0.4f);
						label.Bounds = Bounds;
						AddChild(label);
					}
					{ //ui window
						spades::ui::Label label(Manager);
						label.BackgroundColor = Vector4(0, 0, 0, 0.9f);
						label.Bounds = AABB2(ContentsLeft, ContentsTop, ContentsWidth, ContentsHeight);
						AddChild(label);
					}
					{
						spades::ui::Button button(Manager);
						button.Caption = _Tr("MainScreen", "Glitter, Mile's Map Post-Processing Tool");
						button.Bounds = AABB2(ContentsLeft + 5, ContentsTop + 5, 300, 35);
						button.Enable = true;
						@button.Activated = spades::ui::EventHandler(this.OnMile);
						@mileButton = button;
						AddChild(mileButton);
					}
					{
						spades::ui::Label label(Manager);
						label.Bounds = AABB2(ContentsLeft + 5, ContentsTop + ContentsHeight - 30, 0, 0);
						label.Text = fileName;
						AddChild(label);
					}
					{
						spades::ui::Button button(Manager);
						button.Caption = _Tr("MainScreen", "Done");
						button.Bounds = AABB2(ContentsLeft + ContentsWidth - 65, ContentsTop + ContentsHeight - 40, 60, 35);
						button.Enable = true;
						@button.Activated = spades::ui::EventHandler(this.OnDone);
						AddChild(button);
					}
					{
						CancelButton button(Manager);
						button.Caption = _Tr("MainScreen", "Cancel");
						button.Bounds = AABB2(ContentsLeft + ContentsWidth - 130, ContentsTop + ContentsHeight - 40, 60, 35);
						button.Enable = true;
						@button.Activated = spades::ui::EventHandler(this.OnCancel);
						AddChild(button);
					}
				
					{
						string info = "";
						
						float ySpacing = 0;
						Vector2 pos = 
							Vector2(
								ContentsLeft + 10,
								ContentsTop + 60
							);
						{ //left side
							ySpacing = 50;
							
							info = 
								"Will assume 0 for empty fields if at least one field is given. \n"
								+ "Wont have any effect if all fields are empty. \n";
							@grade = 
								GlitterUIColorFields(
									this, pos, "Grade", 
									"Multiplies the map\'s colors with a RGB value. \n" + info
								);
							pos.y += ySpacing;
							@shadow = 
								GlitterUIColorFields(
									this, pos, "Shadow", 
									"Substracts input as shadows. \n" + info
								);
							
							info =
								"Will assume 0 for empty color fields if at least one color field is given. \n"
								+ "Wont have any effect if all color fields are empty. \n"
								+ "Wont have any effect if Range [(-512)-512] is empty or 0. \n"
								+ "negative range will reverse direction of range.";
							pos.y += ySpacing;
							ySpacing += 30;
							@xRamp = 
								GlitterUIRampUI(
									this, pos, "Ramp X", 
									"Ramps X axis of the map. \n" + info
								);
							pos.y += ySpacing;
							@yRamp = 
								GlitterUIRampUI(
									this, pos, "Ramp Y", 
									"Ramps Y axis of the map. \n" + info
								);
							pos.y += ySpacing;
							@zRamp = 
								GlitterUIRampUI(
									this, pos, "Ramp Z", 
									"Ramps Z axis of the map. \n" + info
								);
						}
						
						pos = 
							Vector2(
								ContentsMid + 10,
								ContentsTop + 60
							);
						{ //right side
							ySpacing = 50;
						
							info = 
								"No effect if field is 0 or empty";
							@noiseMono = 
								GlitterUIFieldElement(
									this, pos, "NoiseMono", 
									"Adds monochromatic noise to map. \n" + info
								);
							pos.y += ySpacing;
							@noiseColor = 
								GlitterUIFieldElement(
									this, pos, "NoiseColor", 
									"Adds chromatic noise to map. \n" + info
								);
							pos.y += ySpacing;
							@rain = 
								GlitterUIFieldElement(
									this, pos, "Rain", 
									"Adds rain to the map. \n" + info
								);
							
							pos.y += ySpacing;
							@snow =
								GlitterUIToggleElement(
									this, pos, "Snow", 
									"Adds snow to the map."
								);
							pos.y += ySpacing;
							@glowClamp =
								GlitterUIToggleElement(
									this, pos, "GlowClamp", 
									"Removes all glow blocks by clamping all color values to 254."
								);
							pos.y += ySpacing;
							@glowStay =
								GlitterUIToggleElement(
									this, pos, "GlowStay", 
									"Ensures the fed glow map keeps"
								);
							pos.y += ySpacing;
							@debug =
								GlitterUIToggleElement(
									this, pos, "Debug", 
									"Replaces colors with a P-map gradient."
								);
							pos.y += ySpacing;
							@repair =
								GlitterUIToggleElement(
									this, pos, "Repair", 
									"Fixes alpha channel issue with some file editors."
								);
						}
						
					}
					
				}
				
			}
			
			private int DoGlitter(GameMap @map) {
				if (useGlitterFromSource) {
					Glitter glitter();
					AddGlitterArgsSource(@glitter);
					return glitter.DoGlitter(@map);
				}
				
				GlitterScript glitter();
				return glitter.DoGlitter(
					map, 
					IntVector3(grade.r, grade.g, grade.b),
					IntVector3(shadow.r, shadow.g, shadow.b),
					IntVector3(xRamp.r, xRamp.g, xRamp.b), xRamp.range,
					IntVector3(yRamp.r, yRamp.g, yRamp.b), yRamp.range,
					IntVector3(zRamp.r, zRamp.g, zRamp.b), zRamp.range,
					noiseMono.val, noiseColor.val, rain.val,
					snow.active, glowClamp.active, glowStay.active, 
					debug.active, repair.active
				);
			}
			
			private void AddGlitterArgsSource(Glitter @glitter) {
				int i = 0;
				
				glitter.GlitterAddArg(i++, int(grade.r));
				glitter.GlitterAddArg(i++, int(grade.g));
				glitter.GlitterAddArg(i++, int(grade.b));
				glitter.GlitterAddArg(i++, int(shadow.r));
				glitter.GlitterAddArg(i++, int(shadow.g));
				glitter.GlitterAddArg(i++, int(shadow.b));
				glitter.GlitterAddArg(i++, int(xRamp.r));
				glitter.GlitterAddArg(i++, int(xRamp.g));
				glitter.GlitterAddArg(i++, int(xRamp.b));
				glitter.GlitterAddArg(i++, int(xRamp.range));
				glitter.GlitterAddArg(i++, int(yRamp.r));
				glitter.GlitterAddArg(i++, int(yRamp.g));
				glitter.GlitterAddArg(i++, int(yRamp.b));
				glitter.GlitterAddArg(i++, int(yRamp.range));
				glitter.GlitterAddArg(i++, int(zRamp.r));
				glitter.GlitterAddArg(i++, int(zRamp.g));
				glitter.GlitterAddArg(i++, int(zRamp.b));
				glitter.GlitterAddArg(i++, int(zRamp.range));
				glitter.GlitterAddArg(i++, int(noiseMono.val));
				glitter.GlitterAddArg(i++, int(noiseColor.val));
				glitter.GlitterAddArg(i++, int(rain.val));
				glitter.GlitterAddArg(i++, snow.active ? 1 : 0);
				glitter.GlitterAddArg(i++, repair.active ? 1 : 0);
				glitter.GlitterAddArg(i++, glowStay.active ? 1 : 0);
				glitter.GlitterAddArg(i++, glowClamp.active ? 1 : 0);
				glitter.GlitterAddArg(i++, debug.active ? 1 : 0);
			}
			
			private void HotKey(string key) {
				if (key == "Escape") {
					Close();//cancel
				} else if (key == "Enter") {
					Done();
				} else {
					UIElement::HotKey(key);
				}
			}
			
			private void OnMile(spades::ui::UIElement @sender) {
				mileButton.Caption = mileButtonToggled
					? _Tr("MainScreen", "Glitter, Mile's Map Post-Processing Tool")
					: _Tr("MainScreen", "https://github.com/yusufcardinal/glitter");
				mileButtonToggled = !mileButtonToggled;
			}
			
			private void OnDone(spades::ui::UIElement @sender) { Done(); }
			
			private void Done() {
				if (DoGlitter(map) < 0) {
					GlitterUIInfo warning(this, "!", " Glitter canceled. no arguments given. ");
					warning.Run();
					return;
				}
				
				FileHandler fH();
				
				string newName = "MapEditor/Maps/" + fileName + " - Glitter.vxl";
				for (int i = 0; fH.FileExists(newName); i++) {
					int glitExt = newName.findFirst("- Glitter");
					newName = newName.substr(0, glitExt + 1) + " Glitter";
					newName += "(" + formatUInt(i, "l", 1) + ")" + ".vxl";
				}
				
				map.Save(newName);
				owner.LoadServerList();
				Close();
			}
			
			private void OnCancel(spades::ui::UIElement @sender) { Close(); }
			
			void Run() {
				owner.Enable = false;
				owner.Parent.AddChild(this);
			}
			
			void Close() {
				owner.Enable = true;
				@this.Parent = null;
				if (Closed !is null)
					Closed(this);
			}
			
		}
		
		class GlitterUIElement {
			private GlitterUI @owner;
			private GlitterUIInfo @info;
			
			GlitterUIElement(GlitterUI @o, Vector2 pos, string caption, string infoText) {
				@owner = o;
				@info = GlitterUIInfo(o, caption, infoText);
				
				{
					spades::ui::Label label(o.Manager);
					label.Bounds = AABB2(pos.x, pos.y, 0, 0);
					label.Text = caption;
					o.AddChild(label);
				}
				
				pos.x += 90 - o.font.Measure(" ? ").x;
				{
					spades::ui::Button button(o.Manager);
					button.Caption = _Tr("Glitter", " ? ");
					button.Bounds = 
						AABB2(pos.x, pos.y - 2.5f, o.font.Measure(button.Caption).x + 5, 30);
					@button.Activated = spades::ui::EventHandler(this.OnInfo);
					o.AddChild(button);
				}
				
			}
			
			private void OnInfo(spades::ui::UIElement @sender) { info.Run(); }
			
		}
		
		class GlitterUIToggleElement : GlitterUIElement {
			private ToggleButton @button;
			
			GlitterUIToggleElement(GlitterUI @o, Vector2 pos, string caption, string infoText) {
				super(o, pos, caption, infoText);
				pos.x += 100;
				
				{
					@button = ToggleButton(o.Manager);
					button.Caption = _Tr("Glitter", "Enabled");
					button.Bounds = AABB2(pos.x, pos.y, o.font.Measure(button.Caption).x + 5, 30);
					button.Enable = true;
					o.AddChild(button);
				}
			}
			
			bool active { get { return button.Toggled; } }
			
		}
		
		class GlitterUIFieldElement : GlitterUIElement {
			private spades::ui::Field @valField;
			
			GlitterUIFieldElement(GlitterUI @o, Vector2 pos, string caption, string infoText) {
				super(o, pos, caption, infoText);
				pos.x += 100;
				
				{
					@valField = spades::ui::Field(o.Manager);
					float width = o.font.Measure("1-100%").x + 5;
					valField.Bounds = AABB2(pos.x, pos.y, width, 25);
					valField.Placeholder = _Tr("Glitter", "0-100%");
					o.AddChild(valField);
				}
				
			}
			
			int val { get { return Min(100, parseInt(valField.Text)); } }
			
		}
		
		class GlitterUIColorFields : GlitterUIElement {
			private spades::ui::Field @rField;
			private spades::ui::Field @gField;
			private spades::ui::Field @bField;
			
			GlitterUIColorFields(GlitterUI @o, Vector2 pos, string caption, string infoText) {
				super(o, pos, caption, infoText);
				pos.x += 100; //caption and infobutton
				
				{
					@rField = spades::ui::Field(o.Manager);
					float width = o.font.Measure("0-255 R").x + 5;
					rField.Bounds = AABB2(pos.x, pos.y, width, 25);
					rField.Placeholder = _Tr("Glitter", "0-255 R");
					o.AddChild(rField);
					
					pos.x += width + 5;
				}
				{
					@gField = spades::ui::Field(o.Manager);
					float width = o.font.Measure("0-255 G").x + 5;
					gField.Bounds = AABB2(pos.x, pos.y, width, 25);
					gField.Placeholder = _Tr("Glitter", "0-255 G");
					o.AddChild(gField);
					
					pos.x += width + 5;
				}
				{
					@bField = spades::ui::Field(o.Manager);
					float width = o.font.Measure("0-255 B").x + 5;
					bField.Bounds = AABB2(pos.x, pos.y, width, 25);
					bField.Placeholder = _Tr("Glitter", "0-255 B");
					o.AddChild(bField);
					
					pos.x += width + 5;
				}
				
			}
			
			int r { get { return rField.Text.length == 0 ? -1 : Min(parseUInt(rField.Text), 255); } }
			int g { get { return gField.Text.length == 0 ? -1 : Min(parseUInt(gField.Text), 255); } }
			int b { get { return bField.Text.length == 0 ? -1 : Min(parseUInt(bField.Text), 255); } }
			
		}
		
		class GlitterUIRampUI : GlitterUIColorFields {
			private spades::ui::Field @rangeField;
			
			GlitterUIRampUI(GlitterUI @o, Vector2 pos, string caption, string infoText) {
				super(o, pos, caption, infoText);
				//caption, info and color fields
				pos.x += 100;
				pos.y += 30;
				
				{
					@rangeField = spades::ui::Field(o.Manager);
					float width = o.font.Measure("(-512)-512").x + 5;
					rangeField.Bounds = AABB2(pos.x, pos.y, width, 25);
					rangeField.Placeholder = _Tr("Glitter", "(-512)-512");
					o.AddChild(rangeField);
				}
				
			}
			
			//if range < 0 then reversed
			int range { get { return Max(-512, Min(512, parseInt(rangeField.Text))); } }
			
		}
		
		class GlitterUIInfo : UIElement {
			private GlitterUI @owner;
			private spades::ui::EventHandler @Closed;
			bool isWarning;
			
			GlitterUIInfo(GlitterUI @o, string caption, string infoText) {
				super(o.ui.manager);
				@owner = o;
				this.Bounds = o.Bounds;
				
				isWarning = caption == "!";
				
				float width = Max(400, int(o.font.Measure(infoText).x) + 10);
				float height = Max(125, int(o.font.Measure(infoText).y) + 10);
				Vector2 pos = 
					Vector2(
						(Manager.Renderer.ScreenWidth - width) * 0.5f,
						(Manager.Renderer.ScreenHeight - height) * 0.5f
					);
				
				{
					
					{
						spades::ui::Label label(Manager);
						label.BackgroundColor = Vector4(1, 1, 1, 1);
						label.Bounds = 
							AABB2(pos.x - 1, pos.y - 1, width + 2, height + 2);
						AddChild(label);
					}
					{
						spades::ui::Label label(Manager);
						label.BackgroundColor = Vector4(0, 0, 0, 1);
						label.Bounds = AABB2(pos.x, pos.y, width, height);
						AddChild(label);
					}
					{
						CancelButton button(Manager);
						button.Caption = _Tr("Glitter", "X");
						button.Bounds = AABB2(pos.x + width - 30, pos.y, 30, 30);
						@button.Activated = spades::ui::EventHandler(this.OnClose);
						AddChild(button);
					}
					{
						spades::ui::Label label(Manager);
						label.Bounds = AABB2(pos.x + 5, pos.y + 5, 0, 0);
						label.Text = caption;
						AddChild(label);
					}
					{
						spades::ui::Label label(Manager);
						label.Bounds = AABB2(pos.x + 5, pos.y + 40, 0, 0);
						label.Text = infoText;
						AddChild(label);
					}
					
				}
				
			}
			
			private void HotKey(string key) {
				if (key == "Escape" || key == "Enter") {
					Close();
				} else {
					UIElement::HotKey(key);
				}
			}
			
			private void OnClose(spades::ui::UIElement @sender) { Close(); }
			
			void Run() {
				owner.Parent.AddChild(this);
				owner.Enable = false;
			}
			
			void Close() {
				owner.Enable = true;
				if (isWarning)
					owner.Close();
				@this.Parent = null;
				if (Closed !is null)
					Closed(this);
			}
			
		}
		
	}

}
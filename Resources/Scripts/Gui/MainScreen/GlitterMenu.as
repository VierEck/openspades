#include "MainMenu.as"

namespace spades {

	class ToggleButton : spades::ui::Button {
		ToggleButton(spades::ui::UIManager manager) {
			super(manager);
			this.Toggled = false;
		}

		void OnActivated() { this.Toggled = !this.Toggled; }
	}
	
	class GlitterMenu : spades::ui::UIElement {
		MainScreenUI @ui;
		MainScreenHelper @helper;
		MainScreenMainMenu @owner;
		float ContentsLeft, ContentsWidth;
		float ContentsTop, ContentsHeight;
		float ContentsMid;
		spades::ui::EventHandler @Closed;
		
		string mapFileName;
		
		spades::ui::Button @mileButton;
		bool mileButtonToggled = false;
		
		spades::ui::Field @gradeFieldR;
		spades::ui::Field @gradeFieldG;
		spades::ui::Field @gradeFieldB;
		
		spades::ui::Field @shadowFieldR;
		spades::ui::Field @shadowFieldG;
		spades::ui::Field @shadowFieldB;
		
		spades::ui::Field @rampXFieldR;
		spades::ui::Field @rampXFieldG;
		spades::ui::Field @rampXFieldB;
		ToggleButton @rampXButtonReversed;
		spades::ui::Field @rampXFieldRange;
		
		spades::ui::Field @rampYFieldR;
		spades::ui::Field @rampYFieldG;
		spades::ui::Field @rampYFieldB;
		ToggleButton @rampYButtonReversed;
		spades::ui::Field @rampYFieldRange;
		
		spades::ui::Field @rampZFieldR;
		spades::ui::Field @rampZFieldG;
		spades::ui::Field @rampZFieldB;
		ToggleButton @rampZButtonReversed;
		spades::ui::Field @rampZFieldRange;
		
		spades::ui::Field @noisemonoField;
		spades::ui::Field @noisecolorField;
		spades::ui::Field @rainField;
		
		ToggleButton @snowButton;
		ToggleButton @repairButton;
		ToggleButton @glowButton;
		ToggleButton @debugButton;
		
		GlitterMenu(MainScreenUI @ui, MainScreenMainMenu @owner, string fN) {
			super(ui.manager);
			@this.owner = owner;
			@this.ui = ui;
			@this.helper = ui.helper;
			this.Bounds = owner.Bounds;
			ContentsWidth = 800.f;
			ContentsLeft = (Manager.Renderer.ScreenWidth - ContentsWidth) * 0.5f;
			ContentsHeight = 550.f;
			ContentsTop = (Manager.Renderer.ScreenHeight - ContentsHeight) * 0.5f;
			
			ContentsMid = ContentsLeft + ContentsWidth * 0.5f;
			
			mapFileName = fN;
			
			{
				spades::ui::Label label(Manager);
				label.BackgroundColor = Vector4(0, 0, 0, 0.4f);
				label.Bounds = Bounds;
				AddChild(label);
			}
			{
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
				label.Text = mapFileName;
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
				spades::ui::Button button(Manager);
				button.Caption = _Tr("MainScreen", "Cancel");
				button.Bounds = AABB2(ContentsLeft + ContentsWidth - 130, ContentsTop + ContentsHeight - 40, 60, 35);
				button.Enable = true;
				@button.Activated = spades::ui::EventHandler(this.OnCancel);
				AddChild(button);
			}
			
			{
				float FieldDimensionY = 25;
				
				float ButtonExtraY = 2.5f;
				float ButtonDimensionY = FieldDimensionY + ButtonExtraY * 2;
				
				float ColorFieldDimensionX = 55;
				string RedPlaceHolder = "0-255 R";
				string GreenPlaceHolder = "0-255 G";
				string BluePlaceHolder = "0-255 B";
				
				float PercentageFieldDimensionX = 50;
				string PercentagePlaceHolder = "0-100%";
				
				float RangeFieldDimensionX = 85;
				string RangePlaceHolder = "0-512 Range";
				string ZRangePlaceHolder = "0-64 Range";
				
				float reversedButtonDimensionX = 75;
				string ReversedCaption = "reversed";
				
				float EnabledButtonDimensionX = reversedButtonDimensionX;
				string EnabledCaption = "enabled";
				
				float InfoButtonDimensionX = 10;
				string InfoButtonCaption = "?";
				
				float xSpacing = 10;
				float ySpacing = 30;
				
				float yInterSpacing = 5;
				
				float TopBegin = 100;
				float LineBegin = 50;
				
				float HeadingSpacing = 65;
				float InfoSpacing = xSpacing * 3;
				float xPos;
				float yPos = ContentsTop + TopBegin; //left page
				{//grade
					xPos = ContentsLeft + LineBegin;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "Grade";
					AddChild(label);
					
					@gradeFieldR = spades::ui::Field(Manager);
					xPos += HeadingSpacing;
					gradeFieldR.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					gradeFieldR.Placeholder = _Tr("Glitter", RedPlaceHolder);
					AddChild(gradeFieldR);
					
					@gradeFieldG = spades::ui::Field(Manager);
					xPos += ColorFieldDimensionX + xSpacing;
					gradeFieldG.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					gradeFieldG.Placeholder = _Tr("Glitter", GreenPlaceHolder);
					AddChild(gradeFieldG);
					
					@gradeFieldB = spades::ui::Field(Manager);
					xPos += ColorFieldDimensionX + xSpacing;
					gradeFieldB.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					gradeFieldB.Placeholder = _Tr("Glitter", BluePlaceHolder);
					AddChild(gradeFieldB);
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += ColorFieldDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoGrade);
					AddChild(button);
					yPos += ButtonExtraY;
				}
				{//shadow
					xPos = ContentsLeft + LineBegin;
					yPos += FieldDimensionY + ySpacing;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "Shadow";
					AddChild(label);
					
					@shadowFieldR = spades::ui::Field(Manager);
					xPos += HeadingSpacing;
					shadowFieldR.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					shadowFieldR.Placeholder = _Tr("Glitter", RedPlaceHolder);
					AddChild(shadowFieldR);
					
					@shadowFieldG = spades::ui::Field(Manager);
					xPos += ColorFieldDimensionX + xSpacing;
					shadowFieldG.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					shadowFieldG.Placeholder = _Tr("Glitter", GreenPlaceHolder);
					AddChild(shadowFieldG);
					
					@shadowFieldB = spades::ui::Field(Manager);
					xPos += ColorFieldDimensionX + xSpacing;
					shadowFieldB.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					shadowFieldB.Placeholder = _Tr("Glitter", BluePlaceHolder);
					AddChild(shadowFieldB);
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += ColorFieldDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoShadow);
					AddChild(button);
					yPos += ButtonExtraY;
				}
				{//ramp x
					xPos = ContentsLeft + LineBegin;
					yPos += FieldDimensionY + ySpacing;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "Ramp X";
					AddChild(label);
					
					@rampXFieldR = spades::ui::Field(Manager);
					xPos += HeadingSpacing;
					rampXFieldR.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					rampXFieldR.Placeholder = _Tr("Glitter", RedPlaceHolder);
					AddChild(rampXFieldR);
					
					@rampXFieldG = spades::ui::Field(Manager);
					xPos += ColorFieldDimensionX + xSpacing;
					rampXFieldG.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					rampXFieldG.Placeholder = _Tr("Glitter", GreenPlaceHolder);
					AddChild(rampXFieldG);
					
					@rampXFieldB = spades::ui::Field(Manager);
					xPos += ColorFieldDimensionX + xSpacing;
					rampXFieldB.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					rampXFieldB.Placeholder = _Tr("Glitter", BluePlaceHolder);
					AddChild(rampXFieldB);
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += ColorFieldDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoRampX);
					AddChild(button);
					yPos += ButtonExtraY;
					
					xPos = ContentsLeft + LineBegin + HeadingSpacing;
					yPos += FieldDimensionY + yInterSpacing;
					
					@rampXButtonReversed = ToggleButton(Manager);
					rampXButtonReversed.Caption = _Tr("Glitter", ReversedCaption);
					yPos -= ButtonExtraY;
					rampXButtonReversed.Bounds = AABB2(xPos, yPos, reversedButtonDimensionX, ButtonDimensionY);
					rampXButtonReversed.Enable = true;
					AddChild(rampXButtonReversed);
					yPos += ButtonExtraY;
					
					@rampXFieldRange = spades::ui::Field(Manager);
					xPos += reversedButtonDimensionX + xSpacing;
					rampXFieldRange.Bounds = AABB2(xPos, yPos, RangeFieldDimensionX, FieldDimensionY);
					rampXFieldRange.Placeholder = _Tr("Glitter", RangePlaceHolder);
					AddChild(rampXFieldRange);
				} 
				{//ramp y
					xPos = ContentsLeft + LineBegin;
					yPos += FieldDimensionY + ySpacing;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "Ramp Y";
					AddChild(label);
					
					@rampYFieldR = spades::ui::Field(Manager);
					xPos += HeadingSpacing;
					rampYFieldR.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					rampYFieldR.Placeholder = _Tr("Glitter", RedPlaceHolder);
					AddChild(rampYFieldR);
					
					@rampYFieldG = spades::ui::Field(Manager);
					xPos += ColorFieldDimensionX + xSpacing;
					rampYFieldG.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					rampYFieldG.Placeholder = _Tr("Glitter", GreenPlaceHolder);
					AddChild(rampYFieldG);
					
					@rampYFieldB = spades::ui::Field(Manager);
					xPos += ColorFieldDimensionX + xSpacing;
					rampYFieldB.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					rampYFieldB.Placeholder = _Tr("Glitter", BluePlaceHolder);
					AddChild(rampYFieldB);
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += ColorFieldDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoRampY);
					AddChild(button);
					yPos += ButtonExtraY;
					
					xPos = ContentsLeft + LineBegin + HeadingSpacing;
					yPos += FieldDimensionY + yInterSpacing;
					
					@rampYButtonReversed = ToggleButton(Manager);
					rampYButtonReversed.Caption = _Tr("Glitter", ReversedCaption);
					yPos -= ButtonExtraY;
					rampYButtonReversed.Bounds = AABB2(xPos, yPos, reversedButtonDimensionX, ButtonDimensionY);
					rampYButtonReversed.Enable = true;
					AddChild(rampYButtonReversed);
					yPos += ButtonExtraY;
					
					@rampYFieldRange = spades::ui::Field(Manager);
					xPos += reversedButtonDimensionX + xSpacing;
					rampYFieldRange.Bounds = AABB2(xPos, yPos, RangeFieldDimensionX, FieldDimensionY);
					rampYFieldRange.Placeholder = _Tr("Glitter", RangePlaceHolder);
					AddChild(rampYFieldRange);
				}
				{//ramp z
					xPos = ContentsLeft + LineBegin;
					yPos += FieldDimensionY + ySpacing;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "Ramp Z";
					AddChild(label);
					
					@rampZFieldR = spades::ui::Field(Manager);
					xPos += HeadingSpacing;
					rampZFieldR.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					rampZFieldR.Placeholder = _Tr("Glitter", RedPlaceHolder);
					AddChild(rampZFieldR);
					
					@rampZFieldG = spades::ui::Field(Manager);
					xPos += ColorFieldDimensionX + xSpacing;
					rampZFieldG.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					rampZFieldG.Placeholder = _Tr("Glitter", GreenPlaceHolder);
					AddChild(rampZFieldG);
					
					@rampZFieldB = spades::ui::Field(Manager);
					xPos += ColorFieldDimensionX + xSpacing;
					rampZFieldB.Bounds = AABB2(xPos, yPos, ColorFieldDimensionX, FieldDimensionY);
					rampZFieldB.Placeholder = _Tr("Glitter", BluePlaceHolder);
					AddChild(rampZFieldB);
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += ColorFieldDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoRampZ);
					AddChild(button);
					yPos += ButtonExtraY;
					
					xPos = ContentsLeft + LineBegin + HeadingSpacing;
					yPos += FieldDimensionY + yInterSpacing;
					
					@rampZButtonReversed = ToggleButton(Manager);
					rampZButtonReversed.Caption = _Tr("Glitter", ReversedCaption);
					yPos -= ButtonExtraY;
					rampZButtonReversed.Bounds = AABB2(xPos, yPos, reversedButtonDimensionX, ButtonDimensionY);
					rampZButtonReversed.Enable = true;
					AddChild(rampZButtonReversed);
					yPos += ButtonExtraY;
					
					@rampZFieldRange = spades::ui::Field(Manager);
					xPos += reversedButtonDimensionX + xSpacing;
					rampZFieldRange.Bounds = AABB2(xPos, yPos, RangeFieldDimensionX, FieldDimensionY);
					rampZFieldRange.Placeholder = _Tr("Glitter", ZRangePlaceHolder);
					AddChild(rampZFieldRange);
				}
				
				HeadingSpacing = 105;
				yPos = ContentsTop + TopBegin; //right page
				{//noisemono
					xPos = ContentsMid + LineBegin;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "NoiseMono";
					AddChild(label);
					
					@noisemonoField = spades::ui::Field(Manager);
					xPos += HeadingSpacing;
					noisemonoField.Bounds = AABB2(xPos, yPos, PercentageFieldDimensionX, FieldDimensionY);
					noisemonoField.Placeholder = _Tr("Glitter", PercentagePlaceHolder);
					AddChild(noisemonoField);
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += PercentageFieldDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoNoiseMono);
					AddChild(button);
					yPos += ButtonExtraY;
				}
				{//noisecolor
					xPos = ContentsMid + LineBegin;
					yPos += FieldDimensionY + ySpacing;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "NoiseColor";
					AddChild(label);
					
					@noisecolorField = spades::ui::Field(Manager);
					xPos += HeadingSpacing;
					noisecolorField.Bounds = AABB2(xPos, yPos, PercentageFieldDimensionX, FieldDimensionY);
					noisecolorField.Placeholder = _Tr("Glitter", PercentagePlaceHolder);
					AddChild(noisecolorField);
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += PercentageFieldDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoNoiseColor);
					AddChild(button);
					yPos += ButtonExtraY;
				}
				{//rain
					xPos = ContentsMid + LineBegin;
					yPos += FieldDimensionY + ySpacing;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "Rain";
					AddChild(label);
					
					@rainField = spades::ui::Field(Manager);
					xPos += HeadingSpacing;
					rainField.Bounds = AABB2(xPos, yPos, PercentageFieldDimensionX, FieldDimensionY);
					rainField.Placeholder = _Tr("Glitter", PercentagePlaceHolder);
					AddChild(rainField);
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += PercentageFieldDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoRain);
					AddChild(button);
					yPos += ButtonExtraY;
				}
				{//snow
					xPos = ContentsMid + LineBegin;
					yPos += FieldDimensionY + ySpacing;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "Snow";
					AddChild(label);
					
					@snowButton = ToggleButton(Manager);
					snowButton.Caption = _Tr("Glitter", EnabledCaption);
					xPos += HeadingSpacing;
					yPos -= ButtonExtraY;
					snowButton.Bounds = AABB2(xPos, yPos, EnabledButtonDimensionX, ButtonDimensionY);
					snowButton.Enable = true;
					AddChild(snowButton);
					yPos += ButtonExtraY;
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += EnabledButtonDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoSnow);
					AddChild(button);
					yPos += ButtonExtraY;
				}
				{//repair
					xPos = ContentsMid + LineBegin;
					yPos += FieldDimensionY + ySpacing;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "Repair";
					AddChild(label);
					
					@repairButton = ToggleButton(Manager);
					repairButton.Caption = _Tr("Glitter", EnabledCaption);
					xPos += HeadingSpacing;
					yPos -= ButtonExtraY;
					repairButton.Bounds = AABB2(xPos, yPos, EnabledButtonDimensionX, ButtonDimensionY);
					repairButton.Enable = true;
					AddChild(repairButton);
					yPos += ButtonExtraY;
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += EnabledButtonDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoRepair);
					AddChild(button);
					yPos += ButtonExtraY;
				}
				{//glowcompliant
					xPos = ContentsMid + LineBegin;
					yPos += FieldDimensionY + ySpacing;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "GlowCompliant";
					AddChild(label);
					
					@glowButton = ToggleButton(Manager);
					glowButton.Caption = _Tr("Glitter", EnabledCaption);
					xPos += HeadingSpacing;
					yPos -= ButtonExtraY;
					glowButton.Bounds = AABB2(xPos, yPos, EnabledButtonDimensionX, ButtonDimensionY);
					glowButton.Enable = true;
					AddChild(glowButton);
					yPos += ButtonExtraY;
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += EnabledButtonDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoGlow);
					AddChild(button);
					yPos += ButtonExtraY;
				}
				{//debug
					xPos = ContentsMid + LineBegin;
					yPos += FieldDimensionY + ySpacing;
					
					spades::ui::Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "Debug";
					AddChild(label);
					
					@debugButton = ToggleButton(Manager);
					debugButton.Caption = _Tr("Glitter", EnabledCaption);
					xPos += HeadingSpacing;
					yPos -= ButtonExtraY;
					debugButton.Bounds = AABB2(xPos, yPos, EnabledButtonDimensionX, ButtonDimensionY);
					debugButton.Enable = true;
					AddChild(debugButton);
					yPos += ButtonExtraY;
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("Glitter", InfoButtonCaption);
					xPos += EnabledButtonDimensionX + InfoSpacing;
					yPos -= ButtonExtraY;
					button.Bounds = AABB2(xPos, yPos, InfoButtonDimensionX, ButtonDimensionY);
					button.Enable = true;
					@button.Activated = spades::ui::EventHandler(this.OnInfoDebug);
					AddChild(button);
					yPos += ButtonExtraY;
				}
				
			}
			
		}
		
		spades::ui::Label @InfoHead;
		spades::ui::Label @InfoLine1;
		spades::ui::Label @InfoLine2;
		spades::ui::Label @InfoLine3;
		int infoLineCount;
		spades::ui::Label @InfoLabel;
		spades::ui::Label @InfoBorder;
		spades::ui::Button @InfoCloseButton;
		bool IsInfoFieldVisible = false;
		void InfoFieldOpen(string headLine, string info) {
			if (IsInfoFieldVisible)
				return;
			IsInfoFieldVisible = true;
			
			string[] @lines = info.split("\n");
			infoLineCount = lines.length;
			
			float width = 400;
			float height = 125;
			
			float xPos = ContentsMid - width * 0.5f;
			float yPos = (ContentsTop + ContentsHeight * 0.5f) - height * 0.5f;
			
			{
				@InfoBorder = spades::ui::Label(Manager);
				InfoBorder.BackgroundColor = Vector4(1, 1, 1, 1);
				InfoBorder.Bounds = AABB2(xPos - 1, yPos - 1, width + 2, height + 2);
				AddChild(InfoBorder);
			}
			{
				@InfoLabel = spades::ui::Label(Manager);
				InfoLabel.BackgroundColor = Vector4(0, 0, 0, 1);
				InfoLabel.Bounds = AABB2(xPos, yPos, width, height);
				AddChild(InfoLabel);
			}
			{
				@InfoHead = spades::ui::Label(Manager);
				InfoHead.Bounds = AABB2(xPos + 5, yPos + 5, 0, 0);
				InfoHead.Text = headLine;
				AddChild(InfoHead);
			}
			for (uint i = 0; i < infoLineCount; i++) {
				//scuffed
				if (i == 0) {
					@InfoLine1 = spades::ui::Label(Manager);
					InfoLine1.Bounds = AABB2(xPos + 5, yPos + 40, 0, 0);
					InfoLine1.Text = lines[i];
					AddChild(InfoLine1);
				}
				if (i == 1) {
					@InfoLine2 = spades::ui::Label(Manager);
					InfoLine2.Bounds = AABB2(xPos + 5, yPos + 67.5f, 0, 0);
					InfoLine2.Text = lines[i];
					AddChild(InfoLine2);
				}
				if (i == 2) {
					@InfoLine3 = spades::ui::Label(Manager);
					InfoLine3.Bounds = AABB2(xPos + 5, yPos + 95, 0, 0);
					InfoLine3.Text = lines[i];
					AddChild(InfoLine3);
					break;
				}
			}
			{
				@InfoCloseButton = spades::ui::Button(Manager);
				InfoCloseButton.Caption = _Tr("Glitter", "X");
				InfoCloseButton.Bounds = AABB2(xPos + width - 25, yPos, 25, 25);
				@InfoCloseButton.Activated = spades::ui::EventHandler(this.OnInfoFieldClose);
				AddChild(InfoCloseButton);
			}
		}
		void InfoFieldClose() {
			if (!IsInfoFieldVisible)
				return;
			IsInfoFieldVisible = false;
			RemoveChild(InfoHead);
			while (infoLineCount-- > 0) {
				if (infoLineCount == 2) RemoveChild(InfoLine3);
				if (infoLineCount == 1) RemoveChild(InfoLine2);
				if (infoLineCount == 0) RemoveChild(InfoLine1);
			}
			RemoveChild(InfoLabel);
			RemoveChild(InfoBorder);
			RemoveChild(InfoCloseButton);
		}
		void OnInfoFieldClose(spades::ui::UIElement @sender) { InfoFieldClose(); }
		
		void OnInfoGrade(spades::ui::UIElement @sender) {
			string info;
			info += "Multiplies the map\'s colors with a RGB value.";
			info += "\nTakes 3 arguments (R, G, B [0-255])";
			InfoFieldOpen("Grade", info);
		}
		void OnInfoShadow(spades::ui::UIElement @sender) {
			string info;
			info += "Substracts input as shadows.";
			info += "\nTakes 3 arguments (R, G, B [0-255])";
			InfoFieldOpen("Shadow", info);
		}
		void OnInfoRampX(spades::ui::UIElement @sender) {
			string info;
			info += "Ramps X axis of the map.";
			info += "\nTakes 5 arguments (R, G, B [0-255],";
			info += "\nreversed [False-True], range[0-512]";
			InfoFieldOpen("Ramp X", info);
		}
		void OnInfoRampY(spades::ui::UIElement @sender) {
			string info;
			info += "Ramps Y axis of the map.";
			info += "\nTakes 5 arguments (R, G, B [0-255],";
			info += "\nreversed [False-True], range[0-512]";
			InfoFieldOpen("Ramp Y", info);
		}
		void OnInfoRampZ(spades::ui::UIElement @sender) {
			string info;
			info += "Ramps Z axis of the map.";
			info += "\nTakes 5 arguments (R, G, B [0-255],";
			info += "\nreversed [False-True], range[0-512]";
			InfoFieldOpen("Ramp Z", info);
		}
		void OnInfoNoiseMono(spades::ui::UIElement @sender) {
			string info;
			info += "Adds monochromatic noise to map.";
			info += "\nTakes 1 argument (percentage).";
			InfoFieldOpen("NoiseMono", info);
		}
		void OnInfoNoiseColor(spades::ui::UIElement @sender) {
			string info;
			info += "Adds chromatic noise to map.";
			info += "\nTakes 1 argument (percentage).";
			InfoFieldOpen("NoiseColor", info);
		}
		void OnInfoRain(spades::ui::UIElement @sender) {
			string info;
			info += "Adds rain to the map.";
			info += "\nTakes 1 argument (percentage).";
			InfoFieldOpen("Rain", info);
		}
		void OnInfoSnow(spades::ui::UIElement @sender) {
			string info;
			info += "Adds snow to the map.";
			InfoFieldOpen("Snow", info);
		}
		void OnInfoRepair(spades::ui::UIElement @sender) {
			string info;
			info += "Fixes alpha channel issue with some file editors.";
			InfoFieldOpen("Repair", info);
		}
		void OnInfoGlow(spades::ui::UIElement @sender) {
			string info;
			info += "Ensures the fed glow map keeps";
			InfoFieldOpen("GlowCompliant", info);
		}
		void OnInfoDebug(spades::ui::UIElement @sender) {
			string info;
			info += "Replaces colors with a P-map gradient.";
			info += "\nUseful for debugging/making sure Glitter works fine.";
			InfoFieldOpen("Debug", info);
		}
		
		
		void OnMile(spades::ui::UIElement @sender) {
			mileButton.Caption = mileButtonToggled
				? _Tr("MainScreen", "Glitter, Mile's Map Post-Processing Tool")
				: _Tr("MainScreen", "https://github.com/yusufcardinal/glitter");
			mileButtonToggled = !mileButtonToggled;
		}
		
		void ProcessArgs() {
			AddArgField(gradeFieldR.Text);
			AddArgField(gradeFieldG.Text);
			AddArgField(gradeFieldB.Text);
			
			AddArgField(shadowFieldR.Text);
			AddArgField(shadowFieldG.Text);
			AddArgField(shadowFieldB.Text);
			
			AddArgField(rampXFieldR.Text);
			AddArgField(rampXFieldG.Text);
			AddArgField(rampXFieldB.Text);
			AddArgButton(rampXButtonReversed.Toggled);
			AddArgField(rampXFieldRange.Text);
			
			AddArgField(rampYFieldR.Text);
			AddArgField(rampYFieldG.Text);
			AddArgField(rampYFieldB.Text);
			AddArgButton(rampYButtonReversed.Toggled);
			AddArgField(rampYFieldRange.Text);
			
			AddArgField(rampZFieldR.Text);
			AddArgField(rampZFieldG.Text);
			AddArgField(rampZFieldB.Text);
			AddArgButton(rampZButtonReversed.Toggled);
			AddArgField(rampZFieldRange.Text);
			
			AddArgField(noisemonoField.Text);
			AddArgField(noisecolorField.Text);
			AddArgField(rainField.Text);
			
			AddArgButton(snowButton.Toggled);
			AddArgButton(snowButton.Toggled);
			AddArgButton(glowButton.Toggled);
			AddArgButton(debugButton.Toggled);
		}
		void AddArgField(string text) { 
			if (text.findFirst("0") < 0
				&& text.findFirst("1") < 0
				&& text.findFirst("2") < 0
				&& text.findFirst("3") < 0
				&& text.findFirst("4") < 0
				&& text.findFirst("5") < 0
				&& text.findFirst("6") < 0
				&& text.findFirst("7") < 0
				&& text.findFirst("8") < 0
				&& text.findFirst("9") < 0
				) { //if string contains no number
				AddArg(-1);
				return;
			}
			AddArg(text.length != 0 ? parseUInt(text) : -1);
		}
		void AddArgButton(bool toggled) { AddArg(toggled ? 1 : 0); }
		void AddArg(int arg) { ui.helper.GlitterAddArg(arg); }
		
		void OnDone(spades::ui::UIElement @sender) { Done(); }
		
		void Done() {
			ProcessArgs();
			ui.helper.GlitterMap("MapEditor/Maps/" + mapFileName);
			owner.LoadServerList();
			Close();
		}
		
		void OnCancel(spades::ui::UIElement @sender) { Close(); }
		
		void HotKey(string key) {
			if (key == "Escape") {
				Close();//cancel
			} else if (key == "Enter") {
				Done();
			} else {
				UIElement::HotKey(key);
			}
		}
		
		void Run() {
			owner.Enable = false;
			owner.Parent.AddChild(this);
		}
		
		void OnClosed() {
			if (Closed !is null)
				Closed(this);
		}
		
		void Close() {
			if (IsInfoFieldVisible) {
				InfoFieldClose();
				return;
			}
			owner.Enable = true;
			@this.Parent = null;
			OnClosed();
		}
		
	}
}
namespace spades {
	
	class HeightMap {
		GameMap @map;
		Bitmap @bitmap;
		
		IntVector3 color;
		uint tool; //circle = 0, square = 1,
		uint thickness;
		
		HeightMap(string fN) {
			@this.bitmap = Bitmap(512, 512);
			@this.map = GameMap(fN);
			
			color = IntVector3(0, 0, 0);
			tool = 0;
			thickness = 1;
		}
		
		void ReloadBitMap(int a, int whichAxis) {
			switch (whichAxis) {
				case 0: GetLayerX(a); break;
				case 1: GetLayerY(a); break;
				default: GetLayerZ(a); break;
			}
		}
		
		void GetLayerX(int x) {
			@this.bitmap = Bitmap(512, 64);
			for (int y = 0; y < 512; y++)
				for (int z = 0; z < 64; z++) {
					uint iCol = map.GetColor(x, y, z);
					uint red = uint8(iCol);
					uint green = uint8(iCol >> 8);
					uint blue = uint8(iCol >> 16);
					uint alpha = map.IsSolid(x, y, z) ? 255 : 0;
					iCol = red | (green << 8) | (blue << 16) | (alpha << 24);
					bitmap.SetPixel(y, z, iCol);
				}
		}
		void GetLayerY(int y) {
			@this.bitmap = Bitmap(512, 64);
			for (int x = 0; x < 512; x++)
				for (int z = 0; z < 64; z++) {
					uint iCol = map.GetColor(x, y, z);
					uint red = uint8(iCol);
					uint green = uint8(iCol >> 8);
					uint blue = uint8(iCol >> 16);
					uint alpha = map.IsSolid(x, y, z) ? 255 : 0;
					iCol = red | (green << 8) | (blue << 16) | (alpha << 24);
					bitmap.SetPixel(x, z, iCol);
				}
		}
		void GetLayerZ(int z) {
			@this.bitmap = Bitmap(512, 512);
			for (int x = 0; x < 512; x++)
				for (int y = 0; y < 512 ; y++) {
					uint iCol = map.GetColor(x, y, z);
					uint red = uint8(iCol);
					uint green = uint8(iCol >> 8);
					uint blue = uint8(iCol >> 16);
					uint alpha = map.IsSolid(x, y, z) ? 255 : 0;
					iCol = red | (green << 8) | (blue << 16) | (alpha << 24);
					bitmap.SetPixel(x, y, iCol);
				}
		}
		
		void SaveMap(string fN) { 
			int saved = map.Save(fN);
			//saved == -1 -> failed ?
		}
		
		void SetLayerX(int x) {
			for (int y = 0; y < 512; y++)
				for (int z = 0; z < 64; z++) {
					uint iCol = bitmap.GetPixel(y, z);
					uint red = uint8(iCol);
					uint green = uint8(iCol >> 8);
					uint blue = uint8(iCol >> 16);
					uint alpha = uint8(iCol >> 24);
					iCol = red | (green << 8) | (blue << 16) | (alpha << 24);
					if (alpha == 255)
						map.SetSolid(x, y, z, iCol);
					else
						map.SetAir(x, y, z);
				}
		}
		void SetLayerY(int y) {
			for (int x = 0; x < 512; x++)
				for (int z = 0; z < 64; z++) {
					uint iCol = bitmap.GetPixel(x, z);
					uint red = uint8(iCol);
					uint green = uint8(iCol >> 8);
					uint blue = uint8(iCol >> 16);
					uint alpha = uint8(iCol >> 24);
					iCol = red | (green << 8) | (blue << 16) | (alpha << 24);
					if (alpha == 255)
						map.SetSolid(x, y, z, iCol);
					else
						map.SetAir(x, y, z);
				}
		}
		void SetLayerZ(int z) {
			for (int x = 0; x < 512; x++)
				for (int y = 0; y < 512; y++) {
					uint iCol = bitmap.GetPixel(x, y);
					uint red = uint8(iCol);
					uint green = uint8(iCol >> 8);
					uint blue = uint8(iCol >> 16);
					uint alpha = uint8(iCol >> 24);
					iCol = red | (green << 8) | (blue << 16) | (alpha << 24);
					if (alpha == 255)
						map.SetSolid(x, y, z, iCol);
					else
						map.SetAir(x, y, z);
				}
		}
		
		void PaintAction(Vector2 pos, bool destroy = false) {
			uint xStart = pos.x - thickness / 2;
			uint yStart = pos.y - thickness / 2;
			for (uint x = xStart; x < xStart + thickness; x++)
				for (uint y = yStart; y < yStart + thickness; y++) {
					if (!destroy)
						Build(x, y);
					else
						Destroy(x, y);
				}
		}
		
		void Build(uint x, uint y) {
			uint iCol = color.x | (color.y << 8) | (color.z << 16) | (255 << 24);
			bitmap.SetPixel(x, y, iCol);
		}
		void Destroy(uint x, uint y) {
			uint iCol = 0 | (0 << 8) | (0 << 16) | (0 << 24);
			bitmap.SetPixel(x, y, iCol);
		}
		
	}
	
	namespace ui {
	
		class HeightMapUI : UIElement {
			Renderer @r;
			private MainScreenUI @ui;
			private MainScreenHelper @helper;
			private MainScreenMainMenu @owner;
			private float ContentsLeft, ContentsRight, ContentsWidth;
			private float ContentsTop, ContentsDown, ContentsHeight;
			private float ContentsMid;
			EventHandler @Closed;
			
			private bool dragging;
			private bool destroying;
			
			private string mapFileName;
			private HeightMap @hMap;
			int currentAxis;
			
			private HeightMapUIAxis @xUI;
			private HeightMapUIAxis @yUI;
			private HeightMapUIAxis @zUI;
			
			private HeightMapUIColorField @redField;
			private HeightMapUIColorField @greenField;
			private HeightMapUIColorField @blueField;
			
			private HeightMapColorSliderBounds @redBounds;
			private HeightMapColorSliderBounds @greenBounds;
			private HeightMapColorSliderBounds @blueBounds;
			
			HeightMapUI(MainScreenUI @ui, MainScreenMainMenu @owner, Renderer @renderer,string fN) {
				super(ui.manager);
				@this.r = renderer;
				@this.owner = owner;
				@this.ui = ui;
				@this.helper = ui.helper;
				this.Bounds = owner.Bounds;
				IsMouseInteractive = true;
				AcceptsFocus = true;
				
				ContentsWidth = 800.f;
				ContentsLeft = (Manager.Renderer.ScreenWidth - ContentsWidth) * 0.5f;
				ContentsRight = ContentsLeft + ContentsWidth;
				ContentsHeight = 550.f;
				ContentsTop = (Manager.Renderer.ScreenHeight - ContentsHeight) * 0.5f;
				ContentsDown = ContentsTop + ContentsHeight;
				ContentsMid = ContentsLeft + ContentsWidth * 0.5f;
				
				//start off with a z map at water level
				currentAxis = 2;
				mapFileName = fN;
				@hMap = HeightMap("MapEditor/Maps/" + fN);
				ReloadMapImage(63);
				
				dragging = destroying = false;
				
				{
					Label label(Manager);
					label.BackgroundColor = Vector4(0, 0, 0, 0.4f);
					label.Bounds = Bounds;
					AddChild(label);
				}
				{
					Label label(Manager);
					label.BackgroundColor = Vector4(0, 0, 0, 0.8f);
					label.Bounds = AABB2(ContentsLeft, ContentsTop, ContentsWidth, ContentsHeight);
					AddChild(label);
				}
				
				float xPos = ContentsLeft + 10;
				float yPos = ContentsTop + 15;
				
				{//coordinate fields
					@xUI = HeightMapUIAxis(this, 0, xPos, yPos);
					yPos += 30;
					
					@yUI = HeightMapUIAxis(this, 1, xPos, yPos);
					yPos += 30;
					
					@zUI = HeightMapUIAxis(this, 2, xPos, yPos);
				}
				{//color fields
					xPos = ContentsLeft + 10;
					yPos = ContentsDown - 155;
					
					{//red
						@redField = HeightMapUIColorField(this);
						redField.Bounds = AABB2(xPos, yPos, 50, 25);
						redField.Placeholder = _Tr("HeightMap", "0 - 255");
						AddChild(redField);
						
						Label label(Manager);
						label.Bounds = AABB2(xPos + 55, yPos + 2, 0, 0);
						label.Text = "R";
						AddChild(label);
						
						yPos += 30;
					}
					{
						@greenField = HeightMapUIColorField(this);
						greenField.Bounds = AABB2(xPos, yPos, 50, 25);
						greenField.Placeholder = _Tr("HeightMap", "0 - 255");
						AddChild(greenField);
						
						Label label(Manager);
						label.Bounds = AABB2(xPos + 55, yPos + 2, 0, 0);
						label.Text = "G";
						AddChild(label);
						
						yPos += 30;
					}
					{
						@blueField = HeightMapUIColorField(this);
						blueField.Bounds = AABB2(xPos, yPos, 50, 25);
						blueField.Placeholder = _Tr("HeightMap", "0 - 255");
						AddChild(blueField);
						
						Label label(Manager);
						label.Bounds = AABB2(xPos + 55, yPos + 2, 0, 0);
						label.Text = "B";
						AddChild(label);
						
						yPos += 30;
					}
					
				}
				{//color slider bounds
					xPos = ContentsLeft + 10;
					yPos = ContentsDown - 75;
					
					yPos += 20;
					@redBounds = HeightMapColorSliderBounds(
						Vector2(xPos - 1, yPos - 9), Vector2(xPos + 256, yPos + 5)
					);
					
					yPos += 20;
					@greenBounds = HeightMapColorSliderBounds(
						Vector2(xPos - 1, yPos - 9), Vector2(xPos + 256, yPos + 5)
					);
					
					yPos += 20;
					@blueBounds = HeightMapColorSliderBounds(
						Vector2(xPos - 1, yPos - 9), Vector2(xPos + 256, yPos + 5)
					);
				}
				
				{
					xPos = ContentsLeft + 15 + 256 - 60;
					yPos = ContentsTop + 15;
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("MainScreen", "Save");
					button.Bounds = AABB2(xPos, yPos, 60, 30);
					@button.Activated = spades::ui::EventHandler(this.OnSave);
					AddChild(button);
				}
				{
					yPos += 30;
					
					spades::ui::Button button(Manager);
					button.Caption = _Tr("MainScreen", "Cancel");
					button.Bounds = AABB2(xPos, yPos, 60, 30);
					@button.Activated = spades::ui::EventHandler(this.OnCancel);
					AddChild(button);
				}
				
				{
					xPos = ContentsLeft + 15;
					yPos = ContentsDown - 15 - 180;
					
					Label label(Manager);
					label.Bounds = AABB2(xPos, yPos, 0, 0);
					label.Text = "Brush Thickness";
					AddChild(label);
					
					HeightMapThicknessField thicknessField(this, hMap);
					thicknessField.Bounds = AABB2(xPos + 120, yPos, 40, 25);
					thicknessField.Placeholder = _Tr("HeightMap", "1");
					AddChild(thicknessField);
				}
				
			}
			
			private void OnSave(spades::ui::UIElement @sender) { SaveMap(); }
			private void SaveMap() { 
				//save current layer
				switch (currentAxis) {
					case 0: hMap.SetLayerX(xUI.coord); break;
					case 1: hMap.SetLayerY(yUI.coord); break;
					default: hMap.SetLayerZ(zUI.coord); break;
				}
				
				//now save the entire map
				hMap.SaveMap("MapEditor/Maps/" + mapFileName); 
			}
			
			private void OnCancel(spades::ui::UIElement @sender) { Close(); }
			
			private void PaintAction(Vector2 clientPosition, bool destroy = false) {
				if (destroy && IsWater())
					return;
				hMap.PaintAction(TranslatePosToHmap(clientPosition), destroy);
			}
			
			void UIAxisConfirm(uint axis, uint oldCoord) {
				//save previous layer
				switch (currentAxis) {
					case 0: hMap.SetLayerX(oldCoord); break;
					case 1: hMap.SetLayerY(oldCoord); break;
					default: hMap.SetLayerZ(oldCoord); break;
				}
				
				//load next layer
				currentAxis = axis;
				switch (axis) {
					case 0: ReloadMapImage(xUI.coord); break;
					case 1: ReloadMapImage(yUI.coord); break;
					default: ReloadMapImage(zUI.coord); break;
				}
			}
			
			void UIColorChanged() {
				hMap.color = IntVector3(redField.val, greenField.val, blueField.val);
			}
			
			private void ReloadMapImage(int a = -1) {
				if (a != -1)
					hMap.ReloadBitMap(a, currentAxis);
			}
			
			void HotKey(string key) {
				if (key == "Escape") {
					Close();
				} else {
					UIElement::HotKey(key);
				}
			}
			
			void MouseDown(MouseButton button, Vector2 clientPosition) {
				dragging = true;
				if (IsInMapImageBounds(clientPosition)) {
					destroying = button == MouseButton::RightMouseButton;
					PaintAction(clientPosition, destroying);
					return;
				}
				
				CheckColorSliderBounds(clientPosition);
			}
			void MouseUp(MouseButton button, Vector2 clientPosition) {
				dragging = false;
				if (button == MouseButton::RightMouseButton)
					destroying = false;
			}
			void MouseMove(Vector2 clientPosition) {
				if (dragging && IsInMapImageBounds(clientPosition)) {
					PaintAction(clientPosition, destroying);
					return;
				}
				
				if (dragging)
					CheckColorSliderBounds(clientPosition);
			}
			
			private void CheckColorSliderBounds(Vector2 clientPosition) {
				if (redBounds.IsInSliderBounds(clientPosition)) {
					redField.val = redBounds.TranslatePosToVal(clientPosition);
					redField.ValChanged();
					UIColorChanged();
					return;
				}
				if (greenBounds.IsInSliderBounds(clientPosition)) {
					greenField.val = greenBounds.TranslatePosToVal(clientPosition);
					greenField.ValChanged();
					UIColorChanged();
					return;
				}if (blueBounds.IsInSliderBounds(clientPosition)) {
					blueField.val = blueBounds.TranslatePosToVal(clientPosition);
					blueField.ValChanged();
					UIColorChanged();
					return;
				}
			}
			
			private bool IsInMapImageBounds(Vector2 clientPosition) {
				if (clientPosition.x > TopLeft().x
					&& clientPosition.y > TopLeft().y
					&& clientPosition.x < DownRight().x
					&& clientPosition.y < DownRight().y
				) {
					return true;
				}
				return false;
			}
			private Vector2 TranslatePosToHmap(Vector2 clientPosition) { return clientPosition - TopLeft(); }
			
			private Vector2 TopLeft() {
				if (IsZ()) {
					return Vector2(ContentsRight - 512 - 10, ContentsTop + 19);
				} else {
					return Vector2(ContentsRight - 512 - 10, ContentsTop + 19 + 192);
				}
			}
			private Vector2 DownRight() {
				if (IsZ()) {
					return TopLeft() + Vector2(512, 512);
				} else {
					return TopLeft() + Vector2(512, 64);
				}
			}
			
			private bool IsZ() { return currentAxis >= 2; }
			private bool IsWater() { return IsZ() && zUI.coord == 63; }
			
			void Render() {
				UIElement::Render();
				
				//draw map
				r.ColorNP = Vector4(1, 1, 1, 1);
				r.DrawImage(r.CreateImage(hMap.bitmap), TopLeft());
				
				DrawColorPicker();
			}
			
			private void DrawColorPicker() {
				int xPos = int(ContentsLeft) + 10;
				int yPos = int(ContentsDown) - 75;
				
				//draw resulting color
				DrawColoredOutlinedRect(hMap.color, xPos + 75, yPos, xPos + 30 + 75, yPos - 30);
				
				yPos += 20;
				//draw red
				DrawColoredOutlinedRect(
					IntVector3(0, 0, 0), xPos, yPos, xPos + 255, yPos - 4
				);
				DrawColoredRect(
					IntVector3(255, 0, 0), xPos, yPos, xPos + hMap.color.x, yPos - 4
				);
				
				yPos += 20;
				//draw blue
				DrawColoredOutlinedRect(
					IntVector3(0, 0, 0), xPos, yPos, xPos + 255, yPos - 4
				);
				DrawColoredRect(
					IntVector3(0, 255, 0), xPos, yPos, xPos + hMap.color.y, yPos - 4
				);
				
				yPos += 20;
				//draw green
				DrawColoredOutlinedRect(
					IntVector3(0, 0, 0), xPos, yPos, xPos + 255, yPos - 4
				);
				DrawColoredRect(
					IntVector3(0, 0, 255), xPos, yPos, xPos + hMap.color.z, yPos - 4
				);
			}
			
			private void DrawColoredOutlinedRect(IntVector3 col, int x1, int y1, int x2, int y2) {
				r.ColorNP = Vector4(1, 1, 1, 1);
				DrawFilledRect(r, x1 - 2, y1 + 2, x2 + 2, y2 - 2);
				r.ColorNP = Vector4(0, 0, 0, 1);
				DrawFilledRect(r, x1 - 1, y1 + 1, x2 + 1, y2 - 1);
				r.ColorNP = ConvertColorRGBA(col);
				DrawFilledRect(r, x1, y1, x2, y2);
			}
			private void DrawColoredRect(IntVector3 col, int x1, int y1, int x2, int y2) {
				r.ColorNP = ConvertColorRGBA(col);
				DrawFilledRect(r, x1, y1, x2, y2);
			}
			
			void Run() {
				owner.Enable = false;
				owner.Parent.AddChild(this);
			}
			
			void Close() {
				owner.Enable = true;
				@this.Parent = null;
				OnClosed();
			}
			void OnClosed() {
				if (Closed !is null)
					Closed(this);
			}
			
		}
		
		class HeightMapUIAxis {
			HeightMapUI @owner;
			Field @field;
			Button @button;
			uint coord;
			uint axis;
			
			HeightMapUIAxis(HeightMapUI @o, uint whichAxis, float xPos, float yPos) {
				@this.owner = o;
				axis = whichAxis;
				coord = IsZ() ? 63 : 0;
				
				Label label(o.Manager);
				label.Bounds = AABB2(xPos, yPos, 0, 0);
				switch (axis) {
					case 0: label.Text = "X"; break;
					case 1: label.Text = "Y"; break;
					default: label.Text = "Z"; break;
				}
				o.AddChild(label);
					
				@field = Field(o.Manager);
				field.Bounds = AABB2(xPos + 15, yPos - 2, 50, 25);
				field.Placeholder = _Tr("HeightMap", IsZ() ? "0 - 63" : "0 - 511");
				if (IsZ())//starting off with z map at water level
					field.Text = "63";
				else
					field.Text = "0";
				o.AddChild(field);
				
				@button = Button(o.Manager);
				button.Caption = _Tr("MainScreen", "Confirm");
				button.Bounds = AABB2(xPos + 75, yPos - 2, 70, 25);
				@button.Activated = EventHandler(this.OnConfirm);
				o.AddChild(button);
			}
			
			void OnConfirm(UIElement @sender) {
				if (!IsNumber(this.field.Text))
					return;
				
				uint newCoord = parseUInt(this.field.Text);
				
				if (newCoord == this.coord)
					return;
				if (IsZ()) {
					if (newCoord > 63)
						return;
				} else {
					if (newCoord > 511)
						return;
				}
				uint oldCoord = this.coord;
				this.coord = newCoord;
				owner.UIAxisConfirm(axis, oldCoord);
			}
			
			private bool IsNumber(string text) {
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
					return false;
				}
				return true;
			}
		
			private bool IsZ() {
				return axis >= 2;
			}
		
		}
		
		class HeightMapUIColorField : Field {
			HeightMapUI @owner;
			uint val;
			
			HeightMapUIColorField(HeightMapUI @o) {
				super(o.Manager);
				@this.owner = o;
				this.val = 0;
				this.Text = "0";
			}
			
			void OnChanged() {
				if (this.Text.length == 0) {
					val = 0;
					owner.UIColorChanged();
					return;
				}
				
				if (!IsNumber(this.Text))
					return;
				
				uint newVal = parseUInt(this.Text);
				if (newVal > 255)
					newVal = 255;
				
				val = newVal;
				owner.UIColorChanged(); 
			}
			
			void ValChanged() { this.Text = formatUInt(val, "l", 3); }
			
			private bool IsNumber(string text) {
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
					return false;
				}
				return true;
			}
		}

		class HeightMapColorSliderBounds {
			Vector2 TopLeft, DownRight;
			
			HeightMapColorSliderBounds(Vector2 tl, Vector2 dr) {
				TopLeft = tl;
				DownRight = dr;
			}
			
			bool IsInSliderBounds(Vector2 clientPosition) {
				if (clientPosition.x > TopLeft.x
					&& clientPosition.y > TopLeft.y
					&& clientPosition.x < DownRight.x
					&& clientPosition.y < DownRight.y
				) {
					return true;
				}
				return false;
			}
			uint TranslatePosToVal(Vector2 clientPosition) {
				return uint(clientPosition.x) - uint(TopLeft.x) - 1;
			}
			
		}
		
		class HeightMapThicknessField : Field {
			private HeightMap @hMap;
			
			HeightMapThicknessField(HeightMapUI @o, HeightMap @hM) {
				super(o.Manager);
				@this.hMap = hM;
				hMap.thickness = 1;
				this.Text = "1";
			}
			
			void OnChanged() {
				uint newVal = parseUInt(this.Text);
				if (newVal <= 0) {
					newVal = 1;
				}
				
				hMap.thickness = newVal;
			}
			
		}
		
	}
	
}
#include "../UIFramework/Label.as"

namespace spades {
	
	class ClientMapTxtWindow : spades::ui::UIElement {

		float contentsTop, contentsHeight;

		ClientUI @ui;
		private ClientUIHelper @helper;
		spades::ui::TxtViewer @viewer;

		private spades::ui::UIElement @genButton;

		ClientMapTxtWindow(ClientUI @ui) {
			super(ui.manager);
			@this.ui = ui;
			@this.helper = ui.helper;

			@Font = Manager.RootElement.Font;
			this.Bounds = Manager.RootElement.Bounds;

			float contentsWidth = Manager.Renderer.ScreenWidth * 0.75f;
			float contentsLeft = (Manager.Renderer.ScreenWidth - contentsWidth) * 0.5f;
			contentsHeight = Manager.Renderer.ScreenHeight - 150.f;
			contentsTop = (Manager.Renderer.ScreenHeight - contentsHeight) * 0.5f;
			{
				spades::ui::Label label(Manager);
				label.BackgroundColor = Vector4(0, 0, 0, 0.4f);
				label.Bounds = Bounds;
				AddChild(label);
			}
			{
				spades::ui::Label label(Manager);
				label.BackgroundColor = Vector4(0, 0, 0, 0.8f);
				label.Bounds = AABB2((Size.x - contentsWidth) * 0.5f, contentsTop - 13.f, contentsWidth, contentsHeight + 27.f);
				AddChild(label);
			}
			{	//text field color
				spades::ui::Label label(Manager);
				label.BackgroundColor = Vector4(1, 1, 1, 0.02f);
				label.Bounds = AABB2(contentsLeft + 10.f, contentsTop + 10.f, contentsWidth - 20.f, contentsHeight - 50.f);
				AddChild(label);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Map.txt Editor");
				button.Bounds = AABB2(contentsLeft, contentsTop + contentsHeight - 15.f, 120.f, 30.f);
				button.Enable = false;
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "X");
				button.Bounds = AABB2(contentsLeft + contentsWidth - 30.f, contentsTop + contentsHeight - 15.f, 30.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnClose);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Save");
				button.Bounds = AABB2(contentsLeft + contentsWidth - 150.f, contentsTop + contentsHeight - 30.f, 50.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnSave);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Load");
				button.Bounds = AABB2(contentsLeft + contentsWidth - 210.f, contentsTop + contentsHeight - 30.f, 50.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnLoad);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Generate");
				button.Bounds = AABB2(contentsLeft + contentsWidth - 290.f, contentsTop + contentsHeight - 30.f, 70.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnGen);
				AddChild(button);
				@genButton = button;
			}
			{
				spades::ui::TxtViewer viewer(Manager);
				AddChild(viewer);
				viewer.Bounds = AABB2(contentsLeft + 10.f, contentsTop + 10.f, contentsWidth - 20.f, contentsHeight - 50.f);
				@this.viewer = viewer;
			}
		}

		void Close() { @ui.ActiveUI = null; }

		private void OnClose(spades::ui::UIElement @sender) { Close(); }
		
		private void OnSave(spades::ui::UIElement @sender) { 
			requestSave(); 
			requestLoad();
		}
		
		private void OnLoad(spades::ui::UIElement @sender) { requestLoad(); }
		
		private void OnGen(spades::ui::UIElement @sender) { requestGen(); }

		void HotKey(string key) {
			if (IsEnabled and (key == "Escape")) {
				Close();
			} else if (key == "S" and (Manager.IsControlPressed or Manager.IsMetaPressed)) {
				requestSave();
				requestLoad();
			} else if (key == "L" and (Manager.IsControlPressed or Manager.IsMetaPressed)) {
				requestLoad();
			} else if (key == "G" and (Manager.IsControlPressed or Manager.IsMetaPressed) and genButton.Enable) {
				requestGen();
			} else {
				UIElement::HotKey(key);
			}
			if (int(viewer.Text.length) == 0) {
				genButton.Enable = true;
			} else {
				genButton.Enable = false;
			}
		}

		void Load(string text) {
			viewer.Text = "";
			
			for (uint i = 0; i < text.length; i++) {
				if (text.substr(i, 1) == '\r') //get rid of this shite
					continue;
			
				viewer.Text += text.substr(i, 1);
			}
			
			genButton.Enable = false;
		}
		
		void requestLoad() { ui.helper.requestLoadTxt(); }
		
		void requestSave() { 
			if (viewer.textmodel is null) {
				return;
			}
			ui.helper.requestSaveTxt(viewer.Text); 
		}
		
		void requestGen() { ui.helper.requestGenTxt(); }

		void Render() {
			Vector2 pos = ScreenPosition;
			Vector2 size = Size;
			Renderer @r = Manager.Renderer;
			Image @img = r.RegisterImage("Gfx/White.tga");

			r.ColorNP = Vector4(1, 1, 1, 0.08f);
			r.DrawImage(img, AABB2(pos.x, pos.y + contentsTop - 15.f, size.x, 1.f));
			r.DrawImage(img, AABB2(pos.x, pos.y + contentsTop + contentsHeight + 15.f, size.x, 1.f));
			r.ColorNP = Vector4(1, 1, 1, 0.2f);
			r.DrawImage(img, AABB2(pos.x, pos.y + contentsTop - 14.f, size.x, 1.f));
			r.DrawImage(img, AABB2(pos.x, pos.y + contentsTop + contentsHeight + 14.f, size.x, 1.f));

			UIElement::Render();
		}
	};
	
	namespace ui { 
	
		class TxtAction {
			int start;
			string oldString;
			string newString;
		}
		
		class TxtViewerSelectionState {
			UIElement @FocusElement;
			int MarkPosition = 0;
			int CursorPosition = 0;
			int currentLine = 0;

			int SelectionStart {
				get final { return Min(MarkPosition, CursorPosition); }
			}

			int SelectionEnd {
				get final { return Max(MarkPosition, CursorPosition); }
			}
		};

		class TxtViewerItemUI : UIElement {
			private string text;
			private Vector4 textColor;
			private int index;
			private int cursor;

			private TxtViewerSelectionState @selection;

			TxtViewerItemUI(UIManager @manager, TxtViewerItem @item,
							 TxtViewerSelectionState @selection) {
				super(manager);

				text = item.Text;
				textColor = item.Color;
				index = item.Index;
				@this.selection = selection;
			}

			void DrawHighlight(float x, float y, float w, float h) {
				Renderer @renderer = Manager.Renderer;
				renderer.ColorNP = Vector4(1.f, 1.f, 1.f, 0.2f);

				Image @img = renderer.RegisterImage("Gfx/White.tga");
				renderer.DrawImage(img, AABB2(x, y, w, h));
			}
			
			void DrawBeam(float x, float y, float h) {
				Renderer @renderer = Manager.Renderer;
				float pulse = sin(Manager.Time * 5.f);
				pulse = abs(pulse);
				renderer.ColorNP = Vector4(1.f, 1.f, 1.f, pulse);

				Image @img = renderer.RegisterImage("Gfx/White.tga");
				renderer.DrawImage(img, AABB2(x - 1.f, y, 2, h));
			}

			void Render() {
				Renderer @renderer = Manager.Renderer;
				Vector2 pos = ScreenPosition;
				Vector2 size = Size;
				float textScale = 1.0f;
				Font @font = this.Font;

				if (text.length > 0) {
					Vector2 txtSize = font.Measure(text) * textScale;
					Vector2 txtPos;
					txtPos = pos + (size - txtSize) * Vector2(0.0f, 0.0f);

					font.Draw(text, txtPos, textScale, textColor);
				}
				
				//draw txtcursor beam
				cursor = selection.CursorPosition - index;
				if (cursor >= 0 and cursor <= int(text.length)) {
					
					float x = font.Measure(text.substr(0, cursor)).x;
					float fontHeight = font.Measure("A").y;		
					DrawBeam(pos.x + x, pos.y, fontHeight);
				}


				if (selection.FocusElement.IsFocused) {
					// Draw selection
					int start = selection.SelectionStart - index;
					int end = selection.SelectionEnd - index;
					if (start < 0) {
						start = 0;
					}
					if (end > int(text.length) + 1) {
						end = int(text.length) + 1;
					}
					if (end > start) {
						float x1 = font.Measure(text.substr(0, start)).x;
						float x2 = font.Measure(text.substr(0, end)).x;

						if (end == int(text.length) + 1) {
							x2 = size.x;
						}

						DrawHighlight(pos.x + x1, pos.y, x2 - x1, size.y);
					}
				}
			}
		};

		class TxtViewerItem {
			string Text;
			Vector4 Color;
			int Index;

			TxtViewerItem(string text, Vector4 color, int index) {
				Text = text;
				Color = color;
				Index = index;
			}
		};

		class TxtViewerModel : ListViewModel {
			UIManager @manager;
			TxtViewerItem @[] lines = {};
			Font @font;
			float width;
			TxtViewerSelectionState @selection;
			int contentStart;
			int contentEnd;

			void AddLine(string text, Vector4 color) {
				int startPos = 0;
				if (font.Measure(text).x <= width) {
					lines.insertLast(TxtViewerItem(text, color, contentEnd));
					contentEnd += text.length + 1;
					return;
				}

				int pos = 0;
				int len = int(text.length);
				bool charMode = false;
				while (startPos < len) {
					int nextPos = pos + 1;
					if (charMode) {
						// skip to the next UTF-8 character boundary
						while (nextPos < len && ((text[nextPos] & 0x80) != 0) &&
							   ((text[nextPos] & 0xc0) != 0xc0))
							nextPos++;
					} else {
						while (nextPos < len && text[nextPos] != 0x20)
							nextPos++;
					}
					if (font.Measure(text.substr(startPos, nextPos - startPos)).x > width) {
						if (pos == startPos) {
							if (charMode) {
								pos = nextPos;
							} else {
								charMode = true;
							}
							continue;
						} else {
							lines.insertLast(TxtViewerItem(text.substr(startPos, pos - startPos),
															color, contentEnd));
							contentEnd += pos - startPos;
							startPos = pos;
							while (startPos < len && text[startPos] == 0x20) {
								startPos++;
							}
							pos = startPos;
							charMode = false;
							continue;
						}
					} else {
						pos = nextPos;
						if (nextPos >= len) {
							lines.insertLast(TxtViewerItem(text.substr(startPos, nextPos - startPos), color, contentEnd));
							contentEnd += nextPos - startPos + 1;
							break;
						}
					}
				}
			}

			/**
			 * Remove the first line from the model.
			 *
			 * `ListViewModel` doesn't support removing items from other places
			 * than the end of the list. Therefore, after calling this,
			 * `ListViewBase.Model` must be reassigned to recreate all elements
			 * in view.
			 */
			void RemoveFirstLines(uint numLines) {
				int removedLength;
				if (lines.length > numLines) {
					removedLength = lines[numLines].Index - contentStart;
				} else {
					removedLength = contentEnd - contentStart;
				}

				lines.removeRange(0, numLines);
				contentStart += removedLength;

				selection.MarkPosition = Max(selection.MarkPosition, contentStart);
				selection.CursorPosition = Max(selection.CursorPosition, contentStart);
			}

			TxtViewerModel(UIManager @manager, string text, Font @font, float width,
							TxtViewerSelectionState @selection) {
				@this.manager = manager;
				@this.font = font;
				this.width = width;
				@this.selection = selection;
				string[] @lines = text.split("\n");
				for (uint i = 0; i < lines.length; i++)
					AddLine(lines[i], Vector4(1.f, 1.f, 1.f, 1.f));
			}

			int NumRows {
				get { return int(lines.length); }
			}

			UIElement @CreateElement(int row) {
				return TxtViewerItemUI(manager, lines[row], selection);
			}

			void RecycleElement(UIElement @elem) {}
		};

		class TxtViewer : ListViewBase {
			private string text;
			TxtViewerModel @textmodel;
			private TxtViewerSelectionState selection;
			private bool dragging = false;
			private string copyText = "";
			
			private TxtAction@ [] history;
			private int historyPos = 0;

			/**
			 * The maximum number of lines. This affects the behavior of the
			 * `AddLine` method. `0` means unlimited.
			 */
			int MaxNumLines = 0;

			TxtViewer(UIManager @manager) {
				super(manager);

				@selection.FocusElement = this;
				AcceptsFocus = true;
				IsMouseInteractive = true;
				@this.Cursor = Cursor(Manager, manager.Renderer.RegisterImage("Gfx/UI/IBeam.png"), Vector2(16.f, 16.f));
			}

			/**
			 * Sets the displayed text. Make sure `TextViewer.Font` is not null before
			 * setting this proeprty.
			 */
			string Text {
				get final { return text; }
				set {
					text = value;
					@textmodel = TxtViewerModel(Manager, text, Font, ItemWidth, selection);
					@Model = textmodel;
					this.selection.MarkPosition = 0;
					this.selection.CursorPosition = 0;
				}
			}

			private int PointToCharIndex(Vector2 clientPosition) {
				if (textmodel is null) {
					return 0;
				}

				int line = int(clientPosition.y / RowHeight) + TopRowIndex;
				if (line < 0) {
					return textmodel.contentStart;
				}
				if (line >= int(textmodel.lines.length)) {
					return textmodel.contentEnd - 1;
				}
				
				//scroll up or down on out of bounds
				if (clientPosition.y < 0.f) {
					MouseWheel(-1.f);
				}
				if (clientPosition.y > (Manager.Renderer.ScreenHeight - 200.f)) {
					MouseWheel(1.f);
				}

				float x = clientPosition.x;
				string text = textmodel.lines[line].Text;
				int lineStartIndex = textmodel.lines[line].Index;
				if (x < 0.f) {
					return lineStartIndex;
				}
				int len = text.length;
				float lastWidth = 0.f;
				Font @font = this.Font;
				// FIXME: use binary search for better performance?
				int idx = 0;
				for (int i = 1; i <= len; i++) {
					int lastIdx = idx;
					idx = GetByteIndexForString(text, 1, idx);
					float width = font.Measure(text.substr(0, idx)).x;
					if (width > x) {
						if (x < (lastWidth + width) * 0.5f) {
							return lastIdx + lineStartIndex;
						} else {
							return idx + lineStartIndex;
						}
					}
					lastWidth = width;
					if (idx >= len) {
						return len + lineStartIndex;
					}
				}
				return len + lineStartIndex;
			}

			void MouseDown(MouseButton button, Vector2 clientPosition) {
				if (button != spades::ui::MouseButton::LeftMouseButton) {
					return;
				}
				dragging = true;
				if (Manager.IsShiftPressed) {
					MouseMove(clientPosition);
				} else {
					selection.MarkPosition = selection.CursorPosition =
						PointToCharIndex(clientPosition);
				}
			}

			void MouseMove(Vector2 clientPosition) {
				if (dragging) {
					selection.CursorPosition = PointToCharIndex(clientPosition);
				}
			}

			void MouseUp(MouseButton button, Vector2 clientPosition) {
				if (button != spades::ui::MouseButton::LeftMouseButton) {
					return;
				}
				dragging = false;
			}

			void KeyDown(string key) {
				KeyAction(key);
				AdjustHeight();
				//keydown seems to use qwerty regardless to ur actual keyboard layout. 
				//u may need to customize the keys to match ur layout or to whatever else to ur own liking. 
				if (Manager.IsControlPressed or Manager.IsMetaPressed /* for OSX; Cmd + [a-z] */) {
					if (key == "C" && this.selection.SelectionEnd > this.selection.SelectionStart) {
						copyText = this.SelectedText;
						return;
					} else if (key == "V" and copyText != "") {
						Write(copyText);
						AdjustHeight();
						return;
					} else if (key == "A") {
						if (textmodel is null) {
							return;
						}
						this.selection.MarkPosition = textmodel.contentStart;
						this.selection.CursorPosition = textmodel.contentEnd;
						return;
					} else if (key == "X" and this.selection.MarkPosition != this.selection.CursorPosition) {
						copyText = this.SelectedText;
						BackSpace();
						AdjustHeight();
						return;
					} else if (key == "Z") {
						Undo();
						AdjustHeight();
						return;
					} else if (key == "Y") {
						Redo();
						AdjustHeight();
						return;
					}
				} 
				Manager.ProcessHotKey(key);
			}
			
			void KeyAction(string key) {
				if (key == "Right") {
					if (this.selection.CursorPosition < int(Text.length)) {
						this.selection.CursorPosition++;
						
						if (Text.substr(this.selection.CursorPosition, 1) == '\r') {
							this.selection.CursorPosition++;
						}
						
						if (!Manager.IsShiftPressed) {
							this.selection.MarkPosition = this.selection.CursorPosition;
						}
					}
				}
				if (key == "Left") {
					if (this.selection.CursorPosition > 0) {
						this.selection.CursorPosition--;
						
						if (Text.substr(this.selection.CursorPosition, 1) == '\r') {
							this.selection.CursorPosition--;
						}
						
						if (!Manager.IsShiftPressed) {
							this.selection.MarkPosition = this.selection.CursorPosition;
						}
					}
				}
				if (key == "Up" or key == "Down") {
					if (textmodel is null) {
						return;
					}
					int cursor = this.selection.CursorPosition;

					auto @lines = textmodel.lines;
					int currentLine;

					for (uint i = 0, count = lines.length; i < count; ++i) {
						int len = int(lines[i].Text.length);
						int lineStart = lines[i].Index;
						int lineEnd = lineStart + len;

						if (cursor >= lineStart and cursor <= lineEnd) {
							currentLine = i;
							break;
						}
					}
					
					int dif = cursor - lines[currentLine].Index;
					int nextLineLen;
					int nextLineIdx = -1;
					if (key == "Up" and currentLine > 0) {
						nextLineIdx = lines[currentLine - 1].Index;
						nextLineLen = int(lines[currentLine - 1].Text.length);
					}
					if (key == "Down" and currentLine < int(lines.length) - 1) {
						nextLineIdx = lines[currentLine + 1].Index;
						nextLineLen = int(lines[currentLine + 1].Text.length);
					}
					if (nextLineIdx == -1) {
						return;
					}
					if (dif > nextLineLen) {
						dif = nextLineLen;
					}
					
					this.selection.CursorPosition = nextLineIdx + dif;
					if (!Manager.IsShiftPressed) {
						this.selection.MarkPosition = this.selection.CursorPosition;
					}
				}
				
				if (key == "End" or key == "Home") {
					if (textmodel is null) {
						return;
					}
					int cursor = this.selection.CursorPosition;

					auto @lines = textmodel.lines;
					int currentStart;
					int currentEnd;

					for (uint i = 0, count = lines.length; i < count; ++i) {
						int len = int(lines[i].Text.length);
						int lineStart = lines[i].Index;
						int lineEnd = lineStart + len;

						if (cursor >= lineStart and cursor <= lineEnd) {
							currentStart = lineStart;
							currentEnd = lineEnd;
							break;
						}
					}
					
					if (key == "End") {
						this.selection.CursorPosition = currentEnd;
					}
					if (key == "Home") {
						this.selection.CursorPosition = currentStart;
					}
					
					if (!Manager.IsShiftPressed) {
						this.selection.MarkPosition = this.selection.CursorPosition;
					}
				}
				
				if (key == "PageUp" or key == "PageDown") {
					if (textmodel is null) {
						return;
					}
						
					if (key == "PageUp") {
						this.selection.CursorPosition = textmodel.contentStart;
						this.ScrollToTop();
					}
					if (key == "PageDown") {
						this.selection.CursorPosition = textmodel.contentEnd - 1;
						this.ScrollToEnd();
					}
					
					if (!Manager.IsShiftPressed) {
						this.selection.MarkPosition = this.selection.CursorPosition;
					}
				}
				
				if (key == "Enter") {
					Write('\n');
				}
				if (key == "BackSpace") {
					BackSpace();
				}
				if (key == "Delete") {
					Delete();
				}
			}
			
			void KeyPress(string text) {
				if (!(Manager.IsControlPressed or Manager.IsMetaPressed) or Manager.IsAltPressed) {
					Write(text);
					AdjustHeight();
				}
			}
			
			void AdjustHeight() {
				if (textmodel is null) {
					return;
				}
				int cursor = this.selection.CursorPosition;

				auto @lines = textmodel.lines;
				int currentLine;

				for (uint i = 0, count = lines.length; i < count; ++i) {
					int len = int(lines[i].Text.length);
					int lineStart = lines[i].Index;
					int lineEnd = lineStart + len;

					if (cursor >= lineStart and cursor <= lineEnd) {
						currentLine = i;
						break;
					}
				}
				
				float cursorY = (currentLine - TopRowIndex) * RowHeight;
				Font @font = this.Font;
				float fontHeight = font.Measure("A").y;
				float outBoundsUp = Manager.Renderer.ScreenHeight - 200.f - (3 * fontHeight);
				float outBoundsDown = 0.f + fontHeight;
				if (cursorY > outBoundsUp) {
					MouseWheel((cursorY - outBoundsUp) / fontHeight);
				} else if (cursorY < outBoundsDown) {
					MouseWheel((cursorY - outBoundsDown) / fontHeight);
				}
			}
			
			void Write(string text) {
				if (!CheckCharType(text)) {
					return;
				}
				
				int cursor = this.selection.CursorPosition;
				int mark = this.selection.MarkPosition;
				if (cursor < mark) {
					Insert(cursor, mark, text);
				} else if (cursor > mark) {
					Insert(mark, cursor, text);
					cursor = mark;
				} else {
					Insert(cursor, cursor, text);
				}
				
				if (Text.substr(cursor, 1) == '\n') {//prevent overlap with next line
					this.selection.CursorPosition--;
				}
				this.selection.CursorPosition = this.selection.MarkPosition = cursor + text.length;
			}
			
			void BackSpace() {
				int cursor = this.selection.CursorPosition;
				int mark = this.selection.MarkPosition;
				int deleteLength;
				if (cursor < mark) {
					Insert(cursor, mark, "");
					deleteLength = 0;
				} else if (cursor > mark) {
					Insert(mark, cursor, "");
					deleteLength = cursor - mark;
				} else {
					if (cursor <= 0) {
						return;
					}
					Insert(cursor - 1, cursor, "");
					deleteLength = 1;
				}
				
				this.selection.CursorPosition = this.selection.MarkPosition = cursor - deleteLength;
			}
			
			void Delete() {
				int cursor = this.selection.CursorPosition;
				if (cursor != this.selection.MarkPosition) {
					BackSpace();
					return;
				}
				
				Insert(cursor, cursor + 1, "");
				this.selection.CursorPosition = this.selection.MarkPosition = cursor;
			}
			
			void Insert(int start, int end, string text) {
				addHistory(start, Text.substr(start, end - start), text);
				Text = Text.substr(0, start) + text + Text.substr(end, -1);
			}
			
			void addHistory(int startAction, string oldS, string newS) {
				TxtAction act;
				act.start = startAction;
				act.oldString = oldS;
				act.newString = newS;
				
				history.length = historyPos;
				history.insertLast(act);
				historyPos++;
			}
			
			void Undo() {
				if (historyPos <= 0) {
					return;
				}
				historyPos--;
				TxtAction act = history[historyPos];
				
				int newlen = int(act.newString.length);
				Text = Text.substr(0, act.start) + act.oldString + Text.substr(act.start + newlen, -1);
				
				int cursor = act.start + int(act.oldString.length);
				this.selection.CursorPosition = this.selection.MarkPosition = cursor;
			}
			
			void Redo() {
				if (historyPos >= int(history.length)) {
					return;
				}
				TxtAction act = history[historyPos];
				historyPos++;
				
				int oldLen = int(act.oldString.length);
				Text = Text.substr(0, act.start) + act.newString + Text.substr(act.start + oldLen, -1);
				
				int cursor = act.start + int(act.newString.length);
				this.selection.CursorPosition = this.selection.MarkPosition = cursor;
			}
			
			private bool CheckCharType(string s) {
				for (uint i = 0, len = s.length; i < len; i++) {
				   int c = s[i];
				   if ((c & 0x80) != 0) {
					   return false;
					}
				}
				return true;
			}

			string SelectedText {
				get final {
					if (textmodel is null) {
						return "";
					}
					string result;
					int start = this.selection.SelectionStart;
					int end = this.selection.SelectionEnd;

					auto @lines = textmodel.lines;

					for (uint i = 0, count = lines.length; i < count; ++i) {
						string line = lines[i].Text;
						int lineStart = lines[i].Index;
						int lineEnd = lineStart + int(line.length);

						if (end >= lineStart && start <= lineEnd) {
							int substrStart = Max(start - lineStart, 0);
							int substrEnd = Min(end - lineStart, int(line.length));
							result += line.substr(substrStart, substrEnd - substrStart);
						}

						if (i < lines.length - 1 && lineEnd < lines[i + 1].Index) {
							// Implicit new line
							if (lineEnd >= start && lineEnd < end) {
								result += "\n";
							}
						}
					}

					return result;
				}
			}

			/**
			 * Appends a text. Make sure `TextViewer.Font` is not null before
			 * calling this method.
			 */
			void AddLine(string line, bool autoscroll = false,
						 Vector4 color = Vector4(1.f, 1.f, 1.f, 1.f)) {
				if (textmodel is null) {
					this.Text = "";
				}
				if (autoscroll) {
					this.Layout();
					if (this.scrollBar.Value < this.scrollBar.MaxValue) {
						autoscroll = false;
					}
				}
				textmodel.AddLine(line, color);
				if (MaxNumLines > 0 && textmodel.NumRows > MaxNumLines) {
					textmodel.RemoveFirstLines(textmodel.NumRows - MaxNumLines);
					@Model = textmodel;
				}
				if (autoscroll) {
					this.Layout();
					this.ScrollToEnd();
				}
			}
		};
	}
}
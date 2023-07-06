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

#include <Core/Settings.h>

#include "Client.h"
#include "IImage.h"
#include "IRenderer.h"
#include "NetClient.h"
#include "PaletteView.h"
#include "Player.h"
#include "World.h"

#include <Core/FileManager.h>
#include <Core/IStream.h>
#include "Fonts.h"
#include "ClientUI.h"

DEFINE_SPADES_SETTING(cg_keyPaletteLeft, "Left");
DEFINE_SPADES_SETTING(cg_keyPaletteRight, "Right");
DEFINE_SPADES_SETTING(cg_keyPaletteUp, "Up");
DEFINE_SPADES_SETTING(cg_keyPaletteDown, "Down");

DEFINE_SPADES_SETTING(cg_keyPaletteInvert, "Keypad 1");
DEFINE_SPADES_SETTING(cg_keyPaletteMix, "Keypad 0");

DEFINE_SPADES_SETTING(cg_CurrentColorRed, "0");
DEFINE_SPADES_SETTING(cg_CurrentColorGreen, "0");
DEFINE_SPADES_SETTING(cg_CurrentColorBlue, "0");

SPADES_SETTING(cg_hudTransparency);

namespace spades {
	namespace client {
		static IntVector3 SanitizeCol(IntVector3 col) {
			if (col.x < 0)
				col.x = 0;
			if (col.y < 0)
				col.y = 0;
			if (col.z < 0)
				col.z = 0;
			return col;
		}

		PaletteView::PaletteView(Client *client) : client(client), renderer(client->GetRenderer()) {
			currentPalettePage = -1;
			DefaultPalette();
			LoadPaletteList();
		}

		PaletteView::~PaletteView() {}

		void PaletteView::DefaultPalette() {
			IntVector3 cols[] = {
			  {128, 128, 128}, {256,   0,   0}, {256, 128,   0}, {256, 256,   0},
			  {0  , 256,   0}, {  0, 256, 256}, {  0,   0, 256}, {256,   0, 256}
			};

			paletteRow = paletteColumn = 8;

			colors.clear();
			auto def = IntVector3::Make(256, 256, 256);
			for (int i = 0; i < 8; i++) {
				for (int j = 1; j < 8; j += 2)
					colors.push_back(SanitizeCol(((cols[i] * j) / 8) - 1));

				auto rem = def - cols[i];
				for (int j = 1; j < 8; j += 2)
					colors.push_back((cols[i] + ((rem * j) / 8) - 1));
			}

			currentColor = defaultColor = 3;
			SetSelectedIndex(defaultColor);
		}

		std::string PaletteView::PalettePath(int i) {
			char filename[256];
			if (i != -1) {
				sprintf(filename, "Mapditor/Palettes/%03d.palette", i);
				return filename;
			}

			int nextPaletteIndex = 1;
			while (1) {
				sprintf(filename, "MapEditor/Palettes/%03d.palette", nextPaletteIndex);
				if (FileManager::FileExists(filename)) {
					nextPaletteIndex++;
					continue;
				}
				return filename;
			}
		}

		std::string PaletteView::WriteColor(IntVector3 color) {
			std::string str = "(";

			if (color.x < 9)
				str += ' ';
			if (color.x < 99)
				str += ' ';
			str += std::to_string(color.x);
			str += ", ";

			if (color.y < 9)
				str += ' ';
			if (color.y < 99)
				str += ' ';
			str += std::to_string(color.y);
			str += ", ";

			if (color.z < 9)
				str += ' ';
			if (color.z < 99)
				str += ' ';
			str += std::to_string(color.z);

			str += ") ";
			return str;
		}

		void PaletteView::WritePaletteList() {
			std::unique_ptr<IStream> stream(FileManager::OpenForWriting("MapEditor/palette.list"));

			std::string list;
			for (size_t i = 0; i < paletteList.size(); i++) {
				list += paletteList[i];
				list += '\n';
			}

			stream->Write(list);
			stream->Flush();

			SPLog("Palette List saved.");
		}

		void PaletteView::LoadPaletteList() {
			if (!FileManager::FileExists("MapEditor/palette.list")) {
				WritePaletteList();
				return;
			}

			std::unique_ptr<IStream> stream(FileManager::OpenForReading("MapEditor/palette.list"));
			int len = (int)(stream->GetLength() - stream->GetPosition());
			std::string list = stream->Read(len);
			std::string page;

			for (size_t i = 0; i < list.size(); i++) {
				if (list[i] != '\n') {
					page += list[i];
					continue;
				}
				paletteList.push_back(page);
				page.clear();
			}
			SPLog("Palette List loaded.");
		}

		void PaletteView::LoadPalettePage(std::string name) {
			if (!FileManager::FileExists(name.c_str()))
				return;

			std::unique_ptr<IStream> stream(FileManager::OpenForReading(name.c_str()));
			int len = (int)(stream->GetLength() - stream->GetPosition());
			std::string list = stream->Read(len);

			colors.clear();
			IntVector3 color;

			int RowColumn = 2;
			int rgb = 3;

			std::string strNumber = "";
			int number;
			for (char c : list) {
				if (isdigit(c)) {
					strNumber += c;
					continue;
				}
				if (strNumber == "")
					continue;
				number = stoi(strNumber);
				strNumber = "";

				if (RowColumn == 2) {
					RowColumn--;
					paletteColumn = number;
					continue;
				}
				if (RowColumn == 1) {
					RowColumn--;
					paletteRow = number;
					continue;
				}

				if (rgb == 3) {
					rgb--;
					color.x = number;
					continue;
				}
				if (rgb == 2) {
					rgb--;
					color.y = number;
					continue;
				}
				rgb = 3;
				color.z = number;
				colors.push_back(color);
			}
			SetSelectedIndex(0);

			list = "Palette Page loaded: ";
			list += name;
			client->ShowAlert(list, Client::AlertType::Notice);
			SPLog("Palette Page loaded: %s", name.c_str());
		}

		void PaletteView::LoadCurrentPalettePage() {
			if (currentPalettePage < 0 || currentPalettePage >= (int)paletteList.size())
				return;

			LoadPalettePage(paletteList[currentPalettePage]);
			UpdatePaletteWindow();
		}

		void PaletteView::SaveCurrentPalettePage() {
			if (currentPalettePage < 0 || currentPalettePage >= (int)paletteList.size())
				return;

			std::unique_ptr<IStream> stream(FileManager::OpenForWriting(paletteList[currentPalettePage].c_str()));

			char buf[256];

			sprintf(buf, "[%d columns, %d rows] \n", paletteColumn, paletteRow);
			std::string page = buf;

			int newline = 0;
			for (auto col : colors) {
				page += WriteColor(col);

				newline++;
				if (newline >= 8) {
					page +=  '\n';
					newline = 0;
				}
			}

			stream->Write(page);
			stream->Flush();

			UpdatePaletteWindow();

			page = "Palette Page saved: " + paletteList[currentPalettePage];
			client->ShowAlert(page, Client::AlertType::Notice);
			SPLog("Palette Page saved: %s", paletteList[currentPalettePage].c_str());
		}

		void PaletteView::NewPalettePage() {
			paletteRow = paletteColumn = 16;

			//zerospades
			IntVector3 cols[] = {
			  {128, 128, 128}, {256,   0,   0}, {256, 128,   0}, {256, 256,   0},
			  {256, 256, 128}, {128, 256,   0}, {  0, 256,   0}, {  0, 256, 128},
			  {0  , 256, 256}, {128, 256, 256}, {  0, 128, 256}, {  0,   0, 256},
			  {128,   0, 256}, {256,   0, 256}, {256, 128, 256}, {256,   0, 128}
			};

			colors.clear();
			IntVector3 def = IntVector3::Make(256, 256, 256);
			int newline = 0;
			for (int i = 0; i < (int)paletteRow; i++) {
				for (int j = 1; j < (int)paletteColumn; j += 2) 
					colors.push_back(SanitizeCol(((cols[i] * j) / (int)paletteColumn) - 1));

				auto rem = def - cols[i];
				for (int j = 1; j < (int)paletteColumn; j += 2)
					colors.push_back(cols[i] + ((rem * j) / (int)paletteColumn) - 1);
			}
			SetSelectedIndex(7);

			std::string page = PalettePath(-1);
			paletteList.push_back(page);
			currentPalettePage = (int)paletteList.size() - 1;
			SaveCurrentPalettePage();

			WritePaletteList();
		}

		void PaletteView::DeleteCurrentPalettePage() { //only removes page from palette list
			if (currentPalettePage < 0 || currentPalettePage >= (int)paletteList.size())
				return;

			paletteList.erase(paletteList.begin() + currentPalettePage);
			WritePaletteList();
			if (currentPalettePage >= (int)paletteList.size()) {
				ChangePalettePage(-1);
			} else {
				LoadCurrentPalettePage();
			}
		}

		void PaletteView::ChangePalettePage(int next) {
			if (next == 0 || (next < 0 && currentPalettePage < 0))
				return;

			currentPalettePage += next;

			if (currentPalettePage == -1) {
				DefaultPalette();
				return;
			}

			if (currentPalettePage >= (int)paletteList.size()) {
				currentPalettePage--;
				return;
			}

			if (!FileManager::FileExists(paletteList[currentPalettePage].c_str())) {
				DeleteCurrentPalettePage();
				return;
			}

			LoadPalettePage(paletteList[currentPalettePage]);
			UpdatePaletteWindow();
		}

		void PaletteView::EditCurrentColor() {
			int index = GetSelectedIndex();
			IntVector3 col;
			col.x = (int)cg_CurrentColorRed;
			col.y = (int)cg_CurrentColorGreen;
			col.z = (int)cg_CurrentColorBlue;
			colors[index] = col;
			SetSelectedIndex(index);
		}

		void PaletteView::CompareCurrentColor() {
			IntVector3 col = colors[GetSelectedIndex()];

			if (col.x != (int)cg_CurrentColorRed ||
				col.y != (int)cg_CurrentColorGreen ||
				col.z != (int)cg_CurrentColorBlue) {
				EditCurrentColor();
			}
		}

		void PaletteView::UpdatePaletteWindow() {
			client->scriptedUI->EnterPaletteWindow();
		}

		int PaletteView::GetSelectedIndex() {
			World *w = client->GetWorld();
			if (!w)
				return -1;

			stmp::optional<Player &> p = w->GetLocalPlayer();
			if (!p)
				return -1;

			IntVector3 col = p->GetBlockColor();
			if (currentColor < (int)colors.size()) {
				return currentColor;
			}
			return -1;
		}

		int PaletteView::GetSelectedOrDefaultIndex() {
			int c = GetSelectedIndex();
			if (c == -1)
				return defaultColor;
			else
				return c;
		}

		void PaletteView::SetSelectedIndex(int idx) {
			if (currentColor >= (int)colors.size())
				return;

			currentColor = idx;
			IntVector3 col = colors[currentColor];

			World *w = client->GetWorld();
			if (!w)
				return;

			stmp::optional<Player &> p = w->GetLocalPlayer();
			if (!p)
				return;

			p->SetHeldBlockColor(col);

			cg_CurrentColorRed = col.x;
			cg_CurrentColorGreen = col.y;
			cg_CurrentColorBlue = col.z;

			client->net->SendHeldBlockColor();
		}

		bool PaletteView::KeyInput(std::string keyName) {
			if (EqualsIgnoringCase(keyName, cg_keyPaletteLeft)) {
				int c = GetSelectedOrDefaultIndex();
				if (c == 0)
					c = (int)colors.size() - 1;
				else
					c--;
				SetSelectedIndex(c);
				return true;
			} else if (EqualsIgnoringCase(keyName, cg_keyPaletteRight)) {
				int c = GetSelectedOrDefaultIndex();
				if (c == (int)colors.size() - 1)
					c = 0;
				else
					c++;
				SetSelectedIndex(c);
				return true;
			} else if (EqualsIgnoringCase(keyName, cg_keyPaletteUp)) {
				int c = GetSelectedOrDefaultIndex();
				if (c < paletteColumn)
					c += (int)colors.size() - paletteColumn;
				else
					c -= paletteColumn;
				SetSelectedIndex(c);
				return true;
			} else if (EqualsIgnoringCase(keyName, cg_keyPaletteDown)) {
				int c = GetSelectedOrDefaultIndex();
				if (c >= (int)colors.size() - paletteColumn)
					c -= (int)colors.size() - paletteColumn;
				else
					c += paletteColumn;
				SetSelectedIndex(c);
				return true;
			} else if (EqualsIgnoringCase(keyName, cg_keyPaletteInvert)) {
				World *w = client->GetWorld();
				if (!w)
					return true;
				stmp::optional<Player &> p = w->GetLocalPlayer();
				if (!p)
					return true;
				IntVector3 clr = p->GetBlockColor();
				clr.x = 255 - clr.x;
				clr.y = 255 - clr.y;
				clr.z = 255 - clr.z;
				p->SetHeldBlockColor(clr);
				client->net->SendHeldBlockColor();
				return true;
			} else if (EqualsIgnoringCase(keyName, cg_keyPaletteMix)) {
				World *w = client->GetWorld();
				if (!w)
					return true;
				stmp::optional<Player &> p = w->GetLocalPlayer();
				if (!p)
					return true;

				IntVector3 clr_a = p->GetBlockColor();
				double a_x = clr_a.x / 255.0;
				double a_y = clr_a.y / 255.0;
				double a_z = clr_a.z / 255.0;
				a_x = a_x <= 0.04045 ? a_x / 12.92 : std::pow((a_x + 0.055) / 1.055, 2.4);
				a_y = a_y <= 0.04045 ? a_y / 12.92 : std::pow((a_y + 0.055) / 1.055, 2.4);
				a_z = a_z <= 0.04045 ? a_z / 12.92 : std::pow((a_z + 0.055) / 1.055, 2.4);

				client->CaptureColor();

				IntVector3 clr_b = p->GetBlockColor();
				double b_x = clr_b.x / 255.0;
				double b_y = clr_b.y / 255.0;
				double b_z = clr_b.z / 255.0;
				b_x = b_x <= 0.04045 ? b_x / 12.92 : std::pow((b_x + 0.055) / 1.055, 2.4);
				b_y = b_y <= 0.04045 ? b_y / 12.92 : std::pow((b_y + 0.055) / 1.055, 2.4);
				b_z = b_z <= 0.04045 ? b_z / 12.92 : std::pow((b_z + 0.055) / 1.055, 2.4);

				b_x = (a_x + b_x) / 2.;
				b_y = (a_y + b_y) / 2.;
				b_z = (a_z + b_z) / 2.;
				b_x = b_x <= 0.0031308 ? b_x * 12.92 : (1.055 * std::pow(b_x, 1./2.4) - 0.055);
				b_y = b_y <= 0.0031308 ? b_y * 12.92 : (1.055 * std::pow(b_y, 1./2.4) - 0.055);
				b_z = b_z <= 0.0031308 ? b_z * 12.92 : (1.055 * std::pow(b_z, 1./2.4) - 0.055);
				b_x = b_x * 255.0 + 0.49;
				b_y = b_y * 255.0 + 0.49;
				b_z = b_z * 255.0 + 0.49;
				clr_b.x = (int)b_x;
				clr_b.y = (int)b_y;
				clr_b.z = (int)b_z;

				colors[defaultColor] = clr_b;
				p->SetHeldBlockColor(clr_b);
				client->net->SendHeldBlockColor();
				return true;
			} else {
				return false;
			}
		}

		void PaletteView::Update() {}

		void PaletteView::Draw() {
			Handle<IImage> img = renderer.RegisterImage("Gfx/Palette.png");

			int sel = GetSelectedIndex();

			float scrW = renderer.ScreenWidth();
			float scrH = renderer.ScreenHeight();

			std::string str = std::to_string(currentPalettePage + 1);
			IFont &font = client->fontManager->GetGuiFont();
			float margin = 5.f;

			float posX = scrW - 18.f;
			float posY = scrH - 55.f;

			auto size = font.Measure(str);
			size += Vector2(margin * 2.f, margin * 2.f);
			size *= 0.9f;

			auto pos = Vector2(posX - size.x, posY - size.y);

			renderer.SetColorAlphaPremultiplied(Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_hudTransparency));
			renderer.DrawImage(nullptr, AABB2(pos.x, pos.y, size.x, size.y));
			font.DrawShadow(
				str, pos + Vector2(margin, margin), 0.8f,
				Vector4(1.f, 1.f, 1.f, (float)cg_hudTransparency),
				Vector4(0.f, 0.f, 0.f, 0.5f * (float)cg_hudTransparency)
			);

			for (size_t phase = 0; phase < 2; phase++) {
				for (size_t i = 0; i < colors.size(); i++) {
					if ((sel == i) != (phase == 1))
						continue;

					int row = static_cast<int>(i / paletteRow);
					int col = static_cast<int>(i % paletteColumn);

					bool selected = sel == i;

					// draw color
					IntVector3 icol = colors[i];
					Vector4 cl;
					cl.x = icol.x / 255.f;
					cl.y = icol.y / 255.f;
					cl.z = icol.z / 255.f;
					cl.w = (float)cg_hudTransparency;

					float x = scrW - 20.f - (paletteColumn * 10.f) + 10.f * col;
					float y = scrH - 26.f - (paletteRow * 10.f) + 10.f * row - 60.f;

					renderer.SetColorAlphaPremultiplied(cl);
					if (selected) {
						renderer.DrawImage(img, MakeVector2(x, y), AABB2(0, 16, 16, 16));
					} else {
						renderer.DrawImage(img, MakeVector2(x, y), AABB2(0, 0, 16, 16));
					}

					renderer.SetColorAlphaPremultiplied(MakeVector4(1, 1, 1, (float)cg_hudTransparency));
					if (selected) {
						renderer.DrawImage(img, MakeVector2(x, y), AABB2(16, 16, 16, 16));
					} else {
						renderer.DrawImage(img, MakeVector2(x, y), AABB2(16, 0, 16, 16));
					}
				}
			}
		}
	} // namespace client
} // namespace spades

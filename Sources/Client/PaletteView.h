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

#pragma once

#include <string>

#include <Core/Math.h>

namespace spades {
	namespace client {
		class Client;
		class IRenderer;
		class PaletteView {
			Client *client;
			IRenderer &renderer;

			int defaultColor;
			int currentColor;
			std::vector<IntVector3> colors;
			int GetSelectedIndex();
			int GetSelectedOrDefaultIndex();

			void SetSelectedIndex(int);

			int paletteRow;
			int paletteColumn;

			std::string PalettePath(int i);

			std::string WriteColor(IntVector3 color);

			void DefaultPalette();

			std::vector<std::string> paletteList;
			void LoadPaletteList();
			void WritePaletteList();
			void SwapPaletteListElements(int a, int b);

			void LoadPalettePage(std::string name);

		public:
			PaletteView(Client *);
			~PaletteView();

			bool KeyInput(std::string);

			void Update();
			void Draw();

			int currentPalettePage;
			void ChangePalettePage(int id);
			void LoadCurrentPalettePage();
			void SaveCurrentPalettePage();
			void NewPalettePage();
			void DeleteCurrentPalettePage();
			void EditCurrentColor();
			void CompareCurrentColor();
		};
	} // namespace client
} // namespace spades

/*
 Copyright (c) 2013 yvt
 Portion of the code is based on Serverbrowser.cpp.

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
#include "ClientUIHelper.h"
#include "ClientUI.h"

namespace spades {
	namespace client {
		ClientUIHelper::ClientUIHelper(ClientUI *ui) : ui(ui) {}

		void ClientUIHelper::ClientUIDestroyed() { ui = NULL; }

		void ClientUIHelper::SayGlobal(const std::string &text) {
			if (!ui)
				return;
			ui->SendChat(text, true);
		}

		void ClientUIHelper::SayTeam(const std::string &text) {
			if (!ui)
				return;
			ui->SendChat(text, false);
		}

		void ClientUIHelper::AlertNotice(const std::string &text) {
			if (!ui)
				return;
			ui->AlertNotice(text);
		}
		void ClientUIHelper::AlertWarning(const std::string &text) {
			if (!ui)
				return;
			ui->AlertWarning(text);
		}
		void ClientUIHelper::AlertError(const std::string &text) {
			if (!ui)
				return;
			ui->AlertError(text);
		}

		void ClientUIHelper::MapEditorSaveMap() {
			if (!ui)
				return;
			ui->MapEditorSaveMap();
		}

		void ClientUIHelper::EditCurrentColor() {
			if (!ui)
				return;
			ui->EditCurrentColor();
		}
		void ClientUIHelper::ChangePalettePage(int next) {
			if (!ui)
				return;
			ui->ChangePalettePage(next);
		}
		void ClientUIHelper::SaveCurrentPalettePage() {
			if (!ui)
				return;
			ui->SaveCurrentPalettePage();
		}
		void ClientUIHelper::LoadCurrentPalettePage() {
			if (!ui)
				return;
			ui->LoadCurrentPalettePage();
		}
		void ClientUIHelper::NewPalettePage() {
			if (!ui)
				return;
			ui->NewPalettePage();
		}
		void ClientUIHelper::DeleteCurrentPalettePage() {
			if (!ui)
				return;
			ui->DeleteCurrentPalettePage();
		}
		void ClientUIHelper::PaletteKeyInput(const std::string &key) {
			if (!ui)
				return;
			ui->PaletteKeyInput(key);
		}
	} // namespace client
} // namespace spades

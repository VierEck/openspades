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

#include "ScriptManager.h"
#include <Client/ClientUIHelper.h>

namespace spades {
	namespace client {
		class ClientUIHelperRegistrar: public ScriptObjectRegistrar {
			
			
		public:
			ClientUIHelperRegistrar():
			ScriptObjectRegistrar("ClientUIHelper") {}
			
			virtual void Register(ScriptManager *manager, Phase phase) {
				asIScriptEngine *eng = manager->GetEngine();
				int r;
				eng->SetDefaultNamespace("spades");
				switch(phase){
					case PhaseObjectType:
						r = eng->RegisterObjectType("ClientUIHelper",
													0, asOBJ_REF);
						manager->CheckError(r);
						break;
					case PhaseObjectMember:
						r = eng->RegisterObjectBehaviour("ClientUIHelper",
														 asBEHAVE_ADDREF,
														 "void f()",
														 asMETHOD(client::ClientUIHelper, AddRef),
														 asCALL_THISCALL);
						manager->CheckError(r);
						r = eng->RegisterObjectBehaviour("ClientUIHelper",
														 asBEHAVE_RELEASE,
														 "void f()",
														 asMETHOD(client::ClientUIHelper, Release),
														 asCALL_THISCALL);
						manager->CheckError(r);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void SayGlobal(const string& in)",
													  asMETHOD(ClientUIHelper, SayGlobal),
													  asCALL_THISCALL);
						manager->CheckError(r);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void SayTeam(const string& in)",
													  asMETHOD(ClientUIHelper, SayTeam),
													  asCALL_THISCALL);
						manager->CheckError(r);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void AlertNotice(const string& in)",
													  asMETHOD(ClientUIHelper, AlertNotice),
													  asCALL_THISCALL);
						manager->CheckError(r);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void AlertWarning(const string& in)",
													  asMETHOD(ClientUIHelper, AlertWarning),
													  asCALL_THISCALL);
						manager->CheckError(r);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void AlertError(const string& in)",
													  asMETHOD(ClientUIHelper, AlertError),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void SaveMap()",
													  asMETHOD(ClientUIHelper, MapEditorSaveMap),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void EditCurrentColor()",
													  asMETHOD(ClientUIHelper, EditCurrentColor),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void ChangePalettePage(int)",
													  asMETHOD(ClientUIHelper, ChangePalettePage),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void SaveCurrentPalettePage()",
													  asMETHOD(ClientUIHelper, SaveCurrentPalettePage),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void LoadCurrentPalettePage()",
													  asMETHOD(ClientUIHelper, LoadCurrentPalettePage),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void NewPalettePage()",
													  asMETHOD(ClientUIHelper, NewPalettePage),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void DeleteCurrentPalettePage()",
													  asMETHOD(ClientUIHelper, DeleteCurrentPalettePage),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void PaletteKeyInput(const string& in)",
													  asMETHOD(ClientUIHelper, PaletteKeyInput),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void requestSaveTxt(const string& in)",
													  asMETHOD(ClientUIHelper, requestSaveTxt),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void requestLoadTxt()",
													  asMETHOD(ClientUIHelper, requestLoadTxt),
													  asCALL_THISCALL);
						r = eng->RegisterObjectMethod("ClientUIHelper",
													  "void requestGenTxt()",
													  asMETHOD(ClientUIHelper, requestGenTxt),
													  asCALL_THISCALL);
						manager->CheckError(r);
						break;
					default:
						break;
				}
			}
		};
		
		static ClientUIHelperRegistrar registrar;
	}
}


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
#include <Core/RefCountedObject.h>
#include <Core/FileManager.h>

namespace spades {
	class FileHandlerRegistrar : public ScriptObjectRegistrar {
		class FileHandler : public RefCountedObject {
		public:
			FileHandler() {};
			~FileHandler() {};

			bool FileExists(const std::string &in) { return FileManager::FileExists(in.c_str()); }

			CScriptArray *EnumFiles(const std::string &in) {
				auto *ctx = asGetActiveContext();
				auto *engine = ctx->GetEngine();
				auto *arrayType = engine->GetTypeInfoByDecl("array<string>");
				auto *array = CScriptArray::Create(arrayType);
				auto names = FileManager::EnumFiles(in.c_str());
				array->Resize(static_cast<asUINT>(names.size()));
				for(std::size_t i = 0; i < names.size(); i++) {
					reinterpret_cast<std::string *>(array->At(static_cast<asUINT>(i)))->assign(names[i]);
				}
				return array;
			}

			std::string ReadAllBytes(const std::string &in) { return FileManager::ReadAllBytes(in.c_str()); }

			void RemoveFile(const std::string &in) { FileManager::RemoveFile(in.c_str()); }

			void RenameFile(const std::string &oldIn, const std::string &newIn) {
				FileManager::RenameFile(oldIn.c_str(), newIn.c_str());
			}

			void CopyToFile(const std::string &oldIn, const std::string &newIn) {
				FileManager::CopyToFile(oldIn.c_str(), newIn.c_str());
			}

		};

		static FileHandler *Factory() {
			try{
				return new FileHandler();
			}catch(const std::exception& ex){
				ScriptContextUtils().SetNativeException(ex);
				return nullptr;
			}
		}

		//todo IStream bind?
		
	public:
		FileHandlerRegistrar():
		ScriptObjectRegistrar("FileHandler") {}

		virtual void Register(ScriptManager *manager, Phase phase) {
			asIScriptEngine *eng = manager->GetEngine();
			int r;
			eng->SetDefaultNamespace("spades");
			switch(phase){
				case PhaseObjectType:
					r = eng->RegisterObjectType("FileHandler",
												0, asOBJ_REF);
					manager->CheckError(r);
					break;
				case PhaseObjectMember:
					r = eng->RegisterObjectBehaviour("FileHandler",
													 asBEHAVE_ADDREF,
													 "void f()",
													 asMETHOD(FileHandler, AddRef),
													 asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectBehaviour("FileHandler",
													 asBEHAVE_RELEASE,
													 "void f()",
													 asMETHOD(FileHandler, Release),
													 asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectBehaviour("FileHandler",
													 asBEHAVE_FACTORY,
													 "FileHandler @f()",
													 asFUNCTION(Factory),
													 asCALL_CDECL);
						manager->CheckError(r);
					r = eng->RegisterObjectMethod("FileHandler",
												  "bool FileExists(const string &in)",
												  asMETHOD(FileHandler, FileExists),
												  asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectMethod("FileHandler",
												  "array<string>@ EnumFiles(const string &in)",
												  asMETHOD(FileHandler, EnumFiles),
												  asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectMethod("FileHandler",
												  "void ReadAllBytes(const string &in)",
												  asMETHOD(FileHandler, ReadAllBytes),
												  asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectMethod("FileHandler",
												  "void RemoveFile(const string &in)",
												  asMETHOD(FileHandler, RemoveFile),
												  asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectMethod("FileHandler",
												  "void RenameFile(const string &in, const string &in)",
												  asMETHOD(FileHandler, RenameFile),
												  asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectMethod("FileHandler",
												  "void CopyToFile(const string &in, const string &in)",
												  asMETHOD(FileHandler, CopyToFile),
												  asCALL_THISCALL);
					manager->CheckError(r);
					break;
				default:
					break;
			}
		}
	};

	static FileHandlerRegistrar registrar;
}

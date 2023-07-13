#include "ScriptManager.h"
#include <Core/Settings.h>
#include <Core/RefCountedObject.h>

namespace spades {

	class MacroRegistrar: public ScriptObjectRegistrar {

	public:
		MacroRegistrar():
		ScriptObjectRegistrar("Macro") {}

		class MacroItem: public RefCountedObject {
			Settings::ItemMacro *macro;
		public:
			MacroItem(const std::string& name):
				macro(Settings::GetInstance()->GetMacroItem(name)){}
			static MacroItem *Construct(const std::string& name) {
				return new MacroItem(name);
			}

			void SetKey(const std::string& v) { macro->key = v; }
			void SetMsg(const std::string& v) { macro->msg = v; }
			std::string GetKey() { return macro->key; }
			std::string GetMsg() { return macro->msg; }
		};

		static CScriptArray *GetAllMacroNames() {
			auto *ctx = asGetActiveContext();
			auto *engine = ctx->GetEngine();
			auto *arrayType = engine->GetTypeInfoByDecl("array<string>");
			auto *array = CScriptArray::Create(arrayType);
			auto names = Settings::GetInstance()->GetAllMacroNames();
			array->Resize(static_cast<asUINT>(names.size()));
			for(std::size_t i = 0; i < names.size(); i++) {
				reinterpret_cast<std::string *>(array->At(static_cast<asUINT>(i)))->assign(names[i]);
			}
			return array;
		}

		static CScriptArray *AddMacroItem() {
			Settings::GetInstance()->AddMacroItem();
			//fixme make this a void
			auto *ctx = asGetActiveContext();
			auto *engine = ctx->GetEngine();
			auto *arrayType = engine->GetTypeInfoByDecl("array<string>");
			auto *array = CScriptArray::Create(arrayType);
			return array;
		}

		static CScriptArray *RemoveMacroItem(const std::string &name) {
			Settings::GetInstance()->RemoveMacroItem(name);
			//fixme make this a void
			auto *ctx = asGetActiveContext();
			auto *engine = ctx->GetEngine();
			auto *arrayType = engine->GetTypeInfoByDecl("array<string>");
			auto *array = CScriptArray::Create(arrayType);
			return array;
		}

		virtual void Register(ScriptManager *manager, Phase phase) {
			asIScriptEngine *eng = manager->GetEngine();
			int r;
			eng->SetDefaultNamespace("spades");
			switch(phase){
				case PhaseObjectType:
					r = eng->RegisterObjectType("MacroItem",
												0, asOBJ_REF);
					manager->CheckError(r);
					break;
				case PhaseObjectMember:
					r = eng->RegisterObjectBehaviour("MacroItem",
													 asBEHAVE_ADDREF,
													 "void f()",
													 asMETHOD(MacroItem, AddRef),
													 asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectBehaviour("MacroItem",
													 asBEHAVE_RELEASE,
													 "void f()",
													 asMETHOD(MacroItem, Release),
													 asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectBehaviour("MacroItem",
													 asBEHAVE_FACTORY,
													 "MacroItem @f(const string& in)",
													 asFUNCTIONPR(MacroItem::Construct, (const std::string&), MacroItem *),
													 asCALL_CDECL);
					manager->CheckError(r);
					r = eng->RegisterObjectMethod("MacroItem",
												  "void set_key(const string& in)",
												  asMETHODPR(MacroItem, SetKey, (const std::string&), void),
												  asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectMethod("MacroItem",
												  "void set_msg(const string& in)",
												  asMETHODPR(MacroItem, SetMsg, (const std::string&), void),
												  asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectMethod("MacroItem",
												  "string get_key()",
												  asMETHOD(MacroItem, GetKey),
												  asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterObjectMethod("MacroItem",
												  "string get_msg()",
												  asMETHOD(MacroItem, GetMsg),
												  asCALL_THISCALL);
					manager->CheckError(r);
					r = eng->RegisterGlobalFunction("array<string>@ GetAllMacroNames()",
												  asFUNCTION(GetAllMacroNames),
												  asCALL_CDECL);//fixme make this a void
					manager->CheckError(r);
					r = eng->RegisterGlobalFunction("array<string>@ AddMacroItem()",
													asFUNCTION(AddMacroItem),
													asCALL_CDECL);//fixme make this a void
					manager->CheckError(r);
					r = eng->RegisterGlobalFunction("array<string>@ RemoveMacroItem(const string& in)",
													asFUNCTION(RemoveMacroItem),
													asCALL_CDECL);
					manager->CheckError(r);

					break;
				default:
					break;
			}
		}
	};

	static MacroRegistrar registrar;
}

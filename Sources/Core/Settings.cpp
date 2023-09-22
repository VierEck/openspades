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

#include <cstdio>
#include <cstdlib>
#include <memory>

#include <Core/Debug.h>
#include "FltkPreferenceImporter.h"
#include "Settings.h"
#include <Core/FileManager.h>
#include <Core/IStream.h>
#include <Core/Math.h>

DEFINE_SPADES_SETTING(cg_performanceSetting, "0");

namespace spades {

#define PERFORMANCEFILE "Performance.cfg"
#define CONFIGFILE "SPConfig.cfg"
	static Settings *instance = NULL;

	Settings *Settings::GetInstance() {
		if (!instance)
			instance = new Settings();
		return instance;
	}

	Settings::Settings() {
		SPADES_MARK_FUNCTION();
		loaded = false;
		isPerformanceSettingLoaded = false;
		allowSwitch = false;
		isPerformance = false;
	}

	void Settings::Load(bool performance) {
		SPADES_MARK_FUNCTION();

		// import Fltk preferences
		bool importedPref = false;
		{
			auto prefs = ImportFltkPreference();
			for (const auto &item : prefs) {
				auto *it = GetItem(item.first, nullptr);

				it->Set(item.second);
			}
			if (prefs.size() > 0)
				importedPref = true;
			// FIXME: remove legacy preference?
		}

		auto config = performance ? PERFORMANCEFILE : CONFIGFILE;

		SPLog("Loading preferences from %s", config);
		loaded = false;
		bool shouldSwitch = false;
		try {
			if (FileManager::FileExists(config)) {
				SPLog("%s found.", config);

				std::string text = FileManager::ReadAllBytes(config);
				auto lines = SplitIntoLines(text);

				std::size_t line = 0;

				while (line < lines.size()) {
					auto &l = lines[line];
					{
						// remove comments
						auto pos = l.find('#');
						if (pos != std::string::npos) {
							l.resize(pos);
						}
					}

					std::size_t startPos = l.find_first_not_of(' ');
					if (startPos == std::string::npos) {
						// no contents in this line
						line++;
						continue;
					}

					auto lineBuf = l;
					std::size_t linePos = 0;

					auto tryDecodeHexDigit = [](char c, int &digit) -> bool {
						if (c >= '0' && c <= '9') {
							digit = c - '0';
							return true;
						} else if (c >= 'a' && c <= 'f') {
							digit = c - 'a' + 10;
							return true;
						} else if (c >= 'A' && c <= 'F') {
							digit = c - 'A' + 10;
							return true;
						} else {
							return false;
						}
					};

					auto readString = [&](bool stopAtColon) {
						std::string buffer;
						int digit1, digit2;
						while (linePos < lineBuf.size() && lineBuf[linePos] == ' ') {
							linePos++;
						}
						while (linePos < lineBuf.size()) {
							if (lineBuf[linePos] == '\\' && linePos + 1 == lineBuf.size() &&
							    line < lines.size() - 1) {
								// line continuation
								line++;
								lineBuf = lines[line];
								linePos = 0;
							} else if (lineBuf[linePos] == '\\' && linePos + 3 < lineBuf.size() &&
							           lineBuf[linePos + 1] == 'x' &&
							           tryDecodeHexDigit(lineBuf[linePos + 2], digit1) &&
							           tryDecodeHexDigit(lineBuf[linePos + 3], digit2)) {
								// hex
								char c = (digit1 << 4) | digit2;
								buffer += c;
								linePos += 3;
							} else if (lineBuf[linePos] == '\\' && linePos + 1 < lineBuf.size()) {
								// escape
								switch (lineBuf[linePos + 1]) {
									case 'n': buffer += '\n'; break;
									case 'r': buffer += '\r'; break;
									case 't': buffer += '\t'; break;
									default: buffer += lineBuf[linePos + 1]; break;
								}
								linePos += 2;
							} else if (lineBuf[linePos] == ':' && stopAtColon) {
								break;
							} else {
								// normal chars
								buffer += lineBuf[linePos];
								linePos++;
							}
						}
						return buffer;
					};

					std::string key = readString(true);
					if (linePos >= lineBuf.size()) {
						SPLog("Warning: no value provided for \"%s\"", key.c_str());
					}
					linePos++;

					if (!performance) {
						if (key.find("4SpadesMacro") == 0) {
							std::string vals = readString(false);
							std::string button, message;
							size_t find = vals.find(" |: ");
							if (find != std::string::npos) {
								auto *itemMacro = GetMacroItem(key);
								itemMacro->key = vals.substr(0, find);
								itemMacro->msg = vals.substr(find + 4);
							}
						} else {
							std::string val = readString(false);
							auto *item = GetItem(key, nullptr);
							item->Set(val);

							if (key == "cg_performanceSetting" && item->intValue > 0)
								allowSwitch = true;
						}
					} else {
						std::string val = readString(false);
						auto *itemSav = GetSavedItem(key, nullptr, true);
						itemSav->string = val;
					}

					line++;
				}

			} else {
				SPLog("%s doesn't exist.", config);
			}

			if (importedPref) {
				SPLog("Legacy preference was imported. Removing the legacy pref file.");
				DeleteFltkPreference();
				Save();
			}

			loaded = true;
		} catch (const std::exception &ex) {
			SPLog("Failed to load preference: %s", ex.what());
			SPLog("Disabling saving preference.");
		}

		if (!performance) {
			Load(true);
		} else {
			allowSwitch = true;
			if (isPerformanceSettingLoaded && cg_performanceSetting)
				SwitchAllItems();
		}
	}

	void Settings::Save(bool performance) {
		auto config = performance ? PERFORMANCEFILE : CONFIGFILE;
		SPLog("Saving preferences to %s", config);
		try {
			std::string buffer;
			buffer = "# OpenSpades config file\n"
			         "#\n"
			         "\n";

			int column = 0;

			auto emitContinuation = [&] {
				buffer += "\\\n";
				column = 0;
			};

			auto emitString = [&](const std::string &val, bool escapeColon) {
				std::size_t i = 0;
				while (i < val.size() && val[i] == ' ') {
					if (column > 78) {
						emitContinuation();
					}
					buffer += "\\ ";
					column += 2;
					i++;
				}
				while (i < val.size()) {
					if (column > 78) {
						emitContinuation();
					}
					unsigned char uc = static_cast<unsigned char>(val[i]);
					switch (val[i]) {
						case '\n':
							buffer += "\\n";
							column += 2;
							i++;
							break;
						case '\r':
							buffer += "\\r";
							column += 2;
							i++;
							break;
						case '\t':
							buffer += "\\t";
							column += 2;
							i++;
							break;
						default:
							std::size_t utf8charsize;
							GetCodePointFromUTF8String(val, i, &utf8charsize);

							if (val[i] == '#' ||                     // comment marker
							    (escapeColon && val[i] == ':') ||    // key/value split
							    uc < 0x20 ||                         // control char
							    (uc >= 0x80 && utf8charsize == 0) || // invalid UTF8
							    utf8charsize >=
							      5) { // valid UTF-8 but codepoint beyond BMP/SMP range
								static const char *s = "0123456789abcdef";
								buffer += "\\x";
								buffer += s[uc >> 4];
								buffer += s[uc & 15];
								column += 3;
								i++;
							} else {
								buffer.append(val, i, utf8charsize);
								column += utf8charsize;
								i += utf8charsize;
							}
							break;
					}
				}
			};

			if (!performance) {
				if (performanceSetting) {
					Item *itm = performanceSetting;

					emitString(itm->name, true);
					buffer += ": ";
					column += 2;

					emitString(itm->string, false);

					buffer += "\n";
					column = 0;
				}

				bool usingPerformance = isPerformance;
				if (usingPerformance)
					SwitchAllItems();

				for (const auto &item : items) {
					Item *itm = item.second;

					emitString(itm->name, true);
					buffer += ": ";
					column += 2;

					emitString(itm->string, false);

					buffer += "\n";
					column = 0;
				}

				if (usingPerformance)
					SwitchAllItems();

				for (const auto &item : itemsMacro) {
					ItemMacro *itm = item.second;

					emitString(itm->name, true);
					buffer += ": ";
					column += 2;

					emitString(itm->key, false);
					buffer += " |: ";
					column += 4;

					emitString(itm->msg, false);

					buffer += "\n";
					column = 0;
				}
			} else {
				for (const auto &item : itemsPerformance) {
					ItemSaved *itm = item.second;

					emitString(itm->name, true);
					buffer += ": ";
					column += 2;

					emitString(itm->string, false);

					buffer += "\n";
					column = 0;
				}
			}

			std::unique_ptr<IStream> s(FileManager::OpenForWriting(config));
			s->Write(buffer);

		} catch (const std::exception &ex) {
			SPLog("Failed to save preference: %s", ex.what());
		}

		if (!performance)
			Save(true);
	}

	void Settings::Flush() {
		if (loaded) {
			SPLog("Saving preference to config files");
			Save();
		} else {
			SPLog("Not saving preferences because loading preferences has failed.");
		}
	}

	std::vector<std::string> Settings::GetAllItemNames() {
		SPADES_MARK_FUNCTION();
		std::vector<std::string> names;
		std::map<std::string, Item *>::iterator it;
		for (it = items.begin(); it != items.end(); it++) {
			names.push_back(it->second->name);
		}
		return names;
	}

	Settings::Item *Settings::GetItem(const std::string &name,
	                                  const SettingItemDescriptor *descriptor) {
		SPADES_MARK_FUNCTION();
		if (name == "cg_performanceSetting")
			return GetPerformanceSetting(descriptor);

		std::map<std::string, Item *>::iterator it;
		Item *item;
		it = items.find(name);
		if (it == items.end()) {
			item = new Item();
			item->name = name;
			item->defaults = true;
			item->descriptor = nullptr;
			item->intValue = 0;
			item->value = 0.0f;

			items[name] = item;
		} else {
			item = it->second;
		}

		if (descriptor) {
			if (item->descriptor) {
				if (*item->descriptor != *descriptor) {
					SPLog("WARNING: setting '%s' has multiple descriptors", name.c_str());
				}
			} else {
				item->descriptor = descriptor;
				const std::string &defaultValue = descriptor->defaultValue;
				if (item->defaults) {
					item->value = static_cast<float>(atof(defaultValue.c_str()));
					item->intValue = atoi(defaultValue.c_str());
					item->string = defaultValue;
				}
			}
		}

		return item;
	}

	Settings::Item *Settings::GetPerformanceSetting(const SettingItemDescriptor *descriptor) {
		SPADES_MARK_FUNCTION();
		Item *item;
		if (!isPerformanceSettingLoaded) {
			item = new Item();
			item->name = "cg_performanceSetting";
			item->defaults = true;
			item->descriptor = nullptr;
			item->intValue = 0;
			item->value = 0.0f;

			performanceSetting = item;
		} else {
			item = performanceSetting;
		}

		if (descriptor) {
			if (item->descriptor) {
				if (*item->descriptor != *descriptor) {
					SPLog("WARNING: setting 'cg_performanceSetting' has multiple descriptors");
				}
			} else {
				item->descriptor = descriptor;
				const std::string &defaultValue = descriptor->defaultValue;
				if (item->defaults) {
					item->value = static_cast<float>(atof(defaultValue.c_str()));
					item->intValue = atoi(defaultValue.c_str());
					item->string = defaultValue;
				}
			}
		}

		isPerformanceSettingLoaded = true;
		return item;
	}

	Settings::ItemSaved *Settings::GetSavedItem(const std::string &name, const SettingItemDescriptor *descriptor, bool performance) {
		SPADES_MARK_FUNCTION();
		if (name == "cg_performanceSetting")
			return nullptr;
		auto &itemList = performance ? itemsPerformance : itemsSaved;
		std::map<std::string, ItemSaved *>::iterator it;
		ItemSaved *itemSav;
		it = itemList.find(name);
		if (it == itemList.end()) {
			Item *itm = GetItem(name, nullptr);
			itemSav = new ItemSaved();
			itemSav->name = name;
			if (itm->string.size() > 0)
				itemSav->string = itm->string;

			itemList[name] = itemSav;
		} else {
			itemSav = it->second;
		}

		if (descriptor)
			itemSav->string = performance ? descriptor->performanceValue : descriptor->defaultValue;

		return itemSav;
	}

	namespace {
		class performanceSettingListener : public ISettingItemListener {
			Settings::ItemHandle handle;
		public:
			performanceSettingListener() : handle("cg_performanceSetting", nullptr) {
				handle.AddListener(this);
			}
			~performanceSettingListener() { handle.RemoveListener(this); }
			void SettingChanged(const std::string &) override {
				if (Settings::GetInstance()->IsPerformance() != (bool)handle)
					Settings::GetInstance()->SwitchAllItems();
			}
		};

		performanceSettingListener perfSetListener;
	}

	void Settings::SwitchAllItems() {
		SPADES_MARK_FUNCTION();
		if (!allowSwitch)
			return;

		auto names = GetAllItemNames();
		for (auto &name : names) {
			ItemSaved *itemSav = GetSavedItem(name, nullptr, !isPerformance);
			ItemSaved *itemSavOpposite = GetSavedItem(name, nullptr, isPerformance);
			Item *item = GetItem(name, nullptr);
			itemSavOpposite->string = item->string;
			item->Set(itemSav->string);
		}
		isPerformance = !isPerformance;
	}

	void Settings::AddMacroItem() {
		SPADES_MARK_FUNCTION();
		std::vector<std::string> allNames = GetAllMacroNames();
		char buf[24];
		for (int i = 0; i < 99; i++) {
			sprintf(buf, "4SpadesMacro_%02d", i);
			if (allNames.size() <= i) {
				GetMacroItem(buf);
				SPLog("New Macro Setting added: %s", buf);
				return;
			}
			if (buf != allNames[i]) {
				GetMacroItem(buf);
				SPLog("New Macro Setting added: %s", buf);
				return;
			}
		}
		SPLog("Too many Macros. maximum is 100");
	}

	void Settings::RemoveMacroItem(const std::string &name) {
		SPADES_MARK_FUNCTION();
		itemsMacro.erase(name);
	}

	Settings::ItemMacro *Settings::GetMacroItem(const std::string &name) {
		SPADES_MARK_FUNCTION();
		std::map<std::string, ItemMacro *>::iterator it = itemsMacro.find(name);
		ItemMacro *item;
		if (it == itemsMacro.end()) {
			item = new ItemMacro();
			item->name = name;
			item->key = "replace me";
			item->msg = "replace me";

			itemsMacro[name] = item;
		} else {
			item = it->second;
		}
		return item;
	}

	std::string Settings::GetMacroItemMsgViaKey(const std::string &key){
		SPADES_MARK_FUNCTION();
		for (auto item : itemsMacro)
			if (EqualsIgnoringCase(item.second->key, key))
				return item.second->msg;
		return "";
	}

	std::vector<std::string> Settings::GetAllMacroNames() {
		SPADES_MARK_FUNCTION();
		std::vector<std::string> names;
		std::map<std::string, ItemMacro *>::iterator it;
		for (it = itemsMacro.begin(); it != itemsMacro.end(); it++) {
			names.push_back(it->second->name);
		}
		return names;
	}

	void Settings::Item::Load() {
		// no longer need to Load
	}

	void Settings::Item::Set(const std::string &str) {
		string = str;
		value = static_cast<float>(atof(str.c_str()));
		intValue = atoi(str.c_str());
		defaults = false;

		NotifyChange();
	}

	void Settings::Item::Set(int v) {
		SPADES_MARK_FUNCTION_DEBUG();
		char buf[256];
		sprintf(buf, "%d", v);
		string = buf;
		intValue = v;
		value = (float)v;
		defaults = false;

		NotifyChange();
	}

	void Settings::Item::Set(float v) {
		SPADES_MARK_FUNCTION_DEBUG();
		char buf[256];
		sprintf(buf, "%f", v);
		string = buf;
		intValue = (int)v;
		value = v;
		defaults = false;

		NotifyChange();
	}

	void Settings::Item::NotifyChange() {
		for (ISettingItemListener *listener : listeners) {
			listener->SettingChanged(name);
		}
	}

	Settings::ItemHandle::ItemHandle(const std::string &name,
	                                 const SettingItemDescriptor *descriptor) {
		SPADES_MARK_FUNCTION();

		item = Settings::GetInstance()->GetItem(name, descriptor);
		Settings::GetInstance()->GetSavedItem(name, descriptor, false);
		Settings::GetInstance()->GetSavedItem(name, descriptor, true);
	}

	void Settings::ItemHandle::operator=(const std::string &value) { item->Set(value); }
	void Settings::ItemHandle::operator=(int value) { item->Set(value); }
	void Settings::ItemHandle::operator=(float value) { item->Set(value); }
	bool Settings::ItemHandle::operator==(int value) {
		item->Load();
		return item->intValue == value;
	}
	bool Settings::ItemHandle::operator!=(int value) {
		item->Load();
		return item->intValue != value;
	}
	Settings::ItemHandle::operator std::string() {
		item->Load();
		return item->string;
	}
	Settings::ItemHandle::operator int() {
		item->Load();
		return item->intValue;
	}
	Settings::ItemHandle::operator float() {
		item->Load();
		return item->value;
	}
	Settings::ItemHandle::operator bool() {
		item->Load();
		return item->intValue != 0;
	}
	const char *Settings::ItemHandle::CString() {
		item->Load();
		return item->string.c_str();
	}
	void Settings::ItemHandle::AddListener(ISettingItemListener *listener) {
		auto &listeners = item->listeners;
		listeners.push_back(listener);
	}
	void Settings::ItemHandle::RemoveListener(ISettingItemListener *listener) {
		auto &listeners = item->listeners;
		auto it = std::find(listeners.begin(), listeners.end(), listener);
		if (it != listeners.end()) {
			listeners.erase(it);
		}
	}

	namespace {
		const SettingItemDescriptor defaultDescriptor{std::string(), std::string(), SettingItemFlags::None};
	}

	const SettingItemDescriptor &Settings::ItemHandle::GetDescriptor() {
		return item->descriptor ? *item->descriptor : defaultDescriptor;
	}

	bool Settings::ItemHandle::IsUnknown() {
		return item->descriptor == nullptr;
	}
}

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

#include <map>
#include <string>
#include <type_traits>
#include <vector>

namespace spades {
	enum class SettingItemFlags { None = 0 };

	inline SettingItemFlags operator|(SettingItemFlags lhs, SettingItemFlags rhs)

	{
		using T = std::underlying_type<SettingItemFlags>::type;
		return (SettingItemFlags)(static_cast<T>(lhs) | static_cast<T>(rhs));
	}

	inline SettingItemFlags &operator|=(SettingItemFlags &lhs, SettingItemFlags rhs) {
		using T = std::underlying_type<SettingItemFlags>::type;
		lhs = (SettingItemFlags)(static_cast<T>(lhs) | static_cast<T>(rhs));
		return lhs;
	}

	struct SettingItemDescriptor {
		const std::string defaultValue;
		const std::string performanceValue;
		const SettingItemFlags flags;

		SettingItemDescriptor(const std::string &defaultValue = std::string(),
		                      const std::string &perfValue = std::string(),
		                      SettingItemFlags flags = SettingItemFlags::None)
		    : defaultValue(defaultValue), 
			  performanceValue(perfValue.size() > 0 ? perfValue : defaultValue), 
			  flags(flags) {}

		bool operator==(const SettingItemDescriptor &o) const {
			return defaultValue == o.defaultValue && flags == o.flags;
		}
		bool operator!=(const SettingItemDescriptor &o) const { return !(*this == o); }
	};

	class ISettingItemListener {
	protected:
		ISettingItemListener() = default;
		virtual ~ISettingItemListener() {}

	public:
		virtual void SettingChanged(const std::string &name) = 0;
	};

	class Settings {
		struct Item {
			std::string name;
			std::string string;
			float value;
			int intValue;

			const SettingItemDescriptor *descriptor;
			bool defaults;

			std::vector<ISettingItemListener *> listeners;

			void Load();
			void Set(const std::string &);
			void Set(int);
			void Set(float);

			void NotifyChange();
		};
		std::map<std::string, Item *> items;
		bool loaded;
		Settings();

		Item *GetItem(const std::string &name, const SettingItemDescriptor *descriptor);

		Item *performanceSetting;
		bool isPerformanceSettingLoaded;
		bool allowSwitch;
		Item *GetPerformanceSetting(const SettingItemDescriptor *descriptor);

		struct ItemSaved {
			std::string name;
			std::string string;
		};
		std::map<std::string, ItemSaved *> itemsSaved;
		std::map<std::string, ItemSaved *> itemsPerformance;
		bool isPerformance;
		ItemSaved *GetSavedItem(const std::string&name, const SettingItemDescriptor *descriptor, bool performance = false);

	public:
		static Settings *GetInstance();

		class ItemHandle {
			Item *item;

		public:
			ItemHandle(const std::string &name, const SettingItemDescriptor *descriptor);
			void operator=(const std::string &);
			void operator=(int);
			void operator=(float);
			bool operator==(int);
			bool operator!=(int);
			operator std::string();
			operator float();
			operator int();
			operator bool();
			const char *CString();

			const SettingItemDescriptor &GetDescriptor();

			/**
			 * Returns whether this config variable is used and defined by the program
			 * or not.
			 */
			bool IsUnknown();

			void AddListener(ISettingItemListener *);
			void RemoveListener(ISettingItemListener *);
		};

		void Save(bool performance = false);
		void Load(bool performance = false);
		void Flush();
		/** Return a list of all config variables, sorted by name. */
		std::vector<std::string> GetAllItemNames();

		bool IsPerformance() { return isPerformance; }
		bool AllowSwitch() { return allowSwitch; }
		void SwitchAllItems();

		struct ItemMacro {
			std::string name;
			std::string key;
			std::string msg;
		};
		std::map<std::string, ItemMacro *> itemsMacro;

		void AddMacroItem();
		void RemoveMacroItem(const std::string &);

		ItemMacro *GetMacroItem(const std::string&);
		std::string GetMacroItemMsgViaKey(const std::string&);

		std::vector<std::string> GetAllMacroNames();
	};
	/*
	template<const char *name, const char *def>
	class Setting: public Settings::ItemHandle {
	public:
	    Setting(): Settings::ItemHandle(name, def, desc){
	    }
	};*/

	static inline bool operator==(const std::string &str, Settings::ItemHandle &handle) {
		return str == (std::string)handle;
	}

// Define SettingItemDescriptor with external linkage so duplicates are
// detected as linker errors.
#define DEFINE_SPADES_SETTING(name, ...)                                                           \
	spades::SettingItemDescriptor name##_desc{__VA_ARGS__};                                        \
	static spades::Settings::ItemHandle name(#name, &name##_desc)

#define SPADES_SETTING(name) static spades::Settings::ItemHandle name(#name, nullptr)
}

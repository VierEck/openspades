/*
 This piece of Code was written by VierEck. and is based on
 Mile's Glitter (https://github.com/yusufcardinal/glitter) and OpenSpades.

 This file is part of 4 of Spades, a fork of OpenSpades.

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

#include <vector>
#include <Client/GameMap.h>
#include <Core/RefCountedObject.h>

namespace spades {
	class GameMap;

	class Glitter : public RefCountedObject {
		std::vector<short> glitArgs;

	public:
		Glitter();
		~Glitter();
			
		void GlitterAddArg(int pos, int arg) { 
			if (pos < 0)
				return;
			
			if (pos >= glitArgs.size())
				glitArgs.resize(pos + 1);
			glitArgs[pos] = arg;
		}
		void GlitterMap(const std::string &);
		int DoGlitter(spades::client::GameMap *map);
	};
}

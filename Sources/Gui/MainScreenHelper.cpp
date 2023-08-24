/*
 Copyright (c) 2013 yvt

 Portion of the code is based on Serverbrowser.cpp (Copyright (c) 2013 learn_more).

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

#include <algorithm>
#include <cctype>
#include <memory>

#include <curl/curl.h>
#include <json/json.h>

#include "Glitter.h"
#include "MainScreen.h"
#include "MainScreenHelper.h"
#include <Core/FileManager.h>
#include <Core/IStream.h>
#include <Core/Settings.h>
#include <Core/Thread.h>
#include <Core/ServerAddress.h>
#include <Gui/PackageUpdateManager.h>
#include <OpenSpades.h>

DEFINE_SPADES_SETTING(cl_serverListUrl, "http://services.buildandshoot.com/serverlist.json");

DEFINE_SPADES_SETTING(cg_demoFileDeleteRule, "2");
DEFINE_SPADES_SETTING(cg_demoFileDeleteMaxFiles, "20");
DEFINE_SPADES_SETTING(cg_demoFileDeleteMaxDays, "7");

namespace spades {
	namespace {
		struct CURLEasyDeleter {
			void operator()(CURL *ptr) const { curl_easy_cleanup(ptr); }
		};
	} // namespace

	class ServerItem {
		// NetClient::Connect
		std::string mName, mIp, mMap, mGameMode;
		std::string mCountry, mVersion;
		int mPing, mPlayers, mMaxPlayers;

		ServerItem(const std::string &name, const std::string &ip, const std::string &map,
		           const std::string &gameMode, const std::string &country,
		           const std::string &version, int ping, int players, int maxPlayers);

	public:
		static ServerItem *Create(Json::Value &val);
		static ServerItem *CreateDemoItem(std::string fileName);
		static ServerItem *MakeMapItem(std::string file_name, bool txtExtension);

		inline const std::string &GetName() const { return mName; }
		inline const std::string &GetAddress() const { return mIp; }
		inline const std::string &GetMapName() const { return mMap; }
		inline const std::string &GetGameMode() const { return mGameMode; }
		inline const std::string &GetCountryCode() const { return mCountry; }
		inline const std::string &GetVersion() const { return mVersion; }
		inline int GetPing() const { return mPing; }
		inline int GetNumPlayers() const { return mPlayers; }
		inline int GetMaxNumPlayers() const { return mMaxPlayers; }
	};

	ServerItem::ServerItem(const std::string &name, const std::string &ip, const std::string &map,
	                       const std::string &gameMode, const std::string &country,
	                       const std::string &version, int ping, int players, int maxPlayers)
	    : mName(name),
	      mIp(ip),
	      mMap(map),
	      mGameMode(gameMode),
	      mCountry(country),
	      mVersion(version),
	      mPing(ping),
	      mPlayers(players),
	      mMaxPlayers(maxPlayers) {}

	ServerItem *ServerItem::Create(Json::Value &val) {
		ServerItem *item = NULL;
		if (val.type() == Json::objectValue) {
			std::string name, ip, map, gameMode, country, version;
			int ping = 0, players = 0, maxPlayers = 0;

			name = val["name"].asString();
			ip = val["identifier"].asString();
			map = val["map"].asString();
			gameMode = val["game_mode"].asString();
			country = val["country"].asString();
			version = val["game_version"].asString();

			ping = val["latency"].asInt();
			players = val["players_current"].asInt();
			maxPlayers = val["players_max"].asInt();
			item =
			  new ServerItem(name, ip, map, gameMode, country, version, ping, players, maxPlayers);
		}
		return item;
	}

	ServerItem *ServerItem::CreateDemoItem(std::string fileName) {
		ServerItem *item = NULL;
		std::string name, ip, map, gameMode, country, version;
		int ping = 0, players = 0, maxPlayers = 1;

		name = fileName;
		ip = "aos://16777343:32887";
		gameMode = country = map = "";

		auto stream = FileManager::OpenForReading(("Demos/" + fileName).c_str());
		unsigned char ver;

		if (fileName.size() > 6 && fileName.substr(fileName.size() - 6, 6) == ".demoz") {
			map = "compressed data. assuming 0.75";
			version = "0.75";
		} else {
			if (stream->Read(&ver, sizeof(ver)) == sizeof(ver)) {
				if (ver != (unsigned char)aos_replayVersion::v1) {
					map = "invalid aos_replay";
				}

				if (stream->Read(&ver, sizeof(ver)) == sizeof(ver)) {
					switch (ver) {
						case (unsigned char)ProtocolVersion::v075:
							version = "0.75";
							break;
						case (unsigned char)ProtocolVersion::v076:
							version = "0.76";
							break;
						default: version = "invalid";
					}
				} else {
					version = "invalid";
				}
			} else {
				map = "invalid aos_replay";
			}
		}

		item = new ServerItem(name, ip, map, gameMode, country, version, ping, players, maxPlayers);
		
		return item;
	}

	ServerItem *ServerItem::MakeMapItem(std::string fileName, bool txtExtension) {
		ServerItem *item = NULL;
		std::string name, ip, map = "", gameMode = "", country = "", version = "";
		int ping = 0, players = 0, maxPlayers = 1;

		name = fileName;
		ip = "aos://16777343:32887";
		if (txtExtension) {
			map = fileName.substr(0, fileName.size() - 4);
			map += ".txt";
		}

		item = new ServerItem(name, ip, map, gameMode, country, version, ping, players, maxPlayers);
		return item;
	}

	namespace gui {
		constexpr auto FAVORITE_PATH = "/favorite_servers.json";

		class MainScreenHelper::ServerListQuery final : public Thread {
			Handle<MainScreenHelper> owner;
			std::string buffer;

			void ReturnResult(std::unique_ptr<MainScreenServerList> &&list) {
				owner->resultCell.store(std::move(list));
				owner = NULL; // release owner
			}

			void ProcessResponse() {
				Json::Reader reader;
				Json::Value root;
				auto resp = stmp::make_unique<MainScreenServerList>();

				if (reader.parse(buffer, root, false)) {
					for (Json::Value::iterator it = root.begin(); it != root.end(); ++it) {
						Json::Value &obj = *it;
						std::unique_ptr<ServerItem> srv{ServerItem::Create(obj)};
						if (srv) {
							resp->list.emplace_back(
							  new MainScreenServerItem(
							    srv.get(), owner->favorites.count(srv->GetAddress()) >= 1),
							  false);
						}
					}
				}

				ReturnResult(std::move(resp));
			}

			void GetDemoList() {
				std::unique_ptr<MainScreenServerList> resp{new MainScreenServerList()};
				std::vector<std::string> fileList = FileManager::EnumFiles("Demos/");

				std::deque<std::string> defaultFiles;
				for (auto &file : fileList) {
					if ((file.size() > 5 && file.substr(file.size() - 5, 5) == ".demo")
						|| (file.size() > 6 && file.substr(file.size() - 6, 6) == ".demoz")) {
						if (file.size() == 41 && file[4] == '-') {
							defaultFiles.push_back(file);
							continue;
						}

						std::unique_ptr<ServerItem> srv{ServerItem::CreateDemoItem(file)};
						if (srv)
							resp->list.emplace_back(new MainScreenServerItem(srv.get(), owner->favorites.count(srv->GetAddress()) >= 1), false);
					}
				}

				if (defaultFiles.size() <= 0) {
					ReturnResult(std::move(resp));
					return;
				}

				//renamed files r completely excluded from the auto delete process, not
				//like this method would work for them anyways.
				//maybe the user liked a particular demo, renamed it, and wants to keep it
				if ((int)cg_demoFileDeleteRule == 1) {
					//delete by maximum age
					time_t t;
					struct tm tm;
					::time(&t);
					t -= (int)cg_demoFileDeleteMaxDays * 86400;
					tm = *localtime(&t);
					char buf[256];
					sprintf(
						buf, "%04d-%02d-%02d_%02d-%02d-%02d", tm.tm_year + 1900, tm.tm_mon + 1,
						tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec
					);
					while (strncmp(buf, defaultFiles.front().c_str(), 19) > 0) {
						FileManager::RemoveFile(("Demos/" + defaultFiles.front()).c_str());
						defaultFiles.pop_front();
					}
				} else if ((int)cg_demoFileDeleteRule > 1) {
					//delete by maximum amount of demo files with "default" names starting with the oldest
					while (defaultFiles.size() > (int)cg_demoFileDeleteMaxFiles) {
						FileManager::RemoveFile(("Demos/" + defaultFiles.front()).c_str());
						defaultFiles.pop_front();
					}
				}
				//put "default" named files always at end of list
				//renamed files should remain on top, they prob have greater significance
				//to the user judging by the fact they were renamed in the first place.
				for (auto &file : defaultFiles) {
					std::unique_ptr<ServerItem> srv{ServerItem::CreateDemoItem(file)};

					if (srv)
						resp->list.emplace_back(new MainScreenServerItem(srv.get(), owner->favorites.count(srv->GetAddress()) >= 1),false);
				}

				ReturnResult(std::move(resp));
			}

			void GetMapList(bool canvas) {
				std::vector<std::string> FileNames;
				if (canvas) {
					FileNames = FileManager::EnumFiles("Maps/Canvas");
				} else {
					FileNames = FileManager::EnumFiles("MapEditor/Maps");
				}

				std::vector<std::string> txtFiles;
				std::unique_ptr<MainScreenServerList> resp{new MainScreenServerList()};
				for (std::string file : FileNames) {
					if (file.size() > 4 && file.substr(file.size() - 4, 4) == ".txt" && !canvas) {
						txtFiles.push_back(file);
						continue;
					}
					if (file.size() < 4 || file.substr(file.size() - 4, 4) != ".vxl")
						continue;

					bool txtExist = false;
					for (std::string txt : txtFiles) {
						if (txt.substr(0, txt.size() - 4) == file.substr(0, file.size() - 4)) {
							txtExist = true;
						}
					}

					std::unique_ptr<ServerItem> srv{ServerItem::MakeMapItem(file, txtExist)};

					if (srv) {
						resp->list.emplace_back(new MainScreenServerItem(srv.get(), owner->favorites.count(srv->GetAddress()) >= 1),false);
					}
				}
				ReturnResult(std::move(resp));
			}

		public:
			int Mode;
			bool Canvas;
			ServerListQuery(MainScreenHelper *owner, int mode, bool canvas) : owner{owner} {
				Mode = mode;
				Canvas = canvas;
			}

			void Run() override {
				try {
					if (Mode == isDemo) {
						GetDemoList();
						return;
					} else if (Mode == isMap) {
						GetMapList(Canvas);
						return;
					}
					std::unique_ptr<CURL, CURLEasyDeleter> cHandle{curl_easy_init()};
					if (cHandle) {
						size_t (*curlWriteCallback)(void *, size_t, size_t, ServerListQuery *) =
						  [](void *ptr, size_t size, size_t nmemb,
						     ServerListQuery *self) -> size_t {
							size_t numBytes = size * nmemb;
							self->buffer.append(reinterpret_cast<char *>(ptr), numBytes);
							return numBytes;
						};
						curl_easy_setopt(cHandle.get(), CURLOPT_USERAGENT, OpenSpades_VER_STR);
						curl_easy_setopt(cHandle.get(), CURLOPT_URL, cl_serverListUrl.CString());
						curl_easy_setopt(cHandle.get(), CURLOPT_WRITEFUNCTION, curlWriteCallback);
						curl_easy_setopt(cHandle.get(), CURLOPT_WRITEDATA, this);
						curl_easy_setopt(cHandle.get(), CURLOPT_LOW_SPEED_TIME, 30l);
						curl_easy_setopt(cHandle.get(), CURLOPT_LOW_SPEED_LIMIT, 15l);
						curl_easy_setopt(cHandle.get(), CURLOPT_CONNECTTIMEOUT, 30l);
						auto reqret = curl_easy_perform(cHandle.get());
						if (CURLE_OK == reqret) {
							ProcessResponse();
						} else {
							SPRaise("HTTP request error (%s).", curl_easy_strerror(reqret));
						}
					} else {
						SPRaise("Failed to create cURL object.");
					}
				} catch (std::exception &ex) {
					auto lst = stmp::make_unique<MainScreenServerList>();
					lst->message = ex.what();
					ReturnResult(std::move(lst));
				} catch (...) {
					auto lst = stmp::make_unique<MainScreenServerList>();
					lst->message = "Unknown error.";
					ReturnResult(std::move(lst));
				}
			}
		};

		MainScreenHelper::MainScreenHelper(MainScreen *scr) : mainScreen(scr), query(NULL) {
			SPADES_MARK_FUNCTION();
			LoadFavorites();
			glitter = stmp::make_unique<Glitter>();
		}

		MainScreenHelper::~MainScreenHelper() {
			SPADES_MARK_FUNCTION();
			if (query) {
				query->MarkForAutoDeletion();
			}
			glitter.reset();
		}

		void MainScreenHelper::MainScreenDestroyed() {
			SPADES_MARK_FUNCTION();
			SaveFavorites();
			mainScreen = NULL;
		}

		void MainScreenHelper::LoadFavorites() {
			SPADES_MARK_FUNCTION();
			Json::Reader reader;

			if (spades::FileManager::FileExists(FAVORITE_PATH)) {
				std::string favs = spades::FileManager::ReadAllBytes(FAVORITE_PATH);
				Json::Value favorite_root;
				if (reader.parse(favs, favorite_root, false)) {
					for (const auto &fav : favorite_root) {
						if (fav.isString())
							favorites.insert(fav.asString());
					}
				}
			}
		}

		void MainScreenHelper::SaveFavorites() {
			SPADES_MARK_FUNCTION();
			Json::StyledWriter writer;
			Json::Value v(Json::ValueType::arrayValue);

			auto fobj = spades::FileManager::OpenForWriting(FAVORITE_PATH);
			for (const auto &favorite : favorites) {
				v.append(Json::Value(favorite));
			}

			fobj->Write(writer.write(v));
		}

		void MainScreenHelper::SetServerFavorite(std::string ip, bool favorite) {
			SPADES_MARK_FUNCTION();
			if (favorite) {
				favorites.insert(ip);
			} else {
				favorites.erase(ip);
			}

			if (result && !result->list.empty()) {
				auto entry = std::find_if(result->list.begin(), result->list.end(),
				                          [&](const Handle<MainScreenServerItem> &entry) {
					                          return entry->GetAddress() == ip;
				                          });
				if (entry != result->list.end()) {
					(*entry)->SetFavorite(favorite);
				}
			}
		}

		bool MainScreenHelper::PollServerListState() {
			SPADES_MARK_FUNCTION();

			// Do we have a new result?
			auto newResult = resultCell.take();
			if (newResult) {
				result = std::move(newResult);
				query->MarkForAutoDeletion();
				query = NULL;
				return true;
			}

			return false;
		}

		void MainScreenHelper::StartQuery(int mode, bool canvas) {
			if (query) {
				// There already is an ongoing query
				return;
			}

			query = new ServerListQuery(this, mode, canvas);
			query->Start();
		}

#include "Credits.inc" // C++11 raw string literal makes some tools (ex. xgettext, Xcode) misbehave

		std::string MainScreenHelper::GetCredits() {
			std::string html = credits;
			html = Replace(html, "${PACKAGE_STRING}", PACKAGE_STRING);
			return html;
		}

		CScriptArray *MainScreenHelper::GetServerList(std::string sortKey, bool descending) {
			if (result == NULL) {
				return NULL;
			}

			using Item = const Handle<MainScreenServerItem> &;
			std::vector<Handle<MainScreenServerItem>> &lst = result->list;
			if (lst.empty())
				return NULL;

			auto compareFavorite = [&](Item x, Item y) -> stmp::optional<bool> {
				if (x->IsFavorite() && !y->IsFavorite()) {
					return true;
				} else if (!x->IsFavorite() && y->IsFavorite()) {
					return false;
				} else {
					return {};
				}
			};

			auto compareInts = [&](int x, int y) -> bool {
				if (descending) {
					return y < x;
				} else {
					return x < y;
				}
			};

			auto compareStrings = [&](const std::string &x0, const std::string &y0) -> bool {
				const auto &x = descending ? y0 : x0;
				const auto &y = descending ? x0 : y0;
				std::string::size_type t = 0;
				for (t = 0; t < x.length() && t < y.length(); ++t) {
					int xx = std::tolower(x[t]);
					int yy = std::tolower(y[t]);
					if (xx != yy) {
						return xx < yy;
					}
				}
				if (x.length() == y.length()) {
					return false;
				}
				return x.length() < y.length();
			};

			if (!sortKey.empty()) {
				if (sortKey == "Ping") {
					std::stable_sort(lst.begin(), lst.end(), [&](Item x, Item y) {
						return compareFavorite(x, y).value_or(
						  compareInts(x->GetPing(), y->GetPing()));
					});
				} else if (sortKey == "NumPlayers") {
					std::stable_sort(lst.begin(), lst.end(), [&](Item x, Item y) {
						return compareFavorite(x, y).value_or(
						  compareInts(x->GetNumPlayers(), y->GetNumPlayers()));
					});
				} else if (sortKey == "Name") {
					std::stable_sort(lst.begin(), lst.end(), [&](Item x, Item y) {
						return compareFavorite(x, y).value_or(
						  compareStrings(x->GetName(), y->GetName()));
					});
				} else if (sortKey == "MapName") {
					std::stable_sort(lst.begin(), lst.end(), [&](Item x, Item y) {
						return compareFavorite(x, y).value_or(
						  compareStrings(x->GetMapName(), y->GetMapName()));
					});
				} else if (sortKey == "GameMode") {
					std::stable_sort(lst.begin(), lst.end(), [&](Item x, Item y) {
						return compareFavorite(x, y).value_or(
						  compareStrings(x->GetGameMode(), y->GetGameMode()));
					});
				} else if (sortKey == "Protocol") {
					std::stable_sort(lst.begin(), lst.end(), [&](Item x, Item y) {
						return compareFavorite(x, y).value_or(
						  compareStrings(x->GetProtocol(), y->GetProtocol()));
					});
				} else if (sortKey == "Country") {
					std::stable_sort(lst.begin(), lst.end(), [&](Item x, Item y) {
						return compareFavorite(x, y).value_or(
						  compareStrings(x->GetCountry(), y->GetCountry()));
					});
				} else {
					SPRaise("Invalid sort key: %s", sortKey.c_str());
				}
			}

			asIScriptEngine *eng = ScriptManager::GetInstance()->GetEngine();
			asITypeInfo *t = eng->GetTypeInfoByDecl("array<spades::MainScreenServerItem@>");
			SPAssert(t != NULL);
			CScriptArray *arr = CScriptArray::Create(t, static_cast<asUINT>(lst.size()));
			for (size_t i = 0; i < lst.size(); i++) {
				arr->SetValue((asUINT)i, &(lst[i]));
			}
			return arr;
		}

		std::string MainScreenHelper::ConnectServer(
			std::string hostname, int protocolVersion, int mode, std::string map_demo, std::string canvasFile
		) {
			if (mainScreen == NULL) {
				return "mainScreen == NULL";
			}
			return mainScreen->Connect(
				ServerAddress(hostname, protocolVersion == 3 ? ProtocolVersion::v075 : ProtocolVersion::v076),
				mode, map_demo, canvasFile
			);
		}

		std::string MainScreenHelper::GetServerListQueryMessage() {
			if (result == NULL)
				return "";
			return result->message;
		}

		std::string MainScreenHelper::GetPendingErrorMessage() {
			std::string s = errorMessage;
			errorMessage.clear();
			return s;
		}

		void MainScreenHelper::RemoveFile(const std::string &fileName) {
			SPADES_MARK_FUNCTION();
			FileManager::RemoveFile(fileName.c_str());
		}

		void MainScreenHelper::RenameFile(const std::string &oldName, const std::string &newName) {
			SPADES_MARK_FUNCTION();
			FileManager::RenameFile(oldName.c_str(), newName.c_str());
		}

		void MainScreenHelper::MainScreenCopyFile(const std::string &oldName) {
			SPADES_MARK_FUNCTION();
			if (!FileManager::FileExists(oldName.c_str())) {
				SPLog("Copying file failed. file not found: %s", oldName.c_str());
				return;
			}

			std::string dir;
			int lastPos = oldName.size() - 1;
			for (int i = lastPos; i > 0; i--) {
				if (oldName[i] == '/') {
					dir = oldName.substr(0, i + 1);
					break;
				}
				if (i == 0) {
					SPLog("Copying file failed. filename string does not contain directory: %s", oldName.c_str());
					return;
				}
			}
			std::vector<std::string> fileNames = FileManager::EnumFiles(dir.c_str());

			while (lastPos-- > 0) {
				if (lastPos == 0) {
					SPLog("Copying file failed. file does not contain extension: %s", oldName.c_str());
					return;
				}
				if (oldName[lastPos] == '.')
					break;
			}
			std::string extension = oldName.substr(lastPos, oldName.size() - lastPos);

			std::string newName = oldName.substr(0, lastPos) + " - Copy" + extension;
			int count = 1;
			char bufCopy[16];
			while (FileManager::FileExists(newName.c_str())) {
				sprintf(bufCopy, " - Copy (%d)", count++);
				newName = oldName.substr(0, lastPos) + bufCopy + extension;
			}

			auto oldStream = FileManager::OpenForReading(oldName.c_str());
			auto newStream = FileManager::OpenForWriting(newName.c_str());
			newStream->Write(oldStream->ReadAllBytes());
		}

		PackageUpdateManager &MainScreenHelper::GetPackageUpdateManager() {
			return PackageUpdateManager::GetInstance();
		}

		MainScreenServerList::~MainScreenServerList() {}

		MainScreenServerItem::MainScreenServerItem(ServerItem *item, bool favorite) {
			SPADES_MARK_FUNCTION();
			name = item->GetName();
			address = item->GetAddress();
			mapName = item->GetMapName();
			gameMode = item->GetGameMode();
			country = item->GetCountryCode();
			protocol = item->GetVersion();
			ping = item->GetPing();
			numPlayers = item->GetNumPlayers();
			maxPlayers = item->GetMaxNumPlayers();
			this->favorite = favorite;
		}

		MainScreenServerItem::~MainScreenServerItem() { SPADES_MARK_FUNCTION(); }

		void MainScreenHelper::GlitterMap(const std::string &fileName) {
			SPADES_MARK_FUNCTION();
			glitter->GlitterMap(fileName);
		}
		void MainScreenHelper::GlitterAddArg(int i) {
			SPADES_MARK_FUNCTION();
			glitter->GlitterAddArg(i);
		}
	} // namespace gui
} // namespace spades

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

#include "CreateProfileScreen.as"
#include "ServerList.as"
#include "../MapEditor/Glitter.as"
#include "../MapEditor/HeightMap.as"

namespace spades {

	class RefreshButton : spades::ui::SimpleButton {
		RefreshButton(spades::ui::UIManager @manager) { super(manager); }
		void Render() {
			SimpleButton::Render();

			Renderer @renderer = Manager.Renderer;
			Vector2 pos = ScreenPosition;
			Vector2 size = Size;
			Image @img = renderer.RegisterImage("Gfx/UI/Refresh.png");
			renderer.DrawImage(img, pos + (size - Vector2(16.f, 16.f)) * 0.5f);
		}
	}

	class ProtocolButton : spades::ui::SimpleButton {
		ProtocolButton(spades::ui::UIManager @manager) {
			super(manager);
			Toggle = true;
		}
	}

	class MainScreenMainMenu : spades::ui::UIElement {

		MainScreenUI @ui;
		MainScreenHelper @helper;
		spades::ui::Field @addressField;

		spades::ui::Button @protocol3Button;
		spades::ui::Button @protocol4Button;

		spades::ui::Button @filterProtocol3Button;
		spades::ui::Button @filterProtocol4Button;
		spades::ui::Button @filterEmptyButton;
		spades::ui::Button @filterFullButton;
		spades::ui::Field @filterField;

		spades::ui::ListView @serverList;
		MainScreenServerListLoadingView @loadingView;
		MainScreenServerListErrorView @errorView;
		bool loading = false, loaded = false, canvasList = false;
		string MapFile = "";
		MainScreenServerItem@[]@ savedlist = array<spades::MainScreenServerItem@>();
		int savedlistIdx = 0;
		
		int mode = 0;
		bool IsServer { 
			get { 
				return mode == 0; 
			} 
			set { 
				if (value)
					ChangeList(0);
			}
		}
		bool IsDemo { 
			get { 
				return mode == 1; 
			} 
			set {
				if (value)
					ChangeList(1);
			}
		}
		bool IsMap { 
			get { 
				return mode == 2; 
			}
			set {
				if (value)
					ChangeList(2);
			}
		}

		private ConfigItem cg_protocolVersion("cg_protocolVersion", "3");
		private ConfigItem cg_lastQuickConnectHost("cg_lastQuickConnectHost", "127.0.0.1");
		private ConfigItem cg_serverlistSort("cg_serverlistSort", "16385");

		MainScreenMainMenu(MainScreenUI @ui) {
			super(ui.manager);
			@this.ui = ui;
			@this.helper = ui.helper;

			float contentsWidth = 785.f;
			float contentsLeft = (Manager.Renderer.ScreenWidth - contentsWidth) * 0.5f;
			float footerPos = Manager.Renderer.ScreenHeight - 50.f;
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("MainScreen", "Servers");
				button.Bounds = AABB2(contentsLeft, 165, 60.f, 35.f);
				button.Enable = true;
				@button.Activated = spades::ui::EventHandler(this.OnServerList);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("MainScreen", "Demos");
				button.Bounds = AABB2(contentsLeft + 63.f, 165, 60.f, 35.f);
				@button.Activated = spades::ui::EventHandler(this.OnDemoList);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("MainScreen", "Maps");
				button.Bounds = AABB2(contentsLeft + 126.f, 165, 60.f, 35.f);
				@button.Activated = spades::ui::EventHandler(this.OnMapList);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("MainScreen", "Connect");
				button.Bounds = AABB2(contentsLeft + contentsWidth - 150.f, 200.f, 150.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnConnectPressed);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("MainScreen", "Connect Local");
				button.Bounds = AABB2(contentsLeft + contentsWidth - 300.f, 200.f, 150.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnConnectLocalPressed);
				AddChild(button);
			}
			{
				@addressField = spades::ui::Field(Manager);
				addressField.Bounds = AABB2(contentsLeft, 200, contentsWidth - 390.f, 30.f);
				addressField.Placeholder = _Tr("MainScreen", "Quick Connect");
				addressField.Text = cg_lastQuickConnectHost.StringValue;
				@addressField.Changed = spades::ui::EventHandler(this.OnAddressChanged);
				AddChild(addressField);
			}
			{
				@protocol3Button = ProtocolButton(Manager);
				protocol3Button.Bounds =
					AABB2(contentsLeft + contentsWidth - 390.f + 6.f, 200, 40.f, 30.f);
				protocol3Button.Caption = _Tr("MainScreen", "0.75");
				@protocol3Button.Activated = spades::ui::EventHandler(this.OnProtocol3Pressed);
				protocol3Button.Toggle = true;
				protocol3Button.Toggled = cg_protocolVersion.IntValue == 3;
				AddChild(protocol3Button);
			}
			{
				@protocol4Button = ProtocolButton(Manager);
				protocol4Button.Bounds =
					AABB2(contentsLeft + contentsWidth - 350.f + 6.f, 200, 40.f, 30.f);
				protocol4Button.Caption = _Tr("MainScreen", "0.76");
				@protocol4Button.Activated = spades::ui::EventHandler(this.OnProtocol4Pressed);
				protocol4Button.Toggle = true;
				protocol4Button.Toggled = cg_protocolVersion.IntValue == 4;
				AddChild(protocol4Button);
			}
			{
				spades::ui::QuitButton button(Manager);
				button.Caption = _Tr("MainScreen", "Quit");
				button.Bounds = AABB2(contentsLeft + contentsWidth - 100.f, footerPos, 100.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnQuitPressed);
				AddChild(button);
			}
			{
				spades::ui::OpenButton button(Manager);
				button.Caption = _Tr("MainScreen", "Credits");
				button.Bounds = AABB2(contentsLeft + contentsWidth - 202.f, footerPos, 100.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnCreditsPressed);
				AddChild(button);
			}
			{
				spades::ui::OpenButton button(Manager);
				button.Caption = _Tr("MainScreen", "Setup");
				button.Bounds = AABB2(contentsLeft + contentsWidth - 304.f, footerPos, 100.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnSetupPressed);
				AddChild(button);
			}
			{
				RefreshButton button(Manager);
				button.Bounds = AABB2(contentsLeft + contentsWidth - 364.f, footerPos, 30.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnRefreshServerListPressed);
				AddChild(button);
			}
			{
				spades::ui::Label label(Manager);
				label.Text = _Tr("MainScreen", "Filter");
				label.Bounds = AABB2(contentsLeft, footerPos, 50.f, 30.f);
				label.Alignment = Vector2(0.f, 0.5f);
				AddChild(label);
			}
			{
				@filterProtocol3Button = ProtocolButton(Manager);
				filterProtocol3Button.Bounds = AABB2(contentsLeft + 50.f, footerPos, 40.f, 30.f);
				filterProtocol3Button.Caption = _Tr("MainScreen", "0.75");
				@filterProtocol3Button.Activated
				= spades::ui::EventHandler(this.OnFilterProtocol3Pressed);
				filterProtocol3Button.Toggle = true;
				AddChild(filterProtocol3Button);
			}
			{
				@filterProtocol4Button = ProtocolButton(Manager);
				filterProtocol4Button.Bounds = AABB2(contentsLeft + 90.f, footerPos, 40.f, 30.f);
				filterProtocol4Button.Caption = _Tr("MainScreen", "0.76");
				@filterProtocol4Button.Activated
				= spades::ui::EventHandler(this.OnFilterProtocol4Pressed);
				filterProtocol4Button.Toggle = true;
				AddChild(filterProtocol4Button);
			}
			{
				@filterEmptyButton = ProtocolButton(Manager);
				filterEmptyButton.Bounds = AABB2(contentsLeft + 135.f, footerPos, 50.f, 30.f);
				filterEmptyButton.Caption = _Tr("MainScreen", "Empty");
				@filterEmptyButton.Activated = spades::ui::EventHandler(this.OnFilterEmptyPressed);
				filterEmptyButton.Toggle = true;
				AddChild(filterEmptyButton);
			}
			{
				@filterFullButton = ProtocolButton(Manager);
				filterFullButton.Bounds = AABB2(contentsLeft + 185.f, footerPos, 70.f, 30.f);
				filterFullButton.Caption = _Tr("MainScreen", "Not Full");
				@filterFullButton.Activated = spades::ui::EventHandler(this.OnFilterFullPressed);
				filterFullButton.Toggle = true;
				AddChild(filterFullButton);
			}
			{
				@filterField = spades::ui::Field(Manager);
				filterField.Bounds = AABB2(contentsLeft + 260.f, footerPos, 120.f, 30.f);
				filterField.Placeholder = _Tr("MainScreen", "Filter");
				@filterField.Changed = spades::ui::EventHandler(this.OnFilterTextChanged);
				AddChild(filterField);
			}
			{
				@serverList = spades::ui::ListView(Manager);
				serverList.Bounds = AABB2(contentsLeft, 270.f, contentsWidth, footerPos - 280.f);
				AddChild(serverList);
			}
			{
				ServerListHeader header(Manager);
				header.Bounds = AABB2(contentsLeft + 2.f, 240.f, 375.f - 2.f, 30.f);
				header.Text = _Tr("MainScreen", "ServerName");
				@header.Activated = spades::ui::EventHandler(this.SortServerListByName);
				AddChild(header);
			}
			{
				ServerListHeader header(Manager);
				header.Bounds = AABB2(contentsLeft + 375.f, 240.f, 55.f, 30.f);
				header.Text = _Tr("MainScreen", "Players");
				@header.Activated = spades::ui::EventHandler(this.SortServerListByNumPlayers);
				AddChild(header);
			}
			{
				ServerListHeader header(Manager);
				header.Bounds = AABB2(contentsLeft + 430.f, 240.f, 150.f, 30.f);
				header.Text = _Tr("MainScreen", "MapName");
				@header.Activated = spades::ui::EventHandler(this.SortServerListByMapName);
				AddChild(header);
			}
			{
				ServerListHeader header(Manager);
				header.Bounds = AABB2(contentsLeft + 580.f, 240.f, 85.f, 30.f);
				header.Text = _Tr("MainScreen", "GameMode");
				@header.Activated = spades::ui::EventHandler(this.SortServerListByGameMode);
				AddChild(header);
			}
			{
				ServerListHeader header(Manager);
				header.Bounds = AABB2(contentsLeft + 665.f, 240.f, 35.f, 30.f);
				header.Text = _Tr("MainScreen", "Ver.");
				@header.Activated = spades::ui::EventHandler(this.SortServerListByProtocol);
				AddChild(header);
			}
			{
				ServerListHeader header(Manager);
				header.Bounds = AABB2(contentsLeft + 700.f, 240.f, 35.f, 30.f);
				header.Text = _Tr("MainScreen", "Loc.");
				@header.Activated = spades::ui::EventHandler(this.SortServerListByCountry);
				AddChild(header);
			}
			{
				ServerListHeader header(Manager);
				header.Bounds = AABB2(contentsLeft + 735.f, 240.f, 35.f, 30.f);
				header.Text = _Tr("MainScreen", "Ping");
				@header.Activated = spades::ui::EventHandler(this.SortServerListByPing);
				AddChild(header);
			}
			{
				@loadingView = MainScreenServerListLoadingView(Manager);
				loadingView.Bounds = AABB2(contentsLeft, 240.f, contentsWidth, 100.f);
				loadingView.Visible = false;
				AddChild(loadingView);
			}
			{
				@errorView = MainScreenServerListErrorView(Manager);
				errorView.Bounds = AABB2(contentsLeft, 240.f, contentsWidth, 100.f);
				errorView.Visible = false;
				AddChild(errorView);
			}
			LoadServerList();
		}

		void LoadServerList() {
			if (loading) {
				return;
			}
			loaded = false;
			loading = true;
			@serverList.Model = spades::ui::ListViewModel(); // empty
			errorView.Visible = false;
			loadingView.Visible = true;
			helper.StartQuery(mode, canvasList);
			canvasList = false;
		}

		private void ServerListItemActivated(ServerListModel @sender, MainScreenServerItem @item) {
			ServerListItemActivatedPass(item);
		}

		private void ServerListItemActivatedPass(MainScreenServerItem @item) {
			if (IsServer) {
				addressField.Text = item.Address;
				cg_lastQuickConnectHost = addressField.Text;
			} else {
				addressField.Text = item.Name;
			}
			if (item.Protocol == "0.75") {
				SetProtocolVersion(3);
			} else if (item.Protocol == "0.76") {
				SetProtocolVersion(4);
			}
			addressField.SelectAll();
		}

		private void ServerListItemDoubleClicked(ServerListModel @sender, MainScreenServerItem @item) {
			ServerListItemActivated(sender, item);

			// Double-click to connect
			Connect();
		}

		private void ServerListItemRightClicked(ServerListModel @sender, MainScreenServerItem @item) {
			if (!IsServer) {
				RightClickContextMenuOpen(item);
				return;
			}
			helper.SetServerFavorite(item.Address, !item.Favorite);
			UpdateServerList();
		}
		
		private void RightClickContextMenuOpen(MainScreenServerItem @item) {
			spades::MainMenuItemContext::MainMenuItemContextUI mmic(
				this, Manager.MouseCursorPosition, item.Name
			);
			mmic.Run();
		}
		
		private void SortServerListByPing(spades::ui::UIElement @sender) { SortServerList(0); }
		private void SortServerListByNumPlayers(spades::ui::UIElement @sender) {
			SortServerList(1);
		}
		private void SortServerListByName(spades::ui::UIElement @sender) { SortServerList(2); }
		private void SortServerListByMapName(spades::ui::UIElement @sender) { SortServerList(3); }
		private void SortServerListByGameMode(spades::ui::UIElement @sender) { SortServerList(4); }
		private void SortServerListByProtocol(spades::ui::UIElement @sender) { SortServerList(5); }
		private void SortServerListByCountry(spades::ui::UIElement @sender) { SortServerList(6); }

		private void SortServerList(int keyId) {
			if (IsServer) {
				return;
			}
			int sort = cg_serverlistSort.IntValue;
			if (int(sort & 0xfff) == keyId) {
				sort ^= int(0x4000);
			} else {
				sort = keyId;
			}
			cg_serverlistSort = sort;
			UpdateServerList();
		}

		private void UpdateServerList() {
			string key = "";
			switch (cg_serverlistSort.IntValue & 0xfff) {
				case 0: key = "Ping"; break;
				case 1: key = "NumPlayers"; break;
				case 2: key = "Name"; break;
				case 3: key = "MapName"; break;
				case 4: key = "GameMode"; break;
				case 5: key = "Protocol"; break;
				case 6: key = "Country"; break;
			}
			if (IsServer) {
				key = "Name";
			}
			MainScreenServerItem @[] @list =
				helper.GetServerList(key, (cg_serverlistSort.IntValue & 0x4000) != 0);
			if ((list is null)or(loading)) {
				@serverList.Model = spades::ui::ListViewModel(); // empty
				return;
			}

			// filter the server list
			bool filterProtocol3 = filterProtocol3Button.Toggled;
			bool filterProtocol4 = filterProtocol4Button.Toggled;
			bool filterEmpty = filterEmptyButton.Toggled;
			bool filterFull = filterFullButton.Toggled;
			string filterText = filterField.Text;
			savedlist.resize(0);
			for (int i = 0, count = list.length; i < count; i++) {
				MainScreenServerItem @item = list[i];
				if (!IsServer) {
					if (filterProtocol3 and(item.Protocol != "0.75")) {
						continue;
					}
					if (filterProtocol4 and(item.Protocol != "0.76")) {
						continue;
					}
					if (filterEmpty and(item.NumPlayers > 0)) {
						continue;
					}
					if (filterFull and(item.NumPlayers >= item.MaxPlayers)) {
						continue;
					}
				}
				if (filterText.length > 0) {
					if (not(StringContainsCaseInsensitive(item.Name, filterText)
								or StringContainsCaseInsensitive(item.MapName, filterText)
									or StringContainsCaseInsensitive(item.GameMode, filterText))) {
						continue;
					}
				}
				savedlist.insertLast(item);
			}

			ServerListModel model(Manager, savedlist);
			@serverList.Model = model;
			@model.ItemActivated = ServerListItemEventHandler(this.ServerListItemActivated);
			@model.ItemDoubleClicked = ServerListItemEventHandler(this.ServerListItemDoubleClicked);
			@model.ItemRightClicked = ServerListItemEventHandler(this.ServerListItemRightClicked);
			serverList.ScrollToTop();
		}

		private void CheckServerList() {
			if (helper.PollServerListState()) {
				MainScreenServerItem @[] @list = helper.GetServerList("", false);
				if (list is null or list.length == 0) {
					// failed.
					// FIXME: show error message?
					loaded = false;
					loading = false;
					errorView.Visible = true;
					loadingView.Visible = false;
					@serverList.Model = spades::ui::ListViewModel(); // empty
					return;
				}
				loading = false;
				loaded = true;
				errorView.Visible = false;
				loadingView.Visible = false;
				UpdateServerList();
			}
		}

		private void OnAddressChanged(spades::ui::UIElement @sender) {
			if (IsServer) {
				return;
			}
			cg_lastQuickConnectHost = addressField.Text;
		}

		private void SetProtocolVersion(int ver) {
			protocol3Button.Toggled = (ver == 3);
			protocol4Button.Toggled = (ver == 4);
			cg_protocolVersion = ver;
		}

		private void OnProtocol3Pressed(spades::ui::UIElement @sender) { SetProtocolVersion(3); }
		private void OnProtocol4Pressed(spades::ui::UIElement @sender) { SetProtocolVersion(4); }

		private void OnFilterProtocol3Pressed(spades::ui::UIElement @sender) {
			filterProtocol4Button.Toggled = false;
			UpdateServerList();
		}
		private void OnFilterProtocol4Pressed(spades::ui::UIElement @sender) {
			filterProtocol3Button.Toggled = false;
			UpdateServerList();
		}
		private void OnFilterFullPressed(spades::ui::UIElement @sender) {
			filterEmptyButton.Toggled = false;
			UpdateServerList();
		}
		private void OnFilterEmptyPressed(spades::ui::UIElement @sender) {
			filterFullButton.Toggled = false;
			UpdateServerList();
		}
		private void OnFilterTextChanged(spades::ui::UIElement @sender) { UpdateServerList(); }

		private void OnRefreshServerListPressed(spades::ui::UIElement @sender) { LoadServerList(); }
		private void OnQuitPressed(spades::ui::UIElement @sender) { ui.shouldExit = true; }
		private void OnCreditsPressed(spades::ui::UIElement @sender) {
			AlertScreen al(this, ui.helper.Credits,
						   Min(500.f, Manager.Renderer.ScreenHeight - 100.f));
			al.Run();
		}
		private void OnSetupPressed(spades::ui::UIElement @sender) {
			PreferenceView al(this, PreferenceViewOptions(), ui.fontManager);
			al.Run();
		}

		private void Connect() {
			if (addressField.Text == "") {
				return;
			}
			if (IsServer) {
				ConnectServer();
			} else if (IsDemo) {
				ConnectDemo();
			} else if (IsMap) {
				ConnectMap();
			}
		}

		private void ConnectServer() {
			string msg = helper.ConnectServer(addressField.Text, cg_protocolVersion.IntValue, 0, "", "");
			if (msg.length > 0) {
				// failde to initialize client.
				AlertScreen al(this, msg);
				al.Run();
			}
		}
		private void ConnectDemo() {
			string DemoFile = ""; 
			string FieldText = addressField.Text;
			bool Found = false; 
			for(int i = 0, count = savedlist.length; i < count; i++) {
				MainScreenServerItem@ item = savedlist[i];
				if (item.Protocol != "0.75" and item.Protocol != "0.76" or item.MapName == "invalid aos_replay") {
					continue;
				}
				if (item.Name == addressField.Text) {
					Found = true;
					break;
				}
			}
			if (!Found) {
				return;
			}
			DemoFile = "Demos/" + addressField.Text;
			FieldText = "aos://16777343:32887";
			string msg = helper.ConnectServer(FieldText, cg_protocolVersion.IntValue, 1, DemoFile, "");
			if (msg.length > 0) {
				// failde to initialize client.
				AlertScreen al(this, msg);
				al.Run();
			}
		}
		private void ConnectMap() {
			string Canvas = "";
			string FieldText = addressField.Text;
			bool Found = false; 
			for(int i = 0, count = savedlist.length; i < count; i++) {
				MainScreenServerItem@ item = savedlist[i];
				if (item.Name == addressField.Text) {
					Found = true;
					break;
				}
			}
			if (!Found) {
				if (!canvasList) {
					if (loading) {
						return;
					}
					loaded = false;
					loading = true;
					@serverList.Model = spades::ui::ListViewModel(); // empty
					errorView.Visible = false;
					loadingView.Visible = true;
					canvasList = true;
					helper.StartQuery(mode, canvasList);
					MapFile = "MapEditor/Maps/" + addressField.Text;
					if (MapFile.findFirst(".vxl") < 0) {
						MapFile += ".vxl";
					}
					return;
				}
				return;
				} else {
				if (canvasList) {
					Canvas = "Maps/Canvas/" + addressField.Text;
				} else {
					MapFile = "MapEditor/Maps/" + addressField.Text;
					Canvas = "";
				}
				FieldText = "aos://16777343:32887";
			}
			string msg = helper.ConnectServer(FieldText, cg_protocolVersion.IntValue, 2, MapFile, Canvas);
			if (msg.length > 0) {
				// failde to initialize client.
				AlertScreen al(this, msg);
				al.Run();
			}
		}

		private void OnConnectPressed(spades::ui::UIElement @sender) { Connect(); }
		private void OnConnectLocalPressed(spades::ui::UIElement @sender) {
			string msg = helper.ConnectServer("127.0.0.1", cg_protocolVersion.IntValue, 0, "", "");
			if (msg.length > 0) {
				// failde to initialize client.
				AlertScreen al(this, msg);
				al.Run();
			}
		}

		private void OnServerList(spades::ui::UIElement @sender) { IsServer = true; }
		private void OnDemoList(spades::ui::UIElement @sender) { IsDemo = true; }
		private void OnMapList(spades::ui::UIElement @sender) { IsMap = true; }

		private void ChangeList(int whichMode) {
			mode = whichMode;
			canvasList = false;
			if (!IsServer) {
				addressField.Text = "";
			} else {
				addressField.Text = cg_lastQuickConnectHost.StringValue;
			}
			LoadServerList();
		}

		void HotKey(string key) {
			if (IsEnabled and key == "Enter") {
				Connect();
			} else if (IsEnabled and key == "Escape") {
				ui.shouldExit = true;
			} else if (IsEnabled and key == "S" and Manager.IsControlPressed) {
				IsServer = true;
			} else if (IsEnabled and key == "D" and Manager.IsControlPressed) {
				IsDemo = true;
			} else if (IsEnabled and key == "M" and Manager.IsControlPressed) {
				IsMap = true;
			} else if (IsEnabled and key == "Down") {
				if (savedlistIdx >= int(savedlist.length) - 1 and int(savedlist.length) > 0) {
					UIElement::HotKey(key);
					return;
				}
				savedlistIdx++;
				ServerListItemActivatedPass(savedlist[savedlistIdx]);
			} else if (IsEnabled and key == "Up") {
				if (savedlistIdx <= 0 and int(savedlist.length) > 0) {
					if (savedlist.length > 0) {
						ServerListItemActivatedPass(savedlist[0]);
					}
					UIElement::HotKey(key);
					return;
				}
				savedlistIdx--;
				ServerListItemActivatedPass(savedlist[savedlistIdx]);
			} else {
				UIElement::HotKey(key);
			}
		}

		void Render() {
			CheckServerList();
			UIElement::Render();

			// check for client error message.
			if (IsEnabled) {
				string msg = helper.GetPendingErrorMessage();
				if (msg.length > 0) {
					// try to maek the "disconnected" message more friendly.
					if (msg.findFirst("Disconnected:") >= 0) {
						int ind1 = msg.findFirst("Disconnected:");
						int ind2 = msg.findFirst("\n", ind1);
						if (ind2 < 0)
							ind2 = msg.length;
						ind1 += "Disconnected:".length;
						msg = msg.substr(ind1, ind2 - ind1);
						msg = _Tr(
							"MainScreen",
							"You were disconnected from the server because of the following reason:\n\n{0}",
							msg);
					}
					if (msg.findFirst("Demo Replay Ended:") >= 0) {
						int ind1 = msg.findFirst("Demo Replay Ended:");
						int ind2 = msg.findFirst("\n", ind1);
						if (ind2 < 0)
							ind2 = msg.length;
						ind1 += "Demo Replay Ended:".length;
						msg = msg.substr(ind1, ind2 - ind1);
						msg = _Tr(
							"MainScreen",
							"Demo Replay Ended:\n\n{0}",
							msg);
					}

					// failed to connect.
					AlertScreen al(this, msg);
					al.Run();
				}
			}
		}
	
	}
	
	namespace MainMenuItemContext {
	
		class MainMenuItemContextUI : spades::ui::UIElement {
			MainScreenMainMenu@ owner;
			private spades::ui::EventHandler @Closed;
			private Vector2 pos;
			private string fileName;
			
			bool isRename;
			
			bool IsServer { get { return owner.IsServer; } }
			bool IsDemo { get { return owner.IsDemo; } }
			bool IsMap { get { return owner.IsMap; } }
			
			MainMenuItemContextUI(MainScreenMainMenu@ o, Vector2 p, string fN) {
				super(o.Manager);
				@owner = o;
				
				IsMouseInteractive = true;
				this.Bounds = o.Bounds;
				
				pos = p;
				fileName = fN;
				
				isRename = false;
				
				{
					spades::ui::Label label(Manager);
					label.BackgroundColor = Vector4(0, 0, 0, 0.8f);
					label.Bounds = AABB2(pos.x, pos.y, 70.f, IsMap ? 205.f : 125.f);
					AddChild(label);
				}
				{
					spades::ui::Button button(Manager);
					button.Caption = _Tr("MainMenuItemContext", "Copy");
					button.Bounds = AABB2(pos.x + 5, pos.y + 5, 60.f, 35.f);
					@button.Activated = spades::ui::EventHandler(this.OnCopy);
					AddChild(button);
				}
				{
					spades::ui::Button button(Manager);
					button.Caption = _Tr("MainMenuItemContext", "Delete");
					button.Bounds = AABB2(pos.x + 5, pos.y + 45.f, 60.f, 35.f);
					@button.Activated = spades::ui::EventHandler(this.OnDelete);
					AddChild(button);
				}
				{
					spades::ui::Button button(Manager);
					button.Caption = _Tr("MainMenuItemContext", "Rename");
					button.Bounds = AABB2(pos.x + 5, pos.y + 85.f, 60.f, 35.f);
					@button.Activated = spades::ui::EventHandler(this.OnRename);
					AddChild(button);
				}
				if (IsMap) {
					{
						spades::ui::Button button(Manager);
						button.Caption = _Tr("MainMenuItemContext", "Glitter");
						button.Bounds = AABB2(pos.x + 5, pos.y + 125.f, 60.f, 35.f);
						@button.Activated = spades::ui::EventHandler(this.OnGlitter);
						AddChild(button);
					}
					{
						spades::ui::Button button(Manager);
						button.Caption = _Tr("MainMenuItemContext", "H-Map");
						button.Bounds = AABB2(pos.x + 5, pos.y + 165.f, 60.f, 35.f);
						@button.Activated = spades::ui::EventHandler(this.OnHeightmap);
						AddChild(button);
					}
					
				}
				
			}
			
			private void OnGlitter(spades::ui::UIElement @sender) {
				spades::ui::GlitterUI gm(owner, owner.ui.fontManager, "MapEditor/Maps/" + fileName);
				gm.Run();
				Close(false);
			}
			
			private void OnHeightmap(spades::ui::UIElement @sender) {
				spades::ui::HeightMapUI hm(owner, "MapEditor/Maps/" + fileName);
				hm.Run();
				Close(false);
			}
			
			private void OnCopy(spades::ui::UIElement @sender) {
				string dir;
				if (IsDemo)
					dir = "Demos/";
				if (IsMap)
					dir = "MapEditor/Maps/";
				string oldName = dir + fileName;
				
				CopyFile(oldName);
				
				Close();
			}
			
			private void OnDelete(spades::ui::UIElement @sender) {
				if (IsServer)
					return;
				
				if (IsDemo)
					RemoveFile("Demos/" + fileName);
				if (IsMap) {
					RemoveFile("MapEditor/Maps/" + fileName);
					string txtFileName = fileName.substr(0, fileName.length - 4) + ".txt";
					RemoveFile("MapEditor/Maps/" + txtFileName);
				}
				
				Close();
			}
			
			private void OnRename(spades::ui::UIElement @sender) {
				ContextRenameField crf(this, pos, fileName);
				crf.Run();
				isRename = true;
			}
			
			void MouseDown(spades::ui::MouseButton button, Vector2 clientPosition) {
				if (!(   clientPosition.x > pos.x
					&& clientPosition.y > pos.y
					&& clientPosition.x < pos.x + 65
					&& clientPosition.y < pos.y + 200)) {
					Close();
				}
			}
			
			void HotKey(string key) {
				if (key == "Escape") {
					Close();
				} else if (key == "R" && !isRename) {
					OnRename(this);
				} else if (key == "D" && !isRename) {
					OnDelete(this);
				} else if (key == "C" && !isRename) {
					OnCopy(this);
				} else if (key == "G" && !isRename && IsMap) {
					OnGlitter(this);
				} else if (key == "H" && !isRename && IsMap) {
					OnHeightmap(this);
				} else {
					UIElement::HotKey(key);
				}
			}
			
			void Run() {
				owner.Enable = false;
				owner.Parent.AddChild(this);
			}
			void Close(bool reload = true) {
				if (reload)
					owner.LoadServerList();
				
				owner.Enable = true;
				@this.Parent = null;
				if (Closed !is null)
					Closed(this);
			}
			
		}
		
		class ContextRenameField : spades::ui::UIElement {
			private MainMenuItemContextUI @owner;
			private Font @font;
			
			private Vector2 pos;
			private string fileName;
			
			private spades::ui::Field @renameField;
			private spades::ui::Button @DoneButton;
			private spades::ui::Label @Background;
			
			private bool IsServer { get { return owner.IsServer; } }
			private bool IsDemo { get { return owner.IsDemo; } }
			private bool IsMap { get { return owner.IsMap; } }
			
			ContextRenameField(MainMenuItemContextUI@ o, Vector2 p, string fN) {
				super(o.Manager);
				@owner = o;
				@font = owner.owner.ui.fontManager.GuiFont;
				
				this.pos = p;
				fileName = fN;
				
				float len = font.Measure(fileName).x;
				
				{
					spades::ui::Label label(Manager);
					label.BackgroundColor = Vector4(0, 0, 0, 0.8f);
					label.Bounds = AABB2(pos.x + 75, pos.y + 80.f, len + 25.f + 55.f, 45.f);
					@Background = label;
					AddChild(Background);
				}
				{
					@renameField = spades::ui::Field(Manager);
					renameField.Bounds = AABB2(pos.x + 80, pos.y + 87.5f, len + 25.f, 30.f);
					renameField.Placeholder = _Tr("MainScreen", fileName);
					renameField.Text = fileName;
					AddChild(renameField);
					@Manager.ActiveElement = renameField;
					renameField.Select(0, fileName.findLast("."));
				}
				{
					spades::ui::Button button(Manager);
					button.Caption = _Tr("MainScreen", "Done");
					button.Bounds = AABB2(pos.x + len + 25.f + 85.f, pos.y + 85.f, 40.f, 35.f);
					@button.Activated = spades::ui::EventHandler(this.OnRename);
					@DoneButton = button;
					AddChild(DoneButton);
				}
				
			}
			
			private string newFileName { 
				get { return renameField.Text; } 
				set {
					renameField.Text = value;
					UpdateBounds();
				}
			}
			
			private void UpdateBounds() {
				float len = font.Measure(newFileName).x;
				
				Background.Bounds = AABB2(pos.x + 75, pos.y + 80.f, len + 25.f + 55.f, 45.f);
				renameField.Bounds = AABB2(pos.x + 80, pos.y + 87.5f, len + 25.f, 30.f);
				DoneButton.Bounds = AABB2(pos.x + len + 25.f + 85.f, pos.y + 85.f, 40.f, 35.f);
			}
			
			private void OnRename(spades::ui::UIElement @sender) {
				if (IsServer)
					return;
				if (newFileName.length <= 0)
					return;
				if (newFileName == fileName)
					return;
				
				if (IsDemo) {
					if (newFileName.substr(newFileName.length - 5, 5) != ".demo"
						&& newFileName.substr(newFileName.length - 6, 6) != ".demoz")
						return;
					if (newFileName.substr(newFileName.length - 5, 5)
						!= fileName.substr(fileName.length - 5, 5))
						return;
					RenameFile("Demos/" + fileName, "Demos/" + newFileName);
				} else if (IsMap) {
					if (newFileName.substr(newFileName.length - 4, 4) != ".vxl")
						return;
					RenameFile("MapEditor/Maps/" + fileName, "MapEditor/Maps/" + newFileName);
					
					fileName = fileName.substr(0, fileName.length - 4) + ".txt";
					newFileName = newFileName.substr(0, newFileName.length - 4) + ".txt";
					RenameFile("MapEditor/Maps/" + fileName, "MapEditor/Maps/" + newFileName);
				}
				
				Close();
			}
			
			void HotKey(string key) {
				UpdateBounds();
				if (key == "Enter") {
					OnRename(this);
				} else if (key == "End") {
					renameField.CursorPosition = newFileName.findLast(".");
					if (!Manager.IsShiftPressed)
						renameField.MarkPosition = newFileName.findLast(".");
				} else if (key == "Home") {
					renameField.CursorPosition = 0;
					if (!Manager.IsShiftPressed)
						renameField.MarkPosition = 0;
				} else {
					UIElement::HotKey(key);
				}
			}
			
			void Run() { owner.AddChild(this); }
			void Close() { owner.Close(); }
			
		}
	
	}

}

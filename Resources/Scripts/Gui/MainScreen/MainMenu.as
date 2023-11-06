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
		
		spades::ui::Label @contextMenuLabel;
		spades::ui::Button @delButton;
		spades::ui::Button @copyButton;
		spades::ui::Button @renameButton;
		spades::ui::Button @renameDoneButton;
		spades::ui::Label @renameLabel;
		spades::ui::Field @renameField;
		spades::ui::Button @glitterButton;
		spades::ui::Button @heightmapButton;
		bool isMapButtonsVisible = false;
		bool isContextMenuActive = false;
		bool isRenameFieldActive = false;
		string currentFileName, newCurrentFileName;
		float xPos;
		float yPos;

		spades::ui::ListView @serverList;
		MainScreenServerListLoadingView @loadingView;
		MainScreenServerListErrorView @errorView;
		bool loading = false, loaded = false, canvasList = false;
		string MapFile = "";
		MainScreenServerItem@[]@ savedlist = array<spades::MainScreenServerItem@>();
		int savedlistIdx = 0;
		int mode = 0;
		int isOnline = 0, isDemo = 1, isMap = 2;

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
			RightClickContextMenuClose();
		}

		void ServerListItemActivated(ServerListModel @sender, MainScreenServerItem @item) {
			ServerListItemActivatedPass(item);
		}

		void ServerListItemActivatedPass(MainScreenServerItem @item) {
			if (mode == isOnline) {
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

		void ServerListItemDoubleClicked(ServerListModel @sender, MainScreenServerItem @item) {
			ServerListItemActivated(sender, item);

			// Double-click to connect
			Connect();
		}

		void ServerListItemRightClicked(ServerListModel @sender, MainScreenServerItem @item) {
			if (mode != isOnline) {
				if (isContextMenuActive)
					RightClickContextMenuClose();
				RightClickContextMenuOpen(item);
				isContextMenuActive = true;
				return;
			}
			helper.SetServerFavorite(item.Address, !item.Favorite);
			UpdateServerList();
		}
		
		void RightClickContextMenuOpen(MainScreenServerItem @item) {
			xPos = ui.manager.MouseCursorPosition.x;
			yPos = ui.manager.MouseCursorPosition.y;
			currentFileName = item.Name;
			{
				spades::ui::Label label(Manager);
				label.BackgroundColor = Vector4(0, 0, 0, 0.8f);
				if (mode == isMap)
					label.Bounds = AABB2(xPos, yPos, 70.f, 205.f);
				else
					label.Bounds = AABB2(xPos, yPos, 70.f, 125.f);
				@contextMenuLabel = label;
				AddChild(contextMenuLabel);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("MainScreen", "Copy");
				button.Bounds = AABB2(xPos + 5, yPos + 5, 60.f, 35.f);
				button.Toggled = false;
				@button.Activated = spades::ui::EventHandler(this.OnCopy);
				@copyButton = button;
				AddChild(copyButton);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("MainScreen", "Delete");
				button.Bounds = AABB2(xPos + 5, yPos + 45.f, 60.f, 35.f);
				button.Toggled = false;
				@button.Activated = spades::ui::EventHandler(this.OnDelete);
				@delButton = button;
				AddChild(delButton);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("MainScreen", "Rename");
				button.Bounds = AABB2(xPos + 5, yPos + 85.f, 60.f, 35.f);
				button.Toggled = false;
				@button.Activated = spades::ui::EventHandler(this.OnRename);
				@renameButton = button;
				AddChild(renameButton);
			}
			if (mode == isMap) {
				{
					spades::ui::Button button(Manager);
					button.Caption = _Tr("MainScreen", "Glitter");
					button.Bounds = AABB2(xPos + 5, yPos + 125.f, 60.f, 35.f);
					button.Toggled = false;
					@button.Activated = spades::ui::EventHandler(this.OnGlitter);
					@glitterButton = button;
					AddChild(glitterButton);
				}
				{
					spades::ui::Button button(Manager);
					button.Caption = _Tr("MainScreen", "H-Map");
					button.Bounds = AABB2(xPos + 5, yPos + 165.f, 60.f, 35.f);
					button.Toggled = false;
					@button.Activated = spades::ui::EventHandler(this.OnHeightmap);
					@heightmapButton = button;
					AddChild(heightmapButton);
				}
				
				isMapButtonsVisible = true;
			}
		}
		
		void MouseDown(spades::ui::MouseButton button, Vector2 clientPosition) {
			if (isContextMenuActive) {
				RightClickContextMenuClose();
			}
		}
		
		void OnGlitter(spades::ui::UIElement @sender) {
			RightClickContextMenuClose();
			spades::ui::GlitterUI gm(ui, this, currentFileName);
			gm.Run();
		}
		
		void OnHeightmap(spades::ui::UIElement @sender) {
			RightClickContextMenuClose();
			spades::ui::HeightMapUI hm(this, "MapEditor/Maps/" + currentFileName);
			hm.Run();
		}
		
		void OnCopy(spades::ui::UIElement @sender) {
			if (mode == isDemo)
				ui.helper.MainScreenCopyFile("Demos/" + currentFileName);
			if (mode == isMap)
				ui.helper.MainScreenCopyFile("MapEditor/Maps/" + currentFileName);
			LoadServerList();
			RightClickContextMenuClose();
		}
		
		void OnDelete(spades::ui::UIElement @sender) {
			if (mode == isOnline)
				return;
			if (mode == isDemo)
				ui.helper.RemoveFile("Demos/" + currentFileName);
			if (mode == isMap) {
				ui.helper.RemoveFile("MapEditor/Maps/" + currentFileName);
				currentFileName = currentFileName.substr(0, currentFileName.length - 4) + ".txt";
				ui.helper.RemoveFile("MapEditor/Maps/" + currentFileName);
			}
			LoadServerList();
			RightClickContextMenuClose();
		}
		
		void OnRename(spades::ui::UIElement @sender) {
			isRenameFieldActive = true;
			{
				spades::ui::Label label(Manager);
				label.BackgroundColor = Vector4(0, 0, 0, 0.8f);
				label.Bounds = AABB2(xPos + 75, yPos + 80.f, 455.f, 45.f);
				@renameLabel = label;
				AddChild(renameLabel);
			}
			{
				@renameField = spades::ui::Field(Manager);
				renameField.Bounds = AABB2(xPos + 80, yPos + 87.5f, 400.f, 30.f);
				renameField.Placeholder = _Tr("MainScreen", currentFileName);
				renameField.Text = currentFileName;
				newCurrentFileName = currentFileName;
				@renameField.Changed = spades::ui::EventHandler(this.OnFileNameChanged);
				AddChild(renameField);
				@Manager.ActiveElement = renameField;
				if (mode == isDemo)
					if (currentFileName.substr(currentFileName.length - 5, 5) == ".demo") {
						renameField.Select(0, currentFileName.length - 5);
					} else if (currentFileName.substr(currentFileName.length - 6, 6) == ".demoz") {
						renameField.Select(0, currentFileName.length - 6);
					}
				if (mode == isMap)
					renameField.Select(0, currentFileName.length - 4);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("MainScreen", "Done");
				button.Bounds = AABB2(xPos + 485, yPos + 85.f, 40.f, 35.f);
				button.Toggled = false;
				@button.Activated = spades::ui::EventHandler(this.OnRenameDoneSender);
				@renameDoneButton = button;
				AddChild(renameDoneButton);
			}
		}
		
		void OnFileNameChanged(spades::ui::UIElement @sender) {
			newCurrentFileName = renameField.Text;
		}
		
		void OnRenameDoneSender(spades::ui::UIElement @sender) { OnRenameDone(); }
		
		void OnRenameDone() {
			if (mode == isOnline)
				return;
			if (newCurrentFileName.length <= 0)
				return;
			if (newCurrentFileName == currentFileName)
				return;
			if (mode == isDemo) {
				if (newCurrentFileName.substr(newCurrentFileName.length - 5, 5) != ".demo"
					&& newCurrentFileName.substr(newCurrentFileName.length - 6, 6) != ".demoz")
					return;
				if (newCurrentFileName.substr(newCurrentFileName.length - 5, 5)
					!= currentFileName.substr(currentFileName.length - 5, 5))
					return;
				ui.helper.RenameFile("Demos/" + currentFileName, "Demos/" + newCurrentFileName);
			}
			if (mode == isMap) {
				if (newCurrentFileName.substr(newCurrentFileName.length - 4, 4) != ".vxl")
					return;
				ui.helper.RenameFile("MapEditor/Maps/" + currentFileName, "MapEditor/Maps/" + newCurrentFileName);
				currentFileName = currentFileName.substr(0, currentFileName.length - 4) + ".txt";
				newCurrentFileName = newCurrentFileName.substr(0, newCurrentFileName.length - 4) + ".txt";
				ui.helper.RenameFile("MapEditor/Maps/" + currentFileName, "MapEditor/Maps/" + newCurrentFileName);
			}
			ui.helper.RenameFile(currentFileName, newCurrentFileName);
			LoadServerList();
			RightClickContextMenuClose();
		}
		
		void RightClickContextMenuClose() {
			if (!isContextMenuActive)
				return;
			RemoveChild(contextMenuLabel);
			RemoveChild(copyButton);
			RemoveChild(delButton);
			RemoveChild(renameButton);
			isContextMenuActive = false;
			
			if (isMapButtonsVisible) {
				RemoveChild(glitterButton);
				RemoveChild(heightmapButton);
			}
			isMapButtonsVisible = false;
			
			if (!isRenameFieldActive)
				return;
			RemoveChild(renameDoneButton);
			RemoveChild(renameField);
			RemoveChild(renameLabel);
			isRenameFieldActive = false;
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
			if (mode != isOnline) {
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
			if (mode != isOnline) {
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
				if (mode != isOnline) {
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
			RightClickContextMenuClose();
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
			if (mode != isOnline) {
				return;
			}
			cg_lastQuickConnectHost = addressField.Text;
			RightClickContextMenuClose();
		}

		private void SetProtocolVersion(int ver) {
			protocol3Button.Toggled = (ver == 3);
			protocol4Button.Toggled = (ver == 4);
			cg_protocolVersion = ver;
			RightClickContextMenuClose();
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
			RightClickContextMenuClose();
		}

		private void OnSetupPressed(spades::ui::UIElement @sender) {
			PreferenceView al(this, PreferenceViewOptions(), ui.fontManager);
			al.Run();
			RightClickContextMenuClose();
		}

		private void Connect() {
			if (addressField.Text == "") {
				return;
			}
			if (mode == isOnline) {
				ConnectServer();
			} else if (mode == isDemo) {
				ConnectDemo();
			} else if (mode == isMap) {
				ConnectMap();
			}
		}

		private void ConnectServer() {
			string msg = helper.ConnectServer(addressField.Text, cg_protocolVersion.IntValue, isOnline, "", "");
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
			string msg = helper.ConnectServer(FieldText, cg_protocolVersion.IntValue, isDemo, DemoFile, "");
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
			string msg = helper.ConnectServer(FieldText, cg_protocolVersion.IntValue, isMap, MapFile, Canvas);
			if (msg.length > 0) {
				// failde to initialize client.
				AlertScreen al(this, msg);
				al.Run();
			}
		}

		private void OnConnectPressed(spades::ui::UIElement @sender) { Connect(); }

		private void OnConnectLocalPressed(spades::ui::UIElement @sender) {
			string msg = helper.ConnectServer("127.0.0.1", cg_protocolVersion.IntValue, isOnline, "", "");
			if (msg.length > 0) {
				// failde to initialize client.
				AlertScreen al(this, msg);
				al.Run();
			}
		}

		private void OnServerList(spades::ui::UIElement @sender) {
			ChangeList(isOnline);
		}
		private void OnDemoList(spades::ui::UIElement @sender) {
			ChangeList(isDemo);
		}
		private void OnMapList(spades::ui::UIElement @sender) {
			ChangeList(isMap);
		}

		private void ChangeList(int whichMode) {
			mode = whichMode;
			canvasList = false;
			if (mode != isOnline) {
				addressField.Text = "";
			} else {
				addressField.Text = cg_lastQuickConnectHost.StringValue;
			}
			LoadServerList();
		}

		void HotKey(string key) {
			if (IsEnabled and key == "Enter") {
				if (isRenameFieldActive) {
					OnRenameDone();
				} else {
					Connect();
				}
			} else if (IsEnabled and key == "Escape") {
				if (isContextMenuActive) {
					RightClickContextMenuClose();
				} else {
					ui.shouldExit = true;
				}
			} else if (IsEnabled and key == "S" and Manager.IsControlPressed) {
				ChangeList(isOnline);
			} else if (IsEnabled and key == "D" and Manager.IsControlPressed) {
				ChangeList(isDemo);
			} else if (IsEnabled and key == "M" and Manager.IsControlPressed) {
				ChangeList(isMap);
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
			} else if (IsEnabled and key == "End" and isRenameFieldActive) {
				renameField.CursorPosition = newCurrentFileName.length - 5;
				if (!Manager.IsShiftPressed)
					renameField.MarkPosition = newCurrentFileName.length - 5;
			} else if (IsEnabled and key == "Home" and isRenameFieldActive) {
				renameField.CursorPosition = 0;
				if (!Manager.IsShiftPressed)
					renameField.MarkPosition = 0;
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

}
//converted spaces to tabs.

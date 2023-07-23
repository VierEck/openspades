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
#include "Menu.as"
#include "FieldWithHistory.as"
#include "ChatLogWindow.as"
#include "ColorPalette.as"
#include "MapTxt.as"

namespace spades {

    class ClientUI {
        private Renderer @renderer;
        private AudioDevice @audioDevice;
        FontManager @fontManager;
        ClientUIHelper @helper;

        spades::ui::UIManager @manager;
        spades::ui::UIElement @activeUI;

        ChatLogWindow @chatLogWindow;
        ClientMapTxtWindow @mapTxtWindow;

        ClientMenu @clientMenu;

        array<spades::ui::CommandHistoryItem @> chatHistory;

        bool shouldExit = false;

        private float time = -1.f;

        ClientUI(Renderer @renderer, AudioDevice @audioDevice, FontManager @fontManager,
                 ClientUIHelper @helper) {
            @this.renderer = renderer;
            @this.audioDevice = audioDevice;
            @this.fontManager = fontManager;
            @this.helper = helper;

            @manager = spades::ui::UIManager(renderer, audioDevice);
            @manager.RootElement.Font = fontManager.GuiFont;

            @clientMenu = ClientMenu(this);
            clientMenu.Bounds = manager.RootElement.Bounds;

            @chatLogWindow = ChatLogWindow(this);
            @mapTxtWindow = ClientMapTxtWindow(this);
        }

        //doesnt translate all keys. only the ones mapeditor UI uses. cursed way of doing this tbh
        ConfigItem cg_UIHotKeyLayout("cg_UIHotKeyLayout");
        string qwerty_Z = "Z";
        string qwerty_Y = "Y";
        string qwerty_R = "R";
        string qwerty_E = "E";
        string qwerty_F = "F";
        string qwerty_D = "D";
        string qwerty_A = "A";
        string qwerty_S = "S";
        string qwerty_L = "L";
        string qwerty_C = "C";
        string qwerty_V = "V";
        string qwerty_X = "X";
        string qwerty_G = "G";
        void UpdateHotKeylayout(){
            if (cg_UIHotKeyLayout.StringValue == "qwertz" or cg_UIHotKeyLayout.StringValue == "german") {
                qwerty_Z = "Y";
                qwerty_Y = "Z";
            } else if (cg_UIHotKeyLayout.StringValue == "azerty" or cg_UIHotKeyLayout.StringValue == "french") {
                qwerty_Z = "W";
                qwerty_A = "Q";
            } else if (cg_UIHotKeyLayout.StringValue == "dvorak") {
                qwerty_Z = "/";
                qwerty_Y = "T";
                qwerty_R = "O";
                qwerty_E = "D";
                qwerty_F = "Y";
                qwerty_D = "H";
                qwerty_S = ";";
                qwerty_L = "P"; 
                qwerty_C = "I";
                qwerty_V = ".";
                qwerty_X = "B";
                qwerty_G = "U";
            } else if (cg_UIHotKeyLayout.StringValue == "colemak") {
                qwerty_Y = "O";
                qwerty_R = "R";
                qwerty_E = "K";
                qwerty_F = "E";
                qwerty_D = "G";
                qwerty_S = "D";
                qwerty_L = "U";
                qwerty_G = "T";
            } else if (cg_UIHotKeyLayout.StringValue == "workman") {
                qwerty_Y = "H";
                qwerty_R = "E";
                qwerty_E = "K";
                qwerty_F = "U";
                qwerty_D = "W";
                qwerty_L = "M";
                qwerty_C = "V";
                qwerty_V = "B";
            } else if (cg_UIHotKeyLayout.StringValue == "neo") {
                qwerty_Z = "B";
                qwerty_Y = "'";
                qwerty_R = "K";
                qwerty_E = "F";
                qwerty_F = "O";
                qwerty_D = ";";
                qwerty_A = "D";
                qwerty_S = "H";
                qwerty_L = "E";
                qwerty_C = "R";
                qwerty_V = "W";
                qwerty_X = "Q";
                qwerty_G = "I";
            } else if (cg_UIHotKeyLayout.StringValue == "dvorak french") {
                qwerty_Z = "[";
                qwerty_Y = "B";
                qwerty_R = "M";
                qwerty_E = "F";
                qwerty_F = "H";
                qwerty_D = ";";
                qwerty_A = "S";
                qwerty_S = "J";
                qwerty_L = ",";
                qwerty_C = "I";
                qwerty_V = "U";
                qwerty_X = "N";
                qwerty_G = "R";
            } else if (cg_UIHotKeyLayout.StringValue == "bépo" or cg_UIHotKeyLayout.StringValue == "bepo") {
                qwerty_Z = "[";
                qwerty_Y = "X";
                qwerty_R = "L";
                qwerty_E = "F";
                qwerty_F = "/";
                qwerty_D = "I";
                qwerty_S = "K";
                qwerty_L = "O";
                qwerty_C = "H";
                qwerty_V = "U";
                qwerty_X = "C";
                qwerty_G = ",";
            }
        }

        void MouseEvent(float x, float y) { manager.MouseEvent(x, y); }

        void WheelEvent(float x, float y) { manager.WheelEvent(x, y); }

        void KeyEvent(string key, bool down) { manager.KeyEvent(key, down); }

        void TextInputEvent(string text) { manager.TextInputEvent(text); }

        void TextEditingEvent(string text, int start, int len) {
            manager.TextEditingEvent(text, start, len);
        }

        bool AcceptsTextInput() { return manager.AcceptsTextInput; }

        AABB2 GetTextInputRect() { return manager.TextInputRect; }

        void RunFrame(float dt) {
            if (time < 0.f) {
                time = 0.f;
            }

            manager.RunFrame(dt);
            if (activeUI !is null) {
                manager.Render();
            }

            time += Min(dt, 0.05f);
        }

        void Closing() {}

        bool WantsClientToBeClosed() { return shouldExit; }

        bool NeedsInput() { return activeUI !is null; }

        void set_ActiveUI(spades::ui::UIElement @value) {
            if (activeUI !is null) {
                manager.RootElement.RemoveChild(activeUI);
            }
            @activeUI = value;
            if (activeUI !is null) {
                activeUI.Bounds = manager.RootElement.Bounds;
                manager.RootElement.AddChild(activeUI);
            }
            manager.KeyPanic();
        }
        spades::ui::UIElement @get_ActiveUI() { return activeUI; }

        void EnterClientMenu() { @ActiveUI = clientMenu; }

        void EnterTeamChatWindow() {
            ClientChatWindow wnd(this, true);
            @ActiveUI = wnd;
            @manager.ActiveElement = wnd.field;
        }
        void EnterGlobalChatWindow() {
            ClientChatWindow wnd(this, false);
            @ActiveUI = wnd;
            @manager.ActiveElement = wnd.field;
        }
        void EnterCommandWindow() {
            ClientChatWindow wnd(this, true);
            wnd.field.Text = "/";
            wnd.field.Select(1, 0);
            wnd.UpdateState();
            @ActiveUI = wnd;
            @manager.ActiveElement = wnd.field;
        }
        void EnterChatLogWindow() {
            @ActiveUI = @chatLogWindow;
            chatLogWindow.ScrollToEnd();
        }
        void CloseUI() { @ActiveUI = null; }

        void EnterPaletteWindow() {
            UpdateHotKeylayout();
            ClientPaletteWindow wnd(this);
            @ActiveUI = wnd;
        }
        void EnterMapTxtWindow() {
            UpdateHotKeylayout();
            @ActiveUI = mapTxtWindow;
            @manager.ActiveElement = mapTxtWindow.viewer;
        }

        void RecordChatLog(string text, Vector4 color) { chatLogWindow.Record(text, color); }

        void LoadMapTxt(string text) { mapTxtWindow.Load(text); }
    }

    ClientUI @CreateClientUI(Renderer @renderer, AudioDevice @audioDevice, FontManager @fontManager,
                             ClientUIHelper @helper) {
        return ClientUI(renderer, audioDevice, fontManager, helper);
    }

}

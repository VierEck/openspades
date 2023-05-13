#include "../Preferences.as"

namespace spades {
    class ClientPaletteWindow : spades::ui::UIElement {
        private ClientUI @ui;
        private ClientUIHelper @helper;

        spades::ui::Button @doButton;

        ClientPaletteWindow(ClientUI @ui) {
            super(ui.manager);
            @this.ui = ui;
            @this.helper = ui.helper;

            float winX = (Manager.Renderer.ScreenWidth);
            float winY = (Manager.Renderer.ScreenHeight) - 80.f;
			
			PaletteConfigLayouter layouter(this, ui.fontManager, winX, winY);
			
			winX = winX - 20.f;
			
			{
                spades::ui::Button button(Manager);
                button.Caption = _Tr("Client", ">");
                button.Bounds = AABB2(winX - 35.f, winY, 20.f, 20.f);
                @button.Activated = spades::ui::EventHandler(this.OnNext);
                AddChild(button);
                @doButton = button;
            }
			{
                spades::ui::Button button(Manager);
                button.Caption = _Tr("Client", "<");
                button.Bounds = AABB2(winX - 57.f, winY, 20.f, 20.f);
                @button.Activated = spades::ui::EventHandler(this.OnPrev);
                AddChild(button);
                @doButton = button;
            }
			{
                spades::ui::Button button(Manager);
                button.Caption = _Tr("Client", "Save");
                button.Bounds = AABB2(winX - 110.f, winY, 50.f, 30.f);
                @button.Activated = spades::ui::EventHandler(this.OnSave);
                AddChild(button);
                @doButton = button;
            }
			{
                spades::ui::Button button(Manager);
                button.Caption = _Tr("Client", "Reload");
                button.Bounds = AABB2(winX - 110.f, winY + 33.f, 50.f, 30.f);
                @button.Activated = spades::ui::EventHandler(this.OnReload);
                AddChild(button);
                @doButton = button;
            }
			{
                spades::ui::Button button(Manager);
                button.Caption = _Tr("Client", "New");
                button.Bounds = AABB2(winX - 163.f, winY, 50.f, 30.f);
                @button.Activated = spades::ui::EventHandler(this.OnNew);
                AddChild(button);
                @doButton = button;
            }
			{
                spades::ui::Button button(Manager);
                button.Caption = _Tr("Client", "Delete");
                button.Bounds = AABB2(winX - 163.f, winY + 33.f, 50.f, 30.f);
                @button.Activated = spades::ui::EventHandler(this.OnDel);
                AddChild(button);
                @doButton = button;
            }
			
			layouter.AddSliderField(_Tr("Preferences", ""),
                                    "cg_CurrentColorRed", 0, 255, 1,
                                    ConfigNumberFormatter(0, " R"));
			layouter.AddSliderField(_Tr("Preferences", ""),
                                    "cg_CurrentColorGreen", 0, 255, 1,
                                    ConfigNumberFormatter(0, " G"));
			layouter.AddSliderField(_Tr("Preferences", ""),
                                    "cg_CurrentColorBlue", 0, 255, 1,
                                    ConfigNumberFormatter(0, " B"));
			layouter.FinishLayout();
        }
		
		private void OnSave(spades::ui::UIElement @sender) {
			ui.helper.SaveCurrentPalettePage();
        }
		private void OnReload(spades::ui::UIElement @sender) {
			ui.helper.LoadCurrentPalettePage();
        }
		private void OnNew(spades::ui::UIElement @sender) {
			ui.helper.NewPalettePage();
        }
		private void OnDel(spades::ui::UIElement @sender) {
			ui.helper.DeleteCurrentPalettePage();
        }
		
		private void OnNext(spades::ui::UIElement @sender) {
			ui.helper.ChangePalettePage(1);
        }
		private void OnPrev(spades::ui::UIElement @sender) {
			ui.helper.ChangePalettePage(-1);
        }
		
		private void Close() { @ui.ActiveUI = null; }
		
		void HotKey(string key) {
			if (IsEnabled and (key == "Up" or key == "Down" or key == "Left" or key == "Right")) {
				//todo enable palette navigation
				return;
            } 
            if (IsEnabled and (key == "Escape" or key == "Enter" or key == "C")) {
                Close();
            } 
        }
    }
	
	class PaletteConfigLayouter { //tbh i dont know wtf im doing but this works out. 
        spades::ui::UIElement @Parent;
        private float FieldX = 5.f;
        private float FieldWidth = 256.f;
        private spades::ui::UIElement @[] items;
        private ConfigHotKeyField @[] hotkeyItems;
        private FontManager @fontManager;
		float winX;
		float winY;

        PaletteConfigLayouter(spades::ui::UIElement @parent, FontManager @fontManager, float x, float y) {
            @Parent = parent;
            @this.fontManager = fontManager;
			winX = x;
			winY = y;
        }

        private spades::ui::UIElement @CreateItem() {
            spades::ui::UIElement elem(Parent.Manager);
            elem.Size = Vector2(300.f, 32.f);
            items.insertLast(elem);
            return elem;
        }

        ConfigSlider
            @AddSliderField(string caption, string configName, float minRange, float maxRange,
                            float step, ConfigNumberFormatter @formatter, bool enabled = true) {
            spades::ui::UIElement @container = CreateItem();

            spades::ui::Label label(Parent.Manager);
            label.Text = caption;
            label.Alignment = Vector2(0.f, 0.5f);
            label.Bounds = AABB2(10.f, 0.f, 10.f, 32.f);
            container.AddChild(label);

            ConfigSlider slider(Parent.Manager, configName, minRange, maxRange, step, formatter);
            slider.Bounds = AABB2(FieldX, 8.f, FieldWidth, 16.f);
            slider.Enable = enabled;
            container.AddChild(slider);

            return slider;
        }

        void FinishLayout() {
            spades::ui::ListView list(Parent.Manager);
            @list.Model = StandardPreferenceLayouterModel(items);
            list.RowHeight = 20.f;
            list.Bounds = AABB2(winX - 550.0f, winY + 2.0f, 360.f, 70.f);
            Parent.AddChild(list);
        }
    }
}

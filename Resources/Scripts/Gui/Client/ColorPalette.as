#include "../Preferences.as"

namespace spades {
    class ClientPaletteWindow : spades::ui::UIElement {
        private ClientUI @ui;
        private ClientUIHelper @helper;
		
		float ContentsLeft, ContentsWidth;
        float ContentsTop, ContentsHeight;

        spades::ui::Button @doButton;
		StandardPreferenceLayouter layouter(this, ui.fontManager);

        ClientPaletteWindow(ClientUI @ui) {
            super(ui.manager);
            @this.ui = ui;
            @this.helper = ui.helper;
			
			ContentsWidth = 800.f;
            ContentsLeft = (Manager.Renderer.ScreenWidth - ContentsWidth) * 0.5f;
            ContentsHeight = 550.f;
            ContentsTop = (Manager.Renderer.ScreenHeight - ContentsHeight) * 0.5f;

            float winX = (Manager.Renderer.ScreenWidth) - 20.f;
            float winY = (Manager.Renderer.ScreenHeight) - 80.f;
			
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
			
			layouter.AddSliderField(_Tr("Preferences", "Red  "),
                                    "cg_CurrentColorRed", 0, 255, 1,
                                    ConfigNumberFormatter(0, "x"));
			layouter.AddSliderField(_Tr("Preferences", "Green"),
                                    "cg_CurrentColorGreen", 0, 255, 1,
                                    ConfigNumberFormatter(0, "x"));
			layouter.AddSliderField(_Tr("Preferences", "Blue "),
                                    "cg_CurrentColorBlue", 0, 255, 1,
                                    ConfigNumberFormatter(0, "x"));
			layouter.FinishLayout();
        }
		
		private void OnSave(spades::ui::UIElement @sender) {
			//todo: save current page
            Close();
        }
		private void OnReload(spades::ui::UIElement @sender) {
			//todo: reload current page's file
            Close();
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
}

#include "../Preferences.as"

namespace spades {
	class ClientPaletteWindow : spades::ui::UIElement {
		private ClientUI @ui;
		private ClientUIHelper @helper;

		ClientPaletteWindow(ClientUI @ui) {
			super(ui.manager);
			@this.ui = ui;
			@this.helper = ui.helper;

			float winX = (Manager.Renderer.ScreenWidth);
			float winY = (Manager.Renderer.ScreenHeight);
			
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", ">");
				button.Bounds = AABB2(winX - 35.f - 20.f, winY - 80.f, 20.f, 20.f);
				@button.Activated = spades::ui::EventHandler(this.OnNext);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "<");
				button.Bounds = AABB2(winX - 57.f - 20.f, winY - 80.f, 20.f, 20.f);
				@button.Activated = spades::ui::EventHandler(this.OnPrev);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Save");
				button.Bounds = AABB2(winX - 110.f - 20.f, winY - 80.f, 50.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnSave);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Reload");
				button.Bounds = AABB2(winX - 110.f - 20.f, winY + 33.f - 80.f, 50.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnReload);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "New");
				button.Bounds = AABB2(winX - 163.f - 20.f, winY - 80.f, 50.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnNew);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Delete");
				button.Bounds = AABB2(winX - 163.f - 20.f, winY + 33.f - 80.f, 50.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnDel);
				AddChild(button);
			}
			
			{
				spades::ui::Label label(Manager);
				label.BackgroundColor = Vector4(0, 0, 0, 0.8f);
				label.Bounds = AABB2(winX - 235.f - 256.f, winY - 80.f, 265, 48.f + 25.f);
				AddChild(label);
				
				AddColorSliderField(_Tr("Preferences", ""),
										"cg_CurrentColorRed", 0, 255, 1,
										ConfigNumberFormatter(0, " R"),
										winX - 235.f - 256.f, winY - 80.f);
				AddColorSliderField(_Tr("Preferences", ""),
										"cg_CurrentColorGreen", 0, 255, 1,
										ConfigNumberFormatter(0, " G"),
										winX - 235.f - 256.f, winY - 64.f + 5.f);
				AddColorSliderField(_Tr("Preferences", ""),
										"cg_CurrentColorBlue", 0, 255, 1,
										ConfigNumberFormatter(0, " B"),
										winX - 235.f - 256.f, winY - 48.f + 10.f);
			}
			
			{
				spades::ui::CancelButton button(Manager);
				button.Caption = _Tr("Client", "Undo");
				button.Bounds = AABB2(winX * 0.48f - 50.f, winY * 0.5f - 15.f, 50.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnUndo);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Redo");
				button.Bounds = AABB2(winX * 0.48f - 103.f, winY * 0.5f - 15.f, 50.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnRedo);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Respawn");
				button.Bounds = AABB2(winX * 0.48f - 103.f, winY * 0.5f - 15.f + 60.f, 103.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnRespawn);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Set Respawn");
				button.Bounds = AABB2(winX * 0.48f - 103.f, winY * 0.5f - 15.f + 60.f + 33.f, 103.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnSetRespawn);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Switch GameMode");
				button.Bounds = AABB2(winX * 0.48f - 236.f, winY * 0.5f - 15.f + 60.f, 130.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnSwitchGameMode);
				AddChild(button);
			}
			{
				spades::ui::Button button(Manager);
				button.Caption = _Tr("Client", "Switch Team");
				button.Bounds = AABB2(winX * 0.48f - 236.f, winY * 0.5f - 15.f + 60.f + 33.f, 130.f, 30.f);
				@button.Activated = spades::ui::EventHandler(this.OnSwitchTeam);
				AddChild(button);
			}
			
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
		
		private void OnUndo(spades::ui::UIElement @sender) {
			ui.helper.SayGlobal("/ud");
		}
		private void OnRedo(spades::ui::UIElement @sender) {
			ui.helper.SayGlobal("/rd");
		}
		
		private void OnSwitchGameMode(spades::ui::UIElement @sender) {
			ui.helper.SayGlobal("/g");
		}
		private void OnSwitchTeam(spades::ui::UIElement @sender) {
			ui.helper.SayGlobal("/s");
		}
		private void OnSetRespawn(spades::ui::UIElement @sender) {
			ui.helper.SayGlobal("/r");
		}
		private void OnRespawn(spades::ui::UIElement @sender) {
			ui.helper.SayGlobal("/k");
		}
		
		private void Close() { @ui.ActiveUI = null; }
		
		private ConfigItem cg_keyEditColor("cg_keyEditColor");
		private ConfigItem cg_keyPaletteLeft("cg_keyPaletteLeft");
		private ConfigItem cg_keyPaletteRight("cg_keyPaletteRight");
		private ConfigItem cg_keyPaletteUp("cg_keyPaletteUp");
		private ConfigItem cg_keyPaletteDown("cg_keyPaletteDown");
		
		void HotKey(string key) {
			if (IsEnabled 
				and (StringCompareCaseInsensitive(key, cg_keyPaletteUp.StringValue) 
						or StringCompareCaseInsensitive(key, cg_keyPaletteDown.StringValue) 
						or StringCompareCaseInsensitive(key, cg_keyPaletteRight.StringValue) 
						or StringCompareCaseInsensitive(key, cg_keyPaletteLeft.StringValue) 
					)
				) {
				ui.helper.PaletteKeyInput(key);
				return;
				} 
			if (IsEnabled and (key == "Escape" or key == "Enter" or StringCompareCaseInsensitive(key, cg_keyEditColor.StringValue))) {
				Close();
				return;
			}
			
			if (IsEnabled and Manager.IsControlPressed and key == ui.qwerty_Z) {
				ui.helper.SayGlobal("/ud");
			}
			if (IsEnabled and Manager.IsControlPressed and key == ui.qwerty_Y) {
				ui.helper.SayGlobal("/rd");
			}
			
			if (IsEnabled and Manager.IsControlPressed and key == ui.qwerty_R) {
				ui.helper.SayGlobal("/r");
			}
			if (IsEnabled and Manager.IsControlPressed and key == ui.qwerty_F) {
				ui.helper.SayGlobal("/k");
			}
			if (IsEnabled and Manager.IsControlPressed and key == ui.qwerty_E) {
				ui.helper.SayGlobal("/s");
			}
			if (IsEnabled and Manager.IsControlPressed and key == ui.qwerty_D) {
				ui.helper.SayGlobal("/g");
			}
		}
		
		void AddColorSliderField(string caption, string configName, float minRange, float maxRange,
							float step, ConfigNumberFormatter @formatter,
							float x, float y, bool enabled = true) {

			spades::ui::Label label(Manager);
			label.Text = caption;
			label.Alignment = Vector2(x, y + 0.5f);
			label.Bounds = AABB2(x + 10.f, y + 0.f, 10.f, 32.f);
			AddChild(label);

			ConfigSlider slider(Manager, configName, minRange, maxRange, step, formatter);
			slider.Bounds = AABB2(x + 5.f, y + 8.f, 256.f, 16.f);
			slider.Enable = enabled;

			AddChild(slider);
		}
		
	}
	
}

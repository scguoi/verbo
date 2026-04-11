mod config;
mod hotkey;
mod output;
mod tray;

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_clipboard_manager::init())
        .setup(|app| {
            tray::create_tray(app.handle()).map_err(|e| Box::<dyn std::error::Error>::from(e))?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            config::read_config,
            config::write_config,
            config::get_config_path,
            hotkey::register_hotkeys,
            hotkey::unregister_all_hotkeys,
            output::simulate_input,
            output::copy_to_clipboard,
            output::check_accessibility_permission,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

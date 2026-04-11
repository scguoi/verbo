mod config;
mod hotkey;
mod output;
mod tray;

#[cfg(target_os = "macos")]
fn setup_macos_floating_window(app: &tauri::AppHandle) {
    use tauri::Manager;

    if let Some(window) = app.get_webview_window("floating") {
        let ns_win = window.ns_window();
        if let Ok(ptr) = ns_win {
            unsafe {
                use objc2::msg_send;
                use objc2::runtime::AnyObject;

                let ns_window = ptr as *mut AnyObject;

                // Accept mouse events without activating the app
                // NSWindow.acceptsMouseMovedEvents = YES
                let _: () = msg_send![ns_window, setAcceptsMouseMovedEvents: true];

                // Set window collection behavior to allow click-through
                // NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary
                let behavior: u64 = (1 << 0) | (1 << 8);
                let _: () = msg_send![ns_window, setCollectionBehavior: behavior];

                // Make the window a non-activating panel style
                // This prevents the app from stealing focus when the pill is clicked
                let _: () = msg_send![ns_window, setStyleMask: 0u64]; // borderless
                let _: () = msg_send![ns_window, setLevel: 3i64]; // NSFloatingWindowLevel
            }
        }
    }
}

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_clipboard_manager::init())
        .setup(|app| {
            tray::create_tray(app.handle()).map_err(|e| Box::<dyn std::error::Error>::from(e))?;
            #[cfg(target_os = "macos")]
            setup_macos_floating_window(app.handle());
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

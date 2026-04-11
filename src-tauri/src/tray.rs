use tauri::{
    menu::{MenuBuilder, MenuItemBuilder, PredefinedMenuItem},
    tray::TrayIconBuilder,
    AppHandle, Emitter,
};

pub fn create_tray(app: &AppHandle) -> Result<(), String> {
    let history = MenuItemBuilder::with_id("history", "History")
        .build(app)
        .map_err(|e| format!("Failed to build History menu item: {e}"))?;
    let settings = MenuItemBuilder::with_id("settings", "Settings")
        .build(app)
        .map_err(|e| format!("Failed to build Settings menu item: {e}"))?;
    let separator = PredefinedMenuItem::separator(app)
        .map_err(|e| format!("Failed to build separator: {e}"))?;
    let quit = MenuItemBuilder::with_id("quit", "Quit")
        .build(app)
        .map_err(|e| format!("Failed to build Quit menu item: {e}"))?;

    let menu = MenuBuilder::new(app)
        .items(&[&history, &settings, &separator, &quit])
        .build()
        .map_err(|e| format!("Failed to build tray menu: {e}"))?;

    let app_handle = app.clone();
    TrayIconBuilder::new()
        .menu(&menu)
        .on_menu_event(move |_app, event| {
            let action = event.id().as_ref();
            if action == "quit" {
                app_handle.exit(0);
                return;
            }
            let _ = app_handle.emit("tray-action", action.to_string());
        })
        .build(app)
        .map_err(|e| format!("Failed to create tray icon: {e}"))?;

    Ok(())
}

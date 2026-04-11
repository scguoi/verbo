use tauri::{AppHandle, Emitter};
use tauri_plugin_global_shortcut::{GlobalShortcutExt, Shortcut, ShortcutState};

#[derive(Clone, serde::Serialize)]
struct HotkeyEvent {
    id: String,
    action: String,
}

#[tauri::command]
pub fn register_hotkeys(app: AppHandle, shortcuts: Vec<(String, String)>) -> Result<(), String> {
    let shortcut_manager = app.global_shortcut();

    shortcut_manager
        .unregister_all()
        .map_err(|e| format!("Failed to unregister existing hotkeys: {e}"))?;

    for (id, accelerator) in shortcuts {
        let shortcut: Shortcut = accelerator
            .parse()
            .map_err(|e| format!("Invalid shortcut '{accelerator}': {e}"))?;

        let id_pressed = id.clone();
        let id_released = id.clone();
        let app_handle = app.clone();

        shortcut_manager
            .on_shortcut(shortcut, move |_app, _shortcut, event| {
                let (action, hotkey_id) = match event.state {
                    ShortcutState::Pressed => ("pressed", &id_pressed),
                    ShortcutState::Released => ("released", &id_released),
                };
                let payload = HotkeyEvent {
                    id: hotkey_id.clone(),
                    action: action.to_string(),
                };
                let _ = app_handle.emit("hotkey", &payload);
            })
            .map_err(|e| format!("Failed to register shortcut '{id}': {e}"))?;
    }

    Ok(())
}

#[tauri::command]
pub fn unregister_all_hotkeys(app: AppHandle) -> Result<(), String> {
    app.global_shortcut()
        .unregister_all()
        .map_err(|e| format!("Failed to unregister hotkeys: {e}"))?;
    Ok(())
}

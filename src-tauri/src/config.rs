use serde_json::Value;
use std::fs;
use std::path::PathBuf;

fn config_dir() -> PathBuf {
    let base = dirs::config_dir().unwrap_or_else(|| PathBuf::from("."));
    base.join("verbo")
}

fn config_path() -> PathBuf {
    config_dir().join("config.json")
}

#[tauri::command]
pub fn read_config() -> Result<Value, String> {
    let path = config_path();
    if !path.exists() {
        return Ok(Value::Null);
    }
    let content = fs::read_to_string(&path).map_err(|e| format!("Failed to read config: {e}"))?;
    let value: Value =
        serde_json::from_str(&content).map_err(|e| format!("Failed to parse config: {e}"))?;
    Ok(value)
}

#[tauri::command]
pub fn write_config(config: Value) -> Result<(), String> {
    let dir = config_dir();
    fs::create_dir_all(&dir).map_err(|e| format!("Failed to create config dir: {e}"))?;

    let json =
        serde_json::to_string_pretty(&config).map_err(|e| format!("Failed to serialize: {e}"))?;
    fs::write(config_path(), json).map_err(|e| format!("Failed to write config: {e}"))?;
    Ok(())
}

#[tauri::command]
pub fn get_config_path() -> String {
    config_path().to_string_lossy().into_owned()
}

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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn config_dir_ends_with_verbo() {
        let dir = config_dir();
        assert_eq!(dir.file_name().unwrap(), "verbo");
    }

    #[test]
    fn config_path_ends_with_config_json() {
        let path = config_path();
        assert_eq!(path.file_name().unwrap(), "config.json");
    }

    #[test]
    fn config_path_is_inside_config_dir() {
        let dir = config_dir();
        let path = config_path();
        assert!(path.starts_with(&dir));
    }

    #[test]
    fn read_config_returns_null_for_nonexistent() {
        // config_path points to a real location, but if verbo hasn't been
        // configured on this machine the file may not exist.
        // This test validates the function doesn't panic.
        let result = read_config();
        assert!(result.is_ok());
    }
}

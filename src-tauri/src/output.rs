use tauri::AppHandle;
use tauri_plugin_clipboard_manager::ClipboardExt;

fn escape_applescript(text: &str) -> String {
    text.replace('\\', "\\\\").replace('"', "\\\"")
}

#[tauri::command]
pub fn simulate_input(text: String) -> Result<(), String> {
    let escaped = escape_applescript(&text);
    let script = format!(
        "tell application \"System Events\" to keystroke \"{}\"",
        escaped
    );

    let output = std::process::Command::new("osascript")
        .arg("-e")
        .arg(&script)
        .output()
        .map_err(|e| format!("Failed to run osascript: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("osascript error: {stderr}"));
    }

    Ok(())
}

#[tauri::command]
pub fn copy_to_clipboard(app: AppHandle, text: String) -> Result<(), String> {
    app.clipboard()
        .write_text(&text)
        .map_err(|e| format!("Failed to copy to clipboard: {e}"))?;
    Ok(())
}

#[tauri::command]
pub fn check_accessibility_permission() -> bool {
    let output = std::process::Command::new("osascript")
        .arg("-e")
        .arg("tell application \"System Events\" to keystroke \"\"")
        .output();

    match output {
        Ok(result) => result.status.success(),
        Err(_) => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn escape_plain_text() {
        assert_eq!(escape_applescript("hello"), "hello");
    }

    #[test]
    fn escape_empty() {
        assert_eq!(escape_applescript(""), "");
    }

    #[test]
    fn escape_backslash() {
        assert_eq!(escape_applescript("a\\b"), "a\\\\b");
    }

    #[test]
    fn escape_double_quote() {
        assert_eq!(escape_applescript(r#"say "hi""#), r#"say \"hi\""#);
    }

    #[test]
    fn escape_mixed() {
        assert_eq!(escape_applescript(r#"a\"b"#), r#"a\\\"b"#);
    }

    #[test]
    fn escape_unicode() {
        assert_eq!(escape_applescript("你好世界"), "你好世界");
    }

    #[test]
    fn escape_newline_preserved() {
        assert_eq!(escape_applescript("a\nb"), "a\nb");
    }
}

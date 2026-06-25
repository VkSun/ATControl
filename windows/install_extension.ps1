$extPath = Join-Path $env:APPDATA "ATControl\extension"

# Открываем Chrome на странице расширений
$chrome = @(
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($chrome) {
    Start-Process $chrome "chrome://extensions"
} else {
    Start-Process "chrome://extensions"
}

Start-Sleep -Seconds 1

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show(
    "Расширение ATControl скопировано на ваш компьютер.`n`n" +
    "Чтобы установить его в Chrome:`n`n" +
    "  1. В открывшемся Chrome включите`n" +
    "     «Режим разработчика» (переключатель вверху справа)`n`n" +
    "  2. Нажмите «Загрузить распакованное расширение»`n`n" +
    "  3. Выберите папку:`n" +
    "     $extPath",
    "Установка расширения ATControl",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null

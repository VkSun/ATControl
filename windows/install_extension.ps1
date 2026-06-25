Add-Type -AssemblyName System.Windows.Forms

$extPath = Join-Path $env:APPDATA "ATControl\extension"

# Предупреждение о совместимости
$result = [System.Windows.Forms.MessageBox]::Show(
    "Расширение ATControl работает только в браузерах на основе Chromium:`n`n" +
    "  ✓  Google Chrome`n" +
    "  ✓  Microsoft Edge`n" +
    "  ✓  Brave`n" +
    "  ✓  Vivaldi`n" +
    "  ✓  Яндекс Браузер`n`n" +
    "Не поддерживается:`n" +
    "  ✗  Opera`n" +
    "  ✗  Mozilla Firefox`n`n" +
    "Продолжить установку расширения?",
    "Совместимость расширения ATControl",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Information
)

if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { exit }

# Определяем браузер по умолчанию
$progId = ""
try {
    $progId = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" -ErrorAction Stop).ProgId
} catch { }

# Определяем тип браузера
$browserType = switch -Wildcard ($progId) {
    "*Chrome*"    { "chrome" }
    "*Edge*"      { "edge" }
    "*Brave*"     { "brave" }
    "*Vivaldi*"   { "vivaldi" }
    "*YaBrowser*" { "yandex" }
    "*Opera*"     { "opera" }
    "*Firefox*"   { "firefox" }
    "*Mozilla*"   { "firefox" }
    default       { "unknown" }
}

# Opera и Firefox не поддерживаются
if ($browserType -eq "opera" -or $browserType -eq "firefox") {
    [System.Windows.Forms.MessageBox]::Show(
        "Ваш браузер по умолчанию не поддерживается расширением ATControl.`n`n" +
        "Установите расширение вручную в одном из поддерживаемых браузеров:`n" +
        "Google Chrome, Microsoft Edge, Brave, Vivaldi или Яндекс Браузер.",
        "Браузер не поддерживается",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    exit
}

# Получаем путь к исполняемому файлу браузера через реестр
function Get-BrowserExe($id) {
    try {
        $cmd = (Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\$id\shell\open\command" -ErrorAction Stop).'(Default)'
        if ($cmd -match '"([^"]+\.exe)"') { return $matches[1] }
        if ($cmd -match '^([^\s"]+\.exe)')  { return $matches[1] }
    } catch { }
    return $null
}

$extUrl = switch ($browserType) {
    "chrome"  { "chrome://extensions" }
    "edge"    { "edge://extensions" }
    "brave"   { "brave://extensions" }
    "vivaldi" { "vivaldi://extensions" }
    "yandex"  { "browser://extensions" }
    default   { "chrome://extensions" }
}

$browserExe = Get-BrowserExe $progId
$opened = $false

if ($browserExe -and (Test-Path $browserExe)) {
    try { Start-Process $browserExe "--new-tab $extUrl"; $opened = $true } catch { }
}

if (-not $opened) {
    try { Start-Process $extUrl; $opened = $true } catch { }
}

if ($opened) { Start-Sleep -Seconds 1 }

# Инструкция по установке
[System.Windows.Forms.MessageBox]::Show(
    "Файлы расширения скопированы на компьютер.`n`n" +
    "Для установки в браузере:`n`n" +
    "  1. Включите «Режим разработчика»`n" +
    "     (переключатель вверху справа)`n`n" +
    "  2. Нажмите «Загрузить распакованное`n" +
    "     расширение»`n`n" +
    "  3. Выберите папку:`n     $extPath",
    "Установка расширения ATControl",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null

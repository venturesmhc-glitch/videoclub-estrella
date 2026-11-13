// Ejecuta un comando de depuración en el servidor del Play (ver src/ServerScriptService/Server/Depurar.lua).
// Uso:  node dbg.js estado | saltar 120 | tomar | gondola TERROR | vcr | danadas | mostrador | cine NOMBRE [desde] [foto]
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const args = process.argv.slice(2);
if (!args.length) { console.error('uso: node dbg.js <comando> [argumentos]'); process.exit(2); }

const lua = args.map(a => (/^-?\d+(\.\d+)?$/.test(a) ? a : JSON.stringify(a))).join(', ');
const codigo = `return game.ServerStorage.Depurar:Invoke(${lua})`;
const tmp = path.join(os.tmpdir(), 'rolbox_dbg.json');
fs.writeFileSync(tmp, JSON.stringify({ datamodel_type: 'Server', code: codigo }));
process.stdout.write(execFileSync(process.execPath, [path.join(__dirname, 'mcp-call.js'), 'execute_luau', '@' + tmp], { encoding: 'utf8' }));

// Cinemáticas: Studio tiene que estar a la vista y con el foco mientras se graba. Si está minimizado no dibuja el 3D, y si otra
// ventana tiene el foco (la terminal, OBS) Roblox silencia el sonido. Por eso, al lanzar un clip se trae Studio al frente
// (los 3 s de cuenta atrás alcanzan). Para no hacerlo: DBG_SIN_FOCO=1.
if (args[0] === 'cine' && !['lista', 'parar'].includes(args[1]) && !process.env.DBG_SIN_FOCO && process.platform === 'win32') {
  const ps = [
    "Add-Type -Name W -Namespace Cine -MemberDefinition '[DllImport(\"user32.dll\")] public static extern bool ShowWindow(System.IntPtr h, int c); [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(System.IntPtr h); [DllImport(\"user32.dll\")] public static extern bool IsIconic(System.IntPtr h);'",
    "$p = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1",
    "if ($p) { if ([Cine.W]::IsIconic($p.MainWindowHandle)) { [Cine.W]::ShowWindow($p.MainWindowHandle, 9) | Out-Null }; [Cine.W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null }",
  ].join('; ');
  try { execFileSync('powershell', ['-NoProfile', '-Command', ps], { stdio: 'ignore' }); } catch (e) { /* no es grave: se enfoca a mano */ }
}

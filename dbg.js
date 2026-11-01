// Ejecuta un comando de depuración en el servidor del Play (ver src/ServerScriptService/Server/Depurar.lua).
// Uso:  node dbg.js estado | saltar 120 | tomar | gondola TERROR | vcr | danadas | mostrador
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

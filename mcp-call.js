// Llama a una herramienta del servidor MCP de Roblox Studio y muestra el resultado.
// Uso: node mcp-call.js <herramienta> '<json>'      (lista de herramientas: node mcp-call.js --list)
// Los argumentos pueden ser JSON en línea, "@archivo.json" (JSON desde un archivo) o "@archivo.lua"
// (código Luau para execute_luau, en el DataModel de edición).
// Si hay varias instancias de Studio abiertas se usa la que tenga un place con nombre (o la de STUDIO_ID).
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

let [tool, argsJson] = process.argv.slice(2);
if (!tool) { console.error('uso: node mcp-call.js <herramienta|--list> [jsonArgs]'); process.exit(2); }
if (argsJson && argsJson.startsWith('@')) {
  const file = argsJson.slice(1);
  const text = fs.readFileSync(file, 'utf8');
  argsJson = file.endsWith('.lua') ? JSON.stringify({ datamodel_type: 'Edit', code: text }) : text;
}

const p = spawn(path.join(__dirname, 'studio-mcp.cmd'), [], { shell: true });
let buf = '';
let reintentos = 0;
const send = o => p.stdin.write(JSON.stringify(o) + '\n');
const done = code => { p.kill(); process.exit(code); };

function imprimir(result) {
  let n = 0;
  for (const c of result.content || []) {
    if (c.type === 'text') console.log(c.text);
    else if (c.type === 'image' && c.data) {
      // Las imágenes se guardan en disco y se imprime la ruta.
      const ext = (c.mimeType || 'image/png').split('/')[1] || 'png';
      const out = path.join(os.tmpdir(), `mcp_img_${Date.now()}_${n++}.${ext}`);
      fs.writeFileSync(out, Buffer.from(c.data, 'base64'));
      console.log(`[image] ${out}`);
    } else console.log(`[${c.type}]`);
  }
  if (result.isError) done(1);
}

p.stdout.on('data', d => {
  buf += d;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (!line) continue;
    const m = JSON.parse(line);
    if (m.id === 1) {
      send({ jsonrpc: '2.0', method: 'notifications/initialized' });
      if (tool === '--list') send({ jsonrpc: '2.0', id: 3, method: 'tools/list', params: {} });
      else send({ jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'list_roblox_studios', arguments: {} } });
    } else if (m.id === 2) {
      // Elegir la instancia de Studio.
      let studios = [];
      try { studios = JSON.parse(m.result.content[0].text).studios || []; } catch (e) { /* sin lista */ }
      if (tool === 'list_roblox_studios') { imprimir(m.result); done(0); }
      // Studio a veces tarda en registrarse tras cerrarse la conexión anterior: se reintenta unos segundos.
      if (studios.length === 0 && reintentos < 20) {
        reintentos++;
        setTimeout(() => send({ jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'list_roblox_studios', arguments: {} } }), 4000);
        continue;
      }
      const elegido = studios.find(s => s.id === process.env.STUDIO_ID) || studios.find(s => s.name) || studios[0];
      const args = argsJson ? JSON.parse(argsJson) : {};
      if (elegido) args.studio_id = elegido.id;
      send({ jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: tool, arguments: args } });
    } else if (m.id === 3) {
      if (m.error) { console.error('ERROR', JSON.stringify(m.error)); done(1); }
      if (tool === '--list') {
        for (const t of m.result.tools) console.log(`${t.name}: ${(t.description || '').split('\n')[0]}`);
      } else {
        imprimir(m.result);
      }
      done(0);
    }
  }
});
p.stderr.on('data', () => {});
send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'mcp-call', version: '1' } } });
setTimeout(() => { console.error('timeout'); done(1); }, 180000);

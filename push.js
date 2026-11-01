// Sincroniza rolbox/src -> Roblox Studio (a través del puente mcp-call.js).
// Convención de archivos:  X.lua = ModuleScript | X.server.lua = Script | X.client.lua = LocalScript
// La primera carpeta es el servicio (ReplicatedStorage, ServerScriptService, StarterPlayer, ...);
// el resto de carpetas se crean como Folder. Uso:  node push.js [filtro-de-ruta]
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const SRC = path.join(__dirname, 'src');
const filtro = process.argv[2] || '';
const LIMITE_CHUNK = 60000;

function archivos(dir) {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...archivos(p));
    else if (e.name.endsWith('.lua')) out.push(p);
  }
  return out;
}

function descriptor(file) {
  const rel = path.relative(SRC, file).split(path.sep);
  let nombre = rel.pop();
  let clase = 'ModuleScript';
  if (nombre.endsWith('.server.lua')) { clase = 'Script'; nombre = nombre.slice(0, -11); }
  else if (nombre.endsWith('.client.lua')) { clase = 'LocalScript'; nombre = nombre.slice(0, -11); }
  else nombre = nombre.slice(0, -4);
  return { ruta: rel, clase, nombre, fuente: fs.readFileSync(file, 'utf8') };
}

function literal(texto) {
  let n = 3;
  while (texto.includes(']' + '='.repeat(n) + ']')) n++;
  const eq = '='.repeat(n);
  return `[${eq}[\n${texto}]${eq}]`;
}

const CABECERA = `
local resultados = {}
local function carpetaHijo(padre, nombre)
	local h = padre:FindFirstChild(nombre)
	if not h then h = Instance.new("Folder"); h.Name = nombre; h.Parent = padre end
	return h
end
local function poner(ruta, clase, nombre, fuente)
	local nodo = game:GetService(ruta[1])
	for i = 2, #ruta do nodo = carpetaHijo(nodo, ruta[i]) end
	local s = nodo:FindFirstChild(nombre)
	if s and s.ClassName ~= clase then s:Destroy(); s = nil end
	if not s then s = Instance.new(clase); s.Name = nombre; s.Parent = nodo end
	s.Source = fuente
	table.insert(resultados, table.concat(ruta, "/") .. "/" .. nombre .. " (" .. clase .. ")")
end
`;

function enviar(chunk) {
  const tmp = path.join(os.tmpdir(), 'rolbox_push.lua');
  fs.writeFileSync(tmp, CABECERA + chunk + '\nreturn table.concat(resultados, "\\n")\n');
  const salida = execFileSync(process.execPath, [path.join(__dirname, 'mcp-call.js'), 'execute_luau', '@' + tmp], { encoding: 'utf8' });
  process.stdout.write(salida);
}

const todos = archivos(SRC).map(descriptor).filter(d => [...d.ruta, d.nombre].join('/').includes(filtro));
let chunk = '';
for (const d of todos) {
  const linea = `poner({${d.ruta.map(r => JSON.stringify(r)).join(',')}}, ${JSON.stringify(d.clase)}, ${JSON.stringify(d.nombre)}, ${literal(d.fuente)})\n`;
  if (chunk.length + linea.length > LIMITE_CHUNK && chunk) { enviar(chunk); chunk = ''; }
  chunk += linea;
}
if (chunk) enviar(chunk);
console.log(`\n${todos.length} script(s) sincronizados.`);

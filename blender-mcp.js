#!/usr/bin/env node
// Servidor MCP (stdio) para Blender: puente hacia el add-on oficial "MCP" de Blender Lab (Blender 5.1+).
// El add-on escucha en localhost:9876 (Preferencias > Add-ons > MCP > Start) y recibe JSON terminado en
// byte nulo: {"type":"execute","code":"...","strict_json":bool}. Una conexion por peticion.
// El codigo corre dentro de Blender y debe dejar su resultado en el dict `result`.
const net = require("net");

const HOST = process.env.BLENDER_MCP_HOST || "localhost";
const PORT = parseInt(process.env.BLENDER_MCP_PORT || "9876", 10);
const TIMEOUT_MS = parseInt(process.env.BLENDER_MCP_TIMEOUT_MS || "120000", 10);

function enBlender(code, strictJson) {
  return new Promise((resolve, reject) => {
    const sock = net.createConnection({ host: HOST, port: PORT });
    const trozos = [];
    let listo = false;
    const fin = (err, val) => {
      if (listo) return;
      listo = true;
      sock.destroy();
      err ? reject(err) : resolve(val);
    };
    sock.setTimeout(TIMEOUT_MS, () => fin(new Error("Blender no respondio a tiempo")));
    sock.on("connect", () =>
      sock.write(JSON.stringify({ type: "execute", code, strict_json: !!strictJson }) + "\0")
    );
    sock.on("data", (d) => {
      trozos.push(d);
      if (d.includes(0)) {
        try {
          const txt = Buffer.concat(trozos).toString("utf8").split("\0")[0];
          fin(null, JSON.parse(txt));
        } catch (e) {
          fin(e);
        }
      }
    });
    sock.on("error", (e) =>
      fin(
        new Error(
          `No se pudo conectar con Blender en ${HOST}:${PORT} (${e.code || e.message}). ` +
            "Abri Blender y en Edit > Preferences > Add-ons > MCP toca 'Start MCP Bridge Server'."
        )
      )
    );
    sock.on("close", () => fin(new Error("Blender cerro la conexion sin responder")));
  });
}

const PY_ESCENA = `
import bpy
sc = bpy.context.scene
result = {
    "archivo": bpy.data.filepath or "(sin guardar)",
    "blender": bpy.app.version_string,
    "escena": sc.name,
    "motor": sc.render.engine,
    "frame": [sc.frame_start, sc.frame_end, sc.frame_current],
    "objetos": [
        {"nombre": o.name, "tipo": o.type, "ubicacion": [round(v, 3) for v in o.location],
         "escala": [round(v, 3) for v in o.scale], "padre": o.parent.name if o.parent else None}
        for o in sc.objects
    ],
    "materiales": [m.name for m in bpy.data.materials],
    "colecciones": [c.name for c in bpy.data.collections],
}
`;

const TOOLS = [
  {
    name: "execute_python",
    description:
      "Ejecuta codigo Python dentro de Blender (bpy disponible). Para devolver datos asigna un dict a la variable `result`, " +
      "por ejemplo: result = {'n': len(bpy.data.objects)}. Lo que se imprima vuelve como stdout. " +
      "Corre en el hilo principal de Blender; evita bucles largos.",
    inputSchema: {
      type: "object",
      properties: { code: { type: "string", description: "Codigo Python a ejecutar" } },
      required: ["code"],
    },
  },
  {
    name: "get_scene_info",
    description: "Resumen de la escena actual de Blender: objetos, materiales, colecciones, motor de render y frames.",
    inputSchema: { type: "object", properties: {} },
  },
];

async function llamar(nombre, args) {
  let r;
  if (nombre === "execute_python") r = await enBlender(String((args && args.code) || ""), false);
  else if (nombre === "get_scene_info") r = await enBlender(PY_ESCENA, true);
  else throw new Error("Herramienta desconocida: " + nombre);
  const partes = [];
  if (r.status === "error") partes.push("ERROR: " + (r.message || ""));
  else partes.push(JSON.stringify(r.result, null, 2));
  if (r.stdout) partes.push("stdout:\n" + r.stdout);
  if (r.stderr) partes.push("stderr:\n" + r.stderr);
  return { content: [{ type: "text", text: partes.join("\n\n") }], isError: r.status === "error" };
}

const enviar = (m) => process.stdout.write(JSON.stringify(m) + "\n");

async function manejar(msg) {
  const { id, method, params } = msg;
  if (id === undefined) return; // notificaciones (initialized, cancelled...)
  try {
    if (method === "initialize") {
      enviar({
        jsonrpc: "2.0",
        id,
        result: {
          protocolVersion: (params && params.protocolVersion) || "2025-06-18",
          capabilities: { tools: {} },
          serverInfo: { name: "blender", version: "1.0.0" },
        },
      });
    } else if (method === "ping") enviar({ jsonrpc: "2.0", id, result: {} });
    else if (method === "tools/list") enviar({ jsonrpc: "2.0", id, result: { tools: TOOLS } });
    else if (method === "tools/call") {
      try {
        enviar({ jsonrpc: "2.0", id, result: await llamar(params.name, params.arguments) });
      } catch (e) {
        enviar({ jsonrpc: "2.0", id, result: { content: [{ type: "text", text: String(e.message) }], isError: true } });
      }
    } else enviar({ jsonrpc: "2.0", id, error: { code: -32601, message: "Metodo no soportado: " + method } });
  } catch (e) {
    enviar({ jsonrpc: "2.0", id, error: { code: -32603, message: String(e.message) } });
  }
}

let buf = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const linea = buf.slice(0, i).trim();
    buf = buf.slice(i + 1);
    if (!linea) continue;
    try {
      manejar(JSON.parse(linea));
    } catch (e) {
      /* linea invalida: se ignora */
    }
  }
});
process.stdin.on("end", () => process.exit(0));

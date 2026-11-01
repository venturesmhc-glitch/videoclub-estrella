#!/bin/bash
# uso: foto.sh camx camy camz mirx miry mirz
cd "$(dirname "$0")"
sed "s/CAMX/$1/;s/CAMY/$2/;s/CAMZ/$3/;s/MIRX/$4/;s/MIRY/$5/;s/MIRZ/$6/" .tmp/cam.lua > .tmp/cam2.lua
node -e 'const fs=require("fs");fs.writeFileSync(".tmp/cam2.json",JSON.stringify({datamodel_type:"Client",code:fs.readFileSync(".tmp/cam2.lua","utf8")}))'
node mcp-call.js execute_luau @.tmp/cam2.json 2>&1 | head -2

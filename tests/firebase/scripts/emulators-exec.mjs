#!/usr/bin/env node
// Lanza `firebase emulators:exec` con el firebase.json de la raíz del repositorio y el proyecto
// demo (sin acceso a producción), y ejecuta el comando de pruebas indicado.
//
//   node scripts/emulators-exec.mjs <emuladores> "<comando>"
//   node scripts/emulators-exec.mjs firestore,storage "node --test rules/*.test.mjs"
//
// Equivale a:
//   firebase emulators:exec --only <emuladores> --project demo-pasaporte-test \
//     --config ../../firebase.json "<comando>"
//
// Además sube FUNCTIONS_DISCOVERY_TIMEOUT a 60 s y antepone $JAVA_HOME/bin al PATH. En Windows, el instalador de Oracle deja primero en el
// PATH un lanzador (`Common Files\Oracle\Java\javapath\java.exe`) que abre la JVM real como
// proceso hijo; al terminar, la CLI de Firebase mata solo el lanzador y el emulador de Firestore
// queda huérfano ocupando el puerto 8080 (la siguiente ejecución falla con "port taken").
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const PROJECT_ID = 'demo-pasaporte-test';

const [only, command] = process.argv.slice(2);
if (!only || !command) {
  console.error('Uso: node scripts/emulators-exec.mjs <emuladores> "<comando>"');
  process.exit(2);
}

const here = path.dirname(fileURLToPath(import.meta.url));
const testsDir = path.resolve(here, '..');
const configPath = path.resolve(testsDir, '..', '..', 'firebase.json');

const env = { ...process.env };
// La CLI da 10 s para descubrir las funciones; en un arranque en frío (Windows, antivirus) no
// siempre alcanza y el script de pruebas empezaría sin funciones cargadas.
env.FUNCTIONS_DISCOVERY_TIMEOUT ??= '60';
if (env.JAVA_HOME) {
  const pathKey = Object.keys(env).find((k) => k.toUpperCase() === 'PATH') ?? 'PATH';
  env[pathKey] = [path.join(env.JAVA_HOME, 'bin'), env[pathKey]].filter(Boolean).join(path.delimiter);
}

const quote = (s) => `"${s.replace(/"/g, '\\"')}"`;
const line = [
  'firebase',
  'emulators:exec',
  '--only',
  only,
  '--project',
  PROJECT_ID,
  '--config',
  quote(configPath),
  quote(command),
].join(' ');

const child = spawn(line, { cwd: testsDir, env, shell: true, stdio: 'inherit' });
child.on('exit', (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
child.on('error', (err) => {
  console.error(`No se pudo ejecutar la CLI de Firebase: ${err.message}`);
  process.exit(1);
});

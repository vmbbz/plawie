import { createHash } from 'node:crypto';
import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = join(repositoryRoot, 'assets', 'vrm');
const outputRoot = join(
  repositoryRoot,
  'site',
  'assets',
  'vrm',
  'gemini-v1',
);

const binaryAssets = [
  ['gemini.vrm', 'gemini.vrm'],
  [join('animations', 'idle_loop.vrma'), join('animations', 'idle_loop.vrma')],
  [join('lib', 'three.module.js'), join('lib', 'three.module.js')],
];

const moduleAssets = [
  [join('lib', 'GLTFLoader.js'), join('lib', 'GLTFLoader.js'), './three.module.js'],
  [join('lib', 'three-vrm.module.js'), join('lib', 'three-vrm.module.js'), './three.module.js'],
  [
    join('lib', 'three-vrm-animation.module.js'),
    join('lib', 'three-vrm-animation.module.js'),
    './three.module.js',
  ],
  [
    join('utils', 'BufferGeometryUtils.js'),
    join('utils', 'BufferGeometryUtils.js'),
    '../lib/three.module.js',
  ],
];

const ensureParent = async (path) => mkdir(dirname(path), { recursive: true });

const rewriteThreeSpecifier = (source, replacement) => source
  .replaceAll("from 'three'", `from '${replacement}'`)
  .replaceAll('from "three"', `from "${replacement}"`);

await rm(outputRoot, { recursive: true, force: true });
await mkdir(outputRoot, { recursive: true });

for (const [sourceRelative, outputRelative] of binaryAssets) {
  const source = join(sourceRoot, sourceRelative);
  const output = join(outputRoot, outputRelative);
  await ensureParent(output);
  await copyFile(source, output);
}

for (const [sourceRelative, outputRelative, threeSpecifier] of moduleAssets) {
  const source = join(sourceRoot, sourceRelative);
  const output = join(outputRoot, outputRelative);
  const contents = await readFile(source, 'utf8');
  await ensureParent(output);
  await writeFile(output, rewriteThreeSpecifier(contents, threeSpecifier));
}

const model = await readFile(join(outputRoot, 'gemini.vrm'));
const manifest = {
  asset: 'gemini.vrm',
  bytes: model.byteLength,
  sha256: createHash('sha256').update(model).digest('hex'),
  animation: 'animations/idle_loop.vrma',
  version: 'gemini-v1',
};
await writeFile(
  join(outputRoot, 'manifest.json'),
  `${JSON.stringify(manifest, null, 2)}\n`,
);

console.log(
  `Prepared ${manifest.version}: ${manifest.bytes} bytes, sha256 ${manifest.sha256}`,
);

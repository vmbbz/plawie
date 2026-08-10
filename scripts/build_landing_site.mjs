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

const limbAssets = [
  'Light_Wave_Left_01.vrma',
  'Light_Wave_Right_01.vrma',
].map((fileName) => [
  join('animations', 'limbs', fileName),
  join('animations', 'limbs', fileName),
]);

binaryAssets.push(...limbAssets);

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
  limbAnimations: await Promise.all(limbAssets.map(async ([, outputRelative]) => {
    const animation = await readFile(join(outputRoot, outputRelative));
    return {
      asset: outputRelative.replaceAll('\\', '/'),
      bytes: animation.byteLength,
      sha256: createHash('sha256').update(animation).digest('hex'),
    };
  })),
  version: 'gemini-v1',
};
await writeFile(
  join(outputRoot, 'manifest.json'),
  `${JSON.stringify(manifest, null, 2)}\n`,
);

const headers = await readFile(join(repositoryRoot, 'site', '_headers'), 'utf8');
const cspMatch = headers.match(/^\s*Content-Security-Policy:\s*(.+)$/m);
if (!cspMatch) {
  throw new Error('Landing-site build requires a Content-Security-Policy header');
}

const cspDirectives = new Map(
  cspMatch[1]
    .split(';')
    .map((directive) => directive.trim())
    .filter(Boolean)
    .map((directive) => {
      const [name, ...sources] = directive.split(/\s+/);
      return [name, sources];
    }),
);
const requiredCspSources = new Map([
  ['connect-src', ["'self'", 'blob:']],
  ['img-src', ["'self'", 'data:', 'blob:']],
]);

for (const [directive, requiredSources] of requiredCspSources) {
  const configuredSources = cspDirectives.get(directive) ?? [];
  for (const source of requiredSources) {
    if (!configuredSources.includes(source)) {
      throw new Error(
        `Landing-site CSP ${directive} must include ${source} for embedded VRM textures`,
      );
    }
  }
}

const scriptSources = cspDirectives.get('script-src') ?? [];
for (const unsafeSource of ["'unsafe-inline'", "'unsafe-eval'"]) {
  if (scriptSources.includes(unsafeSource)) {
    throw new Error(`Landing-site CSP must not include ${unsafeSource}`);
  }
}

const indexHtml = await readFile(join(repositoryRoot, 'site', 'index.html'), 'utf8');
const jsonLdMatch = indexHtml.match(
  /<script type="application\/ld\+json">([\s\S]*?)<\/script>/,
);
if (!jsonLdMatch) {
  throw new Error('Landing-site build requires one inline JSON-LD block');
}
const jsonLdSource = `'sha256-${createHash('sha256')
  .update(jsonLdMatch[1])
  .digest('base64')}'`;
if (!scriptSources.includes(jsonLdSource)) {
  throw new Error(
    `Landing-site CSP script-src must include the current JSON-LD hash ${jsonLdSource}`,
  );
}

console.log(
  `Prepared ${manifest.version}: ${manifest.bytes} bytes, sha256 ${manifest.sha256}`,
);

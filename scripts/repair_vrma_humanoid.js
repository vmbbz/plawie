#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const REQUIRED_BONES = [
  "hips",
  "spine",
  "head",
  "leftUpperLeg",
  "leftLowerLeg",
  "leftFoot",
  "rightUpperLeg",
  "rightLowerLeg",
  "rightFoot",
  "leftUpperArm",
  "leftLowerArm",
  "leftHand",
  "rightUpperArm",
  "rightLowerArm",
  "rightHand",
];

const ROKOKO_NODE_TO_VRM_BONE = {
  Hips: "hips",
  Spine1: "spine",
  Spine3: "chest",
  Spine4: "upperChest",
  Neck: "neck",
  Head: "head",

  LeftThigh: "leftUpperLeg",
  LeftShin: "leftLowerLeg",
  LeftFoot: "leftFoot",
  LeftToe: "leftToes",
  RightThigh: "rightUpperLeg",
  RightShin: "rightLowerLeg",
  RightFoot: "rightFoot",
  RightToe: "rightToes",

  LeftShoulder: "leftShoulder",
  LeftArm: "leftUpperArm",
  LeftForeArm: "leftLowerArm",
  LeftHand: "leftHand",
  RightShoulder: "rightShoulder",
  RightArm: "rightUpperArm",
  RightForeArm: "rightLowerArm",
  RightHand: "rightHand",

  LeftFinger1Metacarpal: "leftThumbMetacarpal",
  LeftFinger1Proximal: "leftThumbProximal",
  LeftFinger1Distal: "leftThumbDistal",
  LeftFinger2Proximal: "leftIndexProximal",
  LeftFinger2Medial: "leftIndexIntermediate",
  LeftFinger2Distal: "leftIndexDistal",
  LeftFinger3Proximal: "leftMiddleProximal",
  LeftFinger3Medial: "leftMiddleIntermediate",
  LeftFinger3Distal: "leftMiddleDistal",
  LeftFinger4Proximal: "leftRingProximal",
  LeftFinger4Medial: "leftRingIntermediate",
  LeftFinger4Distal: "leftRingDistal",
  LeftFinger5Proximal: "leftLittleProximal",
  LeftFinger5Medial: "leftLittleIntermediate",
  LeftFinger5Distal: "leftLittleDistal",

  RightFinger1Metacarpal: "rightThumbMetacarpal",
  RightFinger1Proximal: "rightThumbProximal",
  RightFinger1Distal: "rightThumbDistal",
  RightFinger2Proximal: "rightIndexProximal",
  RightFinger2Medial: "rightIndexIntermediate",
  RightFinger2Distal: "rightIndexDistal",
  RightFinger3Proximal: "rightMiddleProximal",
  RightFinger3Medial: "rightMiddleIntermediate",
  RightFinger3Distal: "rightMiddleDistal",
  RightFinger4Proximal: "rightRingProximal",
  RightFinger4Medial: "rightRingIntermediate",
  RightFinger4Distal: "rightRingDistal",
  RightFinger5Proximal: "rightLittleProximal",
  RightFinger5Medial: "rightLittleIntermediate",
  RightFinger5Distal: "rightLittleDistal",
};

function usage() {
  console.error(
    "Usage: node scripts/repair_vrma_humanoid.js [--check|--write] <file-or-directory>..."
  );
}

function align4(value) {
  return (value + 3) & ~3;
}

function readGlb(filePath) {
  const buffer = fs.readFileSync(filePath);
  if (buffer.length < 12 || buffer.toString("ascii", 0, 4) !== "glTF") {
    throw new Error("not a binary glTF/VRMA file");
  }
  const version = buffer.readUInt32LE(4);
  if (version !== 2) throw new Error(`unsupported glTF version ${version}`);

  const chunks = [];
  let offset = 12;
  while (offset + 8 <= buffer.length) {
    const length = buffer.readUInt32LE(offset);
    const type = buffer.toString("ascii", offset + 4, offset + 8);
    offset += 8;
    chunks.push({ type, data: buffer.subarray(offset, offset + length) });
    offset += length;
  }
  const jsonChunk = chunks.find((chunk) => chunk.type === "JSON");
  if (!jsonChunk) throw new Error("missing JSON chunk");
  const json = JSON.parse(jsonChunk.data.toString("utf8").trim());
  return { chunks, json };
}

function writeGlb(filePath, chunks, json) {
  const nextJson = Buffer.from(`${JSON.stringify(json)}\n`, "utf8");
  const paddedJson = Buffer.concat([
    nextJson,
    Buffer.alloc(align4(nextJson.length) - nextJson.length, 0x20),
  ]);

  const nextChunks = chunks.map((chunk) =>
    chunk.type === "JSON" ? { type: "JSON", data: paddedJson } : chunk
  );
  const totalLength =
    12 + nextChunks.reduce((sum, chunk) => sum + 8 + chunk.data.length, 0);
  const output = Buffer.alloc(totalLength);
  output.write("glTF", 0, "ascii");
  output.writeUInt32LE(2, 4);
  output.writeUInt32LE(totalLength, 8);

  let offset = 12;
  for (const chunk of nextChunks) {
    output.writeUInt32LE(chunk.data.length, offset);
    output.write(chunk.type, offset + 4, "ascii");
    offset += 8;
    chunk.data.copy(output, offset);
    offset += chunk.data.length;
  }
  fs.writeFileSync(filePath, output);
}

function collectVrmaFiles(targets) {
  const files = [];
  for (const target of targets) {
    const resolved = path.resolve(target);
    if (!fs.existsSync(resolved)) {
      throw new Error(`target not found: ${target}`);
    }
    const stat = fs.statSync(resolved);
    if (stat.isDirectory()) {
      for (const entry of fs.readdirSync(resolved).sort()) {
        const child = path.join(resolved, entry);
        if (fs.statSync(child).isFile() && entry.toLowerCase().endsWith(".vrma")) {
          files.push(child);
        }
      }
    } else if (resolved.toLowerCase().endsWith(".vrma")) {
      files.push(resolved);
    }
  }
  return files;
}

function animationDurationSeconds(json) {
  const animation = json.animations?.[0];
  if (!animation) return 0;
  const accessors = new Set();
  for (const channel of animation.channels || []) {
    const sampler = animation.samplers?.[channel.sampler];
    if (sampler && typeof sampler.input === "number") accessors.add(sampler.input);
  }
  let duration = 0;
  for (const accessorIndex of accessors) {
    const max = json.accessors?.[accessorIndex]?.max;
    if (Array.isArray(max) && typeof max[0] === "number") {
      duration = Math.max(duration, max[0]);
    }
  }
  return duration;
}

function buildHumanBones(json) {
  const byName = new Map();
  for (let index = 0; index < (json.nodes || []).length; index += 1) {
    const name = json.nodes[index]?.name;
    if (typeof name === "string" && name.length > 0) byName.set(name, index);
  }
  const bones = {};
  for (const [nodeName, boneName] of Object.entries(ROKOKO_NODE_TO_VRM_BONE)) {
    const node = byName.get(nodeName);
    if (typeof node === "number") bones[boneName] = { node };
  }
  return bones;
}

function ensureHumanoid(json) {
  json.extensions ||= {};
  json.extensionsUsed ||= [];
  if (!json.extensionsUsed.includes("VRMC_vrm_animation")) {
    json.extensionsUsed.push("VRMC_vrm_animation");
  }
  const extension = (json.extensions.VRMC_vrm_animation ||= {});
  extension.specVersion ||= "1.0";
  extension.humanoid ||= {};
  const existing = extension.humanoid.humanBones;
  if (existing && Object.keys(existing).length > 0) return false;
  extension.humanoid.humanBones = buildHumanBones(json);
  return true;
}

function inspect(filePath, write) {
  const { chunks, json } = readGlb(filePath);
  const beforeBones =
    Object.keys(json.extensions?.VRMC_vrm_animation?.humanoid?.humanBones || {})
      .length;
  const changed = ensureHumanoid(json);
  const bones =
    json.extensions?.VRMC_vrm_animation?.humanoid?.humanBones || {};
  const missing = REQUIRED_BONES.filter((bone) => !bones[bone]);
  const animation = json.animations?.[0];
  const channels = animation?.channels?.length || 0;
  const duration = animationDurationSeconds(json);
  const ok = missing.length === 0 && channels > 0 && duration > 0;

  if (write && changed) writeGlb(filePath, chunks, json);

  return {
    file: path.relative(process.cwd(), filePath).replaceAll("\\", "/"),
    ok,
    changed,
    beforeBones,
    afterBones: Object.keys(bones).length,
    channels,
    duration,
    missing,
  };
}

function main() {
  const args = process.argv.slice(2);
  const write = args.includes("--write");
  const check = args.includes("--check") || !write;
  const targets = args.filter((arg) => arg !== "--write" && arg !== "--check");
  if (targets.length === 0) {
    usage();
    process.exit(2);
  }

  const files = collectVrmaFiles(targets);
  if (files.length === 0) throw new Error("no .vrma files found");
  const results = files.map((file) => inspect(file, write));

  for (const result of results) {
    const state = result.ok ? "OK" : "FAIL";
    const action = result.changed ? (write ? "repaired" : "needs-repair") : "unchanged";
    console.log(
      `${state} ${action} ${result.file} bones=${result.beforeBones}->${result.afterBones} channels=${result.channels} duration=${result.duration.toFixed(3)}`
    );
    if (result.missing.length > 0) {
      console.log(`  missing: ${result.missing.join(", ")}`);
    }
  }

  const failed = results.filter((result) => !result.ok);
  const wouldChange = check && results.some((result) => result.changed);
  if (failed.length > 0 || wouldChange) process.exit(1);
}

try {
  main();
} catch (error) {
  console.error(error?.stack || String(error));
  process.exit(1);
}

const fs = require("fs");
const path = require("path");

function safeRead(filePath, maxChars = 16000) {
  try {
    const content = fs.readFileSync(filePath, "utf8");
    return content.length > maxChars ? content.slice(0, maxChars) : content;
  } catch (_) {
    return "";
  }
}

function firstHeading(markdown, fallback) {
  const heading = markdown
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find((line) => line.startsWith("# "));
  if (!heading) return fallback;
  return heading.replace(/^#+\s*/, "").trim() || fallback;
}

function firstParagraph(markdown) {
  return markdown
    .split(/\r?\n\r?\n/)
    .map((block) => block.replace(/\s+/g, " ").trim())
    .find((block) => block && !block.startsWith("#") && !block.startsWith("---")) || "";
}

function classifySkill(slug, body) {
  const lower = `${slug}\n${body}`.toLowerCase();
  const androidNative = new Set(["device-node", "gestures", "tts-voice"]);
  if (androidNative.has(slug)) return "android-native";
  if (/\b(mac|macos|osascript|applescript|imessage|bear notes|things)\b/.test(lower)) {
    return "desktop-only";
  }
  if (/\b(api key|token|oauth|discord|slack|github|notion|trello|spotify|weather)\b/.test(lower)) {
    return "external-service";
  }
  if (/\b(shell|cli|command|tmux|python|node|npm|curl|brew)\b/.test(lower)) {
    return "shell-backed";
  }
  return "openclaw-skill";
}

function findSkillDocument(skillDir) {
  const preferred = path.join(skillDir, "SKILL.md");
  if (fs.existsSync(preferred)) return preferred;

  try {
    const markdown = fs
      .readdirSync(skillDir)
      .filter((name) => name.toLowerCase().endsWith(".md"))
      .sort();
    if (markdown.length > 0) return path.join(skillDir, markdown[0]);
  } catch (_) {
    return null;
  }

  return null;
}

function configToolsFromPath(configPath, errors) {
  try {
    return JSON.parse(safeRead(configPath, 64000) || "{}")?.tools ?? null;
  } catch (error) {
    errors.push(`config_parse_failed:${error?.message || String(error)}`);
    return null;
  }
}

function scanSkillRoot(skillsRoot) {
  const errors = [];
  const skillEntries = [];
  const countsByClass = {};

  try {
    if (!fs.existsSync(skillsRoot)) {
      return {
        ok: false,
        skillsRoot,
        skillCount: 0,
        skills: [],
        countsByClass,
        errors: ["skills_root_missing"]
      };
    }

    const slugs = fs
      .readdirSync(skillsRoot, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
      .filter((name) => !name.startsWith("."))
      .sort();

    for (const slug of slugs) {
      const skillDir = path.join(skillsRoot, slug);
      const documentPath = findSkillDocument(skillDir);
      const body = documentPath ? safeRead(documentPath) : "";
      const capabilityClass = classifySkill(slug, body);
      countsByClass[capabilityClass] = (countsByClass[capabilityClass] || 0) + 1;
      const executionGates = [];
      if (!documentPath) executionGates.push("missing_skill_document");
      skillEntries.push({
        id: slug,
        name: firstHeading(body, slug),
        capabilityClass,
        hasSkillDocument: Boolean(documentPath),
        documentFile: documentPath ? path.basename(documentPath) : null,
        description: firstParagraph(body).slice(0, 240),
        agentUsable: executionGates.length === 0,
        executionGates
      });
    }

    return {
      ok: true,
      skillsRoot,
      skillCount: skillEntries.length,
      skills: skillEntries,
      countsByClass,
      errors
    };
  } catch (error) {
    return {
      ok: false,
      skillsRoot,
      skillCount: skillEntries.length,
      skills: skillEntries,
      countsByClass,
      errors: [...errors, error?.message || String(error)]
    };
  }
}

function inspectSkillRegistry({
  skillsRoot,
  configPath,
  registrySource = "openclaw-skills",
  runtimeOwner = "unknown"
}) {
  const errors = [];
  const scanned = scanSkillRoot(skillsRoot);
  const configTools = configToolsFromPath(configPath, errors);
  const hardGates = (scanned.skills || [])
    .flatMap((skill) => (skill.executionGates || []).map((gate) => `${skill.id}:${gate}`));
  return {
    ...scanned,
    ok: scanned.ok === true,
    readOnly: true,
    executionEnabled: hardGates.length === 0,
    agentUsable: scanned.ok === true,
    registrySource,
    runtimeOwner,
    configPath,
    configTools,
    executionGates: hardGates,
    errors: [...(scanned.errors || []), ...errors]
  };
}

function scanSkillRoots(roots) {
  const map = new Map();
  const errors = [];
  for (const root of roots || []) {
    const scanned = scanSkillRoot(root);
    for (const skill of scanned.skills || []) {
      if (!map.has(skill.id)) map.set(skill.id, { ...skill, root });
    }
    errors.push(...(scanned.errors || []).map((error) => `${root}:${error}`));
  }
  return {
    skills: Array.from(map.values()).sort((a, b) => a.id.localeCompare(b.id)),
    errors
  };
}

function inspectSkillParity({
  nativeSkillsRoot,
  nativeWorkspaceSkillsRoot,
  prootSkillsRoot,
  prootWorkspaceSkillsRoot,
  nativeConfigPath,
  prootConfigPath
}) {
  const errors = [];
  const native = scanSkillRoots([nativeSkillsRoot, nativeWorkspaceSkillsRoot].filter(Boolean));
  const proot = scanSkillRoots([prootSkillsRoot, prootWorkspaceSkillsRoot].filter(Boolean));
  const nativeIds = new Set(native.skills.map((skill) => skill.id));
  const prootIds = new Set(proot.skills.map((skill) => skill.id));
  const missingInNative = Array.from(prootIds).filter((id) => !nativeIds.has(id)).sort();
  const missingInProot = Array.from(nativeIds).filter((id) => !prootIds.has(id)).sort();
  const nativeConfigTools = configToolsFromPath(nativeConfigPath, errors);
  const prootConfigTools = configToolsFromPath(prootConfigPath, errors);
  return {
    ok: missingInNative.length === 0 && native.errors.length === 0,
    nativeSkillCount: native.skills.length,
    prootSkillCount: proot.skills.length,
    nativeSkillNames: native.skills.map((skill) => skill.id),
    prootSkillNames: proot.skills.map((skill) => skill.id),
    missingInNative,
    missingInProot,
    nativeConfigTools,
    prootConfigTools,
    errors: [...errors, ...native.errors, ...proot.errors]
  };
}

module.exports = {
  inspectSkillRegistry,
  inspectSkillParity
};

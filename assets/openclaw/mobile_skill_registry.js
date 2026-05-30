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

function inspectSkillRegistry({ skillsRoot, configPath }) {
  const errors = [];
  const skillEntries = [];
  const countsByClass = {};
  let configTools = null;

  try {
    const config = JSON.parse(safeRead(configPath, 64000) || "{}");
    configTools = config?.tools ?? null;
  } catch (error) {
    errors.push(`config_parse_failed:${error?.message || String(error)}`);
  }

  try {
    if (!fs.existsSync(skillsRoot)) {
      return {
        ok: false,
        readOnly: true,
        executionEnabled: false,
        registrySource: "proot-openclaw-skills",
        skillsRoot,
        configPath,
        skillCount: 0,
        skills: [],
        countsByClass,
        configTools,
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
      skillEntries.push({
        id: slug,
        name: firstHeading(body, slug),
        capabilityClass,
        hasSkillDocument: Boolean(documentPath),
        documentFile: documentPath ? path.basename(documentPath) : null,
        description: firstParagraph(body).slice(0, 240),
        executionEnabled: false
      });
    }

    return {
      ok: true,
      readOnly: true,
      executionEnabled: false,
      registrySource: "proot-openclaw-skills",
      skillsRoot,
      configPath,
      skillCount: skillEntries.length,
      skills: skillEntries,
      countsByClass,
      configTools,
      errors
    };
  } catch (error) {
    return {
      ok: false,
      readOnly: true,
      executionEnabled: false,
      registrySource: "proot-openclaw-skills",
      skillsRoot,
      configPath,
      skillCount: skillEntries.length,
      skills: skillEntries,
      countsByClass,
      configTools,
      errors: [...errors, error?.message || String(error)]
    };
  }
}

module.exports = {
  inspectSkillRegistry
};

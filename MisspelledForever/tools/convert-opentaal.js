const fs = require("fs");
const path = require("path");

const [sourceDir, addonsDir] = process.argv.slice(2);

if (!sourceDir || !addonsDir) {
  console.error("Usage: node tools/convert-opentaal.js <opentaal-hunspell-dir> <Interface/AddOns-dir>");
  process.exit(1);
}

const affPath = path.join(sourceDir, "nl.aff");
const dicPath = path.join(sourceDir, "nl.dic");
const licensePath = path.join(sourceDir, "LICENSE.txt");
const versionPath = path.join(sourceDir, "datetimeversion.txt");

const aff = fs.readFileSync(affPath, "utf8").replace(/^\uFEFF/, "").split(/\r?\n/);
const dic = fs.readFileSync(dicPath, "utf8").replace(/^\uFEFF/, "").split(/\r?\n/);
const license = fs.readFileSync(licensePath, "utf8").replace(/^\uFEFF/, "");
const sourceVersion = fs.existsSync(versionPath) ? fs.readFileSync(versionPath, "utf8").trim() : "unknown";

function normalizeDutchText(value) {
  return value
    .replace(/’/g, "'")
    .replace(/ĳ/g, "ij")
    .replace(/Ĳ/g, "IJ");
}

function luaString(value) {
  return `"${String(value)
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\r/g, "\\r")
    .replace(/\n/g, "\\n")}"`;
}

function stripAffComment(line) {
  return line.replace(/\s+#.*$/, "").trim();
}

function cleanAdd(value) {
  const clean = normalizeDutchText(value.split("/")[0] || "0");
  return clean === "" ? "0" : clean;
}

function cleanStrip(value) {
  return normalizeDutchText(value || "0");
}

function cleanCondition(value) {
  return normalizeDutchText(value || ".");
}

function hasLongFlag(flags, wanted) {
  for (let index = 0; index < flags.length; index += 2) {
    if (flags.slice(index, index + 2) === wanted) return true;
  }
  return false;
}

const metadata = {
  tryChars: "ernitsaoldgkupmchbvjwfzyx'ëqïéèöêüçàûîñäô",
  replace: [],
  prefixGroups: [],
  suffixGroups: [],
};

const groupLookup = {
  PFX: new Map(),
  SFX: new Map(),
};

function getGroup(kind, flag, combine) {
  const map = groupLookup[kind];
  if (!map.has(flag)) {
    const group = { flag, combine, rules: [] };
    map.set(flag, group);
    if (kind === "PFX") metadata.prefixGroups.push(group);
    if (kind === "SFX") metadata.suffixGroups.push(group);
  }
  return map.get(flag);
}

for (const rawLine of aff) {
  const line = stripAffComment(rawLine);
  if (!line) continue;

  const parts = line.split(/\s+/);
  const kind = parts[0];

  if (kind === "TRY" && parts[1]) {
    metadata.tryChars = normalizeDutchText(parts.slice(1).join(""));
    continue;
  }

  if (kind === "REP" && parts.length >= 3 && !/^\d+$/.test(parts[1])) {
    const from = normalizeDutchText(parts[1]);
    const to = normalizeDutchText(parts[2]);
    if (!/[\\^$_]/.test(from) && !/[\\^$_]/.test(to)) {
      metadata.replace.push(`${from} ${to}`);
    }
    continue;
  }

  if ((kind === "PFX" || kind === "SFX") && parts.length >= 4) {
    const flag = parts[1];

    if (/^\d+$/.test(parts[3])) {
      getGroup(kind, flag, parts[2] === "Y" ? "Y" : "N");
      continue;
    }

    const group = getGroup(kind, flag, "N");
    const strip = cleanStrip(parts[2]);
    const add = cleanAdd(parts[3]);
    const condition = cleanCondition(parts[4]);

    if (strip === "0" && add === "0") continue;

    group.rules.push(`${flag} ${strip} ${add} ${condition}`);
  }
}

const words = new Set();
const skipped = {
  empty: 0,
  count: 0,
  slash: 0,
  whitespace: 0,
};

for (let index = 0; index < dic.length; index += 1) {
  const rawLine = dic[index].trim();
  if (!rawLine) {
    skipped.empty += 1;
    continue;
  }
  if (index === 0 && /^\d+$/.test(rawLine)) {
    skipped.count += 1;
    continue;
  }

  const entry = rawLine.split(/\s+/)[0];
  if (!entry || /\s/.test(entry)) {
    skipped.whitespace += 1;
    continue;
  }

  let word = entry;
  let flags = "";
  const slashIndex = entry.indexOf("/");
  if (slashIndex >= 0) {
    const candidateFlags = entry.slice(slashIndex + 1);
    if (!/^[A-Za-z0-9]+$/.test(candidateFlags) || candidateFlags.length % 2 !== 0) {
      skipped.slash += 1;
      continue;
    }
    word = entry.slice(0, slashIndex);
    flags = candidateFlags;
  }

  if (hasLongFlag(flags, "Fw")) {
    continue;
  }

  word = normalizeDutchText(word);
  if (!word || /\s/.test(word) || word.includes("/")) {
    skipped.whitespace += 1;
    continue;
  }

  words.add(flags ? `${word}/${flags}` : word);
}

const regionWords = {
  nlNL: [
    "appje",
    "betaalverzoek",
    "pinpas",
    "patatje",
    "tikkie",
  ],
  nlBE: [
    "amai",
    "allee",
    "confituur",
    "frietkot",
    "goesting",
    "kot",
    "kuisen",
    "plezant",
    "zetel",
  ],
};

function emitArray(name, values, out) {
  out.push(`${name}={`);
  for (const value of values) {
    out.push(`${luaString(value)},`);
  }
  out.push("},");
  out.push("");
}

function emitAffixes(name, groups, out) {
  out.push(`${name}={`);
  for (const group of groups) {
    if (group.rules.length === 0) continue;
    out.push(`${luaString(`${group.flag} ${group.combine} ${group.rules.length}`)},`);
    for (const rule of group.rules) {
      out.push(`${luaString(rule)},`);
    }
  }
  out.push("},");
  out.push("");
}

function buildDictionary(region) {
  const dictionaryWords = new Set(words);
  for (const word of regionWords[region.key]) {
    dictionaryWords.add(word);
  }

  const out = [];
  out.push(`--Language Dictionary: ${region.label}`);
  out.push("--Generated from OpenTaal opentaal-hunspell.");
  out.push("--Source: https://github.com/OpenTaal/opentaal-hunspell");
  out.push("");
  out.push(`function WordDict_GetDictionary_${region.key}()`);
  out.push("return {");
  out.push("UTF8 = true,");
  out.push('FlagType = "long",');
  out.push('Soundslike = "Generic",');
  out.push("Copyright={");
  out.push(`${luaString("Dutch dictionary for spelling checker by OpenTaal (https://opentaal.org).")},`);
  out.push(`${luaString("Source: https://github.com/OpenTaal/opentaal-hunspell.")},`);
  out.push(`${luaString(`OpenTaal source version: ${sourceVersion}.`)},`);
  out.push(`${luaString("Rights: Revised BSD License and/or CC BY 3.0; this port uses the Revised BSD License option.")},`);
  out.push(`${luaString("Creator history: 2020 OpenTaal; 2006-2011 OpenTaal; 2001-2005 Simon Brouwer and others; 1996 Nederlandstalige TeX Gebruikersgroep.")},`);
  out.push("},");
  out.push("");
  emitArray("Try", [metadata.tryChars], out);
  emitArray("Replace", metadata.replace, out);
  emitAffixes("Prefix", metadata.prefixGroups, out);
  emitAffixes("Suffix", metadata.suffixGroups, out);
  out.push("Words={");
  for (const word of Array.from(dictionaryWords).sort((a, b) => a.localeCompare(b, "nl"))) {
    out.push(`${luaString(word)},`);
  }
  out.push("}");
  out.push("}");
  out.push("end");
  out.push("");
  return out.join("\n");
}

function writeModule(region) {
  const addonName = `MisspelledForever_Dict_${region.key}`;
  const addonDir = path.join(addonsDir, addonName);
  fs.mkdirSync(addonDir, { recursive: true });

  fs.writeFileSync(path.join(addonDir, `Dic_${region.key}.lua`), buildDictionary(region), "utf8");
  fs.writeFileSync(path.join(addonDir, "LICENSE-OpenTaal.txt"), license, "utf8");
  fs.writeFileSync(path.join(addonDir, `${addonName}.toc`), [
    "## Interface: 120000, 120001, 16001",
    `## Title: MisspelledForever Dictionary - ${region.label}`,
    "## Version: 1.20.0-forever.5",
    "## Author: Nate (Nathan Pieper), Forever port contributors, OpenTaal",
    `## Notes: Load-on-demand ${region.label} dictionary module for MisspelledForever.`,
    "## LoadOnDemand: 1",
    "## RequiredDeps: MisspelledForever",
    "## X-Original-Author: Nate (Nathan Pieper)",
    "## X-Port: WoW Forever",
    "## X-Dictionary-Source: OpenTaal opentaal-hunspell",
    "## X-Dictionary-License: Revised BSD License",
    "",
    `Dic_${region.key}.lua`,
    "",
  ].join("\n"), "utf8");
}

writeModule({ key: "nlNL", label: "nlNL (Nederlands - Nederland)" });
writeModule({ key: "nlBE", label: "nlBE (Nederlands - Vlaanderen)" });

console.log(`Generated nlNL/nlBE dictionaries from OpenTaal ${sourceVersion}`);
console.log(`Words: ${words.size}; Prefix groups: ${metadata.prefixGroups.length}; Suffix groups: ${metadata.suffixGroups.length}; Replace pairs: ${metadata.replace.length}`);
console.log(`Skipped: ${JSON.stringify(skipped)}`);

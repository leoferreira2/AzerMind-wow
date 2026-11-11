'use strict';
// Read-only discovery. Never start a chat, a picker, or an authentication flow.
const fs = require('fs');
const { execFile } = require('child_process');
const A = require('./agents');
const S = require('./codex-settings');
const MODEL_ID = /^[a-zA-Z0-9][a-zA-Z0-9_./:@+\[\]-]{0,199}$/;
const EFFORT_ID = /^[a-z][a-z0-9_-]{0,31}$/;
const row = (model, name, efforts = [], effortsKnown = true) => ({model, name, efforts, effortsKnown});
// Dated compatibility choices, not a claim about account access. Sources are in
// docs/AI-MODEL-CATALOGS.md. Account/runtime and configured data take precedence.
const COMPATIBILITY = {
  claude: [row('opus','Opus — latest',[],false), row('sonnet','Sonnet — latest',[],false), row('haiku','Haiku — latest',[],false),
    row('claude-opus-5-5','Opus 5.5',['low','medium','high','xhigh','max']),
    row('claude-sonnet-5-5','Sonnet 5.5',['low','medium','high','xhigh','max']),
    row('claude-haiku-5-5','Haiku 5.5',['low','medium','high','xhigh','max']),
    row('claude-opus-4-8','Opus 4.8',['low','medium','high','xhigh','max']),
    row('claude-sonnet-4-6','Sonnet 4.6',['low','medium','high','max'])],
  grok: [row('grok-build','Grok Build',[],false), row('grok-4.7','Grok 4.7',['low','medium','high','xhigh'])],
  agy: [row('gemini-4-argon-high','Gemini 4 Argon (High)'), row('gemini-4-argon-medium','Gemini 4 Argon (Medium)'),
    row('gemini-3.8-flash-high','Gemini 3.8 Flash (High)'), row('gemini-3.8-flash-medium','Gemini 3.8 Flash (Medium)')],
  hermes: [row('opus','Opus (configured provider)',[],false), row('sonnet','Sonnet (configured provider)',[],false),
    row('kimi','Kimi (configured provider)',[],false)],
  codex: [],
};
function cleanModels(value) {
  if (!Array.isArray(value)) return [];
  const seen = new Set(), result = [];
  for (const entry of value) {
    const model = typeof entry === 'string' ? entry : entry?.model || entry?.id || entry?.slug;
    if (!MODEL_ID.test(model || '') || seen.has(model)) continue;
    seen.add(model);
    const rawEfforts = entry.efforts ?? entry.reasoning_efforts ?? entry.supported_reasoning_levels ?? entry.capabilities?.reasoning_effort;
    const efforts = Array.isArray(rawEfforts) ? [...new Set(rawEfforts.map(e => typeof e === 'string' ? e : e?.effort || e?.id || e?.value).filter(e => typeof e==='string' && EFFORT_ID.test(e)))] : [];
    result.push({model, name: String(entry.name || entry.display_name || model).replace(/[\x00-\x1f|]/g,'').slice(0,100),
      efforts, effortsKnown: entry.effortsKnown !== false && Array.isArray(rawEfforts)});
    if (result.length === 80) break;
  }
  return result;
}
function parseModels(output) {
  const plain = String(output).replace(/\x1b\[[0-9;]*m/g,'');
  try {
    const data = JSON.parse(plain);
    return cleanModels(Array.isArray(data) ? data : data.models || data.data || []);
  } catch { /* Older CLIs output a two-column list instead of JSON. */ }
  const result = [];
  for (const line of plain.split(/\r?\n/)) {
    // Require columns, not arbitrary log lines, error text or a bare word.
    const match = line.trim().match(/^([a-zA-Z0-9][a-zA-Z0-9_.:/@+-]*)(?:\s{2,}|\t+)(\S.*)$/);
    if (!match || match[1]==='model-id' || !/[-/.:]/.test(match[1]) || /^https?:/.test(match[1])) continue;
    result.push({model:match[1],name:match[2],effortsKnown:false});
  }
  return cleanModels(result);
}
function probe(id, command, args) {
  return new Promise((resolve, reject) => {
    const env = A.AGENTS[id].env({...process.env});
    execFile(command.file, [...command.args, ...args], {env, windowsHide:true, timeout:3500, maxBuffer:256*1024, shell:false}, (error, stdout) => {
      if (error) reject(new Error('Model discovery unavailable.')); else resolve(stdout);
    });
  });
}
function createCatalogs(getConfig, {cacheFile, run = probe, resolve = A.resolveCommand, codex = S.catalog, now = Date.now} = {}) {
  let cached = {}, inflight, lastAttempt = 0;
  if (cacheFile) {
    try {
      const stat=fs.statSync(cacheFile);
      if (stat.size<512*1024) {
        const saved=JSON.parse(fs.readFileSync(cacheFile,'utf8'));
        for (const id of A.agentIds()) if (saved[id] && now()-saved[id].updatedAt<7*86400000) cached[id]={...saved[id],models:cleanModels(saved[id].models),status:'cached'};
      }
    } catch { /* First run or invalid cache; use compatibility choices. */ }
  }
  function snapshot() {
    return S.providerSettings(getConfig(), codex(), cached);
  }
  async function discover(id) {
    const cfg = A.agentConfig(getConfig(), id), command=resolve(id,cfg);
    const previous=cached[id];
    let models=[], status='compatibility', effortFlag=false;
    if (id === 'codex') { models=cleanModels(codex()); status=models.length ? 'local' : 'unavailable'; }
    else if (command.found) {
      try {
        const help=await run(id,command,['--help']);
        effortFlag = /--(?:reasoning-)?effort\b/.test(help);
        if (id==='grok' || id==='agy') {
          models=parseModels(await run(id,command,['models']));
          status=models.length ? 'discovered' : 'compatibility';
        }
      } catch { status=previous?.models.length ? 'stale' : 'compatibility'; }
    } else status='not-installed';
    if (!models.length && previous?.models.length) { models=previous.models; status='stale'; }
    cached[id]={models, status, effortFlag:effortFlag || (status==='stale' && previous?.effortFlag) || false,
      updatedAt:status==='stale' ? previous.updatedAt : now()};
  }
  function refresh() {
    if (inflight) return inflight;
    // Bound clicks/retries without holding up delivery or launching inference.
    if (lastAttempt && now()-lastAttempt<10000) return Promise.resolve(snapshot());
    lastAttempt=now();
    inflight=Promise.all(A.agentIds().map(discover)).then(() => {
      if (cacheFile) { try { fs.writeFileSync(cacheFile,JSON.stringify(cached,null,2)+'\n'); } catch { /* Read-only installs can operate without cache. */ } }
      return snapshot();
    }).finally(() => { inflight=undefined; });
    return inflight;
  }
  return {snapshot, refresh};
}
module.exports={COMPATIBILITY, cleanModels, parseModels, createCatalogs};

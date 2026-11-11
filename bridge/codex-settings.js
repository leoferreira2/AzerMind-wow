'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const EFFORTS = new Set(['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max', 'ultra']);
function catalog(file = path.join(process.env.CODEX_HOME || path.join(os.homedir(), '.codex'), 'models_cache.json')) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8')).models
      .filter(m => /^[a-zA-Z0-9_.-]{1,100}$/.test(m.slug) && m.visibility !== 'hide' && m.slug !== 'codex-auto-review')
      .slice(0, 40).map(m => ({ model: m.slug, efforts: (m.supported_reasoning_levels || []).map(r => r.effort).filter(e => EFFORTS.has(e)) }));
  } catch { return []; }
}
function apply(cfg, job, models = []) {
  const result = { ...cfg };
  if (job.model) {
    if (!/^[a-zA-Z0-9_.-]{1,100}$/.test(job.model)) throw new Error('Invalid Codex model.');
    result.model = job.model;
    result.reasoning = '';
  }
  if (job.reasoning) {
    if (!EFFORTS.has(job.reasoning)) throw new Error('Invalid Codex reasoning effort.');
    const model = models.find(m => m.model === result.model);
    if (model && model.effortsKnown !== false && !model.efforts.includes(job.reasoning)) throw new Error('Selected model does not support this reasoning effort.');
    result.reasoning = job.reasoning;
  }
  return result;
}
const REASONING = {
  codex: [...EFFORTS], claude: ['low','medium','high','xhigh','max'],
  agy: ['low','medium','high','xhigh','max'], hermes: ['none','minimal','low','medium','high','xhigh','max','ultra'], grok: ['none','minimal','low','medium','high','xhigh','max'],
};
function applyAgent(id, cfg, job, models = [], capabilities) {
  if (!REASONING[id]) throw new Error('Unknown agent.');
  if (id === 'codex') return apply(cfg, job, models);
  const result = {...cfg};
  if (job.model) {
    if (!/^[a-zA-Z0-9][a-zA-Z0-9_./:@+\[\]-]{0,199}$/.test(job.model)) throw new Error('Invalid model identifier.');
    result.model = job.model;
    result.reasoning = '';
  }
  if (job.reasoning) {
    const model = models.find(m => m.model === result.model);
    if (!REASONING[id].includes(job.reasoning) && !model?.efforts.includes(job.reasoning)) throw new Error('Unsupported reasoning effort for ' + id + '.');
    if (model && model.effortsKnown !== false && !model.efforts.includes(job.reasoning)) throw new Error('Selected model does not support this reasoning effort.');
    result.reasoning = job.reasoning;
  }
  if (id === 'grok') {
    result.reasoningSupported=capabilities?.effortFlag === true;
    if (result.reasoning && !result.reasoningSupported) throw new Error('This Grok CLI has not reported support for --effort. Refresh models or update the CLI.');
  }
  return result;
}
function providerSettings(config, codexModels, discovered = {}) {
  const {COMPATIBILITY, cleanModels}=require('./model-catalogs');
  return Object.fromEntries(Object.keys(REASONING).map(id => {
    const own = config.agents?.[id] || {};
    const live=discovered[id] || {};
    const configured=cleanModels(own.models);
    const base=id === 'codex' ? cleanModels(codexModels?.length ? codexModels : live.models) : live.models?.length ? cleanModels(live.models) : cleanModels(COMPATIBILITY[id]);
    const merged=new Map();
    for (const m of configured) merged.set(m.model,m);
    for (const m of base) if (!merged.has(m.model)) merged.set(m.model,m);
    const current=own.model || (id === 'claude' ? config.model || '' : '');
    if (current && !merged.has(current)) for (const m of cleanModels([{model:current,effortsKnown:false}])) merged.set(m.model,m);
    const selected=merged.get(current);
    const models=(selected ? [selected,...[...merged.values()].filter(m => m.model!==current)] : [...merged.values()]).slice(0,80);
    // A discovered CLI without an effort flag must not advertise the union of
    // possible API capabilities (especially on older Grok installations).
    if (id==='grok' && !live.effortFlag) for (const m of models) { m.efforts=[]; m.effortsKnown=false; }
    return [id, {model:own.model || (id === 'claude' ? config.model || '' : ''), reasoning:own.reasoning || '',
      efforts:REASONING[id], models, effortFlag:live.effortFlag === true,
      catalogStatus:live.status || (id==='codex' && models.length ? 'local' : configured.length ? 'configured' : 'compatibility'),
      catalogSource:id==='codex' ? 'Local account catalog' : live.models?.length ? 'Installed provider catalog' : configured.length ? 'Configured and compatibility choices' : 'Compatibility choices (account access not verified)'}];
  }));
}
function defaults(config, request, models, agents, settings) {
  if (!request || !agents.includes(request.agent) || typeof request.model !== 'string' || typeof request.reasoning !== 'string') throw new Error('Invalid AI settings.');
  const meta=(settings || providerSettings(config,models))[request.agent];
  const checked = applyAgent(request.agent, {}, request, meta.models, meta);
  return { ...config, agent: request.agent, agents: { ...config.agents, [request.agent]: { ...config.agents?.[request.agent], model: checked.model || '', reasoning: checked.reasoning || '' } } };
}
module.exports = { catalog, apply, applyAgent, defaults, providerSettings };

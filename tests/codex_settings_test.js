'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const S = require('../bridge/codex-settings');
const P = require('../bridge/protocol');
const A = require('../bridge/agents');

test('Codex model and reasoning survive the pixel and reload protocols', () => {
  const job = P.jobsFromStrip(1, ['s', 'c', '1', 'work', 'agent=codex;model=test-model;reasoning=high', 'name', 'question'].join('\x1F'))[0];
  assert.equal(job.model, 'test-model');
  assert.equal(job.reasoning, 'high');
  const reload = P.parseOutbox('["outbox"] = { ["id"] = 1, ["model"] = "test-model", ["reasoning"] = "high" }');
  assert.equal(reload.model, job.model);
  assert.equal(reload.reasoning, job.reasoning);
});

test('overrides preserve the sandbox and support resumed sessions', () => {
  const base = { permissionMode: 'default', networkAccess: false, extraArgs: ['-c', 'web_search="live"'] };
  const cfg = S.apply(base, { model: 'test-model', reasoning: 'high' }, [{model: 'test-model', efforts: ['high']}]);
  const args = A.AGENTS.codex.args({ cfg, cwd: 'work', resume: 'session' });
  assert.equal(args[args.indexOf('--sandbox') + 1], 'read-only');
  assert.equal(args[args.indexOf('-m') + 1], 'test-model');
  assert.ok(args.includes('model_reasoning_effort="high"'));
  assert.ok(args.includes('resume'));
  assert.equal(base.model, undefined);
  assert.deepEqual(S.apply(base, {}), base);
});

test('invalid model names and unsupported reasoning are rejected', () => {
  assert.throws(() => S.apply({}, {model: '--dangerous value'}));
  assert.throws(() => S.apply({}, {reasoning: 'invented'}));
  assert.throws(() => S.apply({}, {model: 'small', reasoning: 'ultra'}, [{model:'small', efforts:['low']} ]));
  assert.deepEqual(S.catalog('missing-model-cache.json'), []);
});

test('model catalog is serialized for in-game selectors', () => {
  const lua = P.luaTable('AzerMind_Inbox', [], {codexModels: [{model:'test-model', efforts:['low','high']}]});
  assert.ok(lua.includes('codexModels = { { model = "test-model", efforts = { "low", "high" } } }'));
});

test('global defaults preserve security and existing settings without mutating config', () => {
  const config = {agent:'claude', capture:{enabled:true}, agents:{codex:{permissionMode:'default',networkAccess:false,extraArgs:['-c','web_search="live"']},claude:{model:'keep'}}};
  const updated = S.defaults(config, {agent:'codex',model:'test',reasoning:'high'}, [{model:'test',efforts:['high']}], ['codex','claude']);
  assert.equal(updated.agent,'codex');
  assert.equal(updated.agents.codex.model,'test');
  assert.equal(updated.agents.codex.reasoning,'high');
  assert.equal(updated.agents.codex.permissionMode,'default');
  assert.equal(updated.agents.codex.networkAccess,false);
  assert.equal(updated.agents.claude.model,'keep');
  assert.equal(config.agent,'claude');
  assert.equal(config.agents.codex.model,undefined);
  assert.throws(() => S.defaults(config, {agent:'unknown',model:'',reasoning:''}, [], ['codex']));
  const reset = S.defaults(updated, {agent:'codex',model:'',reasoning:''}, [], ['codex']);
  assert.equal(reset.agents.codex.model,'');
  assert.equal(reset.agents.codex.reasoning,'');
});

test('settings commands and defaults serialize independently of chat prompts', () => {
  const job = P.jobsFromStrip(2, ['s','chat','2','','settings','AI settings','{"agent":"codex","model":"","reasoning":""}'].join('\x1F'))[0];
  assert.equal(job.settings,true);
  const lua = P.luaTable('Inbox', [], {aiDefaults:{agent:'codex',model:'test',reasoning:'high'}});
  assert.ok(lua.includes('aiDefaults = { agent = "codex", model = "test", reasoning = "high" }'));
});

test('cancellation identifies a target request without becoming a prompt', () => {
  const record = ['session', 'chat', '9', '', 'cancel=8', 'name', ''].join('\x1F');
  const job = P.jobsFromStrip(9, record)[0];
  assert.equal(job.cancel, 8);
  assert.equal(job.id, 9);
  assert.equal(job.chat, 'chat');
  assert.equal(P.parseFlags('cancel=invalid').cancel, undefined);
});


test('all providers apply model overrides and only supported reasoning flags', () => {
  for (const [id, model, flag] of [
    ['claude','sonnet','--effort'], ['agy','gemini-test','--effort'],
    ['hermes','anthropic/test','--reasoning'], ['grok','grok-test',null],
  ]) {
    const cfg = S.applyAgent(id, {permissionMode:'default'}, {model, reasoning:flag ? 'high' : ''});
    const args = A.AGENTS[id].args({cfg,cwd:'work',prompt:'hello'});
    assert.ok(args.includes(model));
    if(flag) assert.equal(args[args.indexOf(flag)+1], 'high');
    const updated = S.defaults({agents:{codex:{model:'keep'},[id]:{permissionMode:'default'}}}, {agent:id,model,reasoning:flag?'high':''}, [], A.agentIds());
    assert.equal(updated.agents[id].model, model);
    assert.equal(updated.agents[id].permissionMode, 'default');
    assert.equal(updated.agents.codex.model, 'keep');
  }
  assert.throws(() => S.applyAgent('grok', {}, {reasoning:'high'}));
  assert.throws(() => S.applyAgent('claude', {}, {model:'bad;agent=codex'}));
  assert.throws(() => S.applyAgent('hermes', {}, {model:'--flag'}));
});

test('provider catalogs and defaults serialize without crossing providers', () => {
  const settings = S.providerSettings({agents:{claude:{model:'sonnet',models:[{model:'sonnet',efforts:['high']}]}}}, []);
  const text = P.luaTable('Inbox', [], {agentSettings:settings});
  assert.ok(text.includes('["claude"] = { model = "sonnet"'));
  assert.ok(text.includes('["grok"] = { model = ""'));
  assert.equal(settings.grok.effortFlag, false);
  assert.ok(settings.grok.models.length > 0);
  assert.ok(settings.grok.models.every(m => m.efforts.length === 0));
});

const M = require('../bridge/model-catalogs');
test('provider choices are populated without configuration and explicit catalogs override compatibility entries', () => {
 const data=S.providerSettings({agents:{claude:{models:[{model:'sonnet',name:'Team Sonnet',efforts:['low']}]}}},[{model:'local-code',efforts:['high']}]);
 for(const id of A.agentIds()) assert.ok(data[id].models.length>0,id);
 assert.equal(data.claude.models.find(m=>m.model==='sonnet').name,'Team Sonnet');
 assert.deepEqual(data.claude.models.find(m=>m.model==='sonnet').efforts,['low']);
 assert.equal(data.codex.models[0].model,'local-code');
 assert.equal(data.claude.models.find(m=>m.model==='opus').effortsKnown,false,'a family alias is not an account-resolved model');
});

test('model discovery parses bounded JSON and CLI columns without promoting logs into options', () => {
 const parsed=M.parseModels(JSON.stringify({models:[{id:'grok-test',display_name:'Grok',reasoning_efforts:[{id:'deep'},'high','bad;flag']}]}));
 assert.deepEqual(parsed[0].efforts,['deep','high']);
 assert.equal(parsed[0].effortsKnown,true);
 assert.equal(M.parseModels('Login required\nmodel-id  Display name\ngemini-test-high  Gemini Test (High)\n').length,1);
 assert.equal(M.parseModels('grok-test  Grok Test')[0].effortsKnown,false);
 assert.equal(M.cleanModels(Array.from({length:200},(_,i)=>({model:'model-'+i,efforts:[]}))).length,80);
 assert.deepEqual(M.cleanModels([{model:'--flag'},{model:'bad;flag'},{model:'ok',name:'safe|name\n',efforts:[]}]).map(m=>m.name),['safename']);
});

test('discovery only probes help/model listings and retains last good choices on failure', async () => {
 let fail=false,clock=100000; const calls=[];
 const service=M.createCatalogs(()=>({agents:{}}),{
  now:()=>clock,codex:()=>fail ? [] : [{model:'account-only',efforts:['low']}],
  resolve:()=>({file:'fixture',args:[],found:true}),
  run:async(id,command,args)=>{
   calls.push([id,args]);
   if(fail) throw Error('auth or timeout');
   if(args[0]==='--help') return '--effort <LEVEL>';
   return JSON.stringify({models:[{model:id+'-account',efforts:['high']}]});
  }
 });
 const [first,same]=await Promise.all([service.refresh(),service.refresh()]);
 assert.deepEqual(first,same);
 assert.ok(calls.every(([,args])=>args.length===1&&['--help','models'].includes(args[0])));
 assert.equal(first.grok.effortFlag,true);
 assert.deepEqual(first.grok.models[0].efforts,['high']);
 assert.equal(first.codex.models[0].model,'account-only');
 assert.equal(first.agy.models[0].model,'agy-account');
 const count=calls.length; await service.refresh(); assert.equal(calls.length,count);
 clock+=11000; fail=true; const stale=await service.refresh();
 assert.equal(stale.grok.catalogStatus,'stale');
 assert.equal(stale.codex.models[0].model,'account-only','a temporary missing Codex cache keeps the last known account list');
 assert.equal(stale.grok.models[0].model,'grok-account');
 assert.ok(!JSON.stringify(stale).includes('auth or timeout'));
});

test('Grok effort forwarding is gated by the installed CLI and supports per-model effort IDs', () => {
 const models=[{model:'grok-account',efforts:['deep'],effortsKnown:true}];
 assert.throws(()=>S.applyAgent('grok',{}, {model:'grok-account',reasoning:'deep'},models,{effortFlag:false}));
 const cfg=S.applyAgent('grok',{}, {model:'grok-account',reasoning:'deep'},models,{effortFlag:true});
 const args=A.AGENTS.grok.args({cfg,cwd:'work'});
 assert.equal(args[args.indexOf('--effort')+1],'deep');
 assert.throws(()=>S.applyAgent('grok',{}, {model:'grok-account',reasoning:'high'},models,{effortFlag:true}));
 assert.throws(()=>S.apply({}, {model:'fixed',reasoning:'high'},[{model:'fixed',efforts:[]}]));
 assert.equal(S.apply({reasoning:'high'}, {model:'other'}).reasoning,'','changing model does not retain incompatible default reasoning');
});

test('model capability metadata survives Lua transport without account credentials', () => {
 const settings=S.providerSettings({agents:{claude:{token:'never-send',models:[{model:'team',name:'Team model',efforts:['high']}]}}},[]);
 const text=P.luaTable('Inbox',[],{agentSettings:settings});
 assert.ok(text.includes('name = "Team model"'));
 assert.ok(text.includes('effortsKnown = true'));
 assert.ok(text.includes('catalogSource = '));
 assert.ok(!text.includes('never-send'));
});

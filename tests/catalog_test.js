'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const zlib=require('node:zlib');
const {decodeCBOR,metadata,stored,entityRows,lua:serializeLua,questCities}=require('../tools/build-catalog');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const root=path.join(__dirname,'..');
test('quest cities use recorded starters and never infer from destination or nearest capital',()=>{
  const npcs={10:{zoneID:1519},11:{zoneID:130},12:{spawns:{1637:[[40,50]]}}};
  assert.deepEqual(questCities({zoneID:1497,startedBy:[[11]]},npcs,{}),[]);
  assert.deepEqual(questCities({zoneID:130,startedBy:[[10,12]]},npcs,{}),[1519,1637]);
  assert.deepEqual(questCities({startedBy:{2:[20]}},npcs,{20:{zoneID:1497}}),[1497]);
});
function vm(all=true) {
  const L=lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  function run(code) { if(lauxlib.luaL_loadstring(L,to_luastring(code))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK) throw Error(to_jsstring(lua.lua_tostring(L,-1))); }
  function value(expr) { run('RESULT=tostring('+expr+')');lua.lua_getglobal(L,to_luastring('RESULT'));const result=to_jsstring(lua.lua_tostring(L,-1));lua.lua_pop(L,1);return result; }
  run('AzerMind={PlainText=function(s) return s end}; UnitLevel=function() return 23 end');
  run(fs.readFileSync(path.join(root,'addon/AzerMind/Catalog.lua'),'utf8'));
  const modules=all?['AzerMind_Data','AzerMind_Data_ItemDetails','AzerMind_Data_QuestDetails','AzerMind_Data_World']:['AzerMind_Data'];
  for(const module of modules) {
    const toc=fs.readFileSync(path.join(root,'addon',module,module+'.toc'),'utf8');
    for(const file of toc.split(/\r?\n/).filter(s=>s.endsWith('.lua'))) run(fs.readFileSync(path.join(root,'addon',module,file),'utf8'));
  }
  return {run,value};
}
test('initial module loads search indices without item, quest or world details',()=>{
  const v=vm(false);
  assert.equal(v.value('AzerMindCatalog.itemIndex[279391].name'),'Taurajo Headband');
  assert.equal(v.value('AzerMindCatalog.questIndex[479].name'),'Ambermill Investigations');
  for(const kind of ['items','quests','npcs','objects']) assert.equal(v.value(`next(AzerMindCatalog.${kind})`),'nil');
  assert.equal(v.value('AzerMindCatalog.loaded.ItemDetails'),'nil');
  v.run('ITEM_QUERIES=0; C_Item={GetItemInfoInstant=function() ITEM_QUERIES=ITEM_QUERIES+1 end,GetItemInfo=function() ITEM_QUERIES=ITEM_QUERIES+1 end}; LIST=AzerMind.CatalogItemList()');
  assert.equal(v.value('#LIST'),v.value('AzerMindCatalog.manifest.counts.items'));
  assert.equal(v.value('ITEM_QUERIES'),'0','building the index must not query the client for every item');
});
test('city then zone filtering includes multiple starting cities and an explicit unknown bucket',()=>{
  const v=vm(false);
  v.run(`
    C_Map={GetAreaInfo=function(id) return ({[130]="Silverpine Forest",[85]="Tirisfal Glades"})[id] end}
    Q={{id=9000001,title="A",zone="Silverpine Forest",record={zoneID=130,cityIDs={1497}}},
       {id=9000002,title="B",zone="Silverpine Forest",record={zoneID=130,cityIDs={1637}}},
       {id=9000003,title="C",zone="Tirisfal Glades",record={zoneID=85,cityIDs={}}}}
    A=Q[1]; UNKNOWN=Q[3]
    AzerMind.AssignQuestGeography(Q)
    CITIES,ZONES=AzerMind.QuestLocationOptions(Q,"1497")
  `);
  assert.equal(v.value('#ZONES'),'2');
  assert.equal(v.value('ZONES[2].label'),'Silverpine Forest');
  assert.equal(v.value('ZONES[2].count'),'1');
  assert.equal(v.value('AzerMind.QuestMatchesLocation(A,"1497","130")'),'true');
  assert.equal(v.value('AzerMind.QuestMatchesLocation(A,"1637","130")'),'false');
  assert.equal(v.value('AzerMind.QuestMatchesLocation(UNKNOWN,"none","85")'),'true');
  assert.equal(v.value('next(AzerMindCatalog.npcs)'),'nil','location filtering must not load world details');
});
test('CBOR parser rejects corrupt/trailing data and reconstructs chunked metadata',()=>{
  assert.deepEqual(decodeCBOR(Buffer.from('83016178f6','hex')),[1,'x',null]);
  assert.throws(()=>decodeCBOR(Buffer.from('616100','hex')),/Trailing/);
  assert.throws(()=>decodeCBOR(Buffer.from('8201','hex')),/Truncated/);
  const m=metadata('## X: ~2~\n## X-1: abc\n## X-2: def\n');
  assert.equal(stored(m,'X'),'abcdef'); delete m['X-2']; assert.throws(()=>stored(m,'X'),/Missing chunk/);
});
test('scalar arrays use Lua one-based fields rather than JavaScript offsets',()=>{
  const ids=zlib.deflateSync(Buffer.from('811819','hex')).toString('base64');
  // Scalar array: [name,null,null,null,startQuest,null,flags].
  const scalar=Buffer.from('876474657374f6f6f6190d9af6190800','hex').toString('base64');
  const records=entityRows({'X-Item-IDS':ids,'X-Item-25-S':scalar},'Item',{name:1,startQuest:5,questRewards:6,flags:7});
  assert.equal(records[25].name,'test'); assert.equal(records[25].startQuest,3482); assert.equal(records[25].flags,2048); assert.equal(records[25].questRewards,undefined);
});
test('Lua serialization preserves Unicode and escapes controls without executing strings',()=>{
  const s='ação "quoted" \\ \n\x00'; const out=serializeLua(s);
  assert.ok(out.includes('ação')); assert.ok(out.includes('\\000')); assert.ok(out.includes('\\010'));
});
test('bundled snapshot loads in Lua, preserves custom Forever items, and matches manifest counts',()=>{
  const v=vm(); const manifest=JSON.parse(fs.readFileSync(path.join(root,'addon/AzerMind_Data/manifest.json')));
  for(const [kind,count] of Object.entries(manifest.counts)) assert.equal(Number(v.value(`(function() local n=0; for _ in pairs(AzerMindCatalog.${kind}) do n=n+1 end; return n end)()`)),count);
  assert.equal(v.value('AzerMindCatalog.items[279391].name'),'Taurajo Headband');
  assert.equal(v.value('AzerMindCatalog.items[279391].subclassID'),'1');
  assert.equal(v.value('AzerMindCatalog.items[279391].rarity'),'nil');
  assert.equal(v.value('AzerMindCatalog.quests[479].name'),'Ambermill Investigations');
  assert.equal(v.value('AzerMindCatalog.manifest.coverage.dropRates'),'false');
});
test('quest availability uses live confirmations and never invents eligibility',()=>{
  const v=vm(); v.run('Q={id=479,record=AzerMindCatalog.quests[479]}; C_QuestLog={GetLogIndexForQuestID=function() return 0 end,IsQuestFlaggedCompleted=function() return false end}');
  assert.equal(v.value('AzerMind.CatalogQuestStatus(Q)'),'Availability unknown');
  v.run('C_QuestLog.GetLogIndexForQuestID=function() return 2 end'); assert.equal(v.value('AzerMind.CatalogQuestStatus(Q)'),'Active');
  v.run('C_QuestLog.GetLogIndexForQuestID=function() return 0 end; C_QuestLog.IsQuestFlaggedCompleted=function() return true end'); assert.equal(v.value('AzerMind.CatalogQuestStatus(Q)'),'Completed');
  v.run('UnitClass=function() return "Warlock","WARLOCK",9 end; R={id=1,record={requiredClasses=1}}'); assert.equal(v.value('AzerMind.CatalogQuestMatchesCharacter(R)'),'false');
});
test('catalog loader blocks combat and reports missing module without a crash',()=>{
  const v=vm(); v.run('AzerMindCatalog=nil; InCombatLockdown=function() return true end; DB,ERR=AzerMind.LoadCatalog()');
  assert.equal(v.value('DB'),'nil'); assert.match(v.value('ERR'),/combat/);
  v.run('InCombatLockdown=function() return false end; C_AddOns={LoadAddOn=function() return nil,"MISSING" end}; DB,ERR=AzerMind.LoadCatalog()');
  assert.match(v.value('ERR'),/MISSING/);
  v.run('AzerMindCatalog={manifest={layout=2},loaded={}}; C_AddOns.LoadAddOn=function() return true end; DB,ERR=AzerMind.LoadCatalog("World")');
  assert.match(v.value('ERR'),/incomplete/);
});

test('world module retains multiple recorded coordinates and NPC levels for source browsing',()=>{
 const v=vm();
 assert.equal(v.value('(function() for _,npc in pairs(AzerMindCatalog.npcs) do local count=0; for _,points in pairs(npc.spawns or {}) do count=count+#points end; if count>1 and npc.minLevel then return true end end; return false end)()'),'true');
 assert.equal(v.value('(function() for _,item in pairs(AzerMindCatalog.itemIndex) do if item.itemLevel and item.requiredLevel and item.itemLevel~=item.requiredLevel then return true end end; return false end)()'),'true');
});

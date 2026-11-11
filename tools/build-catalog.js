'use strict';
// Read an installed Forever artifact as data, never execute third-party Lua.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { inflateSync } = require('node:zlib');

function decodeCBOR(bytes) {
  let offset = 0;
  function take(n) { if (offset + n > bytes.length) throw Error('Truncated CBOR'); const b=bytes.subarray(offset,offset+n); offset+=n; return b; }
  function length(ai) {
    if (ai < 24) return ai;
    if (ai===24) return take(1).readUInt8();
    if (ai===25) return take(2).readUInt16BE();
    if (ai===26) return take(4).readUInt32BE();
    if (ai===27) { const n=Number(take(8).readBigUInt64BE()); if (!Number.isSafeInteger(n)) throw Error('Unsafe CBOR integer'); return n; }
    throw Error('Unsupported CBOR length');
  }
  function read() {
    const initial=take(1)[0], major=initial>>5, ai=initial&31;
    if (major===7) {
      if (ai===20) return false; if(ai===21) return true; if(ai===22 || ai===23) return null;
      if(ai===26) return take(4).readFloatBE(); if(ai===27) return take(8).readDoubleBE();
      if(ai===25) { const n=take(2).readUInt16BE(), e=(n>>10)&31, f=n&1023; return (n&32768?-1:1)*(e===0?2**-14*f/1024:e===31?(f?NaN:Infinity):2**(e-15)*(1+f/1024)); }
      throw Error('Unsupported CBOR simple value');
    }
    const n=length(ai);
    if(major===0) return n; if(major===1) return -1-n;
    if(major===2 || major===3) return take(n).toString('utf8');
    if(major===4) return Array.from({length:n},read);
    if(major===5) { const out={}; for(let i=0;i<n;i++) { const key=read(); out[key]=read(); } return out; }
    throw Error('Unsupported CBOR major type');
  }
  const value=read(); if(offset!==bytes.length) throw Error('Trailing CBOR data'); return value;
}
function metadata(text) {
  const out={}; for(const line of text.split(/\r?\n/)) { const m=line.match(/^##\s+([^:]+):\s?(.*)$/); if(m) out[m[1]]=m[2]; } return out;
}
function stored(meta,key) {
  const value=meta[key]; if(value===undefined) return undefined;
  const chunks=value.match(/^~(\d+)~$/); if(!chunks) return value;
  let result=''; for(let i=1;i<=Number(chunks[1]);i++) { if(meta[`${key}-${i}`]===undefined) throw Error(`Missing chunk ${key}-${i}`); result+=meta[`${key}-${i}`]; } return result;
}
function entityRows(meta,kind,fields) {
  const prefix=`X-${kind}-`;
  const ids=decodeCBOR(inflateSync(Buffer.from(stored(meta,prefix+'IDS'),'base64')));
  if(!Array.isArray(ids)) throw Error('Missing ID array');
  const out={};
  for(const id of ids) {
    if(!Number.isInteger(id)||id<=0||out[id]) throw Error(`Invalid/duplicate ${kind} ID ${id}`);
    const value=stored(meta,`${prefix}${id}-S`); if(!value) throw Error(`Missing ${kind} ${id}`);
    const row=decodeCBOR(Buffer.from(value,'base64')), item={id};
    for(const [field,index] of Object.entries(fields)) {
      const table=stored(meta,`${prefix}${id}-${index}`);
      const v=table===undefined?row[Array.isArray(row)?index-1:index]:decodeCBOR(Buffer.from(table,'base64'));
      if(v!==undefined && v!==null) item[field]=v;
    }
    if(!item.name) item.name=`${kind} ${id}`;
    out[id]=item;
  }
  return out;
}
function lua(value) {
  if(value===null||value===undefined) return 'nil';
  if(typeof value==='string') return '"'+value.replace(/[\\"\x00-\x1f\x7f]/g,c=>c==='\\'?'\\\\':c==='"'?'\\"':'\\'+c.charCodeAt(0).toString().padStart(3,'0'))+'"';
  if(typeof value==='number') { if(!Number.isFinite(value)) throw Error('Non-finite value'); return String(value); }
  if(typeof value==='boolean') return String(value);
  if(Array.isArray(value)) return '{'+value.map(lua).join(',')+'}';
  return '{'+Object.entries(value).map(([k,v])=>'['+(/^\d+$/.test(k)?k:lua(k))+']='+lua(v)).join(',')+'}';
}
// City membership is derived only from recorded quest starters, never from
// the destination zone, nearest capital, faction, or the player's position.
function questCities(quest,npcs,objects) {
  const capitals=new Set([1497,1519,1537,1637,1638,1657]);
  const cities=new Set();
  for(const [group,records] of [[0,npcs],[1,objects]]) {
    const starters=Array.isArray(quest.startedBy)?quest.startedBy[group]:quest.startedBy?.[group+1];
    for(const id of starters||[]) {
      const source=records[id]; if(!source) continue;
      if(capitals.has(source.zoneID)) cities.add(source.zoneID);
      for(const area of Object.keys(source.spawns||{})) if(capitals.has(Number(area))) cities.add(Number(area));
    }
  }
  return [...cities].sort((a,b)=>a-b);
}
function build(sourceDir, output=path.join(__dirname,'..','addon','AzerMind_Data')) {
  const source=fs.readFileSync(path.join(sourceDir,'QuestieDB_Forever.toc'));
  const meta=metadata(source.toString('utf8'));
  if(meta['X-Flavor']!=='Forever'||meta['X-Mode']!=='baked') throw Error('Requires a baked Forever artifact');
  if(meta['X-Contract-Version']!=='4') throw Error('Unsupported source schema; review the importer before updating');
  const items=entityRows(meta,'Item',{name:1,npcDrops:2,objectDrops:3,itemDrops:4,startQuest:5,questRewards:6,itemLevel:9,requiredLevel:10,classID:12,subclassID:13,vendors:14,relatedQuests:15,teachesSpell:16});
  const quests=entityRows(meta,'Quest',{name:1,startedBy:2,finishedBy:3,requiredLevel:4,level:5,requiredRaces:6,requiredClasses:7,objectivesText:8,objectives:10,sourceItemId:11,preQuestGroup:12,preQuestSingle:13,exclusiveTo:16,zoneID:17,requiredSkill:18,requiredMinRep:19,requiredMaxRep:20,requiredSourceItems:21,nextQuestInChain:22,questFlags:23,parentQuest:25,requiredSpell:30,requiredSpecialization:31,requiredMaxLevel:32,availableUntilCompleted:33,availableStartingWith:34,requiredRanks:35,disabledByQuest:36});
  const npcs=entityRows(meta,'Npc',{name:1,minLevel:4,maxLevel:5,spawns:7,zoneID:9,friendlyToFaction:13});
  const objects=entityRows(meta,'Object',{name:1,spawns:4,zoneID:5});
  for(const quest of Object.values(quests)) quest.cityIDs=questCities(quest,npcs,objects);
  const warnings={missingQuestReferences:0,itemsWithoutSources:0};
  for(const item of Object.values(items)) {
    if(!item.npcDrops?.length&&!item.vendors?.length&&!item.questRewards?.length&&!item.objectDrops?.length) warnings.itemsWithoutSources++;
    for(const qid of item.questRewards||[]) { if(quests[qid]) (quests[qid].rewardItems??=[]).push(item.id); else warnings.missingQuestReferences++; }
  }
  const manifest={schema:1,layout:2,flavor:'Forever',version:meta.Version,source:'QuestieDB',commit:meta['X-BUILD-COMMIT'],sha256:crypto.createHash('sha256').update(source).digest('hex'),
    counts:{items:Object.keys(items).length,quests:Object.keys(quests).length,npcs:Object.keys(npcs).length,objects:Object.keys(objects).length},
    coverage:{rarity:false,icons:false,inventorySlot:false,itemStats:false,dropRates:false,craftingRecipes:false,liveAvailability:false,dynamicCorrections:false},warnings};
  fs.mkdirSync(output,{recursive:true});
  let previous; try { previous=JSON.parse(fs.readFileSync(path.join(output,'manifest.json'))); } catch {}
  let previousIndex={}; try { previousIndex=JSON.parse(fs.readFileSync(path.join(output,'record-hashes.json'))); } catch {}
  const index={},diff={};
  for(const [kind,records] of Object.entries({items,quests,npcs,objects})) {
    index[kind]={}; diff[kind]={added:[],changed:[],removed:[]};
    for(const [id,record] of Object.entries(records)) {
      const hash=crypto.createHash('sha256').update(JSON.stringify(record)).digest('hex'); index[kind][id]=hash;
      if(!previousIndex[kind]?.[id]) diff[kind].added.push(Number(id));
      else if(previousIndex[kind][id]!==hash) diff[kind].changed.push(Number(id));
    }
    for(const id of Object.keys(previousIndex[kind]||{})) if(!records[id]) diff[kind].removed.push(Number(id));
  }
  const pick=(records,fields)=>Object.fromEntries(Object.entries(records).map(([id,row])=>[id,Object.fromEntries(fields.filter(k=>row[k]!==undefined).map(k=>[k,row[k]]))]));
  const itemIndex=pick(items,['id','name','requiredLevel','itemLevel','classID','subclassID']);
  const questIndex=pick(quests,['id','name','level','zoneID','cityIDs','requiredLevel','requiredRaces','requiredClasses']);
  fs.writeFileSync(path.join(output,'Catalog.lua'),'-- Generated lightweight search index. See NOTICE.md.\nAzerMindCatalog='+lua({manifest,loaded:{},itemIndex:{},questIndex:{},items:{},quests:{},npcs:{},objects:{}})+'\n');
  function writeModule(dir,name,groups,initial=[],part) {
    fs.mkdirSync(dir,{recursive:true}); const files=[...initial];
    for(const [kind,records] of Object.entries(groups)) {
    const values=Object.values(records);
    for(let start=0;start<values.length;start+=1000) {
      const name=kind+'-'+(start/1000+1)+'.lua'; files.push(name);
      fs.writeFileSync(path.join(dir,name),'-- Generated QuestieDB-derived data. See AzerMind_Data/NOTICE.md.\n'+values.slice(start,start+1000).map(record=>'AzerMindCatalog.'+kind+'['+record.id+']='+lua(record)).join('\n')+'\n');
    }
    }
    if(part) { files.push('Ready.lua'); fs.writeFileSync(path.join(dir,'Ready.lua'),'AzerMindCatalog.loaded.'+part+'=true\n'); }
    fs.writeFileSync(path.join(dir,name+'.toc'),'## Interface: 16001\n## Title: AzerMind - '+(part||'Catalog index')+'\n## Version: '+manifest.version+'\n## LoadOnDemand: 1\n'+(part?'## Dependencies: AzerMind_Data\n':'')+files.join('\n')+'\n');
  }
  writeModule(output,'AzerMind_Data',{itemIndex,questIndex},['Catalog.lua']);
  writeModule(output+'_ItemDetails','AzerMind_Data_ItemDetails',{items},[],'ItemDetails');
  writeModule(output+'_QuestDetails','AzerMind_Data_QuestDetails',{quests},[],'QuestDetails');
  // Preserve every recorded spawn; entity browsing paginates at runtime.
  const compactWorld=records=>pick(records,['id','name','minLevel','maxLevel','spawns','zoneID','friendlyToFaction']);
  writeModule(output+'_World','AzerMind_Data_World',{npcs:compactWorld(npcs),objects:compactWorld(objects)},[],'World');
  // Remove only files owned by the previous generator layout, inside output.
  for(const file of fs.readdirSync(output)) if(/^(items|quests|npcs|objects)-\d+\.lua$/.test(file)) fs.unlinkSync(path.join(output,file));
  fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  for(const file of ['LICENSE.md','gpl-3.0.md']) fs.copyFileSync(path.join(sourceDir,file),path.join(output,'SOURCE-'+file));
  fs.writeFileSync(path.join(output,'NOTICE.md'),'# Catalog provenance\n\nDerived from QuestieDB '+manifest.version+' (https://github.com/Questie/QuestieDB), commit '+manifest.commit+'.\nOriginal contributors and licensing limitations are preserved in SOURCE-LICENSE.md; GPL text is in SOURCE-gpl-3.0.md. No name or logo rights are claimed.\n\nThis snapshot uses the baked Forever base and static corrections. Runtime dynamic corrections are not executed. Coverage is not a guarantee of live Forever accuracy. Unknown fields remain unknown. Item reward links are derived from item.questRewards and may be incomplete.\n');
  const changes={previous:previous?.sha256||null,current:manifest.sha256,counts:manifest.counts,warnings,diff};
  fs.writeFileSync(path.join(output,'build-report.json'),JSON.stringify(changes,null,2)+'\n');
  fs.writeFileSync(path.join(output,'record-hashes.json'),JSON.stringify(index)+'\n');
  return manifest;
}
module.exports={decodeCBOR,metadata,stored,entityRows,lua,build,questCities};
if(require.main===module) { if(!process.argv[2]) throw Error('Usage: node tools/build-catalog.js PATH_TO_QUESTIEDB'); console.log(JSON.stringify(build(path.resolve(process.argv[2])),null,2)); }

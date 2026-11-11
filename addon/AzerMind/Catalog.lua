-- Adapter over the bundled snapshot. No Questie addon or network required.
local cachedItems, cachedQuests
function AzerMind.LoadCatalog(part)
	if AzerMindCatalog and (not part or AzerMindCatalog.manifest.layout~=2 or AzerMindCatalog.loaded[part]) then return AzerMindCatalog end
	if InCombatLockdown and InCombatLockdown() then return nil, "Open the catalog outside combat." end
	local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
	if not load then return nil, "This client cannot load the bundled catalog." end
	local module=AzerMindCatalog and part and ("AzerMind_Data_"..part) or "AzerMind_Data"
	local ok, loaded, reason = pcall(load, module)
	if not ok or not loaded or not AzerMindCatalog then return nil, "Catalog unavailable: " .. tostring(reason or loaded or "Install AzerMind_Data and restart the game.") end
	if part and not AzerMindCatalog.loaded[part] then
		if module=="AzerMind_Data" then return AzerMind.LoadCatalog(part) end
		return nil,"Catalog module is incomplete: "..module
	end
	return AzerMindCatalog
end
local function Read(fn,...)
	if type(fn)~="function" then return nil end
	local ok,a,b,c,d,e,f,g,h,i,j,k,l,m=pcall(fn,...)
	if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m end
	return nil
end
local cityNames={[1497]="Undercity",[1519]="Stormwind",[1537]="Ironforge",[1637]="Orgrimmar",[1638]="Thunder Bluff",[1657]="Darnassus"}
local areaNames={}
function AzerMind.QuestAreaName(id,fallback)
	if type(id)~="number" or id<=0 then return fallback or "Other / unlocated" end
	if not areaNames[id] then areaNames[id]=Read(C_Map and C_Map.GetAreaInfo or GetAreaInfo,id) or cityNames[id] or ("Area "..id) end
	return areaNames[id]
end
function AzerMind.AssignQuestGeography(quests)
	local db=AzerMindCatalog
	local index=db and (db.questIndex or db.quests) or {}
	for _,q in ipairs(quests) do
		local record=index[q.id] or q.record
		q.cityIDs=record and record.cityIDs or {}
		if record then
			q.areaID=record.zoneID
			q.zone=AzerMind.QuestAreaName(record.zoneID)
		end
		q.zone=type(q.zone)=="string" and q.zone~="" and q.zone or "Other / unlocated"
		q.zoneKey=q.areaID and q.areaID>0 and tostring(q.areaID) or ("label:"..q.zone)
		local names={}; for _,id in ipairs(q.cityIDs) do names[#names+1]=AzerMind.QuestAreaName(id) end
		table.sort(names); q.cityLabel=table.concat(names,", ")
	end
	table.sort(quests,function(a,b)
		if a.zone~=b.zone then return a.zone<b.zone end
		if a.title~=b.title then return a.title<b.title end
		return a.id<b.id
	end)
end
function AzerMind.QuestMatchesLocation(q,city,zone)
	if zone~="all" and q.zoneKey~=zone then return false end
	if city=="all" then return true end
	if city=="none" then return #(q.cityIDs or {})==0 end
	for _,id in ipairs(q.cityIDs or {}) do if tostring(id)==city then return true end end
	return false
end
function AzerMind.QuestLocationOptions(quests,city)
	local cities,zones={},{}
	for _,q in ipairs(quests) do
		if #(q.cityIDs or {})==0 then cities.none=(cities.none or 0)+1 end
		for _,id in ipairs(q.cityIDs or {}) do local key=tostring(id); cities[key]=(cities[key] or 0)+1 end
		if AzerMind.QuestMatchesLocation(q,city,"all") then
			local key=q.zoneKey
			zones[key]=zones[key] or {key=key,label=q.zone,count=0}
			zones[key].count=zones[key].count+1
		end
	end
	local cityOptions,zoneOptions={},{}
	for key,count in pairs(cities) do cityOptions[#cityOptions+1]={key=key,label=key=="none" and "Outside recorded capitals" or AzerMind.QuestAreaName(tonumber(key)),count=count} end
	for _,entry in pairs(zones) do zoneOptions[#zoneOptions+1]=entry end
	table.sort(cityOptions,function(a,b) return a.label<b.label end)
	table.sort(zoneOptions,function(a,b) return a.label<b.label end)
	table.insert(cityOptions,1,{key="all",label="All cities"})
	table.insert(zoneOptions,1,{key="all",label="All zones"})
	return cityOptions,zoneOptions
end
function AzerMind.CatalogItemList()
	local db,err=AzerMind.LoadCatalog(); if not db then return nil,err end
	if cachedItems then return cachedItems end
	cachedItems={}
	local classNames,subclassNames={},{}
	for id,item in pairs(db.itemIndex or db.items) do
		local key=tostring(item.classID)..":"..tostring(item.subclassID)
		if not classNames[item.classID or -1] then classNames[item.classID or -1]=Read(GetItemClassInfo,item.classID) or "" end
		if not subclassNames[key] then subclassNames[key]=Read(GetItemSubClassInfo,item.classID,item.subclassID) or "" end
		local kind,subtype=classNames[item.classID or -1],subclassNames[key]
		if subtype=="" then subtype=nil end
		if not subtype and item.classID==4 then subtype=({[1]="Cloth",[2]="Leather",[3]="Mail",[4]="Plate",[6]="Shields"})[item.subclassID] end
		cachedItems[#cachedItems+1]={key="catalog:"..id,id=id,name=item.name,count=1,location="Catalog",
			level=item.requiredLevel,itemLevel=item.itemLevel,classID=item.classID,subclassID=item.subclassID,kind=kind or "",subtype=subtype or "",slot=""}
	end
	table.sort(cachedItems,function(a,b) if a.name==b.name then return a.id<b.id end; return a.name<b.name end)
	return cachedItems
end
function AzerMind.EnrichCatalogItem(item)
	if not item.link then
		local _,_,_,slot,icon=Read(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,item.id)
		item.slot=slot or item.slot; item.icon=icon or item.icon
		item.link=AzerMind.EntityLink("item",item.id,item.name)
	end
	local name,link,quality,_,level,kind,subtype,_,slot,icon=Read(C_Item and C_Item.GetItemInfo or GetItemInfo,item.id)
	if name then
		item.quality=quality; item.level=level; item.kind=kind or item.kind; item.subtype=subtype or item.subtype
		item.slot=slot or item.slot; item.icon=icon or item.icon; item.link=AzerMind.NormalizeItemLink(link or item.link)
	end
end
local function Ids(values)
	local result={}; for _,id in ipairs(values or {}) do result[#result+1]=tostring(id) end; return table.concat(result,",")
end
local function Named(values,records)
	local result={}
	for _,id in ipairs(values or {}) do
		local record=records[id]; result[#result+1]=(record and record.name or "Unknown").." #"..id
		if record and record.spawns then
			local area,positions=next(record.spawns)
			local pos=positions and positions[1]
			if type(pos)=="table" and type(pos[1])=="number" and type(pos[2])=="number" then
				local zone=Read(C_Map and C_Map.GetAreaInfo,area) or ("Area "..tostring(area))
				result[#result]=result[#result].." ("..zone.." "..string.format("%.1f, %.1f",pos[1],pos[2]).."; one recorded spawn)"
			end
		end
		if #result>=12 then break end
	end
	return table.concat(result,", ")
end
function AzerMind.CatalogQuestMatchesCharacter(q,selectedRace,selectedClass)
	local _,_,race=Read(UnitRace,"player")
	local _,_,class=Read(UnitClass,"player")
	for _,check in ipairs({{(q.record or {}).requiredRaces,selectedRace or race},{(q.record or {}).requiredClasses,selectedClass or class}}) do
		local mask,id=check[1],check[2]
		if type(mask)=="number" and mask>0 and type(id)=="number" and id>0 and math.floor(mask/2^(id-1))%2==0 then return false end
	end
	return true -- Only filters known race/class conflicts; does not establish availability.
end
function AzerMind.CatalogItemDetails(id)
	local db,err=AzerMind.LoadCatalog("ItemDetails"); if not db then return err end
	local world,worldError=AzerMind.LoadCatalog("World")
	local item=db.items[id]; if not item then return "Details unavailable." end
	local lines={"Catalog item #"..id.."; source QuestieDB "..db.manifest.version..". Snapshot; unknown sources are not proof of absence."}
	if item.requiredLevel then lines[#lines+1]="Required level: "..item.requiredLevel end
	if item.npcDrops then lines[#lines+1]="Drops from: "..Named(item.npcDrops,db.npcs).." (rates unknown)" end
	if item.vendors then lines[#lines+1]="Vendors: "..Named(item.vendors,db.npcs) end
	if item.objectDrops then lines[#lines+1]="Objects: "..Named(item.objectDrops,db.objects) end
	if item.questRewards then lines[#lines+1]="Reward from quests: "..Named(item.questRewards,db.questIndex or db.quests) end
	if item.relatedQuests then lines[#lines+1]="Related quest IDs: "..Ids(item.relatedQuests) end
	if item.startQuest then lines[#lines+1]="Starts quest #"..item.startQuest end
	if not world then lines[#lines+1]=worldError end
	return table.concat(lines,"\n")
end
function AzerMind.CatalogQuestList()
	local db,err=AzerMind.LoadCatalog(); if not db then return nil,err end
	if cachedQuests then return cachedQuests end
	cachedQuests={}
	local zones={}
	for id,q in pairs(db.questIndex or db.quests) do
		local area=q.zoneID or 0
		if not zones[area] then zones[area]=AzerMind.QuestAreaName(q.zoneID) end
		local zone=zones[area]
		cachedQuests[#cachedQuests+1]={id=id,title=q.name,level=q.level,zone=zone,record=q}
	end
	table.sort(cachedQuests,function(a,b) if a.title==b.title then return a.id<b.id end; return a.title<b.title end)
	return cachedQuests
end
function AzerMind.CatalogQuestStatus(q)
	local api=C_QuestLog or {}
	local active=Read(api.GetLogIndexForQuestID or GetQuestLogIndexByID,q.id)
	if type(active)=="number" and active>0 then
        local complete=Read(api.IsComplete,q.id)
        if complete==true or complete==1 then return "Ready to turn in" end
        for _,entry in ipairs(AzerMind.ActiveQuests and AzerMind.ActiveQuests() or {}) do if entry.id==q.id and entry.complete then return "Ready to turn in" end end
        return "Active"
    end
	local completed=Read(api.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted,q.id)
	if completed==true then return "Completed" end
	local level=Read(UnitLevel,"player")
	if not AzerMind.CatalogQuestMatchesCharacter(q) then return "Race/class restricted" end
	if level and q.record.requiredLevel and q.record.requiredLevel>level then return "Level too low" end
	return "Availability unknown"
end
function AzerMind.CatalogQuestDetails(q)
	local db,err=AzerMind.LoadCatalog("QuestDetails"); if not db then return err end
	local world,worldError=AzerMind.LoadCatalog("World")
	local record=db.quests[q.id] or q.record
	local lines={"Catalog quest: "..AzerMind.EntityLink("quest",q.id,q.title).." · "..q.zone.." · "..AzerMind.CatalogQuestStatus(q),
		"QuestieDB "..db.manifest.version.." snapshot. Listed requirements may be incomplete; do not assume this quest is available."}
	if q.cityLabel and q.cityLabel~="" then lines[#lines+1]="Recorded starting cities: "..q.cityLabel end
	for _,text in ipairs(record.objectivesText or {}) do lines[#lines+1]=AzerMind.PlainText(text) end
	if record.requiredLevel then lines[#lines+1]="Minimum level: "..record.requiredLevel end
	if record.rewardItems then lines[#lines+1]="Known item rewards (may be incomplete): "..Named(record.rewardItems,db.itemIndex or db.items) end
	for _,field in ipairs({"startedBy","finishedBy"}) do
		local groups=record[field] or {}; local names={}
		for _,entry in ipairs({{1,db.npcs},{2,db.objects},{3,db.itemIndex or db.items}}) do
			local text=Named(groups[entry[1]],entry[2]); if text~="" then names[#names+1]=text end
		end
		if #names>0 then lines[#lines+1]=(field=="startedBy" and "Starts at: " or "Turn in at: ")..table.concat(names,"; ") end
	end
	for _,field in ipairs({"preQuestSingle","preQuestGroup","rewardItems","requiredRaces","requiredClasses","requiredSkill","requiredMinRep","requiredMaxRep","requiredSpell","requiredMaxLevel","exclusiveTo","nextQuestInChain"}) do
		local value=record[field]
		if value then lines[#lines+1]=field..": "..(type(value)=="table" and Ids(value) or tostring(value)) end
	end
	if not world then lines[#lines+1]=worldError end
	return table.concat(lines,"\n")
end


-- Area IDs from the catalog are NOT UI map IDs. Resolve only exact,
-- unambiguous localized area names against the client's own map tree.
function AzerMind.QuestAreaMap(area)
 local name=Read(C_Map and C_Map.GetAreaInfo,tonumber(area))
 if not name then return end
 local maps=Read(C_Map and C_Map.GetMapChildrenInfo,947,nil,true) or {}
 local found
 for _,info in ipairs(maps) do
  if info.name==name and type(info.mapID)=="number" then
   if found and found~=info.mapID then return end
   found=info.mapID
  end
 end
 return found
end
function AzerMind.QuestMapLocations(id, turnin)
 local db,err=AzerMind.LoadCatalog("QuestDetails"); if not db then return nil,err end
 local world,why=AzerMind.LoadCatalog("World"); if not world then return nil,why end
 local q=db.quests[tonumber(id)]; if not q then return nil,"Quest not found in the bundled catalog." end
 local result,seen,mapped={},{},{}
 local function Spawn(record,kind)
  for area,positions in pairs(record and record.spawns or {}) do
   if mapped[area]==nil then mapped[area]=AzerMind.QuestAreaMap(area) or false end
   local map=mapped[area]
   if map then
    for _,pos in ipairs(positions) do
     local x,y=pos[1],pos[2]
     if type(x)=="number" and type(y)=="number" and x==x and y==y and x>=0 and y>=0 and x<=100 and y<=100 then
      local key=map..":"..x..":"..y
      if not seen[key] and #result<200 then
       seen[key]=true
       local label=kind..": "..(record.name or "Unknown").." - "..AzerMind.QuestAreaName(tonumber(area))..string.format(" (%.1f, %.1f)",x,y)
       result[#result+1]={map,x,y,label,"quest"}
      end
     end
    end
   end
  end
 end
 if turnin then
  for _,nid in ipairs((q.finishedBy or {})[1] or {}) do Spawn(db.npcs[nid],"Turn in") end
  for _,oid in ipairs((q.finishedBy or {})[2] or {}) do Spawn(db.objects[oid],"Turn in") end
 else
  for _,entry in ipairs((q.objectives or {})[1] or {}) do Spawn(db.npcs[entry[1]],"Objective") end
  for _,entry in ipairs((q.objectives or {})[2] or {}) do Spawn(db.objects[entry[1]],"Objective") end
  if #((q.objectives or {})[3] or {})>0 then
   local items=AzerMind.LoadCatalog("ItemDetails")
   if items then for _,entry in ipairs(q.objectives[3]) do
    local item=db.items[entry[1]]
    for _,nid in ipairs(item and item.npcDrops or {}) do Spawn(db.npcs[nid],"Item source") end
    for _,oid in ipairs(item and item.objectDrops or {}) do Spawn(db.objects[oid],"Item source") end
   end end
  end
 end
 table.sort(result,function(a,b) if a[1]~=b[1] then return a[1]<b[1] end; if a[2]~=b[2] then return a[2]<b[2] end; return a[3]<b[3] end)
 if #result==0 then return nil,"No reliable mapped coordinates for this quest "..(turnin and "turn-in." or "objective. Try the turn-in option if the quest is complete.") end
 return result,q.name
end
function AzerMind.MarkQuestOnMap(id,turnin)
 if not AzerMindMap then AzerMind.ShowCopy("Map support is unavailable."); return end
 local points,title=AzerMind.QuestMapLocations(id,turnin)
 if not points then AzerMind.ShowCopy(title); return end
 local function Mark(index)
  local ok,err=AzerMindMap.MarkQuest(tonumber(id),title,points[index])
  if not ok then AzerMind.ShowCopy(err) else AzerMind.HideReferenceDialogs() end
 end
 if #points==1 then Mark(1); return end
 local options={}
 for i,p in ipairs(points) do options[#options+1]={key=tostring(i),label=p[4]} end
 AzerMind.ShowQuestLocationMenu(AzerMindFrame,options,nil,function(option) Mark(tonumber(option.key)) end)
end

-- A single bounded browser for NPCs, item sources, and recorded coordinates.
local entityBrowser
function AzerMind.ShowSourceBrowser(kind,id)
 local db,err=AzerMind.LoadCatalog("World")
 if not db then AzerMind.ShowCopy(err); return end
 local entries={}; local title="Mobs & NPCs"
 local function Add(entityKind,entityID,role)
  local records=entityKind=="npc" and db.npcs or entityKind=="object" and db.objects or entityKind=="item" and (db.itemIndex or db.items) or db.questIndex or db.quests
  local r=records[entityID]
  entries[#entries+1]={kind=entityKind,id=entityID,name=r and r.name or (entityKind.." #"..entityID),role=role,record=r}
 end
 if kind=="item" then
  db,err=AzerMind.LoadCatalog("ItemDetails"); if not db then AzerMind.ShowCopy(err); return end
  local item=db.items[id]; title=item and item.name or ("Item #"..id)
  for _,spec in ipairs({{"npcDrops","npc","Drops from"},{"vendors","npc","Sold by"},{"objectDrops","object","Found in"},{"questRewards","quest","Quest reward"}}) do
   for _,source in ipairs(item and item[spec[1]] or {}) do Add(spec[2],source,spec[3]) end
  end
 elseif kind=="quest" then
  db,err=AzerMind.LoadCatalog("QuestDetails"); if not db then AzerMind.ShowCopy(err); return end
  local q=db.quests[id]; title=q and q.name or ("Quest #"..id)
  for _,spec in ipairs({{"startedBy","Starts at"},{"finishedBy","Turn in at"},{"objectives","Objective"}}) do
   for group,entityKind in ipairs({"npc","object"}) do
    for _,value in ipairs(((q or {})[spec[1]] or {})[group] or {}) do Add(entityKind,type(value)=="table" and value[1] or value,spec[2]) end
   end
  end
 elseif kind=="npc" or kind=="object" then
  Add(kind,id,"Recorded location")
  if kind=="npc" then
   local items=AzerMind.LoadCatalog("ItemDetails"); local quests=AzerMind.LoadCatalog("QuestDetails")
   local function Contains(values) for _,value in ipairs(values or {}) do if value==id then return true end end end
   for itemID,item in pairs(items and db.items or {}) do
    if Contains(item.npcDrops) then Add("item",itemID,"Recorded drop") end
    if Contains(item.vendors) then Add("item",itemID,"Sold here") end
   end
   for questID,q in pairs(quests and db.quests or {}) do
    if Contains((q.startedBy or {})[1]) then Add("quest",questID,"Quest giver") end
    if Contains((q.finishedBy or {})[1]) then Add("quest",questID,"Quest turn-in") end
   end
  end
 else for npcID in pairs(db.npcs or {}) do Add("npc",npcID,"NPC") end end
 table.sort(entries,function(a,b) if a.name~=b.name then return a.name<b.name end; return a.id<b.id end)
 if not entityBrowser then
  local T=AzerMindTheme
  local p=CreateFrame("Frame","AzerMindEntityBrowser",AzerMindFrame); entityBrowser=p
  p:SetSize(700,620); p:SetPoint("CENTER"); p:SetFrameStrata("FULLSCREEN_DIALOG"); p:SetFrameLevel(AzerMindFrame:GetFrameLevel()+200)
  p:EnableMouse(true); T.Surface(p,"window"); T.FitDialog(p); table.insert(UISpecialFrames,"AzerMindEntityBrowser")
  p.title=T.Label(p,"",20,-20,T.fonts.title)
  p.search=T.SearchField(p,nil,650,"Search name, NPC ID, role or zone"); p.search:SetPoint("TOPLEFT",24,-92)
  p.rows={}; p.page=1; p.zoneFilter="all"; p.roleFilter="all"
  p.zone=T.Selector(p,"Zone",320,function()
   local options={{key="all",label="All"}}; local seen={}
   for _,e in ipairs(p.entries or {}) do for area in pairs(e.record and e.record.spawns or {}) do
    if not seen[area] then seen[area]=true; options[#options+1]={key=tostring(area),label=AzerMind.QuestAreaName(tonumber(area))} end
   end end
   return options
  end,"all",function(o) p.zoneFilter=o.key; p.page=1; p.Refresh() end); p.zone:SetPoint("TOPLEFT",20,-130)
  p.role=T.Selector(p,"Role",320,function()
   local options={{key="all",label="All"}}; local seen={}
   for _,e in ipairs(p.entries or {}) do if not seen[e.role] then seen[e.role]=true; options[#options+1]={key=e.role,label=e.role} end end
   return options
  end,"all",function(o) p.roleFilter=o.key; p.page=1; p.Refresh() end); p.role:SetPoint("TOPLEFT",352,-130)
  p.info=T.Label(p,"",20,-516); p.info:SetWidth(650)
  local function ShowLocations(entry)
   local options={}
   for area,positions in pairs(entry.record and entry.record.spawns or {}) do
    for _,pos in ipairs(positions) do
     local x,y=pos[1],pos[2]
     if type(x)=="number" and type(y)=="number" and x>=0 and x<=100 and y>=0 and y<=100 then
      options[#options+1]={key=#options+1,label=AzerMind.QuestAreaName(tonumber(area))..string.format(" (%.1f, %.1f)",x,y),area=tonumber(area),x=x,y=y}
     end
    end
   end
   if #options==0 then p.info:SetText("No coordinates are recorded for "..entry.name.."."); return end
   T.ShowChoiceMenu(p,options,nil,function(o)
    local map=AzerMind.QuestAreaMap(o.area)
    if not map then p.info:SetText("This client could not resolve the recorded zone to a map."); return end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn,"Blizzard_WorldMap") end
    if WorldMapFrame and WorldMapFrame.SetMapID then
     WorldMapFrame:SetMapID(map); WorldMapFrame:Show()
     if C_Map and C_Map.SetUserWaypoint and Read(C_Map.CanSetUserWaypointOnMap,map) and UiMapPoint and UiMapPoint.CreateFromCoordinates then
      local point=Read(UiMapPoint.CreateFromCoordinates,map,o.x/100,o.y/100)
      if point then pcall(C_Map.SetUserWaypoint,point) end
     end
     AzerMind.HideReferenceDialogs()
    end
   end,"Search recorded locations")
  end
  for i=1,7 do
   local row=T.Button(p,"",500,40,function() end,"LEFT"); row:SetPoint("TOPLEFT",20,-174-(i-1)*46)
   row:SetScript("OnClick",function(self)
    if self.entry.kind=="quest" then AzerMind.ShowEntityMenu("quest",self.entry.id,"quest:"..self.entry.id,self.entry.name)
    else AzerMind.ShowSourceBrowser(self.entry.kind,self.entry.id) end
   end)
   row.map=T.Button(p,"Map",64,32,function() ShowLocations(row.entry) end); row.map:SetPoint("TOPLEFT",532,-178-(i-1)*46)
   row.link=T.Button(p,"Add",64,32,function()
    local chat=AzerMind.SettingsState(); if chat then AzerMind.AppendQuestDraft(AzerMind.EntityLink(row.entry.kind,row.entry.id,row.entry.name),chat.id) end
   end); row.link:SetPoint("TOPLEFT",604,-178-(i-1)*46)
   T.Tooltip(row,function() return row.entry.name.." #"..row.entry.id end,function()
    local r=row.entry.record or {}; return row.entry.role..(r.minLevel and (" | Levels "..r.minLevel.."-"..(r.maxLevel or r.minLevel)) or "").."\n"..(row.entry.zones or "").."\nClick for details. Map lists all recorded coordinates."
   end)
   p.rows[i]=row
  end
  function p.Refresh()
   local visible={}; local filter=(p.search:GetText() or ""):lower()
   for _,entry in ipairs(p.entries or {}) do
    local areas={}; for area in pairs(entry.record and entry.record.spawns or {}) do areas[#areas+1]=AzerMind.QuestAreaName(tonumber(area)) end
    entry.zones=table.concat(areas,", ")
    local zoneMatch=p.zoneFilter=="all"
    for area in pairs(entry.record and entry.record.spawns or {}) do if tostring(area)==p.zoneFilter then zoneMatch=true end end
    if zoneMatch and (p.roleFilter=="all" or p.roleFilter==entry.role) and (entry.name.." "..entry.id.." "..entry.role.." "..entry.zones):lower():find(filter,1,true) then visible[#visible+1]=entry end
   end
   local pages=math.max(1,math.ceil(#visible/7)); p.page=math.max(1,math.min(p.page,pages))
   for i,row in ipairs(p.rows) do
    local entry=visible[(p.page-1)*7+i]; row:SetShown(entry~=nil); row.map:SetShown(entry~=nil); row.link:SetShown(entry~=nil)
    if entry then row.entry=entry; row:SetText(entry.name.." | "..entry.role..(entry.zones~="" and (" | "..entry.zones) or "")); row.map:SetEnabled(entry.kind=="npc" or entry.kind=="object") end
   end
   p.info:SetText(#visible.." results | Page "..p.page.." / "..pages..(#visible==0 and " | No recorded sources." or ""))
  end
  local previous=T.Button(p,"Previous",100,28,function() p.page=p.page-1; p.Refresh() end); previous:SetPoint("TOPLEFT",20,-570)
  local next=T.Button(p,"Next",100,28,function() p.page=p.page+1; p.Refresh() end); next:SetPoint("TOPLEFT",130,-570)
  local all=T.Button(p,"All NPCs",100,28,function() AzerMind.ShowSourceBrowser() end); all:SetPoint("TOPLEFT",250,-570)
  local close=T.Button(p,"Close",100,28,function() p:Hide() end); close:SetPoint("TOPLEFT",580,-570)
  local copy=T.Button(p,"Copy",90,28,function()
   local lines={p.title:GetText()}; for _,e in ipairs(p.entries) do lines[#lines+1]=e.name.." #"..e.id.." | "..e.role.." | "..(e.zones or "") end
   AzerMind.ShowCopy(table.concat(lines,"\n"))
  end); copy:SetPoint("TOPLEFT",370,-570)
  local url=T.Button(p,"URL",90,28,function() local e=p.entries[1]; if e then AzerMind.ShowCopy("https://www.wowhead.com/forever/"..e.kind.."="..e.id) end end); url:SetPoint("TOPLEFT",470,-570)
  p.search:SetScript("OnTextChanged",function() p.page=1; p.Refresh() end)
  p:SetScript("OnHide",function() p.search:ClearFocus(); T.CloseChoiceMenu() end)
 end
 local p=entityBrowser; p.entries=entries; p.page=1; p.zoneFilter="all"; p.roleFilter="all"; p.zone:SetValue("all","All"); p.role:SetValue("all","All"); p.title:SetText(title); p.search:SetText(""); p:Show(); p.Refresh()
end

function AzerMind.HideReferenceDialogs()
 for _,name in ipairs({"AzerMindEntityBrowser","AzerMindInstanceDetails","AzerMindInstancePicker","AzerMindQuestPicker","AzerMindItemPicker"}) do
  local frame=_G[name]; if frame then frame:Hide() end
 end
end

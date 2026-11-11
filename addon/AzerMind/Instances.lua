-- Bundled factual instance snapshot. Internal IDs are not Blizzard instance IDs.
local T = AzerMindTheme
local picker
function AzerMind.InstanceByID(id)
 for _, record in ipairs(AzerMindInstanceData or {}) do if record.id == tonumber(id) then return record end end
end
function AzerMind.InstanceDetails(record, compact)
 if not record then return "Instance not found in this snapshot." end
 local lines={record.type..": "..record.name, "Level range: "..record.level.." (reference range, not an entry requirement)", "Location: "..record.location}
 if record.entrance and record.entrance.x and record.entrance.y then lines[#lines+1]=string.format("Entrance: map %s, %.1f, %.1f",tostring(record.entrance.mapID),record.entrance.x*100,record.entrance.y*100) end
 if record.size then lines[#lines+1]="Group size: "..record.size end
 if record.status then lines[#lines+1]=record.status end
 local bytes=0
 for _,boss in ipairs(record.bosses or {}) do
  local line="Boss: "..boss.name..(boss.npcID and (" (NPC "..boss.npcID..")") or "")
  lines[#lines+1]=line; bytes=bytes+#line
  for _,item in ipairs(boss.loot or {}) do
   line="  Loot: "..item.name.." (item "..(item.id or "ID unavailable")..")"
   if bytes+#line>6000 then lines[#lines+1]="[Partial loot list: attachment size limit]"; break end
   lines[#lines+1]=line; bytes=bytes+#line
  end
 end
 if #(record.bosses or {})==0 then lines[#lines+1]="Boss names and loot: not available in this snapshot." end
 lines[#lines+1]="Source: "..record.source
 lines[#lines+1]="Snapshot may be incomplete; confirm current Forever rules and drops."
 return table.concat(lines,"\n")
end
function AzerMind.FilterInstances(search, kind, zone, nearLevel)
 local result={}; search=tostring(search or ""):lower()
 for _,r in ipairs(AzerMindInstanceData or {}) do
  local haystack=(r.name.." "..r.location):lower()
  for _,b in ipairs(r.bosses or {}) do haystack=haystack.." "..b.name:lower() end
  if (kind=="All" or r.type==kind) and (zone=="All" or r.location==zone) and haystack:find(search,1,true)
   and (not nearLevel or (r.minLevel>0 and nearLevel>=r.minLevel-5 and nearLevel<=r.maxLevel+5)) then result[#result+1]=r end
 end
 return result
end
function AzerMind.InstanceLink(record)
 return AzerMind.EntityLink("azermindinstance",record.id,record.name)
end
function AzerMind.ShowInstancePicker()
 if not picker then
  local p=CreateFrame("Frame","AzerMindInstancePicker",AzerMindFrame,"BackdropTemplate"); picker=p
  p:SetSize(680,620); p:SetPoint("CENTER",AzerMindFrame,"CENTER"); p:SetClampedToScreen(true)
  p:SetFrameStrata("FULLSCREEN_DIALOG"); p:SetFrameLevel(AzerMindFrame:GetFrameLevel()+50); p:EnableMouse(true); T.Surface(p,"window"); T.FitDialog(p)
  table.insert(UISpecialFrames,"AzerMindInstancePicker")
  T.Label(p,"Dungeons & Raids",20,-18,T.fonts.title)
  T.Label(p,"Choose instances to attach to your question. Nothing is sent yet.",20,-47)
  p.selected={}; p.kind="All"; p.zone="All"; p.page=1; p.rows={}
  local Refresh
  local function Button(label,width,x,y,callback)
   local b=T.Button(p,label,width,28,callback); b:SetPoint("TOPLEFT",x,y); b.caption:SetWidth(width-16); b.caption:SetWordWrap(false); return b
  end
  Button("X",28,632,-14,function() p:Hide() end)
  Button("Mobs & NPCs",148,468,-14,function() AzerMind.ShowSourceBrowser() end)
  p.search=T.SearchField(p,"AzerMindInstanceSearch",612,"Search by instance, boss or location")
  p.search:SetSize(612,28); p.search:SetPoint("TOPLEFT",28,-99); p.search:SetAutoFocus(false); T.Type(p.search,"body")
  local tabs={}
  for i,entry in ipairs({{"All","All"},{"Dungeon","Dungeons"},{"Raid","Raids"}}) do
   local kind=entry[1]
   tabs[kind]=Button(entry[2],100,20+(i-1)*108,-140,function() p.kind=kind; p.page=1; Refresh() end)
  end
  local near=CreateFrame("CheckButton",nil,p,"UICheckButtonTemplate")
  near:SetSize(24,24); near:SetPoint("TOPLEFT",420,-142)
  near:SetScript("OnClick",function(self) p.near=self:GetChecked() and true or false; p.page=1; Refresh() end)
  T.Label(p,"Within 5 levels of me",448,-148)
  local zoneButton
  zoneButton=Button("All locations",310,20,-180,function()
   local seen,options={},{{key="All",label="All locations"}}
   for _,r in ipairs(AzerMindInstanceData or {}) do if not seen[r.location] then seen[r.location]=true; options[#options+1]={key=r.location,label=r.location} end end
   table.sort(options,function(a,b) return a.label<b.label end)
   AzerMind.ShowQuestLocationMenu(zoneButton,options,p.zone,function(option) p.zone=option.key; p.page=1; Refresh() end)
  end)
  -- Keep the meaning of this filter visible after its value changes.
  p.locationButton=zoneButton
  T.SelectorAppearance(zoneButton,"location")
  zoneButton:SetScript("OnEnter",function(self)
   GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText("Location")
   GameTooltip:AddLine("Filter by the area containing the dungeon or raid.",1,1,1,true)
   GameTooltip:AddLine("Current: "..(p.zone=="All" and "All locations" or p.zone),1,1,1,true)
   GameTooltip:Show()
  end)
  zoneButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
  local selectedOnly=T.Toggle(p,"Show selected only",200,false,function(value) p.selectedOnly=value; p.page=1; Refresh() end)
  selectedOnly:SetPoint("TOPLEFT",338,-182)
  Button("Reset filters",118,538,-180,function() p.kind="All"; p.zone="All"; p.near=false; p.selectedOnly=false; p.page=1; p.search:SetText(""); Refresh() end)
  p.count=T.Label(p,"",20,-220)
  p.empty=T.Label(p,"No instances match. Try another search or reset the filters.",30,-300)
  p.empty:SetWidth(600); p.empty:SetJustifyH("CENTER")
  p.pageLabel=T.Label(p,"",260,-550)
  local previous=Button("Previous",110,20,-540,function() p.page=p.page-1; Refresh() end)
  local nextButton=Button("Next",110,546,-540,function() p.page=p.page+1; Refresh() end)
  Button("Select page",118,20,-540+32,function()
   for i=(p.page-1)*6+1,math.min(p.page*6,#p.visible) do p.selected[p.visible[i].id]=true end; Refresh()
  end)
  Button("Select all results",140,146,-508,function() for _,r in ipairs(p.visible) do p.selected[r.id]=true end; Refresh() end)
  local clear=Button("Clear selection",140,294,-508,function() p.selected={}; Refresh() end)
  p.attach=Button("Add to message (0)",206,450,-582,function()
   local chat=AzerMind.SettingsState(); if not chat or chat.id~=p.chatId then p.count:SetText("Conversation changed. Reopen Dungeons & Raids."); return end
   local links={}; for _,r in ipairs(AzerMindInstanceData or {}) do if p.selected[r.id] then links[#links+1]=AzerMind.InstanceLink(r) end end
   if #links>0 and AzerMind.AppendQuestDraft(table.concat(links,"\n"),chat.id) then p:Hide() end
  end)
  T.Primary(p.attach)
  Button("Cancel",100,342,-582,function() p:Hide() end)
  p:SetScript("OnHide",T.CloseChoiceMenu)
  Refresh=function()
   local level=p.near and UnitLevel and UnitLevel("player") or nil
   local matches=AzerMind.FilterInstances(p.search:GetText(),p.kind,p.zone,level)
   p.visible={}; for _,r in ipairs(matches) do if not p.selectedOnly or p.selected[r.id] then p.visible[#p.visible+1]=r end end
   local pages=math.max(1,math.ceil(#p.visible/6)); p.page=math.max(1,math.min(p.page,pages))
   zoneButton:SetText("Location: "..(p.zone=="All" and "All locations" or p.zone))
   local selected=0; for _ in pairs(p.selected) do selected=selected+1 end
   selectedOnly:SetValue(p.selectedOnly)
   for kind,button in pairs(tabs) do T.Selected(button,p.kind==kind) end
   near:SetChecked(p.near)
   p.count:SetText(#p.visible.." matching instances   |   "..selected.." selected across all pages")
   p.pageLabel:SetText("Page "..p.page.." of "..pages)
   previous:SetEnabled(p.page>1); nextButton:SetEnabled(p.page<pages)
   p.attach:SetText("Add to message ("..selected..")"); p.attach:SetEnabled(selected>0); clear:SetEnabled(selected>0)
   p.empty:SetShown(#p.visible==0)
   for i=1,6 do
    local r=p.visible[(p.page-1)*6+i]; local row=p.rows[i]
    if not row then
     row=T.Button(p,"",636,40,function() end,"LEFT",true); row:SetPoint("TOPLEFT",20,-244-(i-1)*44)
     local function Toggle() local id=row.record.id; p.selected[id]=not p.selected[id] or nil; Refresh() end
     row:RegisterForClicks("LeftButtonUp","RightButtonUp")
     local function Details() AzerMind.ShowInstanceDetails(row.record,p) end
     row:SetScript("OnClick",function(_,button) if button=="RightButton" then Details() else Toggle() end end)
     row.check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
     row.check:SetSize(24,24); row.check:SetPoint("LEFT",row,"LEFT",4,0); row.check:SetScript("OnClick",Toggle)
     row.name=T.Label(row,"",36,-6,T.fonts.heading); row.name:SetWidth(490); row.name:SetWordWrap(false); row.name:SetJustifyH("LEFT")
     row.meta=T.Label(row,"",36,-26); row.meta:SetWidth(490); row.meta:SetWordWrap(false); row.meta:SetJustifyH("LEFT"); row.meta:SetTextColor(unpack(T.colors.muted))
     row.details=T.Button(row,"Details",84,28,Details); row.details:SetPoint("RIGHT",row,"RIGHT",-6,0)
     T.Tooltip(row,function() return row.record.name end,function() return "Location: "..row.record.location.."\nLeft-click to select. Details or right-click opens the reference." end)
     p.rows[i]=row
    end
    if r then
     row.record=r; row.check:SetChecked(p.selected[r.id]); T.Selected(row,p.selected[r.id])
     row.name:SetText(r.name); row.meta:SetText(r.type.."  |  Lv "..r.level.."  |  Location: "..r.location); row:Show()
    else row:Hide() end
   end
  end
  p.search:SetScript("OnTextChanged",function() p.page=1; Refresh() end)
  p.search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  p.Refresh=Refresh
 end
 local chat=AzerMind.SettingsState(); if not chat then return end
 if picker.chatId~=chat.id then picker.selected={} end
 picker.chatId=chat.id; picker:Show(); picker.Refresh()
end

-- Keep the reference view in the already-known instance module so a live
-- client reload never depends on discovering a newly added TOC file.
do
 -- Interactive reference view. Copy/export is deliberately a separate action.
 local T=AzerMindTheme
 local details
 local function ValidID(id)
  return type(id)=="number" and id>0 and id==math.floor(id) and id<=2147483647
 end
 local function Entrance(record)
  local e=record.entrance
  return e and ValidID(e.mapID) and type(e.x)=="number" and type(e.y)=="number"
   and e.x==e.x and e.y==e.y and e.x>=0 and e.x<=1 and e.y>=0 and e.y<=1 and e
 end
 local function OpenEntrance(p)
  local e=Entrance(p.record)
  if not e then p.feedback:SetText("No entrance coordinates are recorded for this instance."); return end
  if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn,"Blizzard_WorldMap") end
  if not WorldMapFrame or not WorldMapFrame.SetMapID then p.feedback:SetText("The world map is unavailable on this client."); return end
  local mapOK=pcall(WorldMapFrame.SetMapID,WorldMapFrame,e.mapID)
  if not mapOK then p.feedback:SetText("The client could not open the recorded entrance map."); return end
  WorldMapFrame:Show()
  p.feedback:SetText(string.format("Entrance: %.1f, %.1f. The map is open.",e.x*100,e.y*100))
  if C_Map and C_Map.SetUserWaypoint and C_Map.CanSetUserWaypointOnMap and UiMapPoint and UiMapPoint.CreateFromCoordinates then
   local ok,allowed=pcall(C_Map.CanSetUserWaypointOnMap,e.mapID)
   if ok and allowed then
    local pointOK,point=pcall(UiMapPoint.CreateFromCoordinates,e.mapID,e.x,e.y)
    if pointOK and point then pcall(C_Map.SetUserWaypoint,point) end
   end
  end
  -- The reference dialogs must not cover the map they just opened.
  p:Hide(); if p.returnView then p.returnView:Hide() end
 end
 
 function AzerMind.ShowInstanceDetails(record,returnView)
  if not record then return end
  if not details then
   local p=CreateFrame("Frame","AzerMindInstanceDetails",AzerMindFrame,"BackdropTemplate"); p:Hide()
   p:SetSize(820,620); p:SetPoint("CENTER",UIParent,"CENTER"); p:SetClampedToScreen(true)
   p:SetFrameStrata("FULLSCREEN_DIALOG"); p:SetFrameLevel(AzerMindFrame:GetFrameLevel()+180)
   p:EnableMouse(true); T.Surface(p,"window"); T.FitDialog(p)
   table.insert(UISpecialFrames,"AzerMindInstanceDetails")
   local function Button(parent,text,width,x,y,callback)
    local b=T.Button(parent,text,width,28,callback,nil,true); b:SetPoint("TOPLEFT",x,y)
    b.caption:SetWidth(width-16); b.caption:SetWordWrap(false); return b
   end
   p.title=T.Label(p,"",20,-20,T.fonts.title); p.title:SetWidth(730); p.title:SetWordWrap(false)
   p.summary=T.Label(p,"",20,-54); p.summary:SetWidth(780); p.summary:SetJustifyH("LEFT")
   T.Icon(p,"location",20,-80)
   p.location=T.Label(p,"",46,-80); p.location:SetWidth(750); p.location:SetWordWrap(false)
   Button(p,"X",28,772,-14,function() p:Hide() end)
   local left=CreateFrame("Frame",nil,p); left:SetSize(246,414); left:SetPoint("TOPLEFT",20,-118); T.Surface(left,"panel")
   local right=CreateFrame("Frame",nil,p); right:SetSize(520,414); right:SetPoint("TOPLEFT",280,-118); T.Surface(right,"panel")
   p.bossCount=T.Label(left,"",12,-14,T.fonts.heading)
   p.bossTitle=T.Label(right,"",16,-14,T.fonts.heading); p.bossTitle:SetWidth(380); p.bossTitle:SetWordWrap(false)
   p.npc=Button(right,"NPC details",100,404,-12,function()
    local boss=(p.record.bosses or {})[p.bossIndex]
    if boss and ValidID(boss.npcID) then AzerMind.ShowSourceBrowser("npc",boss.npcID) end
   end)
   p.bossInfo=T.Label(right,"",16,-38); T.Color(p.bossInfo,"SetTextColor","muted")
   p.search=T.SearchField(right,"AzerMindInstanceLootSearch",480,"Search this boss's loot")
   p.search:SetPoint("TOPLEFT",20,-84)
   p.empty=T.Label(right,"",16,-144); p.empty:SetWidth(480); p.empty:SetJustifyH("LEFT")
   p.feedback=T.Label(p,"",20,-550); p.feedback:SetWidth(780); p.feedback:SetJustifyH("LEFT")
   p.bossRows,p.lootRows={},{}
   local Refresh
   for i=1,7 do
    local b=Button(left,"",222,12,-44-(i-1)*44,function() end)
    b:SetHeight(40)
    b.title=T.Label(b,"",10,-6,T.fonts.heading); b.title:SetWidth(202); b.title:SetWordWrap(false)
    b.meta=T.Label(b,"",10,-24); b.meta:SetWidth(202); b.meta:SetWordWrap(false); T.Color(b.meta,"SetTextColor","muted")
    b:SetScript("OnClick",function(self)
     if IsShiftKeyDown and IsShiftKeyDown() and ValidID(self.boss.npcID) then AzerMind.ShowSourceBrowser("npc",self.boss.npcID); return end
     p.bossIndex=self.index; p.lootPage=1; p.search:SetText(""); Refresh()
    end)
    T.Tooltip(b,function() return b.boss.name end,function()
     return "Select to inspect loot."..(ValidID(b.boss.npcID) and ("\nNPC #"..b.boss.npcID) or "\nNPC reference not recorded.")
    end)
    p.bossRows[i]=b
   end
   for i=1,5 do
    local b=Button(right,"",488,16,-126-(i-1)*44,function() end); b:SetHeight(40)
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(28,28); b.icon:SetPoint("TOPLEFT",6,-6)
    b.title=T.Label(b,"",44,-5,T.fonts.heading); b.title:SetWidth(428); b.title:SetWordWrap(false)
    b.meta=T.Label(b,"",44,-24); b.meta:SetWidth(428); b.meta:SetWordWrap(false); T.Color(b.meta,"SetTextColor","muted")
    b:SetScript("OnEnter",function(self)
     GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:ClearLines()
     if ValidID(self.item.id) then pcall(GameTooltip.SetHyperlink,GameTooltip,"item:"..self.item.id)
     else GameTooltip:AddLine(self.item.name,unpack(T.colors.text)); GameTooltip:AddLine("No item reference is recorded. Item actions are unavailable.",1,1,1,true) end
     GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    b:SetScript("OnClick",function(self,button)
     if not ValidID(self.item.id) then p.feedback:SetText("No item reference is recorded for "..self.item.name.."."); return end
     if button=="RightButton" then AzerMind.ShowEntityMenu("item",self.item.id,"item:"..self.item.id,self.item.name)
     elseif SetItemRef then pcall(SetItemRef,"item:"..self.item.id,AzerMind.EntityLink("item",self.item.id,self.item.name),"LeftButton") end
    end)
    p.lootRows[i]=b
   end
   p.bossPageLabel=T.Label(left,"",92,-382); p.bossPageLabel:SetWidth(64); p.bossPageLabel:SetJustifyH("CENTER")
   p.bossPrevious=Button(left,"Previous",74,12,-374,function() p.bossPage=p.bossPage-1; Refresh() end)
   p.bossNext=Button(left,"Next",74,160,-374,function() p.bossPage=p.bossPage+1; Refresh() end)
   p.lootCount=T.Label(right,"",16,-350)
   p.lootPageLabel=T.Label(right,"",184,-382); p.lootPageLabel:SetWidth(152); p.lootPageLabel:SetJustifyH("CENTER")
   p.lootPrevious=Button(right,"Previous",90,16,-374,function() p.lootPage=p.lootPage-1; Refresh() end)
   p.lootNext=Button(right,"Next",90,414,-374,function() p.lootPage=p.lootPage+1; Refresh() end)
   p.back=Button(p,"Back to list",120,20,-576,function() p:Hide() end)
   p.copy=Button(p,"Copy summary",132,156,-576,function()
    AzerMind.ShowCopy(AzerMind.InstanceDetails(p.record)); AzerMindCopy:SetFrameLevel(p:GetFrameLevel()+20)
   end)
   T.Tooltip(p.copy,"Copy instance summary",function() return "Source: "..(p.record.source or "Bundled snapshot")..". Opens selectable text for Ctrl+C." end)
   p.map=Button(p,"Show entrance",144,300,-576,function() OpenEntrance(p) end)
   if p.map.SetMotionScriptsWhileDisabled then p.map:SetMotionScriptsWhileDisabled(true) end
   T.Tooltip(p.map,"Show entrance on map",function() return Entrance(p.record) and "Open the recorded entrance location. This does not move your character." or "Entrance coordinates are not recorded for this instance." end)
   p.attach=Button(p,"Add to message",190,610,-576,function()
    if AzerMind.AppendQuestDraft(AzerMind.InstanceLink(p.record),p.chatId) then
     p:Hide(); if p.returnView then p.returnView:Hide() end
    else p.feedback:SetText("Conversation changed. Reopen these details to add the reference.") end
   end)
   T.Primary(p.attach)
   Refresh=function()
    local bosses=p.record.bosses or {}
    local bossPages=math.max(1,math.ceil(#bosses/7)); p.bossPage=math.max(1,math.min(p.bossPage,bossPages))
    p.bossCount:SetText("Bosses ("..#bosses..")")
    for i,b in ipairs(p.bossRows) do
     local index=(p.bossPage-1)*7+i; local boss=bosses[index]
     if boss then
      b.boss=boss; b.index=index; b.title:SetText(boss.name)
      b.meta:SetText((index==p.bossIndex and "Viewing loot: " or "")..#(boss.loot or {}).." items")
      T.Selected(b,index==p.bossIndex); b:Show()
     else b.boss=nil; b:Hide() end
    end
    p.bossPageLabel:SetText(p.bossPage.." / "..bossPages)
    p.bossPrevious:SetEnabled(p.bossPage>1); p.bossNext:SetEnabled(p.bossPage<bossPages)
    local boss=bosses[p.bossIndex]
    p.npc:SetEnabled(boss and ValidID(boss.npcID) or false)
    p.bossTitle:SetText(boss and boss.name or "No bosses recorded")
    p.bossInfo:SetText(boss and "Loot  |  Hover to inspect; right-click for actions" or "This snapshot has no boss or loot information.")
    local filter=(p.search:GetText() or ""):lower(); local loot={}
    for _,item in ipairs(boss and boss.loot or {}) do if (item.name.." "..tostring(item.id or "")):lower():find(filter,1,true) then loot[#loot+1]=item end end
    p.visibleLoot=loot
    local lootPages=math.max(1,math.ceil(#loot/5)); p.lootPage=math.max(1,math.min(p.lootPage,lootPages))
    for i,b in ipairs(p.lootRows) do
     local item=loot[(p.lootPage-1)*5+i]
     if item then
      b.item=item; b.title:SetText(item.name); b.icon:SetTexture(134400)
      T.Color(b.title,"SetTextColor","text")
      b.meta:SetText(ValidID(item.id) and "Recorded boss drop" or "Item details not recorded")
      if ValidID(item.id) then
       local info=C_Item and C_Item.GetItemInfo or GetItemInfo
       if info then
        local values={pcall(info,item.id)}
        if values[1] then
         if values[11] then b.icon:SetTexture(values[11]) end
         local color=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[values[4]]
         if color then b.title:SetTextColor(color.r,color.g,color.b) end
         local metadata={}
         if type(values[8])=="string" and values[8]~="" then metadata[#metadata+1]=values[8] end
         if type(values[6])=="number" and values[6]>0 then metadata[#metadata+1]="Requires level "..values[6] end
         if #metadata>0 then b.meta:SetText(table.concat(metadata,"  |  ")) end
        end
       end
      end
      b:Show()
     else b.item=nil; b:Hide() end
    end
    p.empty:SetShown(#loot==0)
    p.empty:SetText(not boss and "Select an instance with recorded bosses to browse its loot." or (#(boss.loot or {})==0 and "No loot is recorded for this boss." or "No matching loot. Try another name or item ID."))
    p.lootCount:SetText(#loot.." matching loot items")
    p.lootPageLabel:SetText("Page "..p.lootPage.." of "..lootPages)
    p.lootPrevious:SetEnabled(p.lootPage>1); p.lootNext:SetEnabled(p.lootPage<lootPages)
   end
   p.Refresh=Refresh
   p.search:SetScript("OnTextChanged",function() p.lootPage=1; Refresh() end)
   p.search:SetScript("OnEscapePressed",function() p:Hide() end)
   p:SetScript("OnHide",function() p.search:ClearFocus(); GameTooltip:Hide() end)
   p:RegisterEvent("GET_ITEM_INFO_RECEIVED")
   p:SetScript("OnEvent",function(_,_,id)
    if not p:IsShown() then return end
    for _,b in ipairs(p.lootRows) do if b:IsShown() and b.item and b.item.id==id then Refresh(); return end end
   end)
   details=p
  end
  local p=details
  local chat=AzerMind.SettingsState()
  p.record=record; p.chatId=chat and chat.id; p.returnView=returnView
  p.bossPage=1; p.bossIndex=1; p.lootPage=1; p.search:SetText("")
  p.title:SetText(record.name)
  p.summary:SetText(record.type.."  |  Suggested levels "..record.level..(record.size and ("  |  "..record.size.." players") or ""))
  p.location:SetText("Location: "..record.location)
  p.feedback:SetText(record.status or "Select a boss to browse loot. Item actions do not send a message.")
  p.back:SetText(returnView and "Back to list" or "Close")
  p.map:SetEnabled(Entrance(record) and true or false); p.attach:SetEnabled(chat~=nil)
  p:Show(); p.Refresh()
 end
end

-- Report the actual client error instead of leaving a half-built dialog behind.
do
 local Open=AzerMind.ShowInstanceDetails
 function AzerMind.ShowInstanceDetails(record,returnView)
  local ok,why=xpcall(function() Open(record,returnView) end,function(err)
   return tostring(err)..(debugstack and ("\n"..debugstack(2,8,0)) or "")
  end)
  if not ok then
   if AzerMindInstanceDetails then AzerMindInstanceDetails:Hide() end
   AzerMind.lastUIError=why
   print("|cffff6666[AzerMind] Instance details failed. UI revision 2026-11-11.2.|r")
   AzerMind.ShowCopy("Instance details error (UI 2026-11-11.2):\n"..why)
  end
 end
end

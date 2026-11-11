-- Read-only access to the player's log. No Questie hooks or tracking changes.
local T = AzerMindTheme
local picker
local function Read(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
	if ok then return a, b, c, d, e, f, g, h end
end
-- Compatibility entry point for location choices.
function AzerMind.ShowQuestLocationMenu(anchor,options,selected,onSelect)
 T.ShowChoiceMenu(anchor,options,selected,onSelect,"Search locations")
end
function AzerMind.ActiveQuests()
	local api = C_QuestLog or {}
	local count = Read(api.GetNumQuestLogEntries) or Read(GetNumQuestLogEntries) or 0
	local result, seen, zone = {}, {}, ""
	for index = 1, count do
		local info = Read(api.GetInfo, index)
		if type(info) ~= "table" then
			local title, level, _, header, _, complete, _, id = Read(GetQuestLogTitle, index)
			info = {title=title, level=level, isHeader=header, isComplete=complete == 1, questID=id}
		end
		if info.isHeader then zone = info.title or ""
		elseif type(info.questID) == "number" and info.questID > 0 and not seen[info.questID] then
			seen[info.questID] = true
            local complete=Read(api.IsComplete,info.questID)
            if complete==nil then complete=info.isComplete end
			table.insert(result, {id=info.questID, title=info.title or ("Quest " .. info.questID), level=info.level,
				zone=zone, complete=complete==true or complete==1,
				objectives=Read(api.GetQuestObjectives, info.questID) or {}})
		end
	end
	return result
end
function AzerMind.QuestSelectionText(quests, selected)
	local lines = {}
	for _, q in ipairs(quests) do
		if selected[q.id] then
			local title = q.title:gsub("[|%[%]\r\n]", "")
			local link = "|cffffd36a|Hquest:" .. q.id .. ":" .. (tonumber(q.level) or -1) .. "|h[" .. title .. "]|h|r"
			table.insert(lines, "Active quest: " .. link .. (q.zone ~= "" and (" - " .. q.zone) or "") .. (q.complete and " (ready to turn in)" or ""))
			for _, objective in ipairs(q.objectives or {}) do
				if type(objective.text) == "string" then
					table.insert(lines, "  " .. AzerMind.PlainText(objective.text) .. (objective.finished and " (complete)" or ""))
				end
			end
		end
	end
	return table.concat(lines, "\n")
end

function AzerMind.ShowQuestPicker()
	local chat = AzerMind.SettingsState()
	if not chat then return end
	if not picker then
		local p = CreateFrame("Frame", "AzerMindQuestPicker", AzerMindFrame)
		picker = p; p:SetSize(640, 600); p:SetPoint("CENTER", AzerMindFrame, "CENTER")
		p:SetFrameStrata("FULLSCREEN_DIALOG"); p:SetFrameLevel(AzerMindFrame:GetFrameLevel() + 110)
		p:EnableMouse(true); p:SetClampedToScreen(true)
		if p.SetIgnoreParentAlpha then p:SetIgnoreParentAlpha(true) end
		T.Surface(p, "window"); T.FitDialog(p)
		T.Label(p, "Quests", 20, -18, T.fonts.title)
		T.Label(p, "Select quests to attach. Your tracker will not change.", 20, -46)
		table.insert(UISpecialFrames,"AzerMindQuestPicker")
		p.mode="active"
		local activeTab=T.Button(p,"My quests",120,26,function() p.mode="active"; p.Load() end); activeTab:SetPoint("TOPLEFT",20,-72)
		local catalogTab=T.Button(p,"Quest database",148,26,function() p.mode="catalog"; p.Load() end); catalogTab:SetPoint("TOPLEFT",148,-72)
		local search = T.SearchField(p,nil,592,"Search by quest name, area, or ID")
		search:SetPoint("TOPLEFT",24,-132)
		T.Type(search, "body"); search:SetMaxLetters(120)
		search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		local scroll = CreateFrame("ScrollFrame", "AzerMindQuestPickerScroll", p, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 20, -276); scroll:SetPoint("BOTTOMRIGHT", -40, 105)
		if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end
		local content = CreateFrame("Frame", nil, scroll); content:SetSize(578, 1); scroll:SetScrollChild(content)
		p.rows, p.selected = {}, {}
		p.summary = T.Label(p, "", 20, -537)
		p.version = T.Label(p, "", 20, -566); p.version:SetWidth(350); p.version:SetJustifyH("LEFT")
		p.page=1; p.pageLabel=T.Label(p,"",128,-508)
		p.city="all"; p.zoneFilter="all"
		p.status="All"; p.myLevel=false; p.onlySelected=false
		local function Render()
			if p.rendering then return end; p.rendering=true
			local filter = (search:GetText() or ""):lower()
			local visible, chosen = p.visible or {}, 0
			local query=table.concat({p.mode,filter,p.status,tostring(p.myLevel),tostring(p.classFilter),tostring(p.raceFilter),p.city,p.zoneFilter,tostring(p.onlySelected)},":")
			if query~=p.query then
				p.query=query; p.page=1; visible={}; scroll:SetVerticalScroll(0)
			for _, q in ipairs(p.quests or {}) do
				local status=p.status~="All" and (q.record and AzerMind.CatalogQuestStatus(q) or (q.complete and "Ready to turn in" or "Active")) or nil
				if (q.title .. " " .. q.zone .. " " .. q.id):lower():find(filter, 1, true)
					and (p.status=="All" or status==p.status)
					and (not p.onlySelected or p.selected[q.id])
                    and AzerMind.QuestMatchesLocation(q,p.city,p.zoneFilter)
					and (not q.record or AzerMind.CatalogQuestMatchesCharacter(q,p.raceFilter or 0,p.classFilter or 0))
					and (not p.myLevel or (q.level and q.level>0 and math.abs(q.level-(UnitLevel("player") or 1))<=5)) then table.insert(visible, q) end
			end
			end
			for _ in pairs(p.selected) do chosen=chosen+1 end
			p.visible = visible
			local pages=math.max(1,math.ceil(#visible/25)); p.page=math.min(p.page,pages)
			local pageStart=(p.page-1)*25; local pageCount=math.min(25,#visible-pageStart)
			local first=math.floor(scroll:GetVerticalScroll()/44)+1
			local used=0
			for i=first,math.min(pageCount,first+6) do
				local q=visible[pageStart+i]; used=used+1
				q.status=q.record and AzerMind.CatalogQuestStatus(q) or (q.complete and "Ready to turn in" or "Active")
				local row = p.rows[used]
				if not row then
					row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
					row:SetSize(24, 24)
					row.title = T.Label(row, "", 30, -1); row.title:SetWidth(460); row.title:SetJustifyH("LEFT"); row.title:SetWordWrap(false)
					row.detail = T.Label(row, "", 30, -20); row.detail:SetWidth(460); row.detail:SetJustifyH("LEFT"); row.detail:SetWordWrap(false)
					T.Color(row.detail, "SetTextColor", "muted")
					row:SetHitRectInsets(0, -460, 0, -16)
					row:SetScript("OnClick", function(self) p.selected[self.questId] = self:GetChecked() or nil; if p.onlySelected then p.query=nil end; Render() end)
					row:SetScript("OnEnter",function(self)
						GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:ClearLines()
						GameTooltip:AddLine(self.quest.title,0.91,0.87,0.78)
						if self.quest.record then GameTooltip:AddLine(AzerMind.CatalogQuestDetails(self.quest),0.8,0.85,0.85,true)
						else GameTooltip:AddLine("Quest area: "..self.quest.zone,1,1,1,true); GameTooltip:AddLine(self.quest.complete and "Ready to turn in" or "Active quest",1,1,1) end
						GameTooltip:Show()
					end)
					row:SetScript("OnLeave",function() GameTooltip:Hide() end)
					row.map=T.Button(row,"",30,28,function() AzerMind.MarkQuestOnMap(row.questId,row.quest.complete or row.quest.status=="Ready to turn in") end)
                    row.map:SetPoint("TOPLEFT",500,0); T.Icon(row.map,"location",7,-6)
                    T.Tooltip(row.map,"Show quest on map","Shows recorded objectives, or the turn-in location for ready quests.")
                    row.actions=T.Button(row,"...",30,28,function() AzerMind.ShowEntityMenu("quest",row.questId,"quest:"..row.questId,row.quest.title) end)
                    row.actions:SetPoint("TOPLEFT",536,0)
                    T.Tooltip(row.actions,"Quest actions","Sources, objectives, turn-in, quest log and draft actions.")
                    p.rows[used] = row
				end
				row.quest=q; row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(i-1)*44)
				row.questId = q.id; row:SetChecked(p.selected[q.id] or false)
				row.title:SetText(q.title)
				row.detail:SetText((q.level and ("Level " .. q.level .. " | ") or "") .. (q.cityLabel and q.cityLabel~="" and (q.cityLabel.." - ") or "") .. q.zone .. (q.complete and " | Ready to turn in" or " | "..q.status))
				row:Show()
			end
			for i = used+1, #p.rows do p.rows[i]:Hide() end
			content:SetHeight(math.max(1, pageCount*44))
			p.pageLabel:SetText("Page "..p.page.." / "..pages)
			p.previous:SetEnabled(p.page>1); p.next:SetEnabled(p.page<pages)
			local matching={}; for _,q in ipairs(visible) do matching[q.id]=true end
			local hidden=0; for id in pairs(p.selected) do if not matching[id] then hidden=hidden+1 end end
			p.summary:SetText(chosen>30 and "Choose up to 30 quests per attachment." or (chosen.." selected | "..hidden.." hidden by filters | "..#visible.." results"))
			p.insert:SetText("Add to message ("..chosen..")")
			if (p.removedSelections or 0)>0 then p.summary:SetText(p.removedSelections.." unavailable selections removed | "..p.summary:GetText()) end
			p.insert:SetEnabled(chosen > 0 and chosen<=30)
			p.rendering=false
		end
		scroll:HookScript("OnVerticalScroll",function() if p.insert then Render() end end)
		local function Button(text, width, x, y, action)
			local b = T.Button(p, text, width, 26, action); b:SetPoint("TOPLEFT", x, y); return b
		end
		p.previous=Button("Previous",90,20,-502,function() p.page=math.max(1,p.page-1); scroll:SetVerticalScroll(0); Render() end)
		p.next=Button("Next",90,284,-502,function() p.page=p.page+1; scroll:SetVerticalScroll(0); Render() end)
		local cityButton,zoneButton
		local function LocationLabels()
			p.cityOptions,p.zoneOptions=AzerMind.QuestLocationOptions(p.quests or {},p.city)
			local validCity=false; for _,option in ipairs(p.cityOptions) do if option.key==p.city then validCity=true end end
			if not validCity then p.city="all"; p.cityOptions,p.zoneOptions=AzerMind.QuestLocationOptions(p.quests or {},p.city) end
			local validZone=false; for _,option in ipairs(p.zoneOptions) do if option.key==p.zoneFilter then validZone=true end end
			if not validZone then p.zoneFilter="all" end
			local function Label(options,key,default) for _,option in ipairs(options) do if option.key==key then return option.label end end; return default end
			cityButton:SetText("City: "..Label(p.cityOptions,p.city,"All cities"))
			zoneButton:SetText("Zone: "..Label(p.zoneOptions,p.zoneFilter,"All zones"))
		end
		cityButton=Button("City: All cities",284,20,-166,function(self)
			local db,err=AzerMind.LoadCatalog()
			AzerMind.AssignQuestGeography(p.quests); p.query=nil; LocationLabels(); Render()
			if not db then p.summary:SetText(err); return end
			AzerMind.ShowQuestLocationMenu(self,p.cityOptions,p.city,function(option)
				p.city=option.key; p.zoneFilter="all"; LocationLabels(); Render()
			end)
		end)
		zoneButton=Button("Zone: All zones",308,312,-166,function(self)
			LocationLabels()
			AzerMind.ShowQuestLocationMenu(self,p.zoneOptions,p.zoneFilter,function(option) p.zoneFilter=option.key; LocationLabels(); Render() end)
		end)
        T.SelectorAppearance(cityButton,"location"); T.SelectorAppearance(zoneButton,"location")
        T.Tooltip(zoneButton,function() return zoneButton:GetText() end,"Quest area, not your current position.")
		cityButton:SetScript("OnEnter",function(self)
			GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText("Quest starting city")
			GameTooltip:AddLine("Recorded capital-city starters only. No recorded city means the source does not identify a city. Zone filters the quest area, not your current position.",0.8,0.85,0.85,true); GameTooltip:Show()
		end)
		cityButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
        local classes={{key=0,label="All"},{key=1,label="Warrior"},{key=2,label="Paladin"},{key=3,label="Hunter"},{key=4,label="Rogue"},{key=5,label="Priest"},{key=7,label="Shaman"},{key=8,label="Mage"},{key=9,label="Warlock"},{key=11,label="Druid"}}
        local races={{key=0,label="All"},{key=1,label="Human"},{key=2,label="Orc"},{key=3,label="Dwarf"},{key=4,label="Night Elf"},{key=5,label="Undead"},{key=6,label="Tauren"},{key=7,label="Gnome"},{key=8,label="Troll"}}
        local _,_,myClass=Read(UnitClass,"player"); local _,_,myRace=Read(UnitRace,"player")
        if myClass then table.insert(classes,2,{key=myClass,label="My class"}) end
        if myRace then table.insert(races,2,{key=myRace,label="My race"}) end
        p.classSelector=T.Selector(p,"Class",146,classes,0,function(o) p.classFilter=o.key; Render() end)
        p.classSelector:SetPoint("TOPLEFT",308,-72)
        p.raceSelector=T.Selector(p,"Race",158,races,0,function(o) p.raceFilter=o.key; Render() end)
        p.raceSelector:SetPoint("TOPLEFT",462,-72)
        p.classSelector:SetValue(0,"All"); p.raceSelector:SetValue(0,"All")
		Button("Select all results", 138, 20, -206, function() for _, q in ipairs(p.visible or {}) do p.selected[q.id]=true end; Render() end)
		Button("Clear selection", 124, 166, -206, function() p.selected={}; p.query=nil; Render() end)
        local playerLevel=UnitLevel("player") or 1
        p.levelToggle=T.Toggle(p,"Quest levels "..math.max(1,playerLevel-5).."-"..(playerLevel+5),220,false,function(value) p.myLevel=value; Render() end)
        p.levelToggle:SetPoint("TOPLEFT",20,-242)
        p.selectedToggle=T.Toggle(p,"Show selected only",210,false,function(value) p.onlySelected=value; p.query=nil; Render() end)
        p.selectedToggle:SetPoint("TOPLEFT",244,-242)
		Button("Reset filters",138,482,-242,function()
			p.status="All"; p.myLevel=false; p.myCharacter=false; p.onlySelected=false; p.city="all"; p.zoneFilter="all"
			p.statusSelector:SetValue("All"); p.levelToggle:SetValue(false); p.selectedToggle:SetValue(false)
			p.classFilter=0; p.raceFilter=0; p.classSelector:SetValue(0,"All"); p.raceSelector:SetValue(0,"All"); search:SetText(""); p.query=nil; LocationLabels(); Render()
		end)
        Button("Select page",116,298,-206,function()
            for i=(p.page-1)*25+1,math.min(p.page*25,#p.visible) do p.selected[p.visible[i].id]=true end
            Render()
        end)
        local states={"All","Active","Ready to turn in","Completed","Availability unknown","Level too low","Race/class restricted"}
        local statusOptions={}; for _,value in ipairs(states) do statusOptions[#statusOptions+1]={key=value,label=value} end
        p.statusSelector=T.Selector(p,"Status",198,statusOptions,"All",function(option) p.status=option.key; Render() end)
        p.statusSelector:SetPoint("TOPLEFT",422,-206)
		p.insert = Button("Add to message (0)", 174, 446, -562, function()
			local count=0; for _ in pairs(p.selected) do count=count+1 end; if count==0 or count>30 then return end
			local text
			if p.mode=="catalog" then
				local lines={}; for _,q in ipairs(p.quests) do if p.selected[q.id] then lines[#lines+1]=AzerMind.CatalogQuestDetails(q) end end
				text=table.concat(lines,"\n\n")
			else text=AzerMind.QuestSelectionText(AzerMind.ActiveQuests(),p.selected) end
			if #text>36000 then p.summary:SetText("This attachment is too large. Choose fewer quests."); return end
			if text ~= "" and AzerMind.AppendQuestDraft(text, p.chatId) then p:Hide()
			else p.summary:SetText("Selection changed or conversation switched. Reopen this list.") end
		end)
		T.Primary(p.insert)
		T.Tooltip(p.insert,"Add quests to message","Maximum 30 quests per attachment. Adds to the draft; your tracker does not change.")
		Button("Cancel", 94, 344, -562, function() p:Hide() end)
		Button("X", 24, 596, -14, function() p:Hide() end)
		search:SetScript("OnTextChanged", function()
			p.searchVersion=(p.searchVersion or 0)+1; local version=p.searchVersion
			C_Timer.After(0.15,function() if p.insert and p:IsShown() and p.searchVersion==version then Render() end end)
		end)
		p.Load = function()
			p.query=nil; p.page=1
			local err
			if p.mode=="catalog" then p.quests,err=AzerMind.CatalogQuestList() else p.quests=AzerMind.ActiveQuests() end
			T.SourceSelection(p,p.mode)
            p.quests=p.quests or {}; p.removedSelections=T.ReconcileSelection(p.selected,p.quests,"id"); search:SetText(""); scroll:SetVerticalScroll(0)
			AzerMind.AssignQuestGeography(p.quests); p.city="all"; p.zoneFilter="all"; LocationLabels()
			T.Selected(activeTab,p.mode=="active"); T.Selected(catalogTab,p.mode=="catalog")
			p.version:SetText(p.mode=="catalog" and (AzerMindCatalog and ("Forever snapshot | QuestieDB "..AzerMindCatalog.manifest.version) or "Catalog unavailable") or "Live character quest log")
			Render(); if err then p.summary:SetText(err) end
		end
		p:RegisterEvent("QUEST_LOG_UPDATE")
		p:SetScript("OnEvent", function()
			if p:IsShown() then p.query=nil; if p.mode=="active" then p.quests=AzerMind.ActiveQuests(); p.removedSelections=T.ReconcileSelection(p.selected,p.quests,"id"); AzerMind.AssignQuestGeography(p.quests); LocationLabels() end; Render() end
		end)
		p:SetScript("OnHide",function() T.CloseChoiceMenu() end)
	end
	if picker.chatId~=chat.id then picker.selections={}; picker.selectionSource=nil; picker.selected={} end
    picker.chatId = chat.id; picker.Load(); picker:Show()
end

-- Shared visual vocabulary. Components must use semantic colors, not RGB literals.
AzerMindTheme = {}
local T = AzerMindTheme
T.colors = {
	window = {0.055, 0.049, 0.039, 1},
	panel = {0.085, 0.075, 0.058, 1},
	field = {0.12, 0.105, 0.080, 1},
	selected = {0.095, 0.19, 0.18, 1},
	border = {0.26, 0.32, 0.28, 1},
	accent = {0.60, 0.90, 0.95, 1},
	gold = {0.90, 0.74, 0.39, 1},
	text = {0.91, 0.87, 0.78, 1},
	muted = {0.65, 0.61, 0.53, 1},
	hover = {0.60, 0.90, 0.95, 0.10},
}
T.spacing = {xs=4, sm=8, md=12, lg=20, xl=28}
T.fonts = {title="GameFontNormalLarge", heading="GameFontNormal", body="GameFontHighlightSmall"}
T.typography = {
	title = {file="Fonts\\FRIZQT__.TTF", size=18},
	heading = {file="Fonts\\FRIZQT__.TTF", size=15},
	body = {file="Fonts\\ARIALN.TTF", size=14},
	label = {file="Fonts\\FRIZQT__.TTF", size=13},
	conversation = {file="Fonts\\ARIALN.TTF", size=14},
}
function T.Type(region, role)
	local spec = T.typography[role] or T.typography.body
	region:SetFont(spec.file, spec.size, "")
	if region.SetShadowColor then region:SetShadowColor(0, 0, 0, 0.75); region:SetShadowOffset(1, -1) end
	if region.SetSpacing and role == "body" then region:SetSpacing(3) end
end
T.roles = {
	user = {label="You", color={0.77,0.73,0.62}, bg={0.17,0.15,0.11,0.65}},
	assistant = {label="AI", color={0.60,0.90,0.95}, bg={0.06,0.15,0.15,0.70}},
	system = {label="System", color={0.65,0.61,0.53}, bg={0.12,0.11,0.09,0.65}},
}
function T.Color(region, method, token)
	region[method](region, unpack(T.colors[token]))
end
function T.Surface(frame, token)
	local fill = frame:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints(); T.Color(fill, "SetColorTexture", token)
	if token == "window" or token == "panel" then T.Glow(frame, token == "window" and 0.24 or 0.12) end
	return fill
end

-- Original native-texture treatment: no Forever Quest Tint code or assets required.
-- The solid base stays opaque; only the decorative wash fades to transparent.
function T.Glow(frame, strength)
	if frame.azermindGlow then return end
	frame.azermindGlow = {}
	local c = T.colors.accent
	local wash = frame:CreateTexture(nil, "BORDER", nil, -6)
	wash:SetColorTexture(1, 1, 1, 1)
	wash:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 4)
	wash:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
	if wash.SetGradient and CreateColor then
		wash:SetGradient("VERTICAL", CreateColor(c[1], c[2], c[3], strength), CreateColor(c[1], c[2], c[3], 0))
	else wash:SetColorTexture(c[1], c[2], c[3], strength * 0.25) end
	local function Resize() wash:SetHeight(math.max(1, frame:GetHeight() * 0.65)) end
	Resize(); frame:HookScript("OnSizeChanged", Resize)
	frame.azermindGlow.wash = wash
	-- Nested low-alpha bands create a soft inset rim without hard neon edges.
	for i = 1, 5 do
		local rim = frame:CreateTexture(nil, "BORDER", nil, -5)
		rim:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4 + i, 3 + i)
		rim:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4 - i, 3 + i)
		rim:SetHeight(1)
		rim:SetColorTexture(c[1], c[2], c[3], strength * (6 - i) / 12)
		table.insert(frame.azermindGlow, rim)
	end
end
function T.Label(parent, text, x, y, font)
	local label = parent:CreateFontString(nil, "OVERLAY", font or T.fonts.body)
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); label:SetText(text)
	T.Type(label, font == T.fonts.title and "title" or (font == T.fonts.heading and "heading" or "label"))
	T.Color(label, "SetTextColor", "text")
	return label
end
function T.Selected(button, selected)
	button.selectedState = selected
	selected=selected or button.primary
	T.Color(button.fill, "SetColorTexture", selected and "selected" or "field")
	T.Color(button.caption, "SetTextColor", selected and "accent" or "text")
	for _, edge in ipairs(button.edges) do T.Color(edge, "SetColorTexture", selected and "accent" or "border") end
end
function T.Button(parent, text, width, height, action, align, plain)
	local b
	if plain then
		b = CreateFrame("Button", nil, parent)
		b:SetFontString(b:CreateFontString(nil, "OVERLAY", T.fonts.heading))
	else
		b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	end
	b:SetSize(width, height or 26); b:SetText(text); b:SetScript("OnClick", action)
	-- Keep the native red button artwork for compact controls. Tall composer
	-- controls use a template-free button so the artwork cannot stretch.
	if plain then
		b:SetNormalTexture(""); b:SetPushedTexture(""); b:SetDisabledTexture(""); b:SetHighlightTexture("")
	end
	b.fill = T.Surface(b, "field")
	b.caption = b:GetFontString(); b.caption:ClearAllPoints()
	T.Type(b.caption, "label")
	if align == "LEFT" then b.caption:SetPoint("LEFT", b, "LEFT", 12, 0); b.caption:SetWidth(width - 32); b.caption:SetJustifyH("LEFT")
	else b.caption:SetPoint("CENTER", b, "CENTER") end
	b.edges = {}
	for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
		local line = b:CreateTexture(nil, "BORDER")
		if edge == "TOP" or edge == "BOTTOM" then line:SetHeight(1); line:SetPoint(edge .. "LEFT", b, edge .. "LEFT"); line:SetPoint(edge .. "RIGHT", b, edge .. "RIGHT")
		else line:SetWidth(1); line:SetPoint("TOP" .. edge, b, "TOP" .. edge); line:SetPoint("BOTTOM" .. edge, b, "BOTTOM" .. edge) end
		table.insert(b.edges, line)
	end
	local hover = b:CreateTexture(nil, "HIGHLIGHT"); hover:SetAllPoints(); T.Color(hover, "SetColorTexture", "hover")
	b:HookScript("OnDisable", function(self) T.Color(self.caption, "SetTextColor", "muted") end)
	b:HookScript("OnEnable", function(self) T.Selected(self, self.selectedState or false) end)
	T.Selected(b, false)
	T.Tooltip(b,function() return b:GetText() end)
	return b
end

-- Text stays meaningful when values change; tooltips expose truncated values.
function T.Tooltip(frame, title, description)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(type(title) == "function" and title() or title)
		if description then GameTooltip:AddLine(type(description) == "function" and description() or description, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Small semantic icons made from native textures, with no external assets.
function T.Icon(parent, name, x, y)
	local shapes = {
		location={{2,0,10,2},{0,2,2,7},{12,2,2,7},{2,9,2,3},{10,9,2,3},{4,12,2,2},{8,12,2,2},{6,14,2,2},{6,4,2,3}},
		items={{2,4,12,11},{5,1,6,2},{4,2,2,3},{10,2,2,3}},
		quests={{2,1,12,2},{3,3,2,11},{5,13,10,2},{13,3,2,10},{7,5,4,1},{7,8,4,1}},
		guides={{1,2,1,12},{14,2,1,12},{2,2,5,1},{9,2,5,1},{7,3,2,12},{2,13,5,1},{9,13,5,1}},
		character={{5,0,6,6},{3,8,10,3},{1,11,14,4}},
		instances={{2,2,12,2},{2,4,3,12},{11,4,3,12},{5,4,6,2}},
		search={{2,1,8,2},{0,3,2,6},{10,3,2,6},{2,9,8,2},{10,10,2,2},{12,12,2,2},{14,14,2,2}},
		delete={{1,3,14,2},{5,0,6,2},{2,5,2,10},{12,5,2,10},{4,14,8,2},{6,6,1,6},{9,6,1,6}},
	}
	local icon=CreateFrame("Frame",nil,parent); icon:SetSize(16,16)
	icon:SetPoint("TOPLEFT",parent,"TOPLEFT",x or 0,y or 0)
	for _,stroke in ipairs(shapes[name] or shapes.location) do
		local line=icon:CreateTexture(nil,"ARTWORK")
		line:SetColorTexture(unpack(T.colors.gold)); line:SetSize(stroke[3],stroke[4])
		line:SetPoint("TOPLEFT",icon,"TOPLEFT",stroke[1],-stroke[2])
	end
	return icon
end

function T.SelectorAppearance(button, iconName)
	button.caption:ClearAllPoints()
	button.caption:SetPoint("LEFT",button,"LEFT",iconName and 30 or 12,0)
	button.caption:SetWidth(button:GetWidth()-(iconName and 56 or 42))
	button.caption:SetJustifyH("LEFT"); button.caption:SetWordWrap(false)
	if iconName then button.icon=T.Icon(button,iconName,8,-6) end
	button.arrow=T.Label(button,"v",button:GetWidth()-18,-7)
end

function T.IconLabel(button, name)
	button.icon=T.Icon(button,name,8,-6)
	button.caption:ClearAllPoints(); button.caption:SetPoint("LEFT",button,"LEFT",30,0)
	button.caption:SetWidth(button:GetWidth()-38); button.caption:SetWordWrap(false); button.caption:SetJustifyH("LEFT")
end

function T.SearchField(parent, name, width, label)
	local input=CreateFrame("EditBox",name,parent,"InputBoxTemplate")
	input:SetSize(width,28); input:SetAutoFocus(false); input:SetMaxLetters(120); T.Type(input,"body")
	input.label=T.Label(input,label,0,22)
	input:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
	return input
end

function T.Selector(parent, label, width, options, selected, onSelect)
	local b
	b = T.Button(parent, "", width, 28, function()
		local choices = type(options) == "function" and options() or options
		T.ShowChoiceMenu(b, choices, b.value, function(option)
			b:SetValue(option.key, option.label)
			onSelect(option)
		end, "Search " .. label:lower())
	end, "LEFT")
	T.SelectorAppearance(b)
	function b:SetValue(value, caption)
		self.value = value
		self:SetText(label .. ": " .. tostring(caption or value))
	end
	b:SetValue(selected)
	T.Tooltip(b, function() return b:GetText() end, "Choose an option from the list.")
	return b
end

function T.Toggle(parent, label, width, selected, onChange)
	local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	b:SetSize(24, 24)
	b:SetHitRectInsets(0,-(width-24),0,0)
	b.caption = T.Label(b, label, 28, -5)
	b.caption:SetWidth(width - 28); b.caption:SetJustifyH("LEFT")
	b:SetScript("OnClick", function(self)
		self:SetValue(self:GetChecked()); onChange(self.value)
	end)
	function b:SetValue(value)
		self.value = value and true or false
		self:SetChecked(self.value)
	end
	b.caption:SetWordWrap(false); b:SetValue(selected)
	return b
end

local choiceMenu
function T.CloseChoiceMenu()
	if choiceMenu then choiceMenu:Hide(); choiceMenu.search:ClearFocus() end
end

-- Shared draft-insertion vocabulary and visual emphasis.
function T.Primary(button)
	button.primary=true
	T.Color(button.fill, "SetColorTexture", "selected")
	for _, edge in ipairs(button.edges) do T.Color(edge, "SetColorTexture", "accent") end
end

function T.FitDialog(frame)
	frame:SetAlpha(1)
	if frame.SetIgnoreParentAlpha then frame:SetIgnoreParentAlpha(true) end
	local function Fit()
		local width,height=UIParent:GetWidth(),UIParent:GetHeight()
		if width and height and width>0 and height>0 then
			frame:SetScale(math.min(1,(width-32)/frame:GetWidth(),(height-32)/frame:GetHeight()))
		end
	end
	frame:HookScript("OnShow",Fit)
	UIParent:HookScript("OnSizeChanged",function() if frame:IsShown() then Fit() end end)
	Fit()
end

function T.ProtectChanges(frame, isDirty, discard)
	StaticPopupDialogs["AZERMIND_DISCARD_UI_CHANGES"] = StaticPopupDialogs["AZERMIND_DISCARD_UI_CHANGES"] or {
		text="Discard unsaved settings?", button1="Discard", button2="Keep editing",
		timeout=0, whileDead=true, hideOnEscape=true,
		OnAccept=function(_,data) if data then data.discard() end end,
	}
	frame:HookScript("OnHide",function(self)
		-- Parent/window hiding preserves the draft; only an explicit close asks.
		if self.azermindDiscarding or self:IsShown() or not AzerMindFrame:IsShown() or not isDirty() then return end
		self:Show()
		StaticPopup_Show("AZERMIND_DISCARD_UI_CHANGES",nil,nil,{discard=function()
			self.azermindDiscarding=true; discard(); self:Hide(); self.azermindDiscarding=nil
		end})
	end)
end

-- Reconcile selections against the latest source without losing hidden matches.
function T.ReconcileSelection(selected, entries, key)
	local valid, removed = {}, 0
	for _, entry in ipairs(entries) do valid[entry[key]] = true end
	for id in pairs(selected) do
		if not valid[id] then selected[id] = nil; removed = removed + 1 end
	end
	return removed
end

function T.SourceSelection(panel, source)
	panel.selections = panel.selections or {}
	if panel.selectionSource then panel.selections[panel.selectionSource] = panel.selected end
	panel.selected = panel.selections[source] or {}
	panel.selections[source] = panel.selected
	panel.selectionSource = source
end

-- Searchable shared choices; at most nine rows exist regardless of option count.
function T.ShowChoiceMenu(anchor,options,selected,onSelect,searchLabel)
	if choiceMenu and choiceMenu:IsShown() and choiceMenu.owner==anchor then T.CloseChoiceMenu(); return end
	if not choiceMenu then
		local m=CreateFrame("Frame","AzerMindChoiceMenu",UIParent)
		choiceMenu=m; m:SetSize(304,294); m:SetClampedToScreen(true); m:EnableMouse(true)
		m:SetFrameStrata("TOOLTIP"); m:SetFrameLevel(220); T.Surface(m,"window")
		table.insert(UISpecialFrames,"AzerMindChoiceMenu")
		local search=CreateFrame("EditBox",nil,m,"InputBoxTemplate")
		search:SetSize(270,26); search:SetPoint("TOPLEFT",18,-12); search:SetAutoFocus(false); T.Type(search,"body")
		search:SetScript("OnEscapePressed",function() m:Hide() end)
		m.searchLabel=T.Label(m,"Search options",14,-43)
		local scroll=CreateFrame("ScrollFrame","AzerMindChoiceScroll",m,"UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT",8,-65); scroll:SetPoint("BOTTOMRIGHT",-30,12)
		if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end
		local content=CreateFrame("Frame",nil,scroll); content:SetSize(264,1); scroll:SetScrollChild(content)
		m.rows={}; m.search=search
		m.empty=T.Label(m,"No matching options",14,-78)
		m:SetScript("OnHide",function() search:ClearFocus() end)
		local function Render()
			if m.rendering then return end; m.rendering=true
			local filter=(search:GetText() or ""):lower(); local visible={}
			for _,option in ipairs(m.options or {}) do if option.label:lower():find(filter,1,true) then visible[#visible+1]=option end end
			m.visible=visible; m.activeIndex=math.max(1,math.min(m.activeIndex or 1,#visible))
			local first=math.floor(scroll:GetVerticalScroll()/27)+1; local used=0
			for i=first,math.min(#visible,first+8) do
				used=used+1; local row=m.rows[used]
				if not row then
					row=T.Button(content,"",264,25,function() end,"LEFT"); m.rows[used]=row
					row.keyboardFocus=T.Surface(row,"hover")
					row.caption:SetWordWrap(false)
					row:SetScript("OnClick",function(self) local choose=m.onSelect; m:Hide(); choose(self.option) end)
				end
				local option=visible[i]; row.option=option
				row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(i-1)*27)
				row:SetText(option.label..(option.count and (" ("..option.count..")") or "")); T.Selected(row,option.key==m.selected); row.keyboardFocus:SetShown(i==m.activeIndex); row:Show()
			end
			for i=used+1,#m.rows do m.rows[i]:Hide() end
			m.empty:SetShown(#visible==0)
			content:SetHeight(math.max(1,#visible*27)); m.rendering=false
		end
		search:SetScript("OnTextChanged",function() m.activeIndex=1; scroll:SetVerticalScroll(0); Render() end)
		search:SetAltArrowKeyMode(false)
		search:SetScript("OnArrowPressed",function(_,key)
			if key~="UP" and key~="DOWN" then return end
			m.activeIndex=math.max(1,math.min(#(m.visible or {}),(m.activeIndex or 1)+(key=="DOWN" and 1 or -1)))
			local top=(m.activeIndex-1)*27
			local current=scroll:GetVerticalScroll()
			if top<current then scroll:SetVerticalScroll(top)
			elseif top+27>current+scroll:GetHeight() then scroll:SetVerticalScroll(top+27-scroll:GetHeight()) end
			Render()
		end)
		search:SetScript("OnEnterPressed",function()
			local option=m.visible and m.visible[m.activeIndex or 1]
			if option then local choose=m.onSelect; m:Hide(); choose(option) end
		end)
		scroll:HookScript("OnVerticalScroll",Render)
		m.Refresh=function() search:SetText(""); scroll:SetVerticalScroll(0); Render() end
		m:RegisterEvent("GLOBAL_MOUSE_DOWN")
		m:SetScript("OnEvent",function(self)
			if not self:IsShown() then return end
			if MouseIsOver and self.owner and MouseIsOver(self.owner) then return end
			local x,y=GetCursorPosition()
			local function Inside(frame)
				if not frame then return false end
				local left,right,bottom,top=frame:GetLeft(),frame:GetRight(),frame:GetBottom(),frame:GetTop()
				if not left or not right or not bottom or not top then return false end
				local scale=frame:GetEffectiveScale() or 1
				return x>=left*scale and x<=right*scale and y>=bottom*scale and y<=top*scale
			end
			-- Mouse-down precedes the button's OnClick. Keep the menu open over
			-- its owner so OnClick can toggle it closed rather than reopen it.
			-- Bounds also cover clients where MouseIsOver is absent/unreliable.
			if Inside(self.owner) or Inside(self) then return end
			self:Hide()
		end)
	end
	local m=choiceMenu; m.searchLabel:SetText(searchLabel or "Search options"); m.options=options; m.selected=selected; m.onSelect=onSelect
	m:SetFrameLevel(anchor:GetFrameLevel()+20)
	m.owner=anchor
	m:SetScript("OnUpdate",function(self) if self.owner and not self.owner:IsVisible() then self:Hide() end end)
	m:ClearAllPoints(); m:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-4); m:Show(); m.Refresh(); m.search:SetFocus()
end

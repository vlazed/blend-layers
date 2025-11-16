VLAZED_OVERLAY_ROOT = "/"

local mat_overlay_template = Material("pp/vlazed/overlay")

local pp_overlay = CreateClientConVar("pp_vlazedoverlays", "0", true, false, "Enable overlays", 0, 1)
local width, height = ScrW(), ScrH()

local hookId = "vlazed_overlay_hook"
local callbackId = "vlazed_overlay_callback"

---@enum
local blendModes = {
	normal = 0,

	darken = 1,
	multiply = 2,

	lighten = 3,
	screen = 4,

	overlay = 5,
	softLight = 6,
	hardLight = 7,
}

local blendModeMap = table.Flip(blendModes)

local function iter(a, i)
	i = i + 1
	local v = a[i]
	if v then
		return i, v
	end
end

-- too lazy to change enum structure so gonna iterate from 0
local function ipairs0(a)
	return iter, a, -1
end

---@type OverlayLayer[]
local overlayArray = {}

function render.DrawVlazedOverlay()
	render.UpdateScreenEffectTexture()
	for _, overlay in ipairs(overlayArray) do
		if not IsValid(overlay) then
			continue
		end

		local state = overlay.state
		local material = state.material

		local sfxTexture = render.GetScreenEffectTexture()

		material:SetTexture("$basetexture", sfxTexture)
		material:SetFloat("$c0_x", state.color.r / 255)
		material:SetFloat("$c0_y", state.color.g / 255)
		material:SetFloat("$c0_z", state.color.b / 255)
		material:SetFloat("$c0_w", state.color.a / 255)
		material:SetFloat("$c1_x", state.blend)
		render.SetMaterial(material)

		render.DrawScreenQuad()
		render.UpdateScreenEffectTexture()
	end
	render.SetBlend(1)
end

local function generateOverlayMaterial(index, image)
	local overlayId = Format("overlay_%f", index)
	local overlay = Material("!" .. overlayId)

	if overlay:IsError() then
		overlay = CreateMaterial(overlayId, "screenspace_general", {
			["$pixshader"] = "vlazed_overlay_ps30",
			["$basetexture"] = "_rt_FullFrameFB",
			["$ignorez"] = 1,
			["$cull"] = 1,
			["$vertextransform"] = 1,
			["$c0_x"] = 0.2,
			["$c0_y"] = 1,
			["$c0_z"] = 0.5,
			["$c0_w"] = 7,
			["$c1_x"] = 0.4,
		})
	end
	overlay:SetTexture("$texture1", image)

	return overlay
end

local function enableOverlay()
	if pp_overlay:GetBool() then
		hook.Add("RenderScreenspaceEffects", hookId, function()
			render.DrawVlazedOverlay()
		end)
	else
		hook.Remove("RenderScreenspaceEffects", hookId)
	end
end

cvars.AddChangeCallback("pp_vlazedoverlays", function(cvar, old, new)
	enableOverlay()
end, callbackId)
enableOverlay()

file.CreateDir("vlazed_overlays")

---@param layerList OverlayList
local function refreshLayers(layerList)
	overlayArray = {}
	local orderedList = layerList:GetChildren()
	table.sort(orderedList, function(a, b)
		return a:GetY() > b:GetY()
	end)
	for i, layer in ipairs(orderedList) do
		layer.state.material = generateOverlayMaterial(i, layer.state.image)
		table.insert(overlayArray, layer)
	end
end

---@param parent OverlayList
---@return OverlayLayer
local function addOverlay(parent)
	---@class OverlayLayer: DPanel
	local dPanel = vgui.Create("DPanel", parent)
	dPanel:SetCursor("sizeall")

	dPanel:SetTall(100)

	---@class OverlayState
	dPanel.state = {
		image = "../screenshots/poster 25-11-11 17-05-07 2.png",
		x = 0,
		y = 0,
		w = width,
		h = height,
		material = (Material("")),
		blend = blendModes.normal,
		color = Color(255, 255, 255, 128),
		name = "Layer",
	}

	dPanel.icon = vgui.Create("DImage", dPanel)
	dPanel.icon:SetImage(dPanel.state.image)
	dPanel.icon:SetKeepAspect(true)

	---@class OverlayCapture: DLabel
	dPanel.click = Label("", dPanel)
	dPanel.click:SetMouseInputEnabled(true)
	dPanel.click:SetCursor("hand")

	---@class OverlayDrag: DPanel
	dPanel.drag = vgui.Create("DPanel", dPanel)
	dPanel.drag:SetMouseInputEnabled(false)
	dPanel.drag:SetKeyboardInputEnabled(false)

	---@class OverlayRemoveButton: DImageButton
	dPanel.remove = vgui.Create("DImageButton", dPanel)
	dPanel.remove:SetImage("icon16/cancel.png")

	local dragMargin = 20

	function dPanel.remove.DoClick()
		local menu = DermaMenu()
		menu:AddOption("Confirm delete?", function()
			dPanel:Remove()
			refreshLayers(parent)
		end)
		menu:Open()
	end

	function dPanel:PerformLayout(w, h)
		local icon = self.icon
		local click = self.click
		local drag = self.drag
		local remove = self.remove

		---@diagnostic disable-next-line: undefined-field
		local aspectRatio = icon.ActualWidth / icon.ActualHeight
		icon:SetSize(h * aspectRatio, h)
		click:SetSize(w - dragMargin, h)

		drag:SetPos(w - dragMargin, 0)
		drag:SetSize(dragMargin, h)

		remove:SetSize(dragMargin, dragMargin)
		remove:SetPos(w - dragMargin, 0)
	end

	local textColor
	do
		local skin = dPanel:GetSkin()
		local gray = Color(128, 128, 128, 128)
		local frac = 0
		textColor = skin.Colours.Label.Dark:Lerp(gray, frac)
	end
	local outlineColor = Color(255 - textColor.r, 255 - textColor.g, 255 - textColor.b)
	local textMargin = 10
	function dPanel:PaintOver(w, h)
		draw.SimpleTextOutlined(
			dPanel.state.name,
			"HudDefault",
			w - textMargin - dragMargin,
			h * 0.5,
			textColor,
			TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER,
			1,
			outlineColor
		)
	end

	function dPanel:OnClick(state) end

	function dPanel.click.DoClick()
		dPanel:OnClick(dPanel.state)
	end

	return dPanel
end

---Helper for DForm
---@param cPanel ControlPanel|DForm
---@param name string
---@param type "ControlPanel"|"DForm"
---@return ControlPanel|DForm
local function makeCategory(cPanel, name, type)
	---@type DForm|ControlPanel
	local category = vgui.Create(type, cPanel)

	category:SetLabel(name)
	cPanel:AddItem(category)
	return category
end

local COLOR = FindMetaTable("Color")

list.Set("PostProcess", "Overlay (vlazed)", {

	icon = "gui/postprocess/vlazedoverlay.png",
	convar = "pp_vlazedoverlays",
	category = "#shaders_pp",

	cpanel = function(CPanel)
		---@cast CPanel ControlPanel

		CPanel:Help("Add an overlay of any image from your filesystem!")

		local layers = makeCategory(CPanel, "Layers", "ControlPanel")
		local dPanel = vgui.Create("DPanel", CPanel)
		dPanel:SizeTo(-1, 400, 0)
		layers:AddItem(dPanel)
		local scrollBar = vgui.Create("DScrollPanel", dPanel)
		scrollBar:Dock(FILL)
		---@class OverlayList: DListLayout
		---@field GetChildren fun(self: OverlayList): OverlayLayer[]
		local dragList = vgui.Create("DListLayout", scrollBar)
		dragList:Dock(FILL)
		dragList:MakeDroppable("vlazed_overlay", false)

		---@class OverlayAddButton: DImageButton
		local addButton = vgui.Create("DImageButton", layers)
		addButton:SetImage("icon16/add.png")
		layers:AddItem(addButton)

		local layerSettings = makeCategory(CPanel, "Layer Settings", "ControlPanel")

		layerSettings:Help("Select a layer above to view its settings")

		---@class OverlayName: DTextEntry
		local name = layerSettings:TextEntry("Layer name", "")
		---@class OverlayImage: DTextEntry
		local image = layerSettings:TextEntry("Image path", "")
		---@class OverlayBrowseImage: DImageButton
		local imageButton = vgui.Create("DImageButton", image)
		imageButton:SetImage("icon16/folder_image.png")

		function image:PerformLayout(w, h)
			imageButton:SetSize(h, h)
			imageButton:SetPos(w - h, 0)
		end

		function imageButton:DoClick()
			local fileBrowserFrame = vgui.Create("DFrame")
			---@class OverlayFileBrowser: DFileBrowser
			local fileBrowser = vgui.Create("DFileBrowser", fileBrowserFrame)
			fileBrowserFrame:SetTitle("Select image")
			---@class FileSelect: DButton
			local fileBrowserSelect = vgui.Create("DButton", fileBrowserFrame)

			fileBrowserFrame:SetSize(width / 3, height / 3)
			fileBrowserFrame:SetPos(width / 2 - width / 6, height / 2 - height / 6)

			fileBrowser:SetPath("GAME")
			fileBrowser:SetBaseFolder(VLAZED_OVERLAY_ROOT)
			fileBrowser:SetFileTypes("*.png *.jpg *.jpeg *.vmt")
			fileBrowser:Dock(FILL)
			fileBrowserSelect:Dock(BOTTOM)

			fileBrowserSelect:SetText("Select image")

			fileBrowserFrame:MakePopup()

			local selectedFile = ""
			function fileBrowser:OnSelect(filePath)
				selectedFile = filePath
			end

			function fileBrowserSelect:DoClick()
				if #selectedFile > 0 then
					image:SetValue(selectedFile)
				end

				fileBrowserFrame:Remove()
			end
		end

		---@class OverlayBlendModeBox: DComboBox
		local blendModeBox = layerSettings:ComboBox("Blend Modes") ---@diagnostic disable-line: missing-parameter
		for value, key in ipairs0(blendModeMap) do
			blendModeBox:AddChoice(string.NiceName(key), value)
		end

		---@class OverlayColorMixer: DColorMixer

		---@class OverlayColorPicker: DPanel
		---@field Mixer OverlayColorMixer
		local color = layerSettings:ColorPicker("Color") ---@diagnostic disable-line: missing-parameter

		---@class OverlayPosition: DTextEntry
		local position = layerSettings:TextEntry("Position", "")
		---@class OverlaySize: DTextEntry
		local size = layerSettings:TextEntry("Size", "")

		function dragList:OnModified()
			refreshLayers(dragList)
		end

		local function formatVector(x, y)
			return Format("%d %d", x, y)
		end

		local function parseVector(str)
			local tab = string.Split(str, " ")
			return tonumber(tab[1]) or 0, tonumber(tab[2]) or 0
		end

		---@param state OverlayState
		local function setSettings(state)
			name:SetText(state.name)
			blendModeBox:ChooseOption(string.NiceName(blendModeMap[state.blend]), state.blend + 1)
			image:SetText(state.image)
			position:SetText(formatVector(state.x, state.y))
			size:SetText(formatVector(state.w, state.h))
			color.Mixer:SetColor(state.color)
		end

		---@type OverlayLayer
		local selectedLayer
		local function updateEnabled()
			name:SetEnabled(selectedLayer ~= nil)
			image:SetEnabled(selectedLayer ~= nil)
			blendModeBox:SetEnabled(selectedLayer ~= nil)
			position:SetEnabled(selectedLayer ~= nil)
			size:SetEnabled(selectedLayer ~= nil)
		end

		function addButton:DoClick()
			local layer = addOverlay(dragList)

			function layer:OnClick(state)
				selectedLayer = self
				setSettings(state)
				updateEnabled()
			end

			dragList:Add(layer)
			refreshLayers(dragList)
		end

		function color.Mixer:ValueChanged(newColor) ---@diagnostic disable-line: inject-field
			if not selectedLayer then
				return
			end

			setmetatable(newColor, COLOR)
			selectedLayer.state.color = newColor
		end
		function name:OnValueChange(newVal)
			if not selectedLayer then
				return
			end

			selectedLayer.state.name = newVal
		end
		function position:OnValueChange(newVal)
			if not selectedLayer then
				return
			end

			local x, y = parseVector(newVal)
			selectedLayer.state.x = x
			selectedLayer.state.y = y
		end
		function size:OnValueChange(newVal)
			if not selectedLayer then
				return
			end

			local w, h = parseVector(newVal)
			selectedLayer.state.w = w
			selectedLayer.state.h = h
		end
		function image:OnValueChange(newVal)
			if not selectedLayer then
				return
			end

			local oldImage = selectedLayer.icon:GetImage()
			selectedLayer.icon:SetImage(newVal)
			if not selectedLayer.icon:GetMaterial():IsError() then
				selectedLayer.state.image = newVal
				selectedLayer.state.material:SetTexture("$texture1", newVal)
			else
				selectedLayer.icon:SetImage(oldImage)
			end
		end
		function blendModeBox:OnSelect(_, _, value)
			if not selectedLayer then
				return
			end

			selectedLayer.state.blend = value
		end

		updateEnabled()
	end,
})

-- OpenAllCrates v1.0.2
-- Limyc

log.info("Successfully loaded ".._ENV["!guid"]..".")

local plugin_name = _ENV["!guid"]


-- RoRR Modding Toolkit
mods.on_all_mods_loaded(function() for _, m in pairs(mods) do if type(m) == "table" and m.RoRR_Modding_Toolkit then Actor = m.Actor Buff = m.Buff Callback = m.Callback Equipment = m.Equipment Helper = m.Helper Instance = m.Instance Item = m.Item Net = m.Net Object = m.Object Player = m.Player Resources = m.Resources Survivor = m.Survivor break end end 
	mod_state = {}
	mod_state.is_running = false
	mod_state.ignore_crate = nil
end)
-- Toml Helper
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.tomlfuncs then Toml = v end end 
	mod_config = {
		hotkey_open_crates = 79,
		show_hud = true,
		hud_scale = 1.0,
		hud_position_x = 0.001,
		hud_position_y = 0.1,
		hud_element_spacing = 0,
		hud_group_spacing = 8,
		hud_horizontal_layout = false,
		hud_rtl = false, -- right to left render
		enable_logs = false,
		debug_draw = false,
	}
	mod_config = Toml.config_update(plugin_name, mod_config)
end)

local last_crate_choice = {}
local gm_hud_scale = gm.prefs_get_hud_scale()
local gm_window_width = gm.window_get_width()
local gm_window_height = gm.window_get_height()

local function log_info(s)
	if mod_config.enable_logs then
		log.info(s)
	end
end

local function log_hook(self, other, result, args)
	if mod_config.enable_logs then
		Helper.log_hook(self, other, result, args)
	end
end

local function crate_choice_to_string(c)
	return "obj_id = " .. tostring(c.obj_id) .. " | obj_sprite = " .. tostring(c.obj_sprite) ..
	" | crate_sprite = " .. tostring(c.crate_sprite) .. " | selection = " .. tostring(c.selection)
end

local function get_sprite_index(obj_id)
	local items_arr = gm.variable_global_get("class_item")
	for _, item in ipairs(items_arr) do
		-- compare object id
		if item and item[9] == obj_id then
			log_info("found sprite index " .. tostring(item[8]) .. " for object id " .. obj_id)
			-- return sprite id
			return item[8]
		end
	end

	
	local equipment_arr = gm.variable_global_get("class_equipment")
	for _, equip in ipairs(equipment_arr) do
		-- compare object id
		if equip and equip[9] == obj_id then
			log_info("found sprite index " .. tostring(equip[8]) .. " for object id " .. obj_id)
			-- return sprite id
			return equip[8]
		end
	end
	
	log_info("sprite index not found for obj id " .. obj_id)
	
	return -4.0
end

gui.add_to_menu_bar(function()
	local pressed = false
	local changed = false
	
	ImGui.Spacing()
	ImGui.Text("Hotkeys")
	ImGui.Indent()
	
	pressed, mod_config.hotkey_open_crates = ImGui.Hotkey("Open Crates", mod_config.hotkey_open_crates)
	if pressed then changed = true end
	
	ImGui.Unindent()
	ImGui.Spacing()
	ImGui.Text("HUD")
	ImGui.Indent()
	
	mod_config.show_hud, pressed = ImGui.Checkbox("Show HUD", mod_config.show_hud)
	if pressed then changed = true end
	
	mod_config.hud_scale, pressed = ImGui.DragFloat("Scale", mod_config.hud_scale, 0.01, 0.1, 4)
	if pressed then changed = true end
	
	mod_config.hud_position_x, pressed = ImGui.DragFloat("Position X", mod_config.hud_position_x, 0.001, 0, 1)
	if pressed then changed = true end
	
	mod_config.hud_position_y, pressed = ImGui.DragFloat("Position Y", mod_config.hud_position_y, 0.001, 0, 1)
	if pressed then changed = true end
	
	mod_config.hud_element_spacing, pressed = ImGui.DragFloat("Element Spacing", mod_config.hud_element_spacing)
	if pressed then changed = true end
	
	mod_config.hud_group_spacing, pressed = ImGui.DragFloat("Group Spacing", mod_config.hud_group_spacing)
	if pressed then changed = true end
	
	mod_config.hud_horizontal_layout, pressed = ImGui.Checkbox("Use Horizonal Layout", mod_config.hud_horizontal_layout)
	if pressed then changed = true end
	
	mod_config.hud_rtl, pressed = ImGui.Checkbox("Draw Right to Left", mod_config.hud_rtl)
	if pressed then changed = true end
	
	ImGui.Unindent()
	ImGui.Spacing()
	ImGui.Text("Debug")
	ImGui.Indent()
	
	mod_config.enable_logs, pressed = ImGui.Checkbox("Enable Logs", mod_config.enable_logs)
	if pressed then changed = true end
	
	mod_config.debug_draw, pressed = ImGui.Checkbox("Debug Draw", mod_config.debug_draw)
	if pressed then changed = true end
	
	ImGui.Unindent()
	
	if changed then
		Toml.save_cfg(plugin_name, mod_config)
	end
end)

gui.add_always_draw_imgui(function()
	-- KEY_O
	if ImGui.IsKeyPressed(mod_config.hotkey_open_crates) then
		local crates = Instance.find_all(gm.constants.oCustomObject_pInteractableCrate)
		for _, c in ipairs(crates) do
			if mod_state.ignore_crate and mod_state.ignore_crate == c then 
				goto continue 
			end
			
			local choice = last_crate_choice[c.inventory + 1]
			if choice and choice.obj_id then
				log_info("spawn object id " .. choice.obj_id .. " from inventory " .. c.inventory)
				gm.item_drop_object(choice.obj_id, c.x, c.y, c, false)
				gm.instance_destroy(c)
			end
			
			::continue::
		end
	end
end)

-- ========== Main ==========

gm.pre_code_execute(function(self, other, code, result, flags)
	--log_hook(self, other, result, {})
	-- save selected object for currently open crate inventory
	if self.object_index == gm.constants.oCustomObject_pInteractableCrate
	and code.name:match("oCustomObject_pInteractableCrate_Draw_0")
	and self.active 
	and self.activator == Player.get_client()
	and not self.is_scrapper then  
		-- crate is open, disable the hotkey so we don't softlock
		mod_state.ignore_crate = self
		
		if not last_crate_choice[self.inventory + 1] then 
			last_crate_choice[self.inventory + 1] = {}
			last_crate_choice[self.inventory + 1].crate_sprite = self.sprite_index
			table.sort(last_crate_choice)
		end
		
		local choice = last_crate_choice[self.inventory + 1]
		
		if self.active == 1.0 and not self.was_selection_set then
			if choice.selection then
				self.selection = choice.selection
				log_info("set crate selection to " .. choice.selection)
			else
				choice.selection = self.selection
				log_info("set last selection to " .. choice.selection .. " for inventory " .. self.inventory)
			end
			self.was_selection_set = 1.0
		elseif self.active > 1.0 then
			local new_obj_id = self.contents[self.selection + 1]
			if choice.obj_id ~= new_obj_id then
				choice.obj_id = new_obj_id
				choice.obj_sprite = get_sprite_index(new_obj_id)
				choice.selection = self.selection
				log_info("set last crate object: " .. crate_choice_to_string(choice) .. " for inventory " .. self.inventory)
			end
		end
    end
end)


local c_white = gm.make_colour_rgb(255, 255, 255)

local draw_item_layout = function(sprite_index, x, y, sx, sy)
	local sprite = gm.sprite_get_info(sprite_index)
	local half_w = sprite.width * sx * 0.5
	local half_h = sprite.height * sy * 0.5
	local x_offset = sprite.xoffset * sx * 0.5
	local y_offset = sprite.yoffset * sy * 0.5
	x = x + half_w + x_offset
	y = y + half_h
	gm.draw_sprite_ext(sprite_index, 0, x - x_offset, y + y_offset, sx, sy, 0, c_white, 1)
	return x + (half_w - x_offset), y + half_h
end

local draw_item_layout_horizontal = function(sprite_index, x, y, sx, sy)
	local sprite = gm.sprite_get_info(sprite_index)
	local half_w = sprite.width * sx * 0.5
	local half_h = sprite.height * sy * 0.5
	local x_offset = sprite.xoffset * sx * 0.5
	local y_offset = sprite.yoffset * sy * 0.5
	x = x + half_w + x_offset
	y = y + half_h
	gm.draw_sprite_ext(sprite_index, 0, x - x_offset, y + y_offset, sx, sy, 0, c_white, 1)
	return x + (half_w - x_offset), y + half_h
end
	
gm.post_code_execute(function(self, other, code, result, flags)
	if not mod_state or not mod_state.is_running
	or not mod_config or not mod_config.show_hud then 
		return 
	end
	
	-- gm_Object_oInit_Draw_6 is screen space
	-- gm_Object_oInit_Draw_7 is world space
	if not code.name:match("gml_Object_oInit_Draw_6") then
		--log_info(tostring(code.name))
		return 
	end
	
	local get_sprite_layout_order = function(a, b)
		if mod_config.hud_rtl then
			return b, a
		end
		return a, b
	end
	
	local sx = gm_hud_scale * mod_config.hud_scale
	local sy = gm_hud_scale * mod_config.hud_scale
	local x_start = mod_config.hud_position_x * gm_window_width
	local y_start = mod_config.hud_position_y * gm_window_height
	local x = x_start
	local y = y_start
	
	for _, choice in pairs(last_crate_choice) do
		if choice and choice.obj_sprite then
			local a, b = get_sprite_layout_order(choice.crate_sprite, choice.obj_sprite)
			
			x, _ = draw_item_layout(a, x, y, sx, sy, 0, 0)
			x = x + (mod_config.hud_element_spacing * sx)
			x, y = draw_item_layout(b, x, y, sx, sy, 0, 0)
			
			if mod_config.hud_horizontal_layout then
				x = x + (mod_config.hud_group_spacing * sx)
				y = y_start
			else
				x = x_start
				y = y + (mod_config.hud_group_spacing * sy)
			end
		end
	end

	if mod_config.debug_draw then
		local white_crate = 533
		local meat_chunk = 1509
		local a, b = get_sprite_layout_order(white_crate, meat_chunk)
			
		x = x_start
		y = y_start
		
		x, _ = draw_item_layout(a, x, y, sx, sy, 0, 0)
		x = x + (mod_config.hud_element_spacing * sx)
		x, y = draw_item_layout(b, x, y, sx, sy, 0, 0)
		
		if mod_config.hud_horizontal_layout then
			x = x + (mod_config.hud_group_spacing * sx)
			y = y_start
		else
			x = x_start
			y = y + (mod_config.hud_group_spacing * sy)
		end
		
		x, _ = draw_item_layout(a, x, y, sx, sy, 0, 0)
		x = x + (mod_config.hud_element_spacing * sx)
		x, y = draw_item_layout(b, x, y, sx, sy, 0, 0)

	end
end)

gm.pre_script_hook(gm.constants.prefs_set_hud_scale, function(self, other, result, args)
	--log_hook(self, other, result, args)
	gm_hud_scale = args[1].value
	log_info("set hud scale = " .. gm_hud_scale)
end)

gm.pre_script_hook(gm.constants.window_set_size, function(self, other, result, args)
	--log_hook(self, other, result, args)
	gm_window_width = args[1].value
	gm_window_height = args[2].value
	log_info("set window size scale = " .. gm_window_width .. "x" .. gm_window_height)
end)

gm.pre_script_hook(gm.constants.run_create, function(self, other, result, args)
	--log_hook(self, other, result, args)
	if mod_state then mod_state.is_running = true end
end)

gm.pre_script_hook(gm.constants.run_destroy, function(self, other, result, args)
	--log_hook(self, other, result, args)
	if mod_state then mod_state.is_running = false end
end)

-- OpenAllCrates v1.0.0
-- Limyc

log.info("Successfully loaded ".._ENV["!guid"]..".")

local plugin_name = _ENV["!guid"]

-- RoRR Modding Toolkit
mods.on_all_mods_loaded(function() for _, m in pairs(mods) do if type(m) == "table" and m.RoRR_Modding_Toolkit then Actor = m.Actor Buff = m.Buff Callback = m.Callback Equipment = m.Equipment Helper = m.Helper Instance = m.Instance Item = m.Item Net = m.Net Object = m.Object Player = m.Player Resources = m.Resources Survivor = m.Survivor break end end end)
-- Toml Helper
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.tomlfuncs then Toml = v end end 
	config = {
		enable_logs = false,
		show_hud = true,
		hud_scale = 1.0,
		hud_position_x = 0.0,
		hud_position_y = 0.1,
		hud_element_spacing = 0,
		hud_group_spacing = 0,
		hud_horizontal_layout = false,
		hud_rtl = false, -- right to left render
	}
	config = Toml.config_update(plugin_name, config)
end)

local last_crate_choice = {}
local gm_hud_scale = gm.prefs_get_hud_scale()
local gm_window_width = gm.window_get_width()
local gm_window_height = gm.window_get_height()

local function log_info(s)
	if config.enable_logs then
		log.info(s)
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
	config.enable_logs, pressed = ImGui.Checkbox("Enable Logs", config.enable_logs)
	if pressed then changed = true end
	
	config.show_hud, pressed = ImGui.Checkbox("show_hud", config.show_hud)
	if pressed then changed = true end
	
	config.hud_scale, pressed = ImGui.DragFloat("hud_scale", config.hud_scale, 0.01, 0, 4)
	if pressed then changed = true end
	
	config.hud_position_x, pressed = ImGui.DragFloat("hud_position_x", config.hud_position_x, 0.01, 0, 1)
	if pressed then changed = true end
	
	config.hud_position_y, pressed = ImGui.DragFloat("hud_position_y", config.hud_position_y, 0.01, 0, 1)
	if pressed then changed = true end
	
	config.hud_element_spacing, pressed = ImGui.DragFloat("hud_element_spacing", config.hud_element_spacing)
	if pressed then changed = true end
	
	config.hud_group_spacing, pressed = ImGui.DragFloat("hud_group_spacing", config.hud_group_spacing)
	if pressed then changed = true end
	--config.hud_horizontal_layout, pressed = ImGui.Checkbox("hud_horizontal_layout", config.hud_horizontal_layout)
	--if pressed then changed = true end
	--config.hud_rtl, pressed = ImGui.Checkbox("hud_rtl", config.hud_rtl)
	--if pressed then changed = true end
	
	if changed then
		Toml.save_cfg(plugin_name, config)
	end
end)

gui.add_always_draw_imgui(function()
	-- KEY_O
	if ImGui.IsKeyPressed(79) then
		local crates = Instance.find_all(gm.constants.oCustomObject_pInteractableCrate)
		for _, c in ipairs(crates) do
			local crate_choice = last_crate_choice[c.inventory + 1]
			if crate_choice and crate_choice.obj_id then
				log_info("spawn object id " .. crate_choice.obj_id .. " from inventory " .. c.inventory)
				gm.item_drop_object(crate_choice.obj_id, c.x, c.y, c, false)
				gm.instance_destroy(c)
			end
		end
	end
end)

-- ========== Main ==========

gm.pre_code_execute(function(self, other, code, result, flags)
	-- save selected object for currently open crate inventory
	if self.object_index == gm.constants.oCustomObject_pInteractableCrate
	and self.active 
	and not self.is_scrapper 
	and self.activator == Player.get_client() 
	and code.name:match("oCustomObject_pInteractableCrate_Draw_0") then
		if not last_crate_choice[self.inventory + 1] then 
			last_crate_choice[self.inventory + 1] = {}
			last_crate_choice[self.inventory + 1].crate_sprite = self.sprite_index
			table.sort(last_crate_choice)
		end
		
		local crate_choice = last_crate_choice[self.inventory + 1]
		
		if self.active == 1.0 and not self.was_selection_set then
			if crate_choice.selection then
				self.selection = crate_choice.selection
				log_info("set crate selection to " .. crate_choice.selection)
			else
				crate_choice.selection = self.selection
				log_info("set last selection to " .. crate_choice.selection .. " for inventory " .. self.inventory)
			end
			self.was_selection_set = 1.0
		elseif self.active > 1.0 then
			local new_obj_id = self.contents[self.selection + 1]
			if crate_choice.obj_id ~= new_obj_id then
				crate_choice.obj_id = new_obj_id
				crate_choice.obj_sprite = get_sprite_index(new_obj_id)
				crate_choice.selection = self.selection
				log_info("set last crate object: " .. crate_choice_to_string(crate_choice) .. " for inventory " .. self.inventory)
			end
		end
		
    end
end)

gm.post_code_execute(function(self, other, code, result, flags)
	if not config or not config.show_hug then return end
	-- gm_Object_oInit_Draw_6 is screen space
	-- gm_Object_oInit_Draw_7 is world space
	if not code.name:match("gml_Object_oInit_Draw_6") then
		--log_info(tostring(code.name))
		return 
	end
	
	local sx = gm_hud_scale * config.hud_scale
	local sy = gm_hud_scale * config.hud_scale
	local x = config.hud_position_x * gm_window_width
	local y = config.hud_position_y * gm_window_height
	local crate_offset_y = 17 * sy
	local rot = 0
	local c_white = gm.make_colour_rgb(255, 255, 255)
	--gm.draw_sprite_ext(1509, 0, x, y + y_offset, sx, sy, rot, c_white, 1)
	for _, choice in pairs(last_crate_choice) do
		if choice and choice.obj_sprite then
			local crate_sprite = gm.sprite_get_info(choice.crate_sprite)
			local crate_width = crate_sprite.width * sx
			local crate_height = crate_sprite.height * sy
			local x_pos = x + (crate_width * 0.5)
			local y_pos = y + (crate_height * 0.5) + crate_offset_y
			gm.draw_sprite_ext(choice.crate_sprite, 0, x_pos, y_pos, sx, sy, rot, c_white, 1)
			
			obj_sprite = gm.sprite_get_info(choice.obj_sprite)
			local obj_width = obj_sprite.width * sx
			local obj_height = obj_sprite.height * sy
			x_pos = x_pos + (crate_width * 0.5) + config.hud_element_spacing + (obj_width * 0.5)
			y_pos = y + (obj_height * 0.5)
			gm.draw_sprite_ext(choice.obj_sprite, 0, x_pos, y_pos, sx, sy, rot, c_white, 1)
			
			y = y + (config.hud_group_spacing * sy)
		end
	end
end)

gm.pre_script_hook(gm.constants.prefs_set_hud_scale, function(self, other, result, args)
	gm_hud_scale = args[1].value
	log_info("set hud scale = " .. gm_hud_scale)
end)

gm.pre_script_hook(gm.constants.window_set_size, function(self, other, result, args)
	Helper.log_hook(self, other, result, args)
	gm_window_width = args[1].value
	gm_window_height = args[2].value
	log_info("set window size scale = " .. gm_window_width .. "x" .. gm_window_height)
end)
local celib = require("custom_entities")

meta = {
	name = "Thermal Paste",
	version = "1.0",
	author = "Super Ninja Fat, Bumperoyster, Taffer",
	description = "Get bomb-cascades through this new paste powerup!",
}

local powerup_texture_id
local item_texture_id
do
	local powerup_texture_def = TextureDefinition.new()
	powerup_texture_def.width = 512
	powerup_texture_def.height = 128
	powerup_texture_def.tile_width = 128
	powerup_texture_def.tile_height = 128
	powerup_texture_def.sub_image_offset_x = 0
	powerup_texture_def.sub_image_offset_y = 0
	powerup_texture_def.sub_image_width = 128
	powerup_texture_def.sub_image_height = 128
	powerup_texture_def.texture_path = "thermal_paste.png"
	powerup_texture_id = define_texture(powerup_texture_def)

	local item_texture_def = TextureDefinition.new()
	item_texture_def.width = 512
	item_texture_def.height = 128
	item_texture_def.tile_width = 128
	item_texture_def.tile_height = 128
	item_texture_def.sub_image_offset_x = 128
	item_texture_def.sub_image_offset_y = 0
	item_texture_def.sub_image_width = 384
	item_texture_def.sub_image_height = 128
	item_texture_def.texture_path = "thermal_paste.png"
	item_texture_id = define_texture(item_texture_def)
end

local powerup_id, pickup_id

--[[
    Bombs use idle_counter to track when they should explode. They
    explode when their idle_counter reaches 150. When a bomb is
    damaged by an explosion its idle_counter is set to 148.

    Bombs not in contact with a tile when another bomb damages
    them also explode. However we need to cheat a bit here for
    the desired effect.
]]
---@class ThermalPasteBombData
---@field contact_grace_time integer defines the number of state machine updates a bomb can remain airborne for and retain its original timer for even if it is damaged by another explosion.
---@field contact_timer integer is set to contact_grace_time when in the bomb has an overlay entity. It is decremented by one each state machine update until it reaches 0.
---@field explosion_timer integer serves as a backup timer that is not affected by other bomb explosions. It increments once each state machine update and is otherwise identical to idle_counter bombs normally use. If idle_counter does not match explosion_timer, and contact_timer is greater than zero, we set idle_counter to explosion_timer.

---@class ThermalPasteBomb : Bomb
----@field user_data ThermalPasteBombData

local anim_frame_remap = { [83] = 0, [84] = 1, [85] = 2 }

---@param ent ThermalPasteBomb
---@param c_data ThermalPasteBombData
local function item_update(ent, c_data)
	-- Handle cascade behavior
	c_data.explosion_timer = c_data.explosion_timer + 1
	if ent.overlay and c_data.contact_timer ~= c_data.contact_grace_time then
		c_data.contact_timer = c_data.contact_grace_time
	elseif not ent.overlay and c_data.contact_timer > 0 then
		c_data.contact_timer = c_data.contact_timer - 1
	end
	if ent.idle_counter ~= c_data.explosion_timer and c_data.contact_timer > 0 then
		ent.idle_counter = c_data.explosion_timer
	end

	-- Map vanilla animation frames to our custom texture definition
	local remapped = anim_frame_remap[ent.animation_frame]
	if remapped then
		ent.animation_frame = remapped
	end
end

---@param ent ThermalPasteBomb
---@param c_data ThermalPasteBombData
---@return table
local function item_set(ent, c_data)
	---@type ThermalPasteBombData
	local custom_data = {
		contact_grace_time = 2,
		contact_timer = -1,
		explosion_timer = -1,
	}
	ent:set_texture(item_texture_id)
	ent.animation_frame = 0
	return custom_data
end

local item_id = celib.new_custom_entity(
	item_set,
	item_update,
	celib.CARRY_TYPE.HELD,
	ENT_TYPE.ITEM_PASTEBOMB,
	celib.UPDATE_TYPE.POST_STATEMACHINE
)

-- Powerup: applied to players, draws HUD icon, grants vanilla paste
local function powerup_set(ent)
	ent:give_powerup(ENT_TYPE.ITEM_POWERUP_PASTE)
	return {}
end

local function powerup_update(ent, c_data)
	-- Remove vanilla paste if player dies and loses the custom powerup
	if test_flag(ent.flags, ENT_FLAG.DEAD) and not ent:has_powerup(ENT_TYPE.ITEM_POWERUP_ANKH) then
		ent:remove_powerup(ENT_TYPE.ITEM_POWERUP_PASTE)
	end
end

powerup_id = celib.new_custom_powerup(powerup_set, powerup_update, powerup_texture_id, 0, 0)

-- Pickup: item on the ground that grants the powerup when touched
local function pickup_set(ent)
	celib.set_entity_info_from_custom_id(ent, pickup_id)
end

local function pickup_update() end

local function pickup_picked(_, player)
	celib.do_pickup_effect(player.uid, powerup_texture_id, 0)
end

pickup_id = celib.new_custom_pickup(pickup_set, pickup_update, pickup_picked, powerup_id, ENT_TYPE.ITEM_PICKUP_PASTE)
celib.set_powerup_drop(powerup_id, pickup_id)
celib.add_custom_entity_info(pickup_id, "Thermal Paste", powerup_texture_id, 0, 10000, 1000)
celib.define_custom_entity_tilecode(pickup_id, "thermal_paste", true)

celib.add_custom_shop_chance(pickup_id, celib.CHANCE.COMMON, {
	celib.SHOP_TYPE.WEAPON_SHOP,
	celib.SHOP_TYPE.DICESHOP,
	celib.SHOP_TYPE.TUSKDICESHOP,
	celib.SHOP_TYPE.CAVEMAN,
}, true)
celib.add_custom_container_chance(pickup_id, celib.CHANCE.LOWER, { ENT_TYPE.ITEM_CRATE, ENT_TYPE.ITEM_PRESENT })

-- Convert bombs/paste bombs thrown by players with the powerup into thermal paste bombs
local function has_thermal_paste_powerup(player_uid)
	return celib.custom_types
		and celib.custom_types[powerup_id]
		and celib.custom_types[powerup_id].entities[player_uid] ~= nil
end

-- Apply custom entity to paste bombs thrown by players with the thermal paste powerup
set_post_entity_spawn(function(ent)
	local checked = false
	ent:set_pre_update_state_machine(
		---@param bomb Bomb
		function(bomb)
			if checked then
				return
			end
			checked = true
			local owner_uid = bomb.last_owner_uid
			if owner_uid == -1 then
				return
			end
			local owner = get_entity(owner_uid)
			if not owner or owner.type.search_flags ~= MASK.PLAYER then
				return
			end
			if not has_thermal_paste_powerup(owner_uid) then
				return
			end
			celib.set_custom_entity(bomb.uid, item_id)
		end
	)
end, SPAWN_TYPE.ANY, MASK.ITEM, ENT_TYPE.ITEM_PASTEBOMB)

celib.add_custom_shop_chance(pickup_id, celib.CHANCE.COMMON, {
	celib.SHOP_TYPE.WEAPON_SHOP,
	celib.SHOP_TYPE.DICESHOP,
	celib.SHOP_TYPE.TUSKDICESHOP,
	celib.SHOP_TYPE.CAVEMAN,
}, true)
celib.add_custom_container_chance(pickup_id, celib.CHANCE.LOWER, { ENT_TYPE.ITEM_CRATE, ENT_TYPE.ITEM_PRESENT })

celib.init()

register_option_button("thermal_paste_bomb_item_spawn", "Spawn Thermal Paste Bomb", "", function()
	if #players == 0 then
		return
	end
	local x, y, l = get_position(players[1].uid)
	celib.set_custom_entity(spawn(ENT_TYPE.ITEM_PASTEBOMB, x, y, l, 0, 0), item_id)
end)

register_option_button("thermal_paste_pickup_spawn", "Spawn Thermal Paste Pickup", "", function()
	if #players == 0 then
		return
	end
	local x, y, l = get_position(players[1].uid)
	celib.spawn_custom_entity(pickup_id, x, y, l, 0, 0)
end)

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

-- TODO:
--[[
    - [x] Copy over basic functionality
    - [x] Make a custom pastebomb entity (with a base entity as paste bomb?)
    - [ ] Make a custom pickup entity (with a base entity as paste pickup?)
    - [ ] Make a custom powerup entity (with a base entity as paste powerup?)
    - [ ] Make only bombs or paste bombs created by a player with the powerup turn into thermal paste bombs. Account for powerpack bombs as well.
]]

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

-- celib.add_custom_shop_chance(pickup_id, celib.CHANCE.COMMON, {
-- 	celib.SHOP_TYPE.WEAPON_SHOP,
-- 	celib.SHOP_TYPE.DICESHOP,
-- 	celib.SHOP_TYPE.TUSKDICESHOP,
-- 	celib.SHOP_TYPE.CAVEMAN,
-- }, true)
-- celib.add_custom_container_chance(pickup_id, celib.CHANCE.LOWER, { ENT_TYPE.ITEM_CRATE, ENT_TYPE.ITEM_PRESENT })

celib.init()

register_option_button("thermal_paste_bomb_item_spawn", "Spawn Thermal Paste Bomb", "", function()
	if #players == 0 then
		return
	end
	local x, y, l = get_position(players[1].uid)
	celib.set_custom_entity(spawn(ENT_TYPE.ITEM_PASTEBOMB, x, y, l, 0, 0), item_id)
end)

core:add_listener(
	"faction_turn_end_applyvalues",
	"FactionTurnEnd",
	function(context) return context:faction():is_human() == true; end,
	function()
		local region_list = cm:model():world():region_manager():region_list();
		for i = 0, region_list:num_items() - 1 do
			local current_region = region_list:item_at(i);
			local region_key = current_region:name();
			local region_owner = current_region:owning_faction()
			local region_owner_key = region_owner:name()
			if region_owner:is_human() then
			cm:set_saved_value("playerowned_"..current_region:name(), 1)
			end;
		end;
	end,
	true
);


core:add_listener(
		"ally_give_back_cities",
		"FactionTurnStart",
		function(context) return context:faction():is_human() == true; end,
	function()
			local region_list = cm:model():world():region_manager():region_list();
			for i = 0, region_list:num_items() - 1 do
				local current_region = region_list:item_at(i);
				local region_key = current_region:name();
				local region_owner = current_region:owning_faction()
				local region_owner_key = region_owner:name()
				local owner_culture = region_owner:culture()
				local human_faction = cm:get_local_faction()
				local human_faction_key = cm:get_faction(human_faction)
				local selected_settlement = current_region:settlement()
				local logical_position_x = selected_settlement:logical_position_x();
				local logical_position_y = selected_settlement:logical_position_y();
					if not region_owner:is_human() then
						if region_owner:is_ally_vassal_or_client_state_of(human_faction_key) then 
							if cm:get_saved_value("playerowned_"..current_region:name()) == 1 then						
							cm:transfer_region_to_faction(region_key, human_faction);
							cm:show_message_event_located(human_faction, "event_feed_strings_text_alliesreturn_title", "factions_screen_name_wh_main_a", "event_feed_strings_text_alliesreturn_secondary_detail", logical_position_x, logical_position_y, false, 1311);
							end;
						end;	
					end;
			end;
		end,
		true
);


core:add_listener(
	"reason_for_region_change",
	"RegionFactionChangeEvent",
	true,
	function(context)
		local reason = context:reason()
		local region = context:region():name()
out(reason)
		if reason == "payload" then
		cm:set_saved_value("playerowned_"..region, 0)
out("Region was gifted away through a payload, setting to 0!")
		end;
	end,
	true
);
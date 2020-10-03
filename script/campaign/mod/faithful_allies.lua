-- indices here are faction keys to a further table of regions owned
-- ie., player_owned_regions["wh_main_emp_empire"]["wh_main_reikland_altdorf"] = true
local player_owned_regions = nil

local function init()

    if cm:is_new_game() or player_owned_regions == nil then
        local human_factions = cm:get_human_factions()

        for i = 1, #human_factions do
            local faction_key = human_factions[i]
            local faction_obj = cm:get_faction(faction_key)

            player_owned_regions[faction_key] = {}

            local region_list = faction_obj:region_list()
            for j = 0, region_list:num_items() - 1 do
                local region = region_list:item_at(j)
                local region_key = region:name()

                player_owned_regions[faction_key][region_key] = true
            end
        end
    end

    -- add regions to the list if a player obtains it
    core:add_listener(
        "added_to_player_faction",
        "RegionFactionChangeEvent",
        function(context)
            -- check if the region is occupied by a player faction

            local region = context:region()
            if not region:is_abandoned() then
                local owning_faction = region:owning_faction()
                if player_owned_regions[owning_faction:name()] then
                    return true
                end
            end

            return false
        end,
        function(context)
            local region = context:region()
            local region_key = region:name()
            local faction = region:owning_faction()
            local faction_key = faction:name()

            -- check if this region was owned by the other player; if it was, erase it from the other player's table
            for k,region_list in pairs(player_owned_regions) do
                if region_list[region_key] and k ~= faction_key then
                    player_owned_regions[k][region_key] = nil
                end
            end

            -- add it to the table for the new owner
            player_owned_regions[faction_key][region_key] = true
        end,
        true
    )

    -- remove regions from the list if exchanged via payload
    core:add_listener(
        "reason_for_region_change",
        "RegionFactionChangeEvent",
        function(context)
            local is_players = false
            local region_key = context:region():name()
            for _,region_list in pairs(player_owned_regions) do
                if region_list[region_key] then
                    is_players = true
                end
            end
            
            return is_players and context:reason() == "payload"
        end,
        function(context)

            local region_key = context:region():name()

            for k,region_list in pairs(player_owned_regions) do
                if region_list[region_key] then
                    player_owned_regions[k][region_key] = nil
                end
            end

        end,
        true
    );

    -- listener for the AI to return stuff on player turn start
    -- TODO make this more performative???
    core:add_listener(
		"ally_give_back_cities",
		"FactionTurnStart",
        function(context) 
            return context:faction():is_human() == true; 
        end,
	    function()
			local region_list = cm:model():world():region_manager():region_list();
			for i = 0, region_list:num_items() - 1 do
                local current_region = region_list:item_at(i);
                
                local region_key = current_region:name();
                
                -- test if the region is owned
                local og_owner_key = nil

                for k,reg_list in pairs(player_owned_regions) do
                    if reg_list[region_key] == true then
                        og_owner_key = k
                    end
                end

                if og_owner_key then
                    local og_owner_obj = cm:get_faction(og_owner_key)
                    local region_owner = current_region:owning_faction()
                    
                    local selected_settlement = current_region:settlement()
                    local logical_position_x = selected_settlement:logical_position_x();
                    local logical_position_y = selected_settlement:logical_position_y();
                    
                    if not region_owner:is_human() and region_owner:is_ally_vassal_or_client_state_of(og_owner_obj)  then
                        cm:transfer_region_to_faction(region_key, og_owner_key);
                        cm:show_message_event_located(og_owner_key, "event_feed_strings_text_alliesreturn_title", "factions_screen_name_wh_main_a", "event_feed_strings_text_alliesreturn_secondary_detail", logical_position_x, logical_position_y, false, 1311);
                    end;
                else
                    -- skip this one
                end
			end;
		end,
		true
    );
end

cm:add_first_tick_callback(init)

cm:add_saving_game_callback(
    function(context)
        cm:save_named_value("faithful_allies_region_list", player_owned_regions, context)
    end
)

cm:add_loading_game_callback(
    function(context)
        player_owned_regions = cm:load_named_value("faithful_allies_region_list", {}, context)
    end
)
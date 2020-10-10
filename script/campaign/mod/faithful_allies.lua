-- indices here are faction keys to a further table of regions owned
-- ie., player_owned_regions["wh_main_emp_empire"]["wh_main_reikland_altdorf"] = true
local player_owned_regions = nil

local return_details = {}

local oldModLog = ModLog
local ModLog = function(text) oldModLog("[Faithful Allies] " .. text) end

local function init()

    if cm:is_new_game() or player_owned_regions == nil then
        local human_factions = cm:get_human_factions()

        player_owned_regions = {}

        for i = 1, #human_factions do
            local faction_key = human_factions[i]
            local faction_obj = cm:get_faction(faction_key)

            player_owned_regions[faction_key] = {}

            ModLog("creating player owned region table for faction ["..faction_key.."].")

            local region_list = faction_obj:region_list()
            for j = 0, region_list:num_items() - 1 do
                local region = region_list:item_at(j)
                local region_key = region:name()

                ModLog("adding ["..region_key.."].")

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

            ModLog("adding ["..region_key.."] to faction table ["..faction_key.."].")

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
            for k,region_list in pairs(player_owned_regions) do
                if region_list[region_key] then
                    is_players = true
                end
            end
            
            -- TODO this triggers for all transfer_region_to_faction calls; look into some way around that or sumin
            return is_players and context:reason() == "payload"
        end,
        function(context)
            local region_key = context:region():name()

            ModLog("removing "..region_key.." from all player owned regions")

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
        function(context)
            local current_player = context:faction()
            local current_player_key = current_player:name()

            ModLog("checking player list for ["..current_player_key.."].")

            local player_regions = player_owned_regions[current_player_key]

            for region_key,_ in pairs(player_regions) do
                ModLog("checking region ["..region_key.."].")
                
                local region_obj = cm:get_region(region_key)

                if region_obj:is_abandoned() then
                    -- do naught
                else
                    ModLog("region is not abandoned")
                    local owning_faction = region_obj:owning_faction()
                    local owning_faction_key = owning_faction:name()

                    ModLog("owner is: "..owning_faction_key)

                    if owning_faction_key ~= current_player_key and not owning_faction:is_human() then
                        ModLog("not human!")
                        if owning_faction:is_ally_vassal_or_client_state_of(current_player) then
                            ModLog("allied!")

                            ModLog("triggering the dilemma")
                            local first_cqi = current_player:command_queue_index()
                            local second_cqi = owning_faction:command_queue_index()
                            local region_cqi = region_obj:cqi()
    
                            cm:trigger_dilemma_with_targets(first_cqi, "faithful_allies_return_region", first_cqi, second_cqi, 0, 0, region_cqi, 0)
    
                            ModLog("triggered dilemma")
    
                            return_details["region_key"] = region_key
                            return_details["original_owner"] = current_player_key
                            return_details["new_owner"] = owning_faction:name()
                        end
                    end
                end
            end
		end,
		true
    );

    -- listener for the dilemma propa
    core:add_listener(
        "faithful_allies_dilemma",
        "DilemmaChoiceMadeEvent",
        function(context)
            ModLog("dilemma choice made event trigger'd")
            return context:dilemma() == "faithful_allies_return_region"
        end,
        function(context)
            ModLog("dilemma choice made'd")

            local choice = context:choice()

            local region_key = return_details.region_key
            local og_owner_key = return_details.original_owner
            local new_owner_key = return_details.new_owner

            if choice == 0 then
                ModLog("returning ["..region_key.."] to player ["..og_owner_key.."]")
                -- og owner wants it back!
                local region = cm:get_region(region_key)
                local settlement = region:settlement()

                local logical_position_x = settlement:logical_position_x();
                local logical_position_y = settlement:logical_position_y();

                cm:transfer_region_to_faction(region_key, og_owner_key);
                cm:show_message_event_located(og_owner_key, "event_feed_strings_text_alliesreturn_title", "faithful_allies", "event_feed_strings_text_alliesreturn_secondary_detail", logical_position_x, logical_position_y, false, 1311);
                ModLog("done")
            else
                -- ally can keep it; do nothing(?)
            end

            -- remove the region from the player region list!
            player_owned_regions[og_owner_key][region_key] = nil

            return_details = {}
        end,
        true
    )
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
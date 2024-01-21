local quests = {
    {Name="Collect Stone", Target="default:stone", Quant=30, Desc="Dig in the mine 30 stone blocks.", Rewards={ "default:steel_ingot 5", "default:steel_ingot 3" }, Dif="1", Event="on_dignode"},
    {Name="Build a Castle", Target="default:stonebrick", Quant=10, Desc="Place 10 stonebrick.", Rewards={ "default:sword_steel 3", "default:steel_ingot 3" }, Dif="1", Event="on_placenode"},
    {Name="Craft Wood", Target="default:wood", Quant=30, Desc="Craft 30 wood planks.", Rewards={ "default:steel_ingot 3", "default:steel_ingot 3" }, Dif="1", Event="on_craft"},
    {Name="Join 1 time", Target="", Quant=1, Desc="Join one time", Rewards={ "default:steel_ingot 3", "default:steel_ingot 3" }, Dif="1", Event="on_joinplayer"},
    {Name="Send 1 message", Target="", Quant=1, Desc="Send one message", Rewards={ "default:steel_ingot 3", "default:steel_ingot 3" }, Dif="1", Event="on_chat_message"},
    {Name="Donate 15 diamond", Target="default:diamond", Quant=15, Desc="Donate 15 Diamond", Rewards={ "default:mese_crystal 10" }, Dif="2", Event="on_donate"},
}

local function assign_random_quest(player)
    local player_meta = player:get_meta()
    local has_quest = player_meta:get_int("has_quest")

    if has_quest == 0 then
        local last_assigned_quest = player_meta:get_string("last_assigned_quest")
        local random_quest

        repeat
            random_quest = quests[math.random(#quests)]
        until random_quest.Name ~= last_assigned_quest

        player_meta:set_string("last_assigned_quest", random_quest.Name)

        player_meta:set_string("quest_name", random_quest.Name)
        player_meta:set_string("quest_target", random_quest.Target)
        player_meta:set_int("quest_Quant", random_quest.Quant)
        player_meta:set_string("quest_Desc", random_quest.Desc)
        player_meta:set_string("quest_rewards", table.concat(random_quest.Rewards, ","))
        player_meta:set_int("quest_Dif", tonumber(random_quest.Dif))
        player_meta:set_string("quest_event_type", random_quest.Event)

        player_meta:set_int("has_quest", 1)
    end
end

local ranking_file_path = minetest.get_worldpath() .. "/ranking.txt"

local function update_ranking(player_name)
    local ranking_file = io.open(ranking_file_path, "a+")
    if not ranking_file then
        ranking_file = io.open(ranking_file_path, "w")
        ranking_file:close()
        ranking_file = io.open(ranking_file_path, "a+")
    end

    local content = ranking_file:read("*a")
    ranking_file:close()

    local ranking_data = minetest.deserialize(content) or {}

    if not ranking_data[player_name] then
        ranking_data[player_name] = 0
    end

    ranking_data[player_name] = ranking_data[player_name] + 1
    ranking_file = io.open(ranking_file_path, "w")
    if ranking_file then
        ranking_file:write(minetest.serialize(ranking_data))
        ranking_file:close()
    end
end


local function update_quest_progress(player, node_name, event_type, crafted_item)
    local player_meta = player:get_meta()
    local quest_target = player_meta:get_string("quest_target")
    local quest_Quant = player_meta:get_int("quest_Quant")
    local quest_event_type = player_meta:get_string("quest_event_type")

    if (event_type == quest_event_type and node_name == quest_target) or
            (event_type == "on_craft" and crafted_item == quest_target) or
            (event_type == "on_chat_message" and quest_event_type == "on_chat_message") or
            (event_type == "on_joinplayer" and quest_event_type == "on_joinplayer") then
        local current_progress = player_meta:get_int("quest_progress")
        current_progress = current_progress + 1
        player_meta:set_int("quest_progress", current_progress)

        if current_progress >= quest_Quant then
            minetest.chat_send_player(player:get_player_name(), "Quest Completed: " .. player_meta:get_string("quest_name"))

            local rewards = player_meta:get_string("quest_rewards")
            local reward_items = string.split(rewards, ",")
            for _, reward in ipairs(reward_items) do
                local reward_item, reward_count = string.match(reward, "(%S+)%s*(%d*)")
                reward_count = tonumber(reward_count) or 1
                player:get_inventory():add_item("main", ItemStack({name = reward_item, count = reward_count}))
            end

            player_meta:set_int("has_quest", 0)
            player_meta:set_int("quest_progress", 0)

            assign_random_quest(player)
            update_ranking(player:get_player_name())
        else
            --minetest.chat_send_player(player:get_player_name(), "Quest Progress: " .. current_progress .. "/" .. quest_Quant)
        end
    end
end

minetest.register_chatcommand("quest", {
    Desc = "View your active quest",
    privs = { interact = true },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)

        if not player or not player:is_player() then
            return
        end

        local player_meta = player:get_meta()
        local has_quest = player_meta:get_int("has_quest")

        local quest_name, quest_target, quest_Quant, quest_Desc, quest_progress, quest_event_type =
            player_meta:get_string("quest_name"),
            player_meta:get_string("quest_target"),
            player_meta:get_int("quest_Quant"),
            player_meta:get_string("quest_Desc"),
            player_meta:get_int("quest_progress"),
            player_meta:get_string("quest_event_type")

        local formspec = "size[8,9]" ..
            "label[0,0;" .. minetest.colorize("#FFA500", "--------Quest Information--------") .. "]"

        for i = 0, 7 do
            formspec = formspec .. "image[" .. i .. ",5.2;1,1;gui_hb_bg.png]"
        end

        formspec = formspec ..
            'item_image_button[4.0,0;1,1;' .. quest_target .. ';target_button;]' ..
            "label[0,0.5;" .. "Name: " .. quest_name .. "]" ..
            "label[0,1;" .. "Target: " .. quest_target .. "]" ..
            "label[0,1.5;" .. "Quantity: " .. quest_Quant .. "]" ..
            "label[0,2;" .. "Description: " .. quest_Desc .. "]" ..
            "label[0,2.5;" .. "EventType: " .. quest_event_type .. "]" ..
            "label[0,3;" .. "Progress: " .. quest_progress .. "/" .. quest_Quant .. "]"

        local reward_x = 0
        for _, reward in ipairs(quests[has_quest].Rewards) do
            local item, count = reward:match("([^%s]+)%s*(%d*)")
            count = tonumber(count) or 1
            formspec = formspec .. "item_image_button[" .. reward_x .. "," .. 4.1 .. ";1,1;" .. item .. ";reward_button;" .. count .. "]"
            reward_x = reward_x + 1
        end

        formspec = formspec ..
            "list[current_player;main;0,5.2;8,1;]" ..
            "list[current_player;main;0,6.35;8,3;8]" ..
            "button[5.25,2;2.5,3;give_for_quest;" .. "Give For Quest" .. "]" ..
            "list[current_player;give_for_quest;5,0;3,3;]" ..
            "listring[current_player;main]" ..
            "listring[current_player;give_for_quest]" ..
            "image[7.08,4.2;0.8,0.8;creative_trash_icon.png]" ..
            "list[detached:trash_" .. name .. ";main;7.02,4.1;1,1;]"

        minetest.show_formspec(name, "quest_interface", formspec)
    end,
})

if minetest.get_modpath("sfinv") then
    sfinv.register_page("sfinv:daily_quest", {
        title = "Quest",
        get = function(self, player, context)
            local player_name = player:get_player_name()
            local player_meta = minetest.get_player_by_name(player_name):get_meta()
            local has_quest = player_meta:get_int("has_quest")

                local quest_name, quest_target, quest_Quant, quest_Desc, quest_progress, quest_event_type =
                    player_meta:get_string("quest_name"),
                    player_meta:get_string("quest_target"),
                    player_meta:get_int("quest_Quant"),
                    player_meta:get_string("quest_Desc"),
                    player_meta:get_int("quest_progress"),
                    player_meta:get_string("quest_event_type")

                local formspec = "size[8,9]" ..
                    "label[0,0;" .. minetest.colorize("#FFA500","--------Quest Information--------") .. "]"

                for i = 0, 7 do
                    formspec = formspec .. "image[" .. i .. ",5.2;1,1;gui_hb_bg.png]"
                end

                formspec = formspec ..
                    'item_image_button[4.0,0;1,1;' .. quest_target .. ';target_button;]' ..
                    "label[0,0.5;" .. "Name: " .. quest_name .. "]" ..
                    "label[0,1;" .. "Target: " .. quest_target .. "]" ..
                    "label[0,1.5;" .. "Quantity: " .. quest_Quant .. "]" ..
                    "label[0,2;" .. "Description: " .. quest_Desc .. "]" ..
                    "label[0,2.5;" .. "EventType: " .. quest_event_type .. "]" ..
                    "label[0,3;" .. "Progress: " .. quest_progress .. "/" .. quest_Quant .. "]"

                local reward_x = 0
                for _, reward in ipairs(quests[has_quest].Rewards) do
                    local item, count = reward:match("([^%s]+)%s*(%d*)")
                    count = tonumber(count) or 1
                    formspec = formspec .. "item_image_button[" .. reward_x .. "," .. 4.1 .. ";1,1;" .. item .. ";reward_button;" .. count .. "]"
                    reward_x = reward_x + 1
                end

                formspec = formspec ..
                    "list[current_player;main;0,5.2;8,1;]" ..
                    "list[current_player;main;0,6.35;8,3;8]" ..
                    "button[5.25,2;2.5,3;give_for_quest;" .. "Give For Quest" .. "]" ..
                    "list[current_player;give_for_quest;5,0;3,3;]" ..
                    "listring[current_player;main]" ..
                    "listring[current_player;give_for_quest]" ..
                    "image[7.08,4.2;0.8,0.8;creative_trash_icon.png]" ..
                    "list[detached:trash_" .. player_name .. ";main;7.02,4.1;1,1;]"

                return sfinv.make_formspec(player_name, context, formspec)
        end,
    })
end

if minetest.get_modpath("unified_inventory") then
    local ui = unified_inventory
    if ui.sfinv_compat_layer then
        return
    end

    local function create_quest_formspec(player, perplayer_formspec)
        local name = player:get_player_name()
        local player_name = player:get_player_name()
        local player_meta = minetest.get_player_by_name(player_name):get_meta()
        local quest_name = player_meta:get_string("quest_name")
        local quest_target = player_meta:get_string("quest_target")
        local quest_Quant = player_meta:get_int("quest_Quant")
        local quest_Desc = player_meta:get_string("quest_Desc")
        local quest_progress = player_meta:get_int("quest_progress")
        local quest_event_type = player_meta:get_string("quest_event_type")
        local has_quest = player_meta:get_int("has_quest")


        local formspec = perplayer_formspec.standard_inv_bg ..
            perplayer_formspec.standard_inv ..
            "label[0.5,0.5;" .. minetest.colorize("#FFA500", "--------Quest Information--------") .. "]"

        if quest_target then
            formspec = formspec .. 'item_image_button[5,0.25;1,1;' .. quest_target .. ';target_button;]'
        end

        formspec = formspec ..
            "label[0.5,1;" .. "Name: " .. quest_name .. "]" ..
            "label[0.5,1.5;" .. "Target: " .. (quest_target or "") .. "]" ..
            "label[0.5,2;" .. "Quantity: " .. quest_Quant .. "]" ..
            "label[0.5,2.5;" .. "Description: " .. quest_Desc .. "]" ..
            "label[0.5,3;" .. "EventType: " .. quest_event_type .. "]" ..
            "label[0.5,3.5;" .. "Progress: " .. quest_progress .. "/" .. quest_Quant .. "]"

        local reward_x = 0.5
        if quests and quests[has_quest] and quests[has_quest].Rewards then
            for _, reward in ipairs(quests[has_quest].Rewards) do
                local item, count = reward:match("([^%s]+)%s*(%d*)")
                count = tonumber(count) or 1
                formspec = formspec .. "item_image_button[" .. reward_x .. "," .. 4.1 .. ";1,1;" .. item .. ";reward_button;" .. count .. "]"
                reward_x = reward_x + 1.25
            end
        end

        formspec = formspec ..
        ui.make_inv_img_grid(6.45, 0.25, 3, 3) ..
            "button[7,4.5;2.5,1;give_for_quest;" .. "Give For Quest" .. "]" ..
            "list[current_player;give_for_quest;6.6,0.375;3,3;]"

        return { formspec = formspec }
    end

    ui.register_button("daily_quest", {
        type = "image",
        image = "daily_quest_icon.png",
        tooltip = "Daily Quest",
    })

    ui.register_page("daily_quest", {
        get_formspec = create_quest_formspec,
    })
end

minetest.register_on_dignode(function(pos, oldnode, digger)
    if digger and digger:is_player() then
        update_quest_progress(digger, oldnode.name, "on_dignode")
        if minetest.get_modpath("unified_inventory") then
            unified_inventory.set_inventory_formspec(digger, "daily_quest")
        elseif minetest.get_modpath("sfinv") then
            sfinv.set_page(digger, "sfinv:daily_quest")
        end
    end
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if placer and placer:is_player() then
        update_quest_progress(placer, newnode.name, "on_placenode")
        if minetest.get_modpath("unified_inventory") then
            unified_inventory.set_inventory_formspec(placer, "daily_quest")
        elseif minetest.get_modpath("sfinv") then
            sfinv.set_page(placer, "sfinv:daily_quest")
        end
    end
end)

minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
    local crafted_item = itemstack:get_name()
    local crafted_count = itemstack:get_count()

    if player and player:is_player() then
        for i = 1, crafted_count do
            update_quest_progress(player, nil, "on_craft", crafted_item)
        end
    end
end)

minetest.register_on_chat_message(function(name, message)
    local player = minetest.get_player_by_name(name)

    if player and player:is_player() then
        update_quest_progress(player, nil, "on_chat_message", message)
    end
end)

minetest.register_on_joinplayer(function(player)
    assign_random_quest(player)
    update_quest_progress(player, nil, "on_joinplayer")

    local player_name = player:get_player_name()
    local player_obj = minetest.get_player_by_name(player_name)

    if player_obj then
        player_obj:get_inventory():set_size("give_for_quest", 9)

        local trash = minetest.create_detached_inventory("trash_" .. player_name, {
            allow_put = function(inv, listname, index, stack, player)
                return stack:get_count()
            end,
            on_put = function(inv) inv:set_list("main", {}) end,
        })
        trash:set_size("main", 1)
    end
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "" and fields.give_for_quest then
        local player_name = player:get_player_name()
        local player_meta = player:get_meta()
        local has_quest = player_meta:get_int("has_quest")

        if has_quest == 1 then
            local quest_event_type = player_meta:get_string("quest_event_type")

            if quest_event_type == "on_donate" then
                local quest_target = player_meta:get_string("quest_target")
                local quest_Quant = player_meta:get_int("quest_Quant")
                local quest_progress = player_meta:get_int("quest_progress")

                local player_inventory = player:get_inventory()

                local give_for_quest_inventory = player_inventory:get_list("give_for_quest")

                local total_donated = 0
                for _, item_stack in ipairs(give_for_quest_inventory) do
                    local item_name = item_stack:get_name()

                    if item_name == quest_target then
                        local item_count = item_stack:get_count()

                        local quantity_to_remove = math.min(item_count, quest_Quant - quest_progress)

                        if quantity_to_remove > 0 then
                            total_donated = total_donated + quantity_to_remove

                            player_inventory:remove_item("give_for_quest", ItemStack({name = quest_target, count = quantity_to_remove}))
                        end
                    end
                end

                local new_progress = quest_progress + total_donated
                player_meta:set_int("quest_progress", new_progress)

                if minetest.get_modpath("unified_inventory") then
                    unified_inventory.set_inventory_formspec(player, "daily_quest")
                elseif minetest.get_modpath("sfinv") then
                    sfinv.set_page(player, "sfinv:daily_quest")
                end

                if new_progress >= quest_Quant then
                    minetest.chat_send_player(player_name, "Quest Completed: " .. player_meta:get_string("quest_name"))

                    local rewards = player_meta:get_string("quest_rewards")
                    local reward_items = string.split(rewards, ",")
                    for _, reward in ipairs(reward_items) do
                        local reward_item, reward_count = string.match(reward, "(%S+)%s*(%d*)")
                        reward_count = tonumber(reward_count) or 1
                        player_inventory:add_item("main", ItemStack({name = reward_item, count = reward_count}))
                    end

                    player_meta:set_int("has_quest", 0)
                    player_meta:set_int("quest_progress", 0)

                    assign_random_quest(player)
                end
            end
        else
            minetest.chat_send_player(player_name, "You don't have an active quest.")
        end
    end
end)

minetest.register_chatcommand("ranking", {
    params = "",
    description = "Shows the ranking of players with the most completed quests.",
    func = function(name, param)
        local ranking_file = io.open(ranking_file_path, "r")
        if ranking_file then
            local content = ranking_file:read("*a")
            ranking_file:close()

            local ranking_data = minetest.deserialize(content) or {}

            local sorted_ranking = {}
            for player_name, quest_count in pairs(ranking_data) do
                table.insert(sorted_ranking, {name = player_name, quests_completed = quest_count})
            end

            table.sort(sorted_ranking, function(a, b)
                return a.quests_completed > b.quests_completed
            end)

            local formspec = "size[6.25,8]bgcolor[#00000000;true]background[0,0;6.25,8;gui_formbg.png;true]"

            formspec = formspec .. "label[1,0;" .. minetest.colorize("#FFA500", "--------Player Ranking--------") .. "]"

            local num_players_to_display = #sorted_ranking

            for i = 1, num_players_to_display do
                local player_info = sorted_ranking[i]
                local rank_label = i .. "          " .. player_info.name
                local quest_label = "                        " .. player_info.quests_completed .. " quêtes"

                if i <= 5 then
                    formspec = formspec .. "label[0.5," .. i .. ";" .. rank_label .. "]"
                    formspec = formspec .. "label[2.5," .. i .. ";" .. quest_label .. "]"
                end
            end

            local player_rank = nil
            for i, player_info in ipairs(sorted_ranking) do
                if player_info.name == name then
                    player_rank = i
                    break
                end
            end

            formspec = formspec .. "label[0,7;You have accomplished " .. (ranking_data[name] or 0) .. " quests. \nYour ranking : " .. (player_rank and player_rank or "Unclassified") .. "]"

            minetest.show_formspec(name, "ranking_interface", formspec)
        else
            minetest.chat_send_player(name, "Failed to read rating file.")
        end
    end,
})


if minetest.get_modpath("sfinv") then
    sfinv.register_page("sfinv:ranking", {
        title = "Ranking",
        get = function(self, player, context)
            local player_name = player:get_player_name()
            local ranking_file = io.open(minetest.get_worldpath() .. "/ranking.txt", "r")

            if ranking_file then
                local content = ranking_file:read("*a")
                ranking_file:close()

                local ranking_data = minetest.deserialize(content) or {}

                local sorted_ranking = {}
                for player_name, quest_count in pairs(ranking_data) do
                    table.insert(sorted_ranking, {name = player_name, quests_completed = quest_count})
                end

                table.sort(sorted_ranking, function(a, b)
                    return a.quests_completed > b.quests_completed
                end)

                local formspec = "size[8,9]bgcolor[#00000000;true]background[0,0;8,9;gui_formbg.png;true]" ..
                    "label[0,0;" .. minetest.colorize("#FFA500", "--------Player Ranking--------") .. "]"

                local num_players_to_display = #sorted_ranking

                for i = 1, num_players_to_display do
                    local player_info = sorted_ranking[i]
                    local rank_label = i .. "          " .. player_info.name
                    local quest_label = "                        " .. player_info.quests_completed .. " quests"

                    if i <= 5 then
                        formspec = formspec .. "label[0.5," .. i .. ";" .. rank_label .. "]"
                        formspec = formspec .. "label[2.5," .. i .. ";" .. quest_label .. "]"
                    end
                end

                local player_rank = nil
                for i, player_info in ipairs(sorted_ranking) do
                    if player_info.name == player_name then
                        player_rank = i
                        break
                    end
                end

                formspec = formspec .. "label[0,7;You have completed " .. (ranking_data[player_name] or 0) .. " quests. \nYour ranking: " .. (player_rank and player_rank or "Not ranked") .. "]"

                return sfinv.make_formspec(player_name, context, formspec)
            else
                minetest.chat_send_player(player_name, "Unable to read the ranking file.")
            end
        end,
    })
end

if minetest.get_modpath("unified_inventory") then
    local ui = unified_inventory
    if ui.sfinv_compat_layer then
        return
    end

    local function create_ranking_formspec(player, perplayer_formspec)
        local name = player:get_player_name()
        local ranking_file = io.open(minetest.get_worldpath() .. "/ranking.txt", "r")

        if ranking_file then
            local content = ranking_file:read("*a")
            ranking_file:close()

            local ranking_data = minetest.deserialize(content) or {}

            local sorted_ranking = {}
            for player_name, quest_count in pairs(ranking_data) do
                table.insert(sorted_ranking, {name = player_name, quests_completed = quest_count})
            end

            table.sort(sorted_ranking, function(a, b)
                return a.quests_completed > b.quests_completed
            end)

            local formspec = perplayer_formspec.standard_inv_bg ..
                perplayer_formspec.standard_inv ..
                "label[0.5,0.5;" .. minetest.colorize("#FFA500", "--------Player Ranking--------") .. "]"

            local num_players_to_display = #sorted_ranking

            for i = 1, num_players_to_display do
                local player_info = sorted_ranking[i]
                local rank_label = i .. "     " .. player_info.name
                local quest_label = "                        " .. player_info.quests_completed .. " quests"

                if i <= 5 then
                    formspec = formspec .. "label[0.5," .. i .. ";" .. rank_label .. "]"
                    formspec = formspec .. "label[1.5," .. i .. ";" .. quest_label .. "]"
                end
            end

            local player_rank = nil
            for i, player_info in ipairs(sorted_ranking) do
                if player_info.name == name then
                    player_rank = i
                    break
                end
            end

            formspec = formspec .. "label[6,2;You have completed " .. (ranking_data[name] or 0) .. " quests. \nYour ranking: " .. (player_rank and player_rank or "Not ranked") .. "]"

            return { formspec = formspec }
        else
            minetest.chat_send_player(name, "Unable to read the ranking file.")
            return nil
        end
    end

    ui.register_page("ranking", {
        get_formspec = create_ranking_formspec,
    })

    ui.register_button("ranking", {
        type = "image",
        image = "ranking_icon.png",
        tooltip = "Player Ranking",
        action = function(player)
            ui.set_inventory_formspec(player, "ranking")
        end,
    })
end


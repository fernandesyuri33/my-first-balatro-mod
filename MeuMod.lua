-- MyMod.lua
-- Adds "The Negativator" joker

SMODS.Atlas {
    -- Key for code to find it with
    key = "TheNegativatorAtlas",
    -- The name of the file, for the code to pull the atlas from
    path = "negativator.png",
    -- Width of each sprite in 1x size
    px = 1024,
    -- Height of each sprite in 1x size
    py = 1536
}


SMODS.Joker {
    key = 'negativator',
    loc_txt = {
        name = 'O Negativador',
        text = {
            "Quando um {C:attention}Blind Chefe{} é derrotado:",
            "{C:red}Destrói{} até {C:attention}3{} Curingas a sua {C:attention}esquerda{},",
            "para transformar o Curinga a sua {C:attention}direita{} em {C:dark_edition}Negative{}"
        }
    },
    config = { extra = { used = false, consume_weights = { [1] = 0.60, [2] = 0.30, [3] = 0.10 } } },
    rarity = 3,
    atlas = 'TheNegativatorAtlas', -- vanilla atlas for now
    pos = { x = 0, y = 0 },        -- vanilla sprite slot
    cost = 10,
    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.e_negative
    end,

    calculate = function(self, card, context)
        if card.ability.extra.used then return end
        if context.end_of_round and not context.repetition and context.game_over == false then
            local blind = G and G.GAME and G.GAME.blind
            if blind and blind.boss then
                card.ability.extra.used = true

                G.E_MANAGER:add_event(Event({
                    func = function()
                        local idx
                        for i, c in ipairs(G.jokers.cards) do
                            if c == card then
                                idx = i; break
                            end
                        end
                        if not idx then return true end

                        -- collect up to 3 to the left (you already have this above)
                        local victims = {}
                        local i_left = idx - 1
                        while i_left >= 1 and #victims < 3 do
                            local v = G.jokers.cards[i_left]
                            if v and not v.ability.eternal then victims[#victims + 1] = v end
                            i_left = i_left - 1
                        end

                        -- choose 1..3 using weighted probabilities
                        local function weighted_pick(weights)
                            local w1, w2, w3 = weights[1] or 0.6, weights[2] or 0.3, weights[3] or 0.1
                            local total = w1 + w2 + w3
                            -- use pseudorandom so it’s seed-respecting
                            local r = pseudorandom('negativator_consume') * total
                            if r < w1 then return 1 elseif r < (w1 + w2) then return 2 else return 3 end
                        end

                        local desired = weighted_pick(card.ability.extra.consume_weights or {})
                        local to_consume = math.min(desired, #victims)

                        -- (optional) status ping showing how many we’ll eat
                        if to_consume > 0 then
                            card_eval_status_text(card, 'extra', nil, nil, nil,
                                { message = ('Consome %d'):format(to_consume) })
                        end

                        -- destroy exactly 'to_consume' left jokers
                        for i = 1, to_consume do
                            local v = victims[i]
                            G.E_MANAGER:add_event(Event({
                                func = function()
                                    play_sound('tarot1')
                                    v.T.r = -0.2; v:juice_up(0.3, 0.4)
                                    v.states.drag.is = true
                                    v.children.center.pinch.x = true
                                    G.E_MANAGER:add_event(Event({
                                        trigger = 'after',
                                        delay = 0.3,
                                        blockable = false,
                                        func = function()
                                            if v.area == G.jokers then G.jokers:remove_card(v) end
                                            v:remove()
                                            return true
                                        end
                                    }))
                                    card_eval_status_text(card, 'extra', nil, nil, nil, { message = 'Consumido!' })
                                    return true
                                end
                            }))
                        end

                        G.E_MANAGER:add_event(Event({
                            trigger = 'after',
                            delay = 0.35,
                            func = function()
                                local my_idx
                                for i, c in ipairs(G.jokers.cards) do
                                    if c == card then
                                        my_idx = i; break
                                    end
                                end
                                if not my_idx then return true end
                                local right = G.jokers.cards[my_idx + 1]

                                if right and right ~= card then
                                    if not right.edition or right.edition.key ~= 'e_negative' then
                                        right:set_edition('e_negative', true)
                                        right:juice_up(0.6, 0.6)
                                        card_eval_status_text(right, 'extra', nil, nil, nil, { message = 'Negativado!' })
                                    else
                                        card_eval_status_text(card, 'extra', nil, nil, nil,
                                            { message = 'Já Negativo' })
                                    end
                                else
                                    card_eval_status_text(card, 'extra', nil, nil, nil, { message = 'Nenhum Curinga à direita' })
                                end
                                return true
                            end
                        }))

                        G.E_MANAGER:add_event(Event({
                            trigger = 'after',
                            delay = 0.1,
                            func = function()
                                -- mark as permanently spent and show the red X
                                card.ability.extra.used = true
                                card:set_debuff(true) -- <<< draws the X + disables calculate hooks
                                card:juice_up(0.4, 0.6)
                                card_eval_status_text(card, 'extra', nil, nil, nil, { message = 'Gasto' })
                                return true
                            end
                        }))

                        return true
                    end
                }))
            end
        end
    end,

    add_to_deck = function(self, card, from_debuff)
        if card.ability.extra.used then
            -- Small defer so it applies after any internal toggles
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0,
                func = function()
                    card:set_debuff(true)
                    return true
                end
            }))
        end
    end

}

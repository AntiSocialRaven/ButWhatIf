-- Data
local EDITIONS    = {{key="none",label="None"},{key="e_foil",label="Foil"},{key="e_holo",label="Holo"},{key="e_polychrome",label="Poly"},{key="e_negative",label="Neg"}}
local ENHANCEMENTS= {{key="none",label="None"},{key="m_bonus",label="Bonus"},{key="m_mult",label="Mult"},{key="m_wild",label="Wild"},{key="m_glass",label="Glass"},{key="m_steel",label="Steel"},{key="m_stone",label="Stone"},{key="m_gold",label="Gold"},{key="m_lucky",label="Lucky"}}
local SEALS       = {{key="none",label="None"},{key="Gold",label="Gold"},{key="Red",label="Red"},{key="Blue",label="Blue"},{key="Purple",label="Purple"}}
local RANKS       = {"2","3","4","5","6","7","8","9","10","Jack","Queen","King","Ace"}
local SUITS       = {"Spades","Hearts","Clubs","Diamonds"}

-- State
local SBX_ADD_CARD  = {rank="Ace",suit="Spades",area="hand"}
local SBX_ADD_CTYPE = "Joker"
local SBX_ADD_CKEY  = nil
local SBX_CENTER_PAGE = 1
local SBX_SEARCH    = {text=""}
local SBX_IN_CENTER_PICKER = false

-- Apply helpers
local function apply_edition(card,key)    card:set_edition(key~="none" and key or nil,true,true) end
local function apply_enhancement(card,key) local c=(key=="none") and G.P_CENTERS.c_base or G.P_CENTERS[key]; if c then card:set_ability(c) end end
local function apply_seal(card,key)       card:set_seal(key~="none" and key or nil,true,true) end

-- Spawn helpers
local function spawn_center(key,area)
    local center=G.P_CENTERS[key]; if not center then return end
    local nc=Card(area.T.x+area.T.w/2,area.T.y,G.CARD_W,G.CARD_H,nil,center)
    nc:add_to_deck(); area:emplace(nc); return nc
end
local function spawn_playing_card(rank,suit,area)
    local ck; for k,v in pairs(G.P_CARDS) do if v.suit==suit and v.value==rank then ck=k;break end end
    if not ck then return end
    local nc=Card(area.T.x+area.T.w/2,area.T.y,G.CARD_W,G.CARD_H,G.P_CARDS[ck],G.P_CENTERS.c_base)
    nc:add_to_deck(); area:emplace(nc)
end

-- UI helpers
local function btn(label,func,ref,scale,bg)
    return {n=G.UIT.C,config={align="cm",padding=0.07,r=0.05,colour=bg or G.C.GREY,button=func,ref_table=ref,hover=true,shadow=true},
        nodes={{n=G.UIT.T,config={text=label,scale=scale or 0.33,colour=G.C.UI.TEXT_LIGHT}}}}
end
local function bcell(label,func,ref,scale,bg)
    return {n=G.UIT.C,config={align="cm",padding=0.04},nodes={btn(label,func,ref,scale,bg)}}
end
local function trow(text,scale,col)
    return {n=G.UIT.R,config={align="cm",padding=0.04},nodes={{n=G.UIT.T,config={text=text,scale=scale or 0.33,colour=col or G.C.UI.TEXT_LIGHT}}}}
end

-- Overlay helpers
local function open_overlay(def)
    G.SETTINGS.paused=true
    G.FUNCS.overlay_menu{definition=def}
end
local function close_overlay()
    if G.OVERLAY_MENU then G.OVERLAY_MENU:remove() end
    G.OVERLAY_MENU = nil
    G.SETTINGS.paused = false
end
G.FUNCS.sbx_close=function() close_overlay() end

-- Card editor
local function card_editor_def(card)
    local cur_ed=(card.edition and card.edition.key) or "none"
    local cur_enh="none"
    if card.config and card.config.center then local ck=card.config.center.key or "c_base"; if ck~="c_base" then cur_enh=ck end end
    local cur_seal=card.seal or "none"
    local bonus=card.sbx_bonus_chips or 0
    local ed_row={}
    for _,ed in ipairs(EDITIONS) do local a=ed.key==cur_ed; ed_row[#ed_row+1]=bcell(a and("["..ed.label.."]")or ed.label,"sbx_set_edition",{card=card,key=ed.key},0.27,a and G.C.GREEN or G.C.GREY) end
    local enh1,enh2={},{}
    for i,en in ipairs(ENHANCEMENTS) do local a=en.key==cur_enh; local c=bcell(a and("["..en.label.."]")or en.label,"sbx_set_enhancement",{card=card,key=en.key},0.26,a and G.C.GREEN or G.C.GREY); if i<=5 then enh1[#enh1+1]=c else enh2[#enh2+1]=c end end
    local seal_row={}
    for _,sl in ipairs(SEALS) do local a=sl.key==cur_seal; seal_row[#seal_row+1]=bcell(a and("["..sl.label.."]")or sl.label,"sbx_set_seal",{card=card,key=sl.key},0.27,a and G.C.GREEN or G.C.GREY) end
    return create_UIBox_generic_options({back_func="sbx_close",contents={
        trow("Card Editor",0.42,G.C.WHITE),
        trow("Edition",0.28,G.C.YELLOW),{n=G.UIT.R,config={align="cm",padding=0.03},nodes=ed_row},
        trow("Enhancement",0.28,G.C.YELLOW),{n=G.UIT.R,config={align="cm",padding=0.03},nodes=enh1},{n=G.UIT.R,config={align="cm",padding=0.03},nodes=enh2},
        trow("Seal",0.28,G.C.YELLOW),{n=G.UIT.R,config={align="cm",padding=0.03},nodes=seal_row},
        {n=G.UIT.R,config={align="cm",padding=0.05},nodes={
            {n=G.UIT.T,config={text="Chip Bonus: ",scale=0.28,colour=G.C.YELLOW}},
            bcell("-10","sbx_chip_adj",{card=card,d=-10},0.27,G.C.RED),bcell("-1","sbx_chip_adj",{card=card,d=-1},0.27,G.C.RED),
            {n=G.UIT.C,config={align="cm",padding=0.05},nodes={{n=G.UIT.T,config={text=tostring(bonus),scale=0.36,colour=G.C.WHITE}}}},
            bcell("+1","sbx_chip_adj",{card=card,d=1},0.27,G.C.GREEN),bcell("+10","sbx_chip_adj",{card=card,d=10},0.27,G.C.GREEN),
        }},
        {n=G.UIT.R,config={align="cm",padding=0.05},nodes={
            bcell("Duplicate","sbx_duplicate_card",{card=card},0.3,G.C.BLUE),
            bcell("Remove","sbx_remove_card",{card=card},0.3,G.C.RED),
        }},
    }})
end
local function open_card_editor(card) open_overlay(card_editor_def(card)) end

-- Joker / consumable editor
local function joker_editor_def(card)
    local cur_ed=(card.edition and card.edition.key) or "none"
    local ed_row={}
    for _,ed in ipairs(EDITIONS) do local a=ed.key==cur_ed; ed_row[#ed_row+1]=bcell(a and("["..ed.label.."]")or ed.label,"sbx_joker_set_edition",{card=card,key=ed.key},0.27,a and G.C.GREEN or G.C.GREY) end
    local bonus=card.sbx_bonus_chips or 0
    local xmult=card.sbx_xmult or 0
    local name=(card.config and card.config.center and card.config.center.name) or "?"
    return create_UIBox_generic_options({back_func="sbx_close",contents={
        trow("Joker / Consumable Editor",0.38,G.C.WHITE),
        trow(name,0.3,G.C.YELLOW),
        trow("Edition",0.28,G.C.YELLOW),{n=G.UIT.R,config={align="cm",padding=0.03},nodes=ed_row},
        {n=G.UIT.R,config={align="cm",padding=0.05},nodes={
            {n=G.UIT.T,config={text="+Chips: ",scale=0.28,colour=G.C.YELLOW}},
            bcell("-10","sbx_joker_chip_adj",{card=card,d=-10},0.27,G.C.RED),bcell("-1","sbx_joker_chip_adj",{card=card,d=-1},0.27,G.C.RED),
            {n=G.UIT.C,config={align="cm",padding=0.05},nodes={{n=G.UIT.T,config={text=tostring(bonus),scale=0.34,colour=G.C.WHITE}}}},
            bcell("+1","sbx_joker_chip_adj",{card=card,d=1},0.27,G.C.GREEN),bcell("+10","sbx_joker_chip_adj",{card=card,d=10},0.27,G.C.GREEN),
        }},
        {n=G.UIT.R,config={align="cm",padding=0.05},nodes={
            {n=G.UIT.T,config={text="xMult bonus: ",scale=0.28,colour=G.C.YELLOW}},
            bcell("-1","sbx_joker_xmult_adj",{card=card,d=-1},0.27,G.C.RED),
            {n=G.UIT.C,config={align="cm",padding=0.05},nodes={{n=G.UIT.T,config={text=tostring(xmult),scale=0.34,colour=G.C.WHITE}}}},
            bcell("+1","sbx_joker_xmult_adj",{card=card,d=1},0.27,G.C.GREEN),
        }},
        {n=G.UIT.R,config={align="cm",padding=0.05},nodes={
            bcell("Duplicate","sbx_duplicate_card",{card=card},0.3,G.C.BLUE),
            bcell("Remove","sbx_remove_card",{card=card},0.3,G.C.RED),
        }},
    }})
end
local function open_joker_editor(card) open_overlay(joker_editor_def(card)) end

-- Add playing card
local function add_card_def()
    local s=SBX_ADD_CARD
    local rank_cells={}
    for _,r in ipairs(RANKS) do local a=r==s.rank; rank_cells[#rank_cells+1]=bcell(r,"sbx_pick_rank",{val=r},0.25,a and G.C.GREEN or G.C.GREY) end
    local suit_cells={}
    for _,su in ipairs(SUITS) do local a=su==s.suit; suit_cells[#suit_cells+1]=bcell(su,"sbx_pick_suit",{val=su},0.29,a and G.C.GREEN or G.C.GREY) end
    return create_UIBox_generic_options({back_func="sbx_close",contents={
        trow("Add Playing Card",0.42,G.C.WHITE),
        trow("Rank",0.28,G.C.YELLOW),{n=G.UIT.R,config={align="cm",padding=0.03},nodes=rank_cells},
        trow("Suit",0.28,G.C.YELLOW),{n=G.UIT.R,config={align="cm",padding=0.04},nodes=suit_cells},
        {n=G.UIT.R,config={align="cm",padding=0.05},nodes={
            {n=G.UIT.T,config={text="Add to: ",scale=0.28,colour=G.C.YELLOW}},
            bcell("Hand","sbx_area_hand",{},0.3,s.area=="hand" and G.C.GREEN or G.C.GREY),
            bcell("Deck","sbx_area_deck",{},0.3,s.area=="deck" and G.C.GREEN or G.C.GREY),
        }},
        {n=G.UIT.R,config={align="cm",padding=0.05},nodes={bcell("Add Card","sbx_confirm_add_card",{},0.32,G.C.GREEN)}},
    }})
end
local function open_add_card() SBX_ADD_CARD={rank="Ace",suit="Spades",area="hand"}; open_overlay(add_card_def()) end

-- Add card picker
local COLS = 5   -- cards per row
local ROWS = 4   -- rows per page
local CARDS_PER_PAGE = COLS * ROWS

local function center_list(ctype, search_text)
    local pool=G.P_CENTER_POOLS[ctype]; if not pool then return {} end
    local out={}
    local st=(search_text or ""):lower()
    for _,c in ipairs(pool) do
        if not c.hidden then
            local name=(c.name or c.key or ""):lower()
            local key=(c.key or ""):lower()
            if st=="" or name:find(st,1,true) or key:find(st,1,true) then
                out[#out+1]=c
            end
        end
    end
    table.sort(out,function(a,b) return (a.name or a.key)<(b.name or b.key) end)
    return out
end

local function card_img_node(center, w, h)
    local name = center.name or center.key or "?"
    if #name > 10 then name = name:sub(1,9).."~" end
    return {n=G.UIT.T,config={text=name,scale=0.22,colour=G.C.UI.TEXT_LIGHT}}
end

local function add_center_def()
    local ct=SBX_ADD_CTYPE
    local list=center_list(ct,SBX_SEARCH.text)
    local total_pages=math.max(1,math.ceil(#list/CARDS_PER_PAGE))
    SBX_CENTER_PAGE=math.min(SBX_CENTER_PAGE,total_pages)

    -- Type tabs
    local type_cells={}
    for _,t in ipairs({"Joker","Tarot","Planet","Spectral"}) do
        local a=t==ct
        type_cells[#type_cells+1]=bcell(t,"sbx_center_type",{val=t},0.3,a and G.C.GREEN or G.C.GREY)
    end

    -- Search row
    local search_display = SBX_SEARCH.text=="" and "(type to filter)" or ("\""..SBX_SEARCH.text.."\"")
    local search_row = {n=G.UIT.R,config={align="cm",padding=0.04},nodes={
        {n=G.UIT.T,config={text="Search: ",scale=0.28,colour=G.C.YELLOW}},
        {n=G.UIT.C,config={align="cm",padding=0.04},nodes={{
            n=G.UIT.T,config={text=search_display,scale=0.28,colour=G.C.UI.TEXT_LIGHT}
        }}},
        bcell("X","sbx_search_clear",{},0.28,SBX_SEARCH.text~="" and G.C.RED or G.C.GREY),
    }}

    -- Page slice
    local page_start=(SBX_CENTER_PAGE-1)*CARDS_PER_PAGE+1
    local page_end=math.min(page_start+CARDS_PER_PAGE-1,#list)
    local n_items=math.max(0,page_end-page_start+1)

    -- Card grid
    local grid_rows={}
    if n_items==0 then
        grid_rows[1]=trow("(no results)",0.28,G.C.UI.TEXT_LIGHT)
    else
        for row=1,ROWS do
            local row_nodes={}
            for col=1,COLS do
                local idx=page_start+(row-1)*COLS+(col-1)
                if idx<=page_end then
                    local center=list[idx]
                    local is_sel=(SBX_ADD_CKEY==center.key)
                    local name=center.name or center.key or "?"
                    if #name>9 then name=name:sub(1,8).."~" end
                    local border_col = is_sel and G.C.GREEN or {0.2,0.2,0.2,0.8}
                    row_nodes[#row_nodes+1]={
                        n=G.UIT.C,config={
                            align="cm",padding=0.06,r=0.05,
                            colour=border_col,
                            button="sbx_center_pick",
                            ref_table={key=center.key},
                            hover=true,shadow=true,
                            minw=1.1,minh=0.5,
                        },
                        nodes={{
                            n=G.UIT.T,config={text=name,scale=0.24,colour=is_sel and G.C.WHITE or G.C.UI.TEXT_LIGHT}
                        }}
                    }
                end
            end
            if #row_nodes>0 then
                grid_rows[#grid_rows+1]={n=G.UIT.R,config={align="cm",padding=0.04},nodes=row_nodes}
            end
        end
    end

    -- Pagination
    local page_label="Page "..SBX_CENTER_PAGE.." / "..total_pages
    local nav_cells={}
    if SBX_CENTER_PAGE>1 then nav_cells[#nav_cells+1]=bcell("< Prev","sbx_center_prev",{},0.3,G.C.GREY) end
    nav_cells[#nav_cells+1]={n=G.UIT.C,config={align="cm",padding=0.06},nodes={{
        n=G.UIT.T,config={text=page_label,scale=0.3,colour=G.C.UI.TEXT_LIGHT}
    }}}
    if SBX_CENTER_PAGE<total_pages then nav_cells[#nav_cells+1]=bcell("Next >","sbx_center_next",{},0.3,G.C.GREY) end

    local sel_name="None selected"
    if SBX_ADD_CKEY and G.P_CENTERS[SBX_ADD_CKEY] then
        sel_name=G.P_CENTERS[SBX_ADD_CKEY].name or SBX_ADD_CKEY
    end

    local contents={
        trow("Add Joker / Consumable",0.4,G.C.WHITE),
        {n=G.UIT.R,config={align="cm",padding=0.04},nodes=type_cells},
        search_row,
    }
    for _,r in ipairs(grid_rows) do contents[#contents+1]=r end
    contents[#contents+1]={n=G.UIT.R,config={align="cm",padding=0.04},nodes=nav_cells}
    contents[#contents+1]=trow("Selected: "..sel_name,0.26,G.C.YELLOW)
    contents[#contents+1]={n=G.UIT.R,config={align="cm",padding=0.05},nodes={
        bcell("Spawn","sbx_confirm_add_center",{},0.34,SBX_ADD_CKEY and G.C.GREEN or G.C.GREY)
    }}

    return create_UIBox_generic_options({back_func="sbx_close_center",contents=contents})
end

local function open_add_center()
    SBX_ADD_CKEY=nil; SBX_CENTER_PAGE=1; SBX_SEARCH.text=""
    SBX_IN_CENTER_PICKER=true
    open_overlay(add_center_def())
end

-- main menu
local function sandbox_menu_def()
    return create_UIBox_generic_options({back_func="sbx_close",contents={
        trow("Sandbox Menu",0.45,G.C.WHITE),
        {n=G.UIT.R,config={align="cm",padding=0.06},nodes={
            bcell("Add Playing Card","sbx_open_add_card",{},0.32,G.C.BLUE),
            bcell("Add Joker/Consumable","sbx_open_add_center",{},0.32,G.C.BLUE),
        }},
        {n=G.UIT.R,config={align="cm",padding=0.06},nodes={
            {n=G.UIT.T,config={text="Money: ",scale=0.3,colour=G.C.YELLOW}},
            bcell("-$10","sbx_money_adj",{d=-10},0.3,G.C.RED),bcell("-$1","sbx_money_adj",{d=-1},0.3,G.C.RED),
            bcell("+$1","sbx_money_adj",{d=1},0.3,G.C.GREEN),bcell("+$10","sbx_money_adj",{d=10},0.3,G.C.GREEN),bcell("+$100","sbx_money_adj",{d=100},0.3,G.C.GREEN),
        }},
        {n=G.UIT.R,config={align="cm",padding=0.06},nodes={
            bcell("Pass Round","sbx_pass_round",{},0.32,G.C.ORANGE),
            bcell("Reroll Boss","sbx_reroll_boss",{},0.32,G.C.ORANGE),
        }},
        trow("Right-click jokers, consumables, or hand cards to edit.",0.26,G.C.UI.TEXT_LIGHT),
    }})
end
local function open_sandbox_menu() open_overlay(sandbox_menu_def()) end

-- handlers for card editor
G.FUNCS.sbx_set_edition=function(e) local r=e.config.ref_table; if not(r and r.card) then return end; apply_edition(r.card,r.key); close_overlay(); open_card_editor(r.card) end
G.FUNCS.sbx_set_enhancement=function(e) local r=e.config.ref_table; if not(r and r.card) then return end; apply_enhancement(r.card,r.key); close_overlay(); open_card_editor(r.card) end
G.FUNCS.sbx_set_seal=function(e) local r=e.config.ref_table; if not(r and r.card) then return end; apply_seal(r.card,r.key); close_overlay(); open_card_editor(r.card) end
G.FUNCS.sbx_chip_adj=function(e) local r=e.config.ref_table; if not(r and r.card) then return end; r.card.sbx_bonus_chips=math.max(0,(r.card.sbx_bonus_chips or 0)+r.d); close_overlay(); open_card_editor(r.card) end
G.FUNCS.sbx_remove_card=function(e)
    local r=e.config.ref_table; if not(r and r.card) then return end
    local card=r.card; close_overlay()
    for _,area in ipairs({G.hand,G.deck,G.jokers,G.consumeables}) do
        if area then for _,c in ipairs(area.cards) do if c==card then area:remove_card(card); card:remove(); return end end end
    end
end

G.FUNCS.sbx_duplicate_card=function(e)
    local r=e.config.ref_table; if not(r and r.card) then return end
    local src=r.card
    -- Find which area it lives in
    local src_area
    for _,area in ipairs({G.hand,G.deck,G.jokers,G.consumeables}) do
        if area then for _,c in ipairs(area.cards) do if c==src then src_area=area; break end end end
        if src_area then break end
    end
    if not src_area then return end
    -- Spawn a copy with the same center
    local center = src.config and src.config.center or G.P_CENTERS.c_base
    local nc=Card(src_area.T.x+src_area.T.w/2,src_area.T.y,G.CARD_W,G.CARD_H,src.base and G.P_CARDS[src.base.id] or nil,center)
    -- Copy edition, seal, bonus chips
    if src.edition then nc:set_edition(src.edition.key,true,true) end
    if src.seal then nc:set_seal(src.seal,true,true) end
    nc.sbx_bonus_chips = src.sbx_bonus_chips
    nc.sbx_xmult = src.sbx_xmult
    nc:add_to_deck()
    src_area:emplace(nc)
    close_overlay()
end

-- handlers for joker editor
G.FUNCS.sbx_joker_set_edition=function(e) local r=e.config.ref_table; if not(r and r.card) then return end; apply_edition(r.card,r.key); close_overlay(); open_joker_editor(r.card) end
G.FUNCS.sbx_joker_chip_adj=function(e) local r=e.config.ref_table; if not(r and r.card) then return end; r.card.sbx_bonus_chips=math.max(0,(r.card.sbx_bonus_chips or 0)+r.d); close_overlay(); open_joker_editor(r.card) end
G.FUNCS.sbx_joker_xmult_adj=function(e) local r=e.config.ref_table; if not(r and r.card) then return end; r.card.sbx_xmult=math.max(0,(r.card.sbx_xmult or 0)+r.d); close_overlay(); open_joker_editor(r.card) end

-- handlers for add playing card
G.FUNCS.sbx_open_add_card=function() close_overlay(); open_add_card() end
G.FUNCS.sbx_open_add_center=function() close_overlay(); open_add_center() end
G.FUNCS.sbx_pick_rank=function(e) local r=e.config.ref_table; if r then SBX_ADD_CARD.rank=r.val end; close_overlay(); open_overlay(add_card_def()) end
G.FUNCS.sbx_pick_suit=function(e) local r=e.config.ref_table; if r then SBX_ADD_CARD.suit=r.val end; close_overlay(); open_overlay(add_card_def()) end
G.FUNCS.sbx_area_hand=function() SBX_ADD_CARD.area="hand"; close_overlay(); open_overlay(add_card_def()) end
G.FUNCS.sbx_area_deck=function() SBX_ADD_CARD.area="deck"; close_overlay(); open_overlay(add_card_def()) end
G.FUNCS.sbx_confirm_add_card=function() spawn_playing_card(SBX_ADD_CARD.rank,SBX_ADD_CARD.suit,(SBX_ADD_CARD.area=="hand") and G.hand or G.deck); close_overlay() end

-- handlers for add center
G.FUNCS.sbx_close_center=function()
    SBX_SEARCH.text=""; SBX_IN_CENTER_PICKER=false; close_overlay()
end
G.FUNCS.sbx_search_clear=function()
    SBX_SEARCH.text=""; SBX_CENTER_PAGE=1; close_overlay(); open_overlay(add_center_def())
end
G.FUNCS.sbx_center_type=function(e) local r=e.config.ref_table; if r then SBX_ADD_CTYPE=r.val; SBX_ADD_CKEY=nil; SBX_CENTER_PAGE=1 end; close_overlay(); open_overlay(add_center_def()) end
G.FUNCS.sbx_center_pick=function(e) local r=e.config.ref_table; if r and r.key then SBX_ADD_CKEY=r.key end; close_overlay(); open_overlay(add_center_def()) end
G.FUNCS.sbx_center_prev=function() SBX_CENTER_PAGE=math.max(1,SBX_CENTER_PAGE-1); close_overlay(); open_overlay(add_center_def()) end
G.FUNCS.sbx_center_next=function() SBX_CENTER_PAGE=SBX_CENTER_PAGE+1; close_overlay(); open_overlay(add_center_def()) end
G.FUNCS.sbx_confirm_add_center=function()
    if not SBX_ADD_CKEY then return end
    local area=(SBX_ADD_CTYPE=="Joker") and G.jokers or G.consumeables
    spawn_center(SBX_ADD_CKEY,area); close_overlay()
end


-- handlers for sandbox menu
G.FUNCS.sbx_money_adj=function(e) local r=e.config.ref_table; if not r then return end; ease_dollars(r.d); close_overlay(); open_sandbox_menu() end
G.FUNCS.sbx_pass_round=function()
    close_overlay()
    G.E_MANAGER:add_event(Event({func=function()
        if G.STATE == G.STATES.SELECTING_HAND and G.GAME.blind then
            G.GAME.chips = G.GAME.blind.chips + 1

            if G.hand_text_area and G.hand_text_area.game_chips then
                G.hand_text_area.game_chips:update_text()
            end
        end
        return true
    end}))
end

G.FUNCS.sbx_reroll_boss=function()
    close_overlay()
    G.E_MANAGER:add_event(Event({func=function()
        if not (G.GAME and G.GAME.blind_on_deck=="Boss") then return true end

        G.GAME.bosses_used = {}

        if G.GAME.round_resets and G.GAME.round_resets.blind_states then
            G.GAME.round_resets.blind_states.Boss = {triggered=false}
        end

        if G.HUD_blind then G.HUD_blind:remove(); G.HUD_blind=nil end
        if G.UIDEF and G.UIDEF.blind_select_opts then
            G.E_MANAGER:add_event(Event({func=function()
                if G.blind_select_opts then
                    G.blind_select_opts:remove()
                    G.blind_select_opts=nil
                end
                return true
            end}))
        end
        return true
    end}))
end

local _sbx_funcs_mt = getmetatable(G.FUNCS)
if not _sbx_funcs_mt then
    setmetatable(G.FUNCS, {
        __index = function(t, k)
            if type(k) ~= "string" then
                return function() end
            end
            return nil
        end
    })
end

-- Right click
local orig_R_press=Controller.queue_R_cursor_press
function Controller:queue_R_cursor_press(x,y)
    if G.SETTINGS.paused then orig_R_press(self,x,y); return end
    local target = self.hovering and self.hovering.target
    if target then
        if G.jokers and target.area==G.jokers then
            open_joker_editor(target); return
        end
        if G.consumeables and target.area==G.consumeables then
            open_joker_editor(target); return
        end
        if G.hand and target.area==G.hand and G.STATE==G.STATES.SELECTING_HAND then
            open_card_editor(target); return
        end
    end
    orig_R_press(self,x,y)
end

-- Scoring hooks
local orig_get_chip_bonus=Card.get_chip_bonus
Card.get_chip_bonus=function(self,...) local base=orig_get_chip_bonus and orig_get_chip_bonus(self,...) or 0; return (base or 0)+(self.sbx_bonus_chips or 0) end

local orig_calculate_card=Card.calculate_card
Card.calculate_card=function(self,context,...)
    local ret=orig_calculate_card and orig_calculate_card(self,context,...)
    if context and context.scoring_hand and (self.sbx_bonus_chips or 0)>0 then ret=ret or {}; ret.chips=(ret.chips or 0)+self.sbx_bonus_chips end
    return ret
end

local orig_calculate_joker=Card.calculate_joker
Card.calculate_joker=function(self,context,...)
    local ret=orig_calculate_joker and orig_calculate_joker(self,context,...) or {}
    if context and context.joker_main then
        if (self.sbx_bonus_chips or 0)>0 then ret=ret or {}; ret.chips=(ret.chips or 0)+self.sbx_bonus_chips end
        if (self.sbx_xmult or 0)>0 then ret=ret or {}; ret.x_mult=(ret.x_mult or 1)*(1+self.sbx_xmult) end
    end
    return ret
end

-- CONFIG
-- Defaults
if not SMODS.current_mod.config then SMODS.current_mod.config = {} end
local cfg = SMODS.current_mod.config
if cfg.keybinds_enabled == nil then cfg.keybinds_enabled = false end

-- Keybind actions
local function hovered_card()
    local target = G.CONTROLLER and G.CONTROLLER.hovering and G.CONTROLLER.hovering.target
    if not target then return nil, nil end
    if G.jokers and target.area == G.jokers then return target, "joker" end
    if G.consumeables and target.area == G.consumeables then return target, "joker" end
    if G.hand and target.area == G.hand then return target, "hand" end
    return nil, nil
end

local function duplicate_hovered()
    local card = hovered_card()
    if not card then return end
    local src_area
    for _,area in ipairs({G.hand,G.deck,G.jokers,G.consumeables}) do
        if area then for _,c in ipairs(area.cards) do if c==card then src_area=area; break end end end
        if src_area then break end
    end
    if not src_area then return end
    local center = card.config and card.config.center or G.P_CENTERS.c_base
    local nc = Card(src_area.T.x+src_area.T.w/2, src_area.T.y, G.CARD_W, G.CARD_H,
        card.base and G.P_CARDS[card.base.id] or nil, center)
    if card.edition then nc:set_edition(card.edition.key,true,true) end
    if card.seal then nc:set_seal(card.seal,true,true) end
    nc.sbx_bonus_chips = card.sbx_bonus_chips
    nc.sbx_xmult = card.sbx_xmult
    nc:add_to_deck(); src_area:emplace(nc)
end

local function remove_hovered()
    local card = hovered_card()
    if not card then return end
    for _,area in ipairs({G.hand,G.deck,G.jokers,G.consumeables}) do
        if area then for _,c in ipairs(area.cards) do
            if c==card then area:remove_card(card); card:remove(); return end
        end end
    end
end

local function cycle_edition_hovered(dir)
    local card = hovered_card()
    if not card then return end
    local cur = (card.edition and card.edition.key) or "none"
    local idx = 1
    for i,ed in ipairs(EDITIONS) do if ed.key==cur then idx=i; break end end
    idx = ((idx - 1 + dir) % #EDITIONS) + 1
    apply_edition(card, EDITIONS[idx].key)
end

local function cycle_seal_hovered(dir)
    local card, kind = hovered_card()
    if not card or kind ~= "hand" then return end
    local cur = card.seal or "none"
    local idx = 1
    for i,sl in ipairs(SEALS) do if sl.key==cur then idx=i; break end end
    idx = ((idx - 1 + dir) % #SEALS) + 1
    apply_seal(card, SEALS[idx].key)
end

local function cycle_enhancement_hovered(dir)
    local card, kind = hovered_card()
    if not card or kind ~= "hand" then return end
    local cur = "none"
    if card.config and card.config.center then
        local ck = card.config.center.key or "c_base"
        if ck ~= "c_base" then cur = ck end
    end
    local idx = 1
    for i,en in ipairs(ENHANCEMENTS) do if en.key==cur then idx=i; break end end
    idx = ((idx - 1 + dir) % #ENHANCEMENTS) + 1
    apply_enhancement(card, ENHANCEMENTS[idx].key)
end

-- Keybinds
local orig_keypressed=love.keypressed
love.keypressed=function(key,scancode,isrepeat)
    if key=="f2" then
        if G.OVERLAY_MENU then close_overlay() elseif G.STATE==G.STATES.SELECTING_HAND then open_add_card() end; return
    end
    if key=="f3" then
        if G.OVERLAY_MENU then close_overlay()
        elseif G.STATE==G.STATES.SELECTING_HAND
            or G.STATE==G.STATES.BLIND_SELECT
            or G.STATE==G.STATES.SHOP
            or G.STATE==G.STATES.TAROT_PACK
            or G.STATE==G.STATES.PLANET_PACK
            or G.STATE==G.STATES.SPECTRAL_PACK
            or G.STATE==G.STATES.BUFFOON_PACK
            or G.STATE==G.STATES.STANDARD_PACK
            then open_sandbox_menu() end; return
    end
    -- Center picker search input
    if SBX_IN_CENTER_PICKER and G.OVERLAY_MENU then
        if key=="backspace" then
            if SBX_SEARCH.text~="" then
                SBX_SEARCH.text=SBX_SEARCH.text:sub(1,-2)
                SBX_CENTER_PAGE=1; close_overlay(); open_overlay(add_center_def())
            end; return
        end
        if key=="escape" then SBX_IN_CENTER_PICKER=false; close_overlay(); return end
        local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
        local char = (#key==1) and (shift and key:upper() or key) or (key=="space" and " " or nil)
        if char and #SBX_SEARCH.text < 20 then
            SBX_SEARCH.text=SBX_SEARCH.text..char; SBX_CENTER_PAGE=1
            close_overlay(); open_overlay(add_center_def())
        end
        return
    end
    -- Hotkeys
    if cfg.keybinds_enabled and not G.OVERLAY_MENU then
        local in_run = G.STATE and (
            G.STATE==G.STATES.SELECTING_HAND or
            G.STATE==G.STATES.HAND_PLAYED or
            G.STATE==G.STATES.DRAW_TO_HAND or
            G.STATE==G.STATES.SHOP or
            G.STATE==G.STATES.BLIND_SELECT or
            G.STATE==G.STATES.TAROT_PACK or
            G.STATE==G.STATES.PLANET_PACK or
            G.STATE==G.STATES.SPECTRAL_PACK or
            G.STATE==G.STATES.BUFFOON_PACK or
            G.STATE==G.STATES.STANDARD_PACK
        )
        if in_run then
        -- D = duplicate
        if key=="d" then duplicate_hovered(); return end
        -- Delete/X = remove
        if key=="delete" or key=="x" then remove_hovered(); return end
        -- E / Q = cycle ed
        if key=="e" then cycle_edition_hovered(1); return end
        if key=="q" then cycle_edition_hovered(-1); return end
        -- S / A = cycle seal
        if key=="s" then cycle_seal_hovered(1); return end
        if key=="a" then cycle_seal_hovered(-1); return end
        -- W / Tab = cycle enhancement
        if key=="w" then cycle_enhancement_hovered(1); return end
        if key=="tab" then cycle_enhancement_hovered(-1); return end
        -- F = toggle foil
        if key=="f" then
            local card = hovered_card()
            if card then
                local cur = card.edition and card.edition.key
                apply_edition(card, cur=="e_foil" and "none" or "e_foil")
            end; return
        end
        -- H = toggle holo
        if key=="h" then
            local card = hovered_card()
            if card then
                local cur = card.edition and card.edition.key
                apply_edition(card, cur=="e_holo" and "none" or "e_holo")
            end; return
        end
        -- P = toggle poly
        if key=="p" then
            local card = hovered_card()
            if card then
                local cur = card.edition and card.edition.key
                apply_edition(card, cur=="e_polychrome" and "none" or "e_polychrome")
            end; return
        end
        -- N = toggle neg
        if key=="n" then
            local card = hovered_card()
            if card then
                local cur = card.edition and card.edition.key
                apply_edition(card, cur=="e_negative" and "none" or "e_negative")
            end; return
        end
        end -- if in_run
    end -- if keybinds_enabled
    if orig_keypressed then return orig_keypressed(key,scancode,isrepeat) end
end

-- config tab
SMODS.current_mod.config_tab=function()
    return {n=G.UIT.ROOT,config={align="cm",colour=G.C.BLACK,r=0.1,padding=0.2,minw=5,minh=1},nodes={
        trow("Sandbox Mod",0.4,G.C.WHITE),
        {n=G.UIT.R,config={align="cm",padding=0.1},nodes={
            create_toggle({
                label="Enable Hotkeys",
                ref_table=cfg, ref_value="keybinds_enabled",
                active_colour=G.C.GREEN,
            })
        }},
        trow("Hotkeys (hover a card, then press):",0.28,G.C.YELLOW),
        trow("D=Duplicate  Del/X=Remove",0.26,G.C.UI.TEXT_LIGHT),
        trow("E/Q=Cycle Edition  F=Foil  H=Holo  P=Poly  N=Neg",0.26,G.C.UI.TEXT_LIGHT),
        trow("S/A=Cycle Seal  W/Tab=Cycle Enhancement",0.26,G.C.UI.TEXT_LIGHT),
        trow("F2=Add Card  F3=Sandbox Menu  Right-click=Edit",0.26,G.C.UI.TEXT_LIGHT),
    }}
end

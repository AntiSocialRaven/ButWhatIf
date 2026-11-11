-- But What If X? - edit your current run and explore what could have been.
-- Menus: [ = add a playing card, ] = sandbox menu (spawner, money, pass round...), right-click a card = edit it.

-- Data
local EDITIONS    = {{key="none",label="None"},{key="e_foil",label="Foil"},{key="e_holo",label="Holo"},{key="e_polychrome",label="Poly"},{key="e_negative",label="Neg"}}
local ENHANCEMENTS= {{key="none",label="None"},{key="m_bonus",label="Bonus"},{key="m_mult",label="Mult"},{key="m_wild",label="Wild"},{key="m_glass",label="Glass"},{key="m_steel",label="Steel"},{key="m_stone",label="Stone"},{key="m_gold",label="Gold"},{key="m_lucky",label="Lucky"}}
local SEALS       = {{key="none",label="None"},{key="Gold",label="Gold"},{key="Red",label="Red"},{key="Blue",label="Blue"},{key="Purple",label="Purple"}}
local RANKS       = {"2","3","4","5","6","7","8","9","10","Jack","Queen","King","Ace"}
local SUITS       = {"Spades","Hearts","Clubs","Diamonds"}

-- State
local SBX_ADD_CARD = {rank="Ace",suit="Spades",area="hand"}
local SBX_SEARCH   = {text=""}
local SBX_IN_PICKER = false

-- Apply helpers
local function apply_edition(card,key)    card:set_edition(key~="none" and key or nil,true,true) end
local function apply_enhancement(card,key) local c=(key=="none") and G.P_CENTERS.c_base or G.P_CENTERS[key]; if c then card:set_ability(c) end end
local function apply_seal(card,key)       card:set_seal(key~="none" and key or nil,true,true) end
local function is_playing_card(card) local s=card.ability and card.ability.set return s=="Default" or s=="Enhanced" end

-- Spawn helpers
local function spawn_playing_card(rank,suit,area)
    local ck; for k,v in pairs(G.P_CARDS) do if v.suit==suit and v.value==rank then ck=k;break end end
    if not ck then return end
    local nc=create_playing_card({front=G.P_CARDS[ck],center=G.P_CENTERS.c_base},area)
    if area==G.hand then nc:juice_up(0.3,0.3) end
end

-- UI helpers
local function btn(label,func,ref,scale,bg,minw)
    return {n=G.UIT.C,config={align="cm",padding=0.07,r=0.05,minw=minw,colour=bg or G.C.GREY,button=func,ref_table=ref,hover=true,shadow=true},
        nodes={{n=G.UIT.T,config={text=label,scale=scale or 0.33,colour=G.C.UI.TEXT_LIGHT}}}}
end
local function bcell(label,func,ref,scale,bg,minw)
    return {n=G.UIT.C,config={align="cm",padding=0.04},nodes={btn(label,func,ref,scale,bg,minw)}}
end
local function trow(text,scale,col)
    return {n=G.UIT.R,config={align="cm",padding=0.04},nodes={{n=G.UIT.T,config={text=text,scale=scale or 0.33,colour=col or G.C.UI.TEXT_LIGHT}}}}
end
local function section(title,colour,rows)
    local nodes={trow(title,0.32,colour or G.C.YELLOW)}
    for _,r in ipairs(rows) do nodes[#nodes+1]=r end
    return {n=G.UIT.R,config={align="cm",r=0.1,colour=G.C.L_BLACK,emboss=0.05,padding=0.07,minw=9},nodes=nodes}
end
local function row(nodes) return {n=G.UIT.R,config={align="cm",padding=0.03},nodes=nodes} end
local function r2(x) return math.floor(x*100+0.5)/100 end
local function fmt(v) if type(v)~="number" then return tostring(v) end if v==math.floor(v) then return tostring(v) end return tostring(r2(v)) end
local function card_params() return {bypass_discovery_center=true,bypass_discovery_ui=true,bypass_lock=true} end

-- Overlay helpers
local function open_overlay(def)
    G.SETTINGS.paused=true
    G.FUNCS.overlay_menu{definition=def}
end
local function close_overlay()
    if G.OVERLAY_MENU then G.OVERLAY_MENU:remove() end
    G.OVERLAY_MENU = nil
    G.SETTINGS.paused = false
    SBX_IN_PICKER = false
end
G.FUNCS.sbx_close=function() close_overlay() end

-- ===================== card editor =====================
-- One editor for every card: its own numbers (what the card is built from), bonus chips / xMult,
-- edition, seal, enhancement (playing cards), duplicate and remove. Numbers change in place, live.
local EDIT = {}
local function edit_fields(card)
    local f, ab = {}, card.ability
    for k in pairs(card.config.center.config or {}) do
        if k~="extra" and type(ab[k])=="number" then f[#f+1]={ab,k,k} end
    end
    if type(ab.extra)=="number" then f[#f+1]={ab,"extra","extra"}
    elseif type(ab.extra)=="table" then
        for k,v in pairs(ab.extra) do if type(v)=="number" then f[#f+1]={ab.extra,k,k} end end
    end
    if is_playing_card(card) then
        for _,k in ipairs{"perma_bonus","perma_mult","perma_x_mult","perma_h_chips","perma_h_mult"} do
            if type(ab[k])=="number" then f[#f+1]={ab,k,(k:gsub("perma_","permanent "))} end
        end
        if card.base and type(card.base.nominal)=="number" then f[#f+1]={card.base,"nominal","rank chips"} end
    end
    table.sort(f,function(a,b) return a[3]<b[3] end)
    while #f>9 do table.remove(f) end
    ab.sbx_chips = ab.sbx_chips or 0
    ab.sbx_xmult = ab.sbx_xmult or 0
    f[#f+1]={ab,"sbx_chips","bonus +chips"}
    f[#f+1]={ab,"sbx_xmult","bonus xMult (+1)"}
    f[#f+1]={ab,"extra_value","sell value +"}
    for _,x in ipairs(f) do x.text=fmt(x[1][x[2]]) end
    return f
end
local function choice_row(list,current,func,colour)
    local cells={}
    for _,o in ipairs(list) do
        local on=o.key==current
        cells[#cells+1]=bcell(on and ("["..o.label.."]") or o.label,func,{key=o.key},0.27,on and (colour or G.C.GREEN) or G.C.GREY)
    end
    return cells
end
local function editor_def()
    local card=EDIT.card
    local center=card.config.center
    local name=localize{type="name_text",set=center.set,key=center.key}
    if is_playing_card(card) and card.base then name=tostring(card.base.value).." of "..tostring(card.base.suit) end
    local num_rows={}
    for i,x in ipairs(EDIT.fields) do
        local ops={}
        for _,op in ipairs{"/2","-1","+1","x2","x10"} do ops[#ops+1]=bcell(op,"sbx_edit_num",{i=i,op=op},0.26,(op=="/2" or op=="-1") and G.C.RED or G.C.GREEN,0.55) end
        num_rows[#num_rows+1]={n=G.UIT.R,config={align="cm",padding=0.01},nodes={
            {n=G.UIT.C,config={align="cr",minw=2.8},nodes={{n=G.UIT.T,config={text=x[3],scale=0.3,colour=G.C.UI.TEXT_LIGHT}}}},
            {n=G.UIT.C,config={align="cm",minw=1.5,r=0.08,colour=G.C.BLACK,padding=0.05},nodes={
                {n=G.UIT.T,config={ref_table=x,ref_value="text",scale=0.34,colour=G.C.GOLD}}}},
            {n=G.UIT.C,config={align="cm"},nodes=ops},
        }}
    end
    local contents={
        trow("Edit: "..name,0.45,G.C.WHITE),
        trow("Changes apply instantly. Hover the card afterwards to see its new text.",0.26),
        section("Numbers",G.C.GOLD,num_rows),
        section("Edition",G.C.DARK_EDITION,{row(choice_row(EDITIONS,card.edition and card.edition.key or "none","sbx_edit_edition",G.C.DARK_EDITION))}),
        section("Seal",G.C.RED,{row(choice_row(SEALS,card.seal or "none","sbx_edit_seal",G.C.RED))}),
    }
    if is_playing_card(card) then
        local cur=center.key~="c_base" and center.key or "none"
        local cells=choice_row(ENHANCEMENTS,cur,"sbx_edit_enh",G.C.SECONDARY_SET.Enhanced)
        local r1,r2_={},{}
        for i,c in ipairs(cells) do if i<=5 then r1[#r1+1]=c else r2_[#r2_+1]=c end end
        contents[#contents+1]=section("Enhancement",G.C.SECONDARY_SET.Enhanced,{row(r1),row(r2_)})
    end
    contents[#contents+1]=row{bcell("Duplicate","sbx_duplicate_card",{card=card},0.32,G.C.BLUE,2),bcell("Remove","sbx_remove_card",{card=card},0.32,G.C.RED,2)}
    return create_UIBox_generic_options({back_func="sbx_close",contents=contents})
end
local function open_editor(card)
    if not (card and card.ability and card.config and card.config.center) then return end
    EDIT.card,EDIT.fields=card,edit_fields(card)
    open_overlay(editor_def())
end
G.FUNCS.sbx_edit_num=function(e)
    local r=e.config.ref_table; local x=EDIT.fields[r.i]; if not x then return end
    local v=x[1][x[2]]; if type(v)~="number" then return end
    if r.op=="/2" then v=v/2 elseif r.op=="-1" then v=v-1 elseif r.op=="+1" then v=v+1 elseif r.op=="x2" then v=v*2 else v=v*10 end
    if v~=math.floor(v) then v=r2(v) end
    if (x[2]=="sbx_chips" or x[2]=="sbx_xmult") and v<0 then v=0 end
    x[1][x[2]]=v; x.text=fmt(v)
    if x[2]=="extra_value" then EDIT.card:set_cost() end
    EDIT.card:juice_up(0.3,0.3); play_sound("chips1",1.1,0.4)
end
G.FUNCS.sbx_edit_edition=function(e) apply_edition(EDIT.card,e.config.ref_table.key); open_overlay(editor_def()) end
G.FUNCS.sbx_edit_seal=function(e) apply_seal(EDIT.card,e.config.ref_table.key); open_overlay(editor_def()) end
G.FUNCS.sbx_edit_enh=function(e) apply_enhancement(EDIT.card,e.config.ref_table.key); EDIT.fields=edit_fields(EDIT.card); open_overlay(editor_def()) end

local function card_area_of(card)
    for _,area in ipairs({G.hand,G.deck,G.jokers,G.consumeables}) do
        if area then for _,c in ipairs(area.cards) do if c==card then return area end end end
    end
end
local function duplicate(card)
    local area=card_area_of(card); if not area then return end
    local playing=is_playing_card(card)
    if playing then G.playing_card=(G.playing_card or 0)+1 end -- same steps the game uses for DNA
    local nc=copy_card(card,nil,nil,playing and G.playing_card or nil)
    if playing then table.insert(G.playing_cards,nc) end
    nc:add_to_deck(); area:emplace(nc); nc:start_materialize()
end
local function remove(card)
    local area=card_area_of(card); if not area then return end
    card:start_dissolve()
end
G.FUNCS.sbx_remove_card=function(e) local r=e.config.ref_table; close_overlay(); if r and r.card then remove(r.card) end end
G.FUNCS.sbx_duplicate_card=function(e) local r=e.config.ref_table; close_overlay(); if r and r.card then duplicate(r.card) end end

-- bonus chips / xMult added in the editor (stored in ability, so they survive saving)
local orig_get_chip_bonus=Card.get_chip_bonus
function Card:get_chip_bonus(...)
    local base=orig_get_chip_bonus(self,...)
    local b=self.ability and self.ability.sbx_chips
    if b and b~=0 and not self.ability.extra_enhancement then base=base+b end
    return base
end
local orig_get_chip_x_mult=Card.get_chip_x_mult
if orig_get_chip_x_mult then
    function Card:get_chip_x_mult(...)
        local base=orig_get_chip_x_mult(self,...)
        local x=self.ability and self.ability.sbx_xmult
        if x and x>0 and not self.ability.extra_enhancement then base=(base and base>0 and base or 1)*(1+x) end
        return base
    end
end
local orig_calculate_joker=Card.calculate_joker
function Card:calculate_joker(context,...)
    local ret,trig=orig_calculate_joker(self,context,...)
    -- only ADD an effect when there is one: returning {} for every context makes Steamodded log warnings
    if context and context.joker_main and not context.blueprint and self.ability and not self.debuff then
        local c,x=self.ability.sbx_chips or 0,self.ability.sbx_xmult or 0
        if c~=0 or x>0 then
            local extra={}
            if c~=0 then extra.chips=c end
            if x>0 then extra.x_mult=1+x end
            ret=type(ret)=="table" and SMODS.merge_effects({ret,extra}) or extra
        end
    end
    return ret,trig
end

-- ===================== add playing card =====================
local function add_card_def()
    local s=SBX_ADD_CARD
    local rank_cells={}
    for _,r in ipairs(RANKS) do rank_cells[#rank_cells+1]=bcell(r,"sbx_pick_rank",{val=r},0.25,r==s.rank and G.C.GREEN or G.C.GREY) end
    local suit_cells={}
    for _,su in ipairs(SUITS) do suit_cells[#suit_cells+1]=bcell(su,"sbx_pick_suit",{val=su},0.29,su==s.suit and G.C.GREEN or G.C.GREY) end
    return create_UIBox_generic_options({back_func="sbx_close",contents={
        trow("Add Playing Card",0.42,G.C.WHITE),
        trow("Rank",0.28,G.C.YELLOW),row(rank_cells),
        trow("Suit",0.28,G.C.YELLOW),row(suit_cells),
        {n=G.UIT.R,config={align="cm",padding=0.05},nodes={
            {n=G.UIT.T,config={text="Add to: ",scale=0.28,colour=G.C.YELLOW}},
            bcell("Hand","sbx_area_hand",{},0.3,s.area=="hand" and G.C.GREEN or G.C.GREY),
            bcell("Deck","sbx_area_deck",{},0.3,s.area=="deck" and G.C.GREEN or G.C.GREY),
        }},
        row{bcell("Add Card","sbx_confirm_add_card",{},0.32,G.C.GREEN)},
    }})
end
local function open_add_card() SBX_ADD_CARD={rank="Ace",suit="Spades",area="hand"}; open_overlay(add_card_def()) end
G.FUNCS.sbx_open_add_card=function() close_overlay(); open_add_card() end
G.FUNCS.sbx_pick_rank=function(e) SBX_ADD_CARD.rank=e.config.ref_table.val; open_overlay(add_card_def()) end
G.FUNCS.sbx_pick_suit=function(e) SBX_ADD_CARD.suit=e.config.ref_table.val; open_overlay(add_card_def()) end
G.FUNCS.sbx_area_hand=function() SBX_ADD_CARD.area="hand"; open_overlay(add_card_def()) end
G.FUNCS.sbx_area_deck=function() SBX_ADD_CARD.area="deck"; open_overlay(add_card_def()) end
G.FUNCS.sbx_confirm_add_card=function() spawn_playing_card(SBX_ADD_CARD.rank,SBX_ADD_CARD.suit,(SBX_ADD_CARD.area=="hand") and G.hand or G.deck); close_overlay() end

-- ===================== spawner: a grid of real cards, click to add instantly =====================
local SPAWN={kind="Joker",page=1,msg=""}
local KINDS={{"Joker",G.C.BLUE},{"Tarot",G.C.SECONDARY_SET.Tarot},{"Planet",G.C.SECONDARY_SET.Planet},
    {"Spectral",G.C.SECONDARY_SET.Spectral},{"Voucher",G.C.SECONDARY_SET.Voucher},{"Tag",G.C.ORANGE}}
local COLS,ROWS,TAG_COLS,TAG_ROWS=6,3,10,3
local function display_name(c)
    local ok,n=pcall(localize,{type="name_text",set=c.set or SPAWN.kind,key=c.key})
    return (ok and type(n)=="string" and n~="ERROR") and n or (c.name or c.key or "?")
end
local function spawn_list()
    local pool=G.P_CENTER_POOLS[SPAWN.kind] or {}
    local st=SBX_SEARCH.text:lower()
    local out={}
    for _,c in ipairs(pool) do
        if not (SMODS.hide_from_collection and SMODS.hide_from_collection(c)) then
            if st=="" or display_name(c):lower():find(st,1,true) or (c.key or ""):lower():find(st,1,true) then out[#out+1]=c end
        end
    end
    return out
end
local function per_page() return SPAWN.kind=="Tag" and TAG_COLS*TAG_ROWS or COLS*ROWS end
local function spawn_now(key)
    if SPAWN.kind=="Tag" then
        if G.P_TAGS[key] then add_tag(Tag(key)) end
    elseif SPAWN.kind=="Voucher" then
        G.GAME.used_vouchers[key]=true
        Card.apply_to_run(nil,G.P_CENTERS[key])
    else
        local area=SPAWN.kind=="Joker" and G.jokers or G.consumeables
        local n=create_card(SPAWN.kind,area,nil,nil,nil,nil,key,"sbx_spawn")
        n:add_to_deck(); area:emplace(n); n:start_materialize()
    end
    SPAWN.msg="Added "..display_name(G.P_CENTERS[key] or G.P_TAGS[key] or {key=key})
    play_sound("card1",1.2,0.6)
end
G.FUNCS.sbx_spawn_tag=function(e) spawn_now(e.config.ref_table.key) end
local function grid()
    local list=spawn_list()
    local first=(SPAWN.page-1)*per_page()
    local rows={}
    if SPAWN.kind=="Tag" then
        for r=1,TAG_ROWS do
            local cells={}
            for c=1,TAG_COLS do
                local center=list[first+(r-1)*TAG_COLS+c]
                if center then
                    local tag=Tag(center.key,true); tag.hide_ability=false
                    local ui,sp=tag:generate_UI(0.8)
                    sp.click=function() spawn_now(center.key) end
                    cells[#cells+1]={n=G.UIT.C,config={align="cm",padding=0.06,r=0.1,colour=G.C.L_BLACK,button="sbx_spawn_tag",ref_table={key=center.key},hover=true},nodes={ui}}
                end
            end
            if cells[1] then rows[#rows+1]=row(cells) end
        end
    else
        local s=0.8
        for r=1,ROWS do
            local area=CardArea(G.ROOM.T.x,G.ROOM.T.h,(COLS+0.25)*G.CARD_W*s,G.CARD_H*s,
                {card_limit=COLS,type="title",highlight_limit=0,collection=true,card_w=G.CARD_W*s})
            for c=1,COLS do
                local center=list[first+(r-1)*COLS+c]
                if center then
                    local card=Card(area.T.x+area.T.w/2,area.T.y,G.CARD_W*s,G.CARD_H*s,G.P_CARDS.empty,center,card_params())
                    card.sbx_spawn=center.key
                    area:emplace(card)
                end
            end
            rows[#rows+1]={n=G.UIT.R,config={align="cm",padding=0.04,no_fill=true},nodes={{n=G.UIT.O,config={object=area}}}}
        end
    end
    if not rows[1] then rows[1]=trow("(no results)",0.3) end
    return rows,math.max(1,math.ceil(#list/per_page()))
end
local function spawner_def()
    local rows,pages=grid()
    SPAWN.page=math.min(SPAWN.page,pages)
    local kinds={}
    for _,k in ipairs(KINDS) do kinds[#kinds+1]=bcell(k[1],"sbx_spawn_kind",{val=k[1]},0.3,SPAWN.kind==k[1] and G.C.GOLD or k[2],1.4) end
    kinds[#kinds+1]=bcell("Playing card","sbx_open_add_card",{},0.3,G.C.GREY,1.8)
    local contents={
        trow("Spawner",0.5,G.C.WHITE),
        trow("Click a card or tag to add it right now. Hover for details. Type to search.",0.27),
        row(kinds),
        {n=G.UIT.R,config={align="cm",padding=0.03},nodes={
            {n=G.UIT.T,config={text="Search: ",scale=0.3,colour=G.C.YELLOW}},
            {n=G.UIT.T,config={text=SBX_SEARCH.text=="" and "(just start typing)" or ('"'..SBX_SEARCH.text..'"'),scale=0.3,colour=G.C.UI.TEXT_LIGHT}},
            bcell("X","sbx_search_clear",{},0.28,SBX_SEARCH.text~="" and G.C.RED or G.C.GREY),
        }},
        {n=G.UIT.R,config={align="cm",r=0.1,colour=G.C.BLACK,emboss=0.05,padding=0.08,minh=3},nodes=rows},
    }
    if pages>1 then
        local nav={}
        nav[#nav+1]=bcell("< Prev","sbx_spawn_page",{d=-1},0.3,SPAWN.page>1 and G.C.RED or G.C.GREY)
        nav[#nav+1]={n=G.UIT.C,config={align="cm",minw=1.8},nodes={{n=G.UIT.T,config={text="Page "..SPAWN.page.." / "..pages,scale=0.32,colour=G.C.UI.TEXT_LIGHT}}}}
        nav[#nav+1]=bcell("Next >","sbx_spawn_page",{d=1},0.3,SPAWN.page<pages and G.C.RED or G.C.GREY)
        contents[#contents+1]=row(nav)
    end
    contents[#contents+1]={n=G.UIT.R,config={align="cm"},nodes={{n=G.UIT.T,config={ref_table=SPAWN,ref_value="msg",scale=0.32,colour=G.C.GREEN}}}}
    return create_UIBox_generic_options({back_func="sbx_close",contents=contents})
end
local function open_spawner()
    SBX_IN_PICKER=true
    open_overlay(spawner_def())
    SBX_IN_PICKER=true
end
G.FUNCS.sbx_open_spawner=function() SPAWN.page=1; SPAWN.msg=""; SBX_SEARCH.text=""; open_spawner() end
G.FUNCS.sbx_spawn_kind=function(e) SPAWN.kind=e.config.ref_table.val; SPAWN.page=1; open_spawner() end
G.FUNCS.sbx_spawn_page=function(e) SPAWN.page=math.max(1,SPAWN.page+e.config.ref_table.d); open_spawner() end
G.FUNCS.sbx_search_clear=function() SBX_SEARCH.text=""; SPAWN.page=1; open_spawner() end

-- clicking a card in the spawner adds it instead of picking it up
local orig_click=Card.click
function Card:click(...)
    if self.sbx_spawn then spawn_now(self.sbx_spawn); self:juice_up(0.3,0.3); return end
    return orig_click(self,...)
end

-- ===================== sandbox menu =====================
local function sandbox_menu_def()
    return create_UIBox_generic_options({back_func="sbx_close",contents={
        trow("Sandbox Menu",0.45,G.C.WHITE),
        row{bcell("Spawner","sbx_open_spawner",{},0.34,G.C.GREEN,2.4),bcell("Add Playing Card","sbx_open_add_card",{},0.32,G.C.BLUE,2.6)},
        {n=G.UIT.R,config={align="cm",padding=0.06},nodes={
            {n=G.UIT.T,config={text="Money: ",scale=0.3,colour=G.C.YELLOW}},
            bcell("-$10","sbx_money_adj",{d=-10},0.3,G.C.RED),bcell("-$1","sbx_money_adj",{d=-1},0.3,G.C.RED),
            bcell("+$1","sbx_money_adj",{d=1},0.3,G.C.GREEN),bcell("+$10","sbx_money_adj",{d=10},0.3,G.C.GREEN),bcell("+$100","sbx_money_adj",{d=100},0.3,G.C.GREEN),
        }},
        row{bcell("Pass Round","sbx_pass_round",{},0.32,G.C.ORANGE),bcell("Reroll Boss","sbx_reroll_boss",{},0.32,G.C.ORANGE)},
        trow("Right-click any joker, consumable or card in hand to edit it.",0.26),
    }})
end
local function open_sandbox_menu() open_overlay(sandbox_menu_def()) end
G.FUNCS.sbx_money_adj=function(e) ease_dollars(e.config.ref_table.d); open_sandbox_menu() end
G.FUNCS.sbx_pass_round=function()
    close_overlay()
    G.E_MANAGER:add_event(Event({func=function()
        if G.STATE == G.STATES.SELECTING_HAND and G.GAME.blind then
            G.GAME.chips = G.GAME.blind.chips + 1
            if G.hand_text_area and G.hand_text_area.game_chips then G.hand_text_area.game_chips:update_text() end
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
                if G.blind_select_opts then G.blind_select_opts:remove(); G.blind_select_opts=nil end
                return true
            end}))
        end
        return true
    end}))
end

-- Right click a card = edit it
local orig_R_press=Controller.queue_R_cursor_press
function Controller:queue_R_cursor_press(x,y)
    if G.SETTINGS.paused then orig_R_press(self,x,y); return end
    local target = self.hovering and self.hovering.target
    if target and target.area and ((G.jokers and target.area==G.jokers) or (G.consumeables and target.area==G.consumeables)
        or (G.hand and target.area==G.hand)) then
        open_editor(target); return
    end
    orig_R_press(self,x,y)
end

-- ===================== config & hotkeys =====================
if not SMODS.current_mod.config then SMODS.current_mod.config = {} end
local cfg = SMODS.current_mod.config
if cfg.keybinds_enabled == nil then cfg.keybinds_enabled = true end

local function hovered_card()
    local target = G.CONTROLLER and G.CONTROLLER.hovering and G.CONTROLLER.hovering.target
    if not target then return nil, nil end
    if G.jokers and target.area == G.jokers then return target, "joker" end
    if G.consumeables and target.area == G.consumeables then return target, "joker" end
    if G.hand and target.area == G.hand then return target, "hand" end
    return nil, nil
end
local function cycle(list,cur,dir)
    local idx=1
    for i,o in ipairs(list) do if o.key==cur then idx=i; break end end
    return list[((idx-1+dir)%#list)+1].key
end
local function cycle_edition_hovered(dir)
    local card=hovered_card(); if not card then return end
    apply_edition(card,cycle(EDITIONS,(card.edition and card.edition.key) or "none",dir))
end
local function cycle_seal_hovered(dir)
    local card,kind=hovered_card(); if not card or kind~="hand" then return end
    apply_seal(card,cycle(SEALS,card.seal or "none",dir))
end
local function cycle_enhancement_hovered(dir)
    local card,kind=hovered_card(); if not card or kind~="hand" then return end
    local ck=card.config.center.key
    apply_enhancement(card,cycle(ENHANCEMENTS,ck~="c_base" and ck or "none",dir))
end
local function toggle_edition_hovered(key)
    local card=hovered_card(); if not card then return end
    apply_edition(card,(card.edition and card.edition.key)==key and "none" or key)
end

local MENU_STATES={"SELECTING_HAND","BLIND_SELECT","SHOP","TAROT_PACK","PLANET_PACK","SPECTRAL_PACK","BUFFOON_PACK","STANDARD_PACK","SMODS_BOOSTER_OPENED"}
local function menu_ok() for _,s in ipairs(MENU_STATES) do if G.STATES[s] and G.STATE==G.STATES[s] then return true end end end
local function toggle_add_card()
    if G.OVERLAY_MENU then close_overlay() elseif G.STATE==G.STATES.SELECTING_HAND then open_add_card() end
end
local function toggle_sandbox_menu()
    if G.OVERLAY_MENU then close_overlay() elseif menu_ok() then open_sandbox_menu() end
end

local orig_keypressed=love.keypressed
love.keypressed=function(key,scancode,isrepeat)
    if key=="f2" then toggle_add_card(); return end
    if key=="f3" then toggle_sandbox_menu(); return end
    -- spawner search box: typing filters the grid
    if SBX_IN_PICKER and G.OVERLAY_MENU then
        if key=="escape" then close_overlay(); return end
        if key=="backspace" then
            if SBX_SEARCH.text~="" then SBX_SEARCH.text=SBX_SEARCH.text:sub(1,-2); SPAWN.page=1; open_spawner() end
            return
        end
        local char=(#key==1 and key:match("[%w%-' ]")) and key or (key=="space" and " " or nil)
        if char and #SBX_SEARCH.text<20 then SBX_SEARCH.text=SBX_SEARCH.text..char; SPAWN.page=1; open_spawner() end
        return
    end
    -- menu keys that work on keyboards without an F row (Chromebooks)
    if key=="[" then toggle_add_card(); return end
    if key=="]" then toggle_sandbox_menu(); return end
    if cfg.keybinds_enabled and not G.OVERLAY_MENU and G.STATE and (menu_ok() or G.STATE==G.STATES.HAND_PLAYED or G.STATE==G.STATES.DRAW_TO_HAND) then
        if key=="d" then local c=hovered_card(); if c then duplicate(c) end; return end
        if key=="x" or key=="delete" or key=="backspace" then local c=hovered_card(); if c then remove(c) end; return end
        if key=="e" then cycle_edition_hovered(1); return end
        if key=="q" then cycle_edition_hovered(-1); return end
        if key=="s" then cycle_seal_hovered(1); return end
        if key=="a" then cycle_seal_hovered(-1); return end
        if key=="w" then cycle_enhancement_hovered(1); return end
        if key=="tab" then cycle_enhancement_hovered(-1); return end
        if key=="f" then toggle_edition_hovered("e_foil"); return end
        if key=="h" then toggle_edition_hovered("e_holo"); return end
        if key=="p" then toggle_edition_hovered("e_polychrome"); return end
        if key=="n" then toggle_edition_hovered("e_negative"); return end
    end
    if orig_keypressed then return orig_keypressed(key,scancode,isrepeat) end
end

SMODS.current_mod.config_tab=function()
    return {n=G.UIT.ROOT,config={align="cm",colour=G.C.BLACK,r=0.1,padding=0.2,minw=5,minh=1},nodes={
        trow("But What If X?",0.4,G.C.WHITE),
        {n=G.UIT.R,config={align="cm",padding=0.1},nodes={
            create_toggle({label="Enable Hotkeys",ref_table=cfg,ref_value="keybinds_enabled",active_colour=G.C.GREEN})
        }},
        trow("Menus:",0.28,G.C.YELLOW),
        trow("] = Sandbox menu (Spawner, money, pass round, reroll boss)   [ = Add playing card",0.26),
        trow("Right-click a joker, consumable or card in hand = full card editor",0.26),
        trow("(F2/F3 also work on keyboards with an F row)",0.24,G.C.UI.TEXT_INACTIVE),
        trow("Hotkeys (hover a card, then press):",0.28,G.C.YELLOW),
        trow("D=Duplicate  X/Backspace=Remove",0.26),
        trow("E/Q=Cycle Edition  F=Foil  H=Holo  P=Poly  N=Neg",0.26),
        trow("S/A=Cycle Seal  W/Tab=Cycle Enhancement",0.26),
    }}
end

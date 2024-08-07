do return (function ()
    
  local Tunnel <const> = module("vrp", "lib/Tunnel")
  local Proxy <const> = module("vrp", "lib/Proxy")

  local vRPclient <const> = Tunnel.getInterface('vRP', 'vRP')
  local vRP <const> = Proxy.getInterface[[vRP]]

  local skinsCache <const> = {}
  local Skin <const> = {}
  Skin.__index = Skin
  local defaultModel <const> = "mp_m_freemode_01"


  function Skin.new(model, price)
    return setmetatable( { model = model, price = price, cache = nil}, Skin)
  end

  function Skin:remove(player)
    if self.cache then 
      vRPclient.setCustomization(player,{model = self.cache})
    else
      vRPclient.setCustomization(player,{model = defaultModel})
    end
  end

  function Skin:apply(player)
    local user_id = vRP.getUserId{player}
    if self.model then 
      vRPclient.getCustomization(player,{},function(custom)

        if not skinsCache[user_id] then skinsCache[user_id] = {}  end;

        if not skinsCache[user_id].used then
          skinsCache[user_id].used = true 
          self.cache = custom
        end

        vRPclient.setCustomization(player,{ {model = self.model }, false})
      end)
    end 
  end
  

  local function ownedSkins(player)
      local user_id <const> = vRP.getUserId{player}
    
      if not skinsCache[user_id] then return vRPclient.notify(player, {'~r~Eroare~w~: Nu ai niciun skin!'}) end;

      if #skinsCache[user_id].menu > 0  then return vRP.openMenu{player,skinsCache[user_id].menu} end; 

      skinsCache[user_id].menu = {name="Skins",css={top="75px", header_color="rgba(0,125,255,0.75)"}}
          for _, skin in pairs(skinsCache[user_id].skins) do
            skinsCache[user_id].menu[skin.name] = {function(player)

                if skinsCache[user_id].used == skin.model then 
                  return skinsCache[user_id].skins[skin.name]:remove(player)
                end

                skinsCache[user_id].skins[skin.name]:apply(player)
                vRPclient.notify(player,{('~g~Succes~w~: Ai folosit skin-ul %s'):format(skin.name)})
                skinsCache[user_id].used = skin.model
            end}

        skinsCache[user_id].menu['#RESET'] = {function(player) vRPclient.setCustomization(player,{model = defaultModel})  end,'Reseteaza-ti skin-ul la model-ul default'}

      end; vRP.openMenu{player,skinsCache[user_id].menu}
      
  end


  local function buySkins(player)

    local skinsMenu <const> = {name="Skins",css={top="75px", header_color="rgba(0,125,255,0.75)"}}
    local user_id <const> = vRP.getUserId{player}

    for name, skin in pairs(SkinsConfig) do 

      skinsMenu[name] = {function(player,choice)

        vRP.request{player, ('Vrei sa cumperi skin-ul %s'):format(name) .. ' ?', 60, function(player,ok)
          if not ok then return end;
          if skinsCache[user_id] and skinsCache[user_id].skins[name] then return vRPclient.notify(player,{'~r~Eroare~w~: Ai deja acest skin!'}) end;
          if not vRP.tryFullPayment{user_id,skin.price} then return vRPclient.notify(player,{'~r~Eroare~w~: Nu ai destui bani'}) end;
          skinsCache[user_id] = { skins = { } , menu = {  } }
          local skin = Skin.new(skin.model, skin.price); skin.name = name;
          skinsCache[user_id].skins[name] = skin
          vRPclient.notify(player,{('~g~Succes~w~: Ai cumparat skin-ul %s'):format(name)})

        end}
    
      end,('Pret: %s<br>Model: %s'):format(skin.price,skin.model)}
    end; vRP.openMenu{player,skinsMenu}

  end
  

  local function menuHandler(f)

      f {
          ['Skins'] = {
            function(player)

              local choices <const> = {name="Choices",css={top="75px", header_color="rgba(0,125,255,0.75)"}}

              choices.Buy = {buySkins, 'Cumpara skin-uri'}
              choices.Owned = {ownedSkins,'Skin-urile tale'}
              vRP.openMenu{player,choices}

            end

          }
      }

  end; vRP.registerMenuBuilder{"main", menuHandler}

  local function leaveHandler (user_id)

    if skinsCache[user_id] then 
      exports['ghmattimysql']:execute("UPDATE vrp_users SET skins = @data WHERE id = @id", {data = json.encode(skinsCache[user_id]['skins']), id = user_id}, function() skinsCache[user_id] = nil end)
    end

  end 

  local function spawnHandler (user_id, _, first_spawn)
      if not first_spawn then return end;
      
      exports['ghmattimysql']:execute(('SELECT skins FROM vrp_users WHERE id = %d'):format(user_id), function (rows)
          local res = rows[1].skins
          if type(res) ~= 'table' then return end;
          skinsCache[user_id] =  { skins = json.decode(res), menu = { } }

          for idx, skin in pairs(skinsCache[user_id].skins) do skinsCache[user_id].skins[idx] = Skin.new(skin.model,skin.price) end

        end)
  end


  AddEventHandler("vRP:playerSpawn", spawnHandler); AddEventHandler("vRP:playerLeave", leaveHandler )
end)() end
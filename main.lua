api:set_lua_name("Lockstep")

-- Create UI tab
local tabs = { main = api:AddTab("Lockstep") }
local gb = tabs.main:AddLeftGroupbox("Main Features")
gb:AddToggle("adv_fakepos_toggle", { Text = "Advanced Fake Position Resolver", Default = false })
gb:AddToggle("auto_resolver_toggle", { Text = "Auto Resolver", Default = false })
gb:AddToggle("ai_resolver_toggle", { Text = "AI-Powered Resolver", Default = false })
gb:AddToggle("trashtalk_toggle", { Text = "Trashtalk (Lockstep)", Default = false })

-- Trashtalk logic
local trashtalk_toggle = api:get_ui_object("trashtalk_toggle")
local hit_cache = {}
local trashtalk_msgs = {
    "Lockstep dominance. You got resolved!",
    "You just got Lockstepped.",
    "Get real, Lockstep sees through you.",
    "You call that fake? Lockstep calls that lunch.",
    "Nice try, but Lockstep resolves everyone.",
    "Outplayed and resolved: Lockstep way!",
    "Try harder, your anti-aim is my warmup.",
    "Skill issue? More like resolver issue. Lockstep wins!"
}
api:on_event("localplayer_hit_player", function(event)
    if trashtalk_toggle:GetValue() and event and event.Target and event.GameName == "Da Hood" then
        local target_id = tostring(event.Target.UserId)
        local tick = api:utility_tick()
        if not hit_cache[target_id] or (tick - hit_cache[target_id]) > 12 then
            local msg = trashtalk_msgs[math.random(1, #trashtalk_msgs)]
            api:chat(msg)
            hit_cache[target_id] = tick
        end
    end
end)

-- Resolver tracking
local resolver_data = {}

local function track_movement(target)
    if not target then return end
    local id = target.UserId or ""
    local fpos = api:get_client_cframe(target)
    if not fpos then return end

    if not resolver_data[id] then
        resolver_data[id] = {hist={}, last_time=os.clock()}
    end
    local hist = resolver_data[id].hist
    local now = os.clock()
    table.insert(hist, {pos=fpos.Position, time=now})
    if #hist > 35 then table.remove(hist, 1) end
    resolver_data[id].last_time = now
end

-- Regression AI-powered resolver
local function predict_regression(history, extrapolate_dt)
    if #history < 2 then return history[#history].pos end
    local n = #history
    local sx, sy, sz, st, st2, sxt, syt, szt = 0,0,0,0,0,0,0,0
    for i=1,n do
        local pt, t = history[i].pos, history[i].time
        sx, sy, sz = sx + pt.X, sy + pt.Y, sz + pt.Z
        st, st2 = st + t, st2 + t*t
        sxt, syt, szt = sxt + pt.X * t, syt + pt.Y * t, szt + pt.Z * t
    end
    local denom = (n*st2 - st*st)
    if denom == 0 then return history[n].pos end
    local bx = (n*sxt - st*sx)/denom
    local by = (n*syt - st*sy)/denom
    local bz = (n*szt - st*sz)/denom
    local ax = (sx - bx*st)/n
    local ay = (sy - by*st)/n
    local az = (sz - bz*st)/n
    local target_time = history[n].time + (extrapolate_dt or 0.15)
    return Vector3.new(ax + bx*target_time, ay + by*target_time, az + bz*target_time)
end

local function ai_resolver(target)
    if not target then return end
    local id = target.UserId or ""
    local data = resolver_data[id]
    if not data or #data.hist < 2 then return end
    local pred = predict_regression(data.hist, 0.15)
    if pred then
        api:notify("[Lockstep][AI] Predicted real pos: " .. tostring(pred))
        local v1 = (data.hist[#data.hist].pos - data.hist[#data.hist-1].pos) / (data.hist[#data.hist].time - data.hist[#data.hist-1].time)
        if v1.Magnitude > 25 then
            api:notify("[Lockstep][AI] Suspicious move detected for " .. tostring(target.Name))
        end
        return pred
    end
end

-- Advanced resolver logic
local function advanced_resolver(target)
    if not target then return end
    local id = target.UserId or ""
    local data = resolver_data[id]
    if not data or #data.hist < 3 then
        api:notify("[Lockstep][ADV] Insufficient data for advanced resolution.")
        return
    end
    local h = data.hist
    local dt1 = h[#h].time - h[#h-1].time
    local dt2 = h[#h-1].time - h[#h-2].time
    if dt1 <= 0 or dt2 <= 0 then
        api:notify("[Lockstep][ADV] Invalid frame timings.")
        return
    end
    local v1 = (h[#h].pos - h[#h-1].pos)/dt1
    local v2 = (h[#h-1].pos - h[#h-2].pos)/dt2
    local angle_change = (v1-v2).Magnitude
    if v1.Magnitude > 30 or v2.Magnitude > 30 then
        api:notify("[Lockstep][ADV] Extreme velocity detected (possible fake/exploit) for " .. tostring(target.Name))
    end
    if angle_change > 12 then
        api:notify("[Lockstep][ADV] Sudden directional change detected (anti-aim/fake) for " .. tostring(target.Name))
    end
    -- Out-of-bounds/void detection
    local pos = h[#h].pos
    if math.abs(pos.X) > 5000 or math.abs(pos.Y) > 5000 or math.abs(pos.Z) > 5000 then
        api:notify("[Lockstep][ADV] Void/invalid position detected for " .. tostring(target.Name))
    end
end

-- Auto resolver logic
local function auto_resolver(target)
    if not target then return end
    local id = target.UserId or ""
    local data = resolver_data[id]
    if not data or #data.hist == 0 then
        api:set_fake(target, false)
        api:notify("[Lockstep][AUTO] No data for " .. tostring(target.Name) .. "; disabling fake.")
        return
    end
    local pred = ai_resolver(target)
    local last_pos = data.hist[#data.hist].pos
    if not last_pos or math.abs(last_pos.X) > 5000 or math.abs(last_pos.Y) > 5000 or math.abs(last_pos.Z) > 5000 then
        api:set_fake(target, false)
        api:notify("[Lockstep][AUTO] Void/desync detected, disabling fake (" .. tostring(target.Name) .. ")")
        return
    end
    local v_eval = (#data.hist >= 2 and (data.hist[#data.hist].pos - data.hist[#data.hist-1].pos)/ (data.hist[#data.hist].time-data.hist[#data.hist-1].time)) or Vector3.new()
    if v_eval.Magnitude > 30 then
        api:set_fake(target, false)
        api:notify("[Lockstep][AUTO] Exploit/fake detected, disabling fake (" .. tostring(target.Name) .. ")")
        return
    end
    api:set_fake(target, true)
    api:notify("[Lockstep][AUTO] Target resolved: " .. tostring(target.Name))
end

-- Main loop: track and invoke resolvers according to toggles
api:on_event("game_tick", function()
    for _, player in ipairs(api:get_players()) do
        track_movement(player)
        if api:get_ui_object("ai_resolver_toggle"):GetValue() then
            ai_resolver(player)
        end
        if api:get_ui_object("adv_fakepos_toggle"):GetValue() then
            advanced_resolver(player)
        end
        if api:get_ui_object("auto_resolver_toggle"):GetValue() then
            auto_resolver(player)
        end
    end
end)

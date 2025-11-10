api:set_lua_name("Lockstep")

local tabs = { main = api:AddTab("Lockstep") }
local gb = tabs.main:AddLeftGroupbox("Main Features")
gb:AddToggle("ai_resolver_toggle", { Text = "AI Resolver (Ultimate)", Default = false })
gb:AddToggle("trashtalk_toggle", { Text = "Trashtalk (Lockstep)", Default = false })

-- Upgraded trashtalk logic
local trashtalk_toggle = api:get_ui_object("trashtalk_toggle")
local hit_cache, last_tr_msg = {}, {}
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
local rare_msgs = {
    "Lockstep just deleted your career.",
    "Is that all you got? Lockstep never loses.",
    "Lockstep's resolver just retired you.",
    "You vs Lockstep = History lesson!"
}
api:on_event("localplayer_hit_player", function(event)
    if not (trashtalk_toggle:GetValue() and event and event.Target and event.GameName == "Da Hood") then return end
    local target_id = tostring(event.Target.UserId)
    local tick = api:utility_tick()
    if not hit_cache[target_id] or hit_cache[target_id] ~= tick then
        local pool = trashtalk_msgs
        if math.random() < 0.05 then pool = rare_msgs end
        local msg
        repeat
            msg = pool[math.random(1, #pool)]
        until msg ~= last_tr_msg[target_id] or #pool == 1
        api:chat(msg)
        hit_cache[target_id] = tick
        last_tr_msg[target_id] = msg
    end
end)

-- Ultra-advanced AI Resolver with feedback tuning
local ai_model = {}
local global_feedback = { hits = 0, misses = 0, last_feedback_tick = 0 }

local function exp_smooth(last, new, alpha) return last and (last * (1 - alpha) + new * alpha) or new end
local function median(tbl)
    table.sort(tbl, function(a, b) return a < b end)
    local n = #tbl
    return n > 0 and tbl[math.floor(n / 2)+1] or 0
end

local function cluster_filter(values, threshold)
    local med = median(values)
    local filtered = {}
    for _, v in ipairs(values) do
        if math.abs(v - med) < (threshold or 30) then table.insert(filtered, v) end
    end
    return filtered
end

local function movement_state(target)
    local fpos = api:get_client_cframe(target)
    if not fpos then return "unknown" end
    local vel = fpos.Velocity or Vector3.new()
    if vel.Magnitude > 50 then return "sprinting"
    elseif vel.Magnitude > 15 then return "running"
    elseif vel.Magnitude <= 2 then return "idle"
    else return "moving" end
end

local function feedback_tune(id, hit_success)
    local data = ai_model[id]
    if not data then return end
    if hit_success then
        data.hits = (data.hits or 0) + 1
        global_feedback.hits = global_feedback.hits + 1
    else
        data.misses = (data.misses or 0) + 1
        global_feedback.misses = global_feedback.misses + 1
    end
    ai_model[id] = data
end

-- Automatic tuning based on global feedback stats
local function auto_tune_parameters()
    local total = global_feedback.hits + global_feedback.misses
    if total < 5 then return end -- Need min data
    
    local hit_rate = global_feedback.hits / total
    
    -- Adjust global aggression/confidence thresholds based on hit rate
    if hit_rate > 0.75 then
        -- High success: be more aggressive, lower confidence threshold
        global_feedback.aggression_mult = math.min(2.0, (global_feedback.aggression_mult or 1) + 0.05)
        global_feedback.conf_threshold = math.max(0.5, (global_feedback.conf_threshold or 0.65) - 0.02)
        api:notify("[Lockstep][Tuning] Hit rate high (" .. string.format("%.1f", hit_rate*100) .. "%) - increasing aggression")
    elseif hit_rate < 0.45 then
        -- Low success: be more conservative, raise confidence threshold
        global_feedback.aggression_mult = math.max(0.5, (global_feedback.aggression_mult or 1) - 0.05)
        global_feedback.conf_threshold = math.min(0.95, (global_feedback.conf_threshold or 0.65) + 0.03)
        api:notify("[Lockstep][Tuning] Hit rate low (" .. string.format("%.1f", hit_rate*100) .. "%) - lowering aggression")
    else
        api:notify("[Lockstep][Tuning] Hit rate balanced (" .. string.format("%.1f", hit_rate*100) .. "%)")
    end
    
    -- Per-player tuning
    for id, data in pairs(ai_model) do
        if data.hits and data.misses then
            local p_total = data.hits + data.misses
            if p_total > 3 then
                local p_hit_rate = data.hits / p_total
                -- Adjust per-player smoothing alpha based on success
                if p_hit_rate > 0.7 then
                    data.smooth_alpha = math.min(0.8, (data.smooth_alpha or 0.5) + 0.05)
                elseif p_hit_rate < 0.4 then
                    data.smooth_alpha = math.max(0.1, (data.smooth_alpha or 0.5) - 0.05)
                end
                -- Adjust prediction extrapolation distance
                if p_hit_rate > 0.8 then
                    data.predict_dt = math.min(0.3, (data.predict_dt or 0.15) + 0.02)
                elseif p_hit_rate < 0.35 then
                    data.predict_dt = math.max(0.05, (data.predict_dt or 0.15) - 0.03)
                end
            end
        end
    end
    
    global_feedback.last_feedback_tick = api:utility_tick()
end

local function ai_track(target)
    if not target then return end
    local id = target.UserId or ""
    local fpos = api:get_client_cframe(target)
    if not fpos then return end

    if not ai_model[id] then
        ai_model[id] = {
            history = {}, anomalies = 0, confidence = 1, last_pred = nil, smooth_pos = nil,
            aggression = 1, last_state = "unknown", hits = 0, misses = 0,
            anti_resolver = 0, smooth_alpha = 0.5, predict_dt = 0.15
        }
    end
    local data = ai_model[id]
    local now = os.clock()
    table.insert(data.history, {
        pos = fpos.Position,
        head = fpos.Head or fpos.Position,
        time = now,
        state = movement_state(target)
    })
    if #data.history > 50 then table.remove(data.history, 1) end

    -- Detect anti-resolver attempts
    if #data.history >= 3 then
        local h = data.history
        local v1 = h[#h].pos - h[#h-1].pos
        local v2 = h[#h-1].pos - h[#h-2].pos
        local angle_change = (v1 - v2).Magnitude
        if angle_change > 30 then
            data.anti_resolver = (data.anti_resolver or 0) + 1
            data.aggression = math.min(2, data.aggression + 0.2)
        else
            data.aggression = math.max(1, data.aggression - 0.03)
        end
    end

    ai_model[id] = data
end

local function cubic_predict(data)
    local h = data.history
    local n = #h
    if n < 4 then return h[n] and h[n].pos or nil end

    local times, xs, ys, zs = {}, {}, {}, {}
    for i=math.max(1,n-7),n do
        table.insert(times, h[i].time)
        table.insert(xs, h[i].pos.X); table.insert(ys, h[i].pos.Y); table.insert(zs, h[i].pos.Z)
    end
    local dt = times[#times] - times[1]
    if dt == 0 then return h[n].pos end
    
    local vels = {}
    for i=2,#times do
        local vel = Vector3.new(
            (xs[i] - xs[i-1])/(times[i]-times[i-1]),
            (ys[i] - ys[i-1])/(times[i]-times[i-1]),
            (zs[i] - zs[i-1])/(times[i]-times[i-1])
        )
        table.insert(vels, vel)
    end
    vels = cluster_filter(vels, 40)
    local median_vel = vels[math.floor(#vels/2)+1] or Vector3.new()
    
    -- Use dynamically tuned predict_dt
    local predict_dt = data.predict_dt or 0.15
    return h[n].pos + median_vel * predict_dt
end

local function ai_predict(target)
    local id = target.UserId or ""
    local data = ai_model[id] or {history = {}, anomalies = 0, confidence = 1, aggression = 1, smooth_alpha = 0.5}
    local hist = data.history
    if #hist < 7 then return hist[#hist] and hist[#hist].pos or nil, 1 end

    local pred = cubic_predict(data)
    local pred_head = hist[#hist] and hist[#hist].head or nil

    -- Lag compensation
    local ping = api:get_ping and api:get_ping(target) or 0
    if ping > 120 then pred = pred + Vector3.new(0, 0, math.min(20, ping * 0.02)) end

    -- Adaptive confidence with global feedback tuning
    local base_confidence = (#hist > 8 and 0.95 or 0.7) * (data.aggression or 1)
    local global_agg = global_feedback.aggression_mult or 1
    local confidence = base_confidence * global_agg
    data.last_pred, data.confidence = pred, confidence

    if api:get_ui_object("ai_resolver_toggle"):GetValue() then
        local conf_threshold = global_feedback.conf_threshold or 0.65
        if pred and confidence > conf_threshold and math.abs(pred.X) < 5000 and math.abs(pred.Y) < 5000 and math.abs(pred.Z) < 5000 then
            local msg = string.format("[Lockstep][AI-Ult] Pos: %s [Conf: %.2f][Agg: %.2f][State: %s]", tostring(pred), confidence, data.aggression, hist[#hist].state)
            msg = pred_head and msg..(" [Head: %s]"):format(tostring(pred_head)) or msg
            if data.anti_resolver and data.anti_resolver > 2 then
                msg = msg .. " [Anti-resolver attempts detected]"
            end
            api:notify(msg)
        end
    end

    ai_model[id] = data
    return pred, confidence, pred_head
end

local function share_peers(target, pred)
    -- Stub for team/bot collaboration
    return
end

-- Main event loop with automatic feedback tuning
api:on_event("game_tick", function()
    if not api:get_ui_object("ai_resolver_toggle"):GetValue() then return end
    
    -- Tune parameters every ~50 ticks (roughly 1 second)
    local tick = api:utility_tick()
    if (tick - global_feedback.last_feedback_tick) > 50 then
        auto_tune_parameters()
    end
    
    for _, player in ipairs(api:get_players()) do
        ai_track(player)
        local pred, conf, hpred = ai_predict(player)
        share_peers(player, pred)
    end
end)

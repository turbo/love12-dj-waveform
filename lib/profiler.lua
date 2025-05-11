-- very tiny profiler helper ------------------------------------
local P  = { stack = {}, acc = {}, hits = {} }

function P.push(tag)
    table.insert(P.stack, { tag = tag, t0 = love.timer.getTime() })
end

function P.pop()
    local rec = table.remove(P.stack)
    local dt  = love.timer.getTime() - rec.t0
    P.acc[rec.tag]  = (P.acc[rec.tag] or 0) + dt
    P.hits[rec.tag] = (P.hits[rec.tag] or 0) + 1
    return dt
end

function P.reset()
    for k in pairs(P.acc)  do P.acc[k]  = 0 end
    for k in pairs(P.hits) do P.hits[k] = 0 end
end

function P.report(printToConsole, nuke)
    local out = {}
    for tag, tot in pairs(P.acc) do
        local ms = (tot / (P.hits[tag] or 1)) * 1000
        out[#out+1] = string.format("%s %.2f ms", tag, ms)
    end
    table.sort(out)
    if printToConsole then
        print(table.concat(out, " | "))
    end
    if nuke then
      P.reset()
    end
    return out
end

return P

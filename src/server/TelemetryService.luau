local Run=game:GetService("RunService") local A=game:GetService("AnalyticsService")
local T={Seen={},Counts={}}
local steps={"SessionReady","BackyardEntered","FirstCageGrabbed","FirstHeistEscaped","FirstCritterReceived","FirstTrainingStarted","FarmUnlocked","FarmEntered"}
local function safe(fn) if not Run:IsStudio() then task.spawn(function() pcall(fn) end) end end
function T.Event(p,name,value,fields)
 T.Counts[name]=(T.Counts[name] or 0)+1
 local custom if fields then custom={} for i,v in ipairs(fields) do if i<=3 then custom["CustomField0"..i]=tostring(v) end end end
 safe(function() A:LogCustomEvent(p,name,value or 1,custom) end)
end
function T.Funnel(p,name)
 local i=table.find(steps,name) if not i then return end T.Seen[p]=T.Seen[p] or {}
 if T.Seen[p][name] then return end T.Seen[p][name]=true T.Counts[name]=(T.Counts[name] or 0)+1
 safe(function() A:LogOnboardingFunnelStepEvent(p,i,name) end)
end
function T.Progress(p,zone,name) safe(function() A:LogProgressionCompleteEvent(p,"Habitats",zone,name) end) end
function T.Economy(p,source,amount,balance,name)
 if amount<=0 then return end T.Counts[name]=(T.Counts[name] or 0)+1
 safe(function() A:LogEconomyEvent(p,source and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink,"Cash",amount,balance,"Gameplay",name) end)
end
function T.Remove(p) T.Seen[p]=nil end
return T

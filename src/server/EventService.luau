local S=game.ReplicatedStorage.CritterHeistShared local C=require(S.GameConfig)
local V={Start=os.clock(),CurrentEvent="Cooldown",EventEndsAt=0,Participants={}}
function V.Init(ctx) V.C=ctx V.Start=os.clock() V.EventEndsAt=workspace:GetServerTimeNow()+C.GoldenPeriod end
function V.StateAt(elapsed)
 if elapsed<C.GoldenPeriod then return elapsed>=C.GoldenPeriod-C.GoldenWarning and "Warning" or "Cooldown",C.GoldenPeriod-elapsed end
 local phase=elapsed%C.GoldenPeriod
 if phase<C.GoldenDuration then return "Active",C.GoldenDuration-phase elseif phase>=C.GoldenPeriod-C.GoldenWarning then return "Warning",C.GoldenPeriod-phase else return "Cooldown",C.GoldenPeriod-phase end
end
function V.Snapshot() return {State=V.CurrentEvent,EndsAt=V.EventEndsAt} end
function V.Active() return V.CurrentEvent=="Active" end
function V.Tick()
 local state,remaining=V.StateAt(os.clock()-V.Start) local changed=state~=V.CurrentEvent
 V.CurrentEvent=state V.EventEndsAt=workspace:GetServerTimeNow()+remaining
 if changed then if state=="Active" then V.Participants={} end
 for _,s in pairs(V.C.PlayerStateService.States) do V.C.PlayerStateService.Emit(s,"GoldenRush"..(state=="Active" and "Started" or state=="Warning" and "Warning" or "Ended"),V.Snapshot()) end end
 local beacon=V.C.WorldBuilder.Root.Hub.GoldenBeacon
 beacon.Label.Text.Text="GOLDEN RUSH"..(state=="Active" and " • ACTIVE!" or state=="Warning" and " • INCOMING!" or "").."
"..string.format("%02d:%02d",math.floor(remaining/60),math.floor(remaining%60))
 beacon.PointLight.Brightness=state=="Active" and 3 or state=="Warning" and 2 or 1
 beacon:SetAttribute("EventState",state)
end
function V.Participate(s)
 if V.Active() and not V.Participants[s.Player.UserId] then V.Participants[s.Player.UserId]=true V.C.TelemetryService.Event(s.Player,"GoldenRushParticipated",1) end
end
return V

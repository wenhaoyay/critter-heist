local S=game.ReplicatedStorage.CritterHeistShared local C=require(S.GameConfig) local E=require(S.EconomyConfig)
local R={RNG=Random.new()}
function R.Init(ctx) R.C=ctx end
function R.Shield(s)
 if not R.C.PlayerStateService.Near(s,s.Base.ShieldSwitch) or s.Heist or s.Theft or os.clock()<s.ManualReady or next(s.Transit)~=nil then return false end
 s.ShieldUntil=math.max(s.ShieldUntil,os.clock()+C.ManualShield) s.ManualReady=os.clock()+C.ShieldCooldown
 R.C.BaseService.Sign(s) R.C.PlayerStateService.Emit(s,"ShieldChanged",{Text="SHIELD ACTIVE • 60 SECONDS"})
 R.C.TelemetryService.Event(s.Player,"ManualShieldUsed") return true
end
function R.Daily(s)
 if not R.C.PlayerStateService.Near(s,s.Base.Daily) or s.RewardBusy or s.Heist or s.Theft or os.time()-s.Profile.LastDailyReward<C.DailyCooldown then return false end
 s.RewardBusy=true s.Profile.LastDailyReward=os.time()
 local item=E.Roll(E.Highest(s.Profile.SpeedPower),3,s.Profile.LuckLevel,false,R.RNG)
 R.C.CritterService.Grant(s,item,"DailyCage") R.C.TelemetryService.Event(s.Player,"DailyCageClaimed",E.Highest(s.Profile.SpeedPower))
 task.spawn(function() R.C.DataService.Save(s.Player,false) s.RewardBusy=false end) return true
end
function R.Rebirth(s)
 if not R.C.PlayerStateService.Near(s,R.C.WorldBuilder.Root.Hub.Rebirth) or s.RewardBusy or s.Heist or s.Theft or next(s.Transit)~=nil then return false end
 local p=s.Profile if p.SpeedPower<150000 or p.Cash<C.RebirthCash or E.Highest(p.SpeedPower)<6 then R.C.PlayerStateService.Emit(s,"Notice",{Text="Rebirth requires Space Lab, 150K Speed and $1B."}) return false end
 s.RewardBusy=true local oldCash=p.Cash
 p.Rebirths+=1 p.Cash=0 p.SpeedPower=0 p.TreadmillLevel=1 p.LuckLevel=1 p.BaseLevel=1 p.CritterPads={} p.ProtectedPad=nil
 R.C.BaseService.Refresh(s) R.C.BaseService.Home(s) R.C.PlayerStateService.Full(s)
 R.C.PlayerStateService.Emit(s,"RebirthComplete",{Text="REBORN! +"..(p.Rebirths*50).."% income • +"..(p.Rebirths*20).."% training"})
 R.C.TelemetryService.Event(s.Player,"RebirthCompleted",p.Rebirths) R.C.TelemetryService.Economy(s.Player,false,oldCash,0,"RebirthReset") if p.Rebirths==1 then R.C.TelemetryService.Progress(s.Player,7,"FirstRebirth") end
 task.spawn(function() R.C.DataService.Save(s.Player,false) s.RewardBusy=false end) return true
end
function R.Settings(s,key,value)
 if type(key)~="string" or type(value)~="boolean" or s.Profile.Settings[key]==nil then return false end
 s.Profile.Settings[key]=value R.C.PlayerStateService.Full(s) return true
end
return R

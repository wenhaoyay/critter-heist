local S=game.ReplicatedStorage.CritterHeistShared local C=require(S.GameConfig) local E=require(S.EconomyConfig) local Z=require(S.ZoneRegistry)
local T={}
function T.Init(ctx) T.C=ctx end
function T.Tick(s,dt)
 local root=T.C.PlayerStateService.Valid(s) if not root or s.Heist or s.Theft or s.Zone~=0 then return end
 local pos=s.Base.Treadmill.CFrame:PointToObjectSpace(root.Position)
 if math.abs(pos.X)<=3.6 and math.abs(pos.Z)<=5.3 and pos.Y>=0 and pos.Y<=6 then
 if not s.TrainingStarted then s.TrainingStarted=true if not s.Profile.TutorialComplete then T.C.TelemetryService.Funnel(s.Player,"FirstTrainingStarted") end end
 local before=E.Highest(s.Profile.SpeedPower)
 s.Profile.SpeedPower=math.min(C.MaxSpeed,s.Profile.SpeedPower+E.TreadRates[s.Profile.TreadmillLevel]*(1+s.Profile.Rebirths*0.2)*dt)
 local after=E.Highest(s.Profile.SpeedPower)
 if after>before then
 for zone=before+1,after do T.C.PlayerStateService.Emit(s,"ZoneUnlocked",{Zone=zone,Name=Z[zone].Name}) T.C.TelemetryService.Progress(s.Player,zone,Z[zone].Id) end
 if before<2 and after>=2 and not s.Profile.TutorialComplete then T.C.TelemetryService.Funnel(s.Player,"FarmUnlocked") end
 end
 T.C.PlayerStateService.Sync(s)
 end
end
function T.Upgrade(s,kind,part)
 if not T.C.PlayerStateService.Near(s,part) or part:GetAttribute("BaseId")~=s.BaseId or s.Heist or s.Theft or not T.C.PlayerStateService.Rate(s,"Upgrade",0.6) then return false end
 local key,costs if kind=="Treadmill" then key="TreadmillLevel" costs=E.TreadCosts elseif kind=="Luck" then key="LuckLevel" costs=E.LuckCosts elseif kind=="Base" then key="BaseLevel" costs=E.BaseCosts else return false end
 local level=s.Profile[key] local cost=costs[level+1]
 if not cost then return false end if s.Profile.Cash<cost then T.C.PlayerStateService.Emit(s,"Notice",{Text="Need $"..E.Format(cost).." for the next "..kind.." level."}) return false end
 s.Profile.Cash-=cost s.Profile[key]+=1 T.C.BaseService.Refresh(s)
 T.C.PlayerStateService.Emit(s,"Upgrade",{Text=kind.." upgraded to LV "..(level+1)})
 T.C.TelemetryService.Event(s.Player,"UpgradePurchased",cost,{kind,level+1,E.Highest(s.Profile.SpeedPower)})
 T.C.TelemetryService.Economy(s.Player,false,cost,s.Profile.Cash,kind.."Upgrade") return true
end
function T.Enter(s,zone,part)
 if type(zone)~="number" or not Z[zone] or not T.C.PlayerStateService.Near(s,part) or s.Heist or s.Theft or not T.C.PlayerStateService.Rate(s,"Portal",1) then return false end
 if s.Profile.SpeedPower<Z[zone].Speed then T.C.PlayerStateService.Emit(s,"Notice",{Text="Train to "..E.Format(Z[zone].Speed).." Speed to enter "..Z[zone].Name.."."}) return false end
 s.Zone=zone T.C.PlayerStateService.Teleport(s,T.C.WorldBuilder.Zones[zone]:GetAttribute("Origin")*CFrame.new(0,5,4))
 if zone==1 and not s.Profile.TutorialComplete then T.C.TelemetryService.Funnel(s.Player,"BackyardEntered") end
 if zone==2 and s.Profile.TutorialRewardClaimed and not s.Profile.TutorialComplete then
 s.Profile.TutorialComplete=true T.C.TelemetryService.Funnel(s.Player,"FarmEntered") T.C.TelemetryService.Event(s.Player,"TutorialCompleted",os.clock()-s.Joined)
 T.C.PlayerStateService.Emit(s,"Notice",{Text="You're a heister! Explore, collect, and train."}) task.spawn(function() T.C.DataService.Save(s.Player,false) end)
 end
 T.C.PlayerStateService.Sync(s) T.C.PlayerStateService.Full(s) return true
end
return T

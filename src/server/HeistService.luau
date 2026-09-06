local S=game.ReplicatedStorage.CritterHeistShared local C=require(S.GameConfig) local E=require(S.EconomyConfig) local Z=require(S.ZoneRegistry) local Models=require(S.CritterModels)
local H={CageReady={},RNG=Random.new()}
function H.Init(ctx) H.C=ctx end
function H.Cancel(s,reason)
 local h=s.Heist if not h then return end s.Heist=nil
 if h.Guardian then h.Guardian:Destroy() end if h.Carry then h.Carry:Destroy() end
 H.C.PlayerStateService.Sync(s)
 if reason then H.C.PlayerStateService.Emit(s,"HeistEnded",{Reason=reason}) end
end
function H.Start(s,zone,tier,part)
 local root=H.C.PlayerStateService.Valid(s) local z=Z[zone] local t=C.Tiers[tier]
 if not root or not z or not t or s.Zone~=zone or s.Profile.SpeedPower<z.Speed or s.Heist or s.Theft or s.RewardBusy or s.StunnedUntil and s.StunnedUntil>os.clock() then return false end
 if not H.C.PlayerStateService.Near(s,part) or not H.C.PlayerStateService.Rate(s,"Cage",0.5) then return false end
 local key=zone..":"..tier if (H.CageReady[key] or 0)>os.clock() then return false end
 H.CageReady[key]=os.clock()+t.Respawn*(H.C.EventService.Active() and 0.5 or 1) part.ProximityPrompt.Enabled=false
 local cf=H.C.WorldBuilder.Zones[zone]:GetAttribute("Origin")
 local spawn=root.Position+cf.LookVector*t.HeadStart
 local species=({"Puppy","HighlandCow","Monkey","PolarCub","BabyDragon","CosmicAxolotl"})[zone]
 local guardian=Models.Build(species,"Normal") guardian.Name=z.Guardian guardian:ScaleTo(zone==3 and 2.6 or 2.1)
 guardian.Parent=H.C.Runtime.Guardians guardian:PivotTo(CFrame.lookAt(Vector3.new(spawn.X,4.5,spawn.Z),Vector3.new(root.Position.X,4.5,root.Position.Z)))
 H.C.WorldBuilder.Label(guardian.PrimaryPart,"!
"..string.upper(z.Guardian),190,95)
 if zone==3 then for _,side in ipairs({-1,1}) do H.C.WorldBuilder.Part(guardian,"GorillaArm",Vector3.new(3,7,3),guardian:GetPivot()*CFrame.new(side*4,0,0),Color3.fromRGB(100,91,110),nil,Enum.PartType.Ball,false) end end
 local aura=Instance.new("Attachment",guardian.PrimaryPart) local dust=Instance.new("ParticleEmitter",aura) dust.Texture="rbxasset://textures/particles/smoke_main.dds" dust.Rate=zone==2 and 6 or 3 dust.Lifetime=NumberRange.new(0.3,0.6) dust.Speed=NumberRange.new(1,2) dust.Size=NumberSequence.new(0.5,1.5) dust.Transparency=NumberSequence.new(0.7,1) dust.Color=ColorSequence.new(z.Color)
 s.Heist={Zone=zone,Tier=tier,Started=os.clock(),Guardian=guardian,Carry=H.C.CritterService.Carry(s,nil,true),Path={Vector3.new(root.Position.X,4.5,root.Position.Z)},LastBreadcrumb=root.Position,Index=1,Speed=E.WalkSpeed(z.Speed)*t.Speed}
 if not s.Profile.TutorialRewardClaimed then H.C.TelemetryService.Funnel(s.Player,"FirstCageGrabbed") end
 H.C.PlayerStateService.Sync(s) H.C.PlayerStateService.Emit(s,"HeistStarted",{Zone=zone,Tier=tier})
 H.C.EventService.Participate(s) return true
end
function H.Finish(s,caught)
 local h=s.Heist if not h then return end
 local duration=os.clock()-h.Started local zone,tier=h.Zone,h.Tier
 H.Cancel(s)
 H.C.TelemetryService.Event(s.Player,"HeistCompleted",duration,{Z[zone].Id,C.Tiers[tier].Name,caught and "Caught" or "Escaped"})
 if caught then
 s.StunnedUntil=os.clock()+C.StunSeconds H.C.PlayerStateService.Sync(s) H.C.PlayerStateService.Emit(s,"HeistCaught",{Text="BONKED! Try a quicker route."}) return end
 local item if not s.Profile.TutorialRewardClaimed then
 item={SpeciesId="Raccoon",Mutation="Normal"} s.Profile.TutorialRewardClaimed=true H.C.TelemetryService.Funnel(s.Player,"FirstHeistEscaped")
 else item=E.Roll(zone,tier,s.Profile.LuckLevel,H.C.EventService.Active(),H.RNG) end
 H.C.CritterService.Grant(s,item,"WildHeist") if not s.Profile.TutorialComplete then H.C.TelemetryService.Funnel(s.Player,"FirstCritterReceived") end
 H.C.PlayerStateService.Emit(s,"HeistCompleted",{})
 s.RewardBusy=true task.spawn(function() H.C.DataService.Save(s.Player,false) s.RewardBusy=false end)
end
function H.Tick(s,dt)
 local h=s.Heist if not h then return end local root=H.C.PlayerStateService.Valid(s)
 if not root or os.clock()-h.Started>C.HeistTimeout then H.Cancel(s,"Heist timed out") return end
 local localPos=H.C.WorldBuilder.Zones[h.Zone]:GetAttribute("Origin"):PointToObjectSpace(root.Position)
 if math.abs(localPos.X)>61 or localPos.Z < -144 or localPos.Y>23 then H.Cancel(s,"Stay inside the habitat") return end
 if localPos.Z>=0 then
 local minimum=C.Tiers[h.Tier].Depth/(E.WalkSpeed(s.Profile.SpeedPower)*1.5)
 if os.clock()-h.Started>=minimum then H.Finish(s,false) else H.Cancel(s,"Invalid escape") end return
 end
 if (root.Position-h.LastBreadcrumb).Magnitude>=2 then table.insert(h.Path,Vector3.new(root.Position.X,4.5,root.Position.Z)) h.LastBreadcrumb=root.Position end
 -- Allow the grab cue to reach the player before the guardian accelerates.
 if os.clock()-h.Started<0.4 then return end
 local pos=h.Guardian:GetPivot().Position local travel=h.Speed*dt
 while travel>0 and h.Index<=#h.Path do local target=h.Path[h.Index] local delta=target-pos local distance=delta.Magnitude
 if distance<=travel then pos=target travel-=distance h.Index+=1 else pos+=delta.Unit*travel travel=0 end end
 local look=Vector3.new(root.Position.X,pos.Y,root.Position.Z) if (look-pos).Magnitude>0.05 then h.Guardian:PivotTo(CFrame.lookAt(pos,look)) end
 if h.Index>40 then for _=1,h.Index-1 do table.remove(h.Path,1) end h.Index=1 end
 local flat=Vector3.new(root.Position.X-pos.X,0,root.Position.Z-pos.Z).Magnitude
 if flat<C.CatchDistance and math.abs(root.Position.Y-pos.Y)<7 then H.Finish(s,true) end
end
function H.Maintain()
 for key,cage in pairs(H.C.WorldBuilder.Cages) do local ready=(H.CageReady[key] or 0)<=os.clock() cage.Core.ProximityPrompt.Enabled=ready cage.Core.Transparency=ready and 0.62 or 0.9 end
end
return H

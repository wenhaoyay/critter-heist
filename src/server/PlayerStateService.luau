local S=game.ReplicatedStorage.CritterHeistShared local C=require(S.GameConfig) local E=require(S.EconomyConfig)
local P={States={}}
function P.Init(context) P.Context=context end
function P.Add(player,profile)
 local s={Player=player,Profile=profile,Transit={},ShieldUntil=os.clock()+C.NewShield,ManualReady=0,TheftReady=0,Zone=0,Joined=os.clock(),Income=0,LastPosition=nil,MoveCredit=8,Tokens=10,TokenTime=os.clock(),ActionAt={},PassiveBatch=0,Connections={},Loaded=true,Generation=0}
 P.States[player]=s P.Sync(s) return s
end
function P.Get(player) return P.States[player] end
function P.Alive(s) local ch=s.Player.Character local h=ch and ch:FindFirstChildOfClass("Humanoid") local r=ch and ch:FindFirstChild("HumanoidRootPart") return r and h and h.Health>0 and r or nil end
function P.Valid(s) local d=s and P.Context.DataService.Records[s.Player] return s and s.Loaded and not s.Closing and d and not d.Unsafe and P.Alive(s) end
function P.Near(s,part,distance) local root=P.Valid(s) return root and part and part:IsDescendantOf(workspace) and (root.Position-part.Position).Magnitude<=(distance or C.InteractionDistance) end
function P.Rate(s,key,interval)
 local now=os.clock() if s.ActionAt[key] and now-s.ActionAt[key]<(interval or 0.4) then return false end s.ActionAt[key]=now return true
end
function P.Token(s)
 local now=os.clock() s.Tokens=math.min(10,s.Tokens+(now-s.TokenTime)*5) s.TokenTime=now
 if s.Tokens<1 then return false end s.Tokens-=1 return true
end
function P.Emit(s,event,data) if s.Player.Parent then P.Context.Remotes.StateDelta:FireClient(s.Player,event,data or {}) end end
function P.Objective(s)
 if s.Heist then return "RUN TO THE SAFE LINE!"
 elseif s.Theft then return "GET TO YOUR BASE! • OWNER CAN BUST YOU"
 elseif not s.Profile.TutorialRewardClaimed then return "STEAL YOUR FIRST CRITTER! • BACKYARD"
 elseif not s.Profile.TutorialComplete then return s.Profile.SpeedPower<100 and "TRAIN YOUR SPEED! • YOUR BASE" or "FARM UNLOCKED! • ENTER FARM"
 else return "HEIST → TRAIN → UNLOCK • "..(s.Zone>0 and "Escape with a cage" or "Choose your next habitat") end
end
function P.Sync(s)
 local p=s.Profile s.Income=E.Income(p,s.Transit)
 for _,key in ipairs({"Cash","SpeedPower","TreadmillLevel","BaseLevel","LuckLevel","Rebirths"}) do s.Player:SetAttribute(key,p[key]) end
 s.Player:SetAttribute("IncomePerSecond",s.Income) s.Player:SetAttribute("HighestUnlockedZone",E.Highest(p.SpeedPower))
 s.Player:SetAttribute("Objective",P.Objective(s)) s.Player:SetAttribute("CurrentZone",s.Zone)
 local root=P.Alive(s) if root then local h=root.Parent:FindFirstChildOfClass("Humanoid") h.WalkSpeed=s.StunnedUntil and s.StunnedUntil>os.clock() and 0 or E.WalkSpeed(p.SpeedPower)*(s.Theft and C.TheftPenalty or 1) end
end
function P.Snapshot(s)
 local p=s.Profile
 return {Discoveries=p.Discoveries,ProtectedPad=p.ProtectedPad,Settings=p.Settings,PadData=p.CritterPads,TutorialRewardClaimed=p.TutorialRewardClaimed,TutorialComplete=p.TutorialComplete,Collection=E.Collection(p),LastDailyReward=p.LastDailyReward,Event=P.Context.EventService.Snapshot(),BaseId=s.BaseId}
end
function P.Full(s) P.Emit(s,"State",P.Snapshot(s)) end
function P.Teleport(s,cf) local root=P.Alive(s) if not root then return end s.Player.Character:PivotTo(cf) root.AssemblyLinearVelocity=Vector3.zero s.LastPosition=cf.Position s.MoveCredit=8 s.TeleportUntil=os.clock()+0.6 end
function P.Movement(s,dt)
 local root=P.Alive(s) if not root then return false end
 local pos=root.Position
 if s.LastPosition and (not s.TeleportUntil or os.clock()>s.TeleportUntil) then
 local distance=Vector3.new(pos.X-s.LastPosition.X,0,pos.Z-s.LastPosition.Z).Magnitude
 s.MoveCredit=math.min(12,s.MoveCredit+E.WalkSpeed(s.Profile.SpeedPower)*1.35*dt)-distance
 if s.MoveCredit < -8 then
 if s.Heist then P.Context.HeistService.Cancel(s,"Invalid movement") end
 if s.Theft then P.Context.TheftService.Cancel(s,"CancelledInvalid") end
 s.Zone=0 P.Context.BaseService.Home(s) s.MoveCredit=8 return false
 end end
 s.LastPosition=pos
 if pos.Y < -12 or math.abs(pos.X)>478 or math.abs(pos.Z)>478 then
 if s.Heist then P.Context.HeistService.Cancel(s,"Out of bounds") end
 if s.Theft then P.Context.TheftService.Cancel(s,"CancelledInvalid") end
 s.Zone=0 P.Context.BaseService.Home(s) return false end
 return true
end
return P

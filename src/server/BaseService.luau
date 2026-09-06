local S=game.ReplicatedStorage.CritterHeistShared local E=require(S.EconomyConfig) local C=require(S.GameConfig)
local B={Owners={}}
function B.Init(ctx) B.C=ctx end
function B.Assign(s)
 for i=1,8 do if not B.Owners[i] then
 B.Owners[i]=s s.BaseId=i s.Base=B.C.WorldBuilder.Bases[i] s.Base:SetAttribute("OwnerId",s.Player.UserId) s.Player:SetAttribute("AssignedBaseId",i)
 B.Refresh(s) return true end end return false
end
function B.Home(s)
 if s.Base then local cf=s.Base:GetAttribute("Origin") s.Zone=0 B.C.PlayerStateService.Teleport(s,cf*CFrame.new(0,5,-23)) B.C.PlayerStateService.Sync(s) end
end
function B.Inside(s,position)
 if not s.Base then return false end local p=s.Base:GetAttribute("Origin"):PointToObjectSpace(position)
 return math.abs(p.X)<=27 and math.abs(p.Z)<=32 and p.Y>=0 and p.Y<=12
end
function B.Sign(s)
 local text=s.Player.DisplayName.."'S BASE
+$"..E.Format(s.Income).."/s • ⭐ "..s.Profile.Rebirths
 local remaining=math.max(0,math.ceil(s.ShieldUntil-os.clock()))
 if remaining>0 then text..="
🛡 SHIELDED • "..string.format("%02d:%02d",math.floor(remaining/60),remaining%60) end
 s.Base.OwnerSign.Label.Text.Text=text
 for _,wall in s.Base.Shield:GetChildren() do wall.Transparency=remaining>0 and 0.72 or 1 end
 local daily=s.Base.Daily local seconds=math.max(0,C.DailyCooldown-(os.time()-s.Profile.LastDailyReward))
 daily.ProximityPrompt.ActionText=seconds==0 and "OPEN!" or string.format("%02dh %02dm",math.floor(seconds/3600),math.floor(seconds%3600/60))
 daily.Attachment.ReadyGlow.Enabled=seconds==0
end
function B.Refresh(s)
 local p=s.Profile local base=s.Base if not base then return end
 base.Critters:ClearAllChildren() local slots=E.BaseSlots[p.BaseLevel]
 for _,pad in base.Pads:GetChildren() do
 local i=pad:GetAttribute("PadIndex") local k=tostring(i) local item=p.CritterPads[k] local reserved=s.Transit[k]
 pad.Color=i>slots and Color3.fromRGB(132,141,150) or p.ProtectedPad==i and Color3.fromRGB(255,217,111) or Color3.fromRGB(111,239,195)
 pad.Label.Text.Text=i>slots and "🔒 LV "..math.max(2,math.ceil((i-2)/2)) or reserved and "IN TRANSIT!" or item and (p.ProtectedPad==i and "🛡 PROTECTED" or "") or "EMPTY"
 pad.ProximityPrompt.Enabled=i<=slots and item~=nil and not reserved
 if item and not reserved then B.C.CritterService.Render(s,pad,item) end
 end
 base.Progress:ClearAllChildren() local origin=base:GetAttribute("Origin")
 for i=2,p.BaseLevel do
 B.C.WorldBuilder.Part(base.Progress,"LevelAccent"..i,Vector3.new(46,0.2,0.4),origin*CFrame.new(0,1.55,29-(i-2)*1.2),Color3.fromRGB(244,218,134),i>=5 and Enum.Material.Neon or nil,nil,false)
 end
 if p.BaseLevel>=4 then
 for _,x in ipairs({-11,11}) do B.C.WorldBuilder.Part(base.Progress,"EntrancePost",Vector3.new(1,10,1),origin*CFrame.new(x,6,-30),Color3.fromRGB(191,159,231),nil,nil,false) end
 B.C.WorldBuilder.Part(base.Progress,"EntranceHeader",Vector3.new(23,1,1),origin*CFrame.new(0,11,-30),Color3.fromRGB(191,159,231),Enum.Material.Neon,nil,false)
 end
 local grade=math.ceil(p.TreadmillLevel/2) base.Treadmill.Color=({Color3.fromRGB(45,56,79),Color3.fromRGB(61,113,140),Color3.fromRGB(101,99,150),Color3.fromRGB(84,160,178)})[grade]
 base.Treadmill.Label.Text.Text="⚡ TRAIN • LV "..p.TreadmillLevel.."
+"..E.Format(E.TreadRates[p.TreadmillLevel]*(1+p.Rebirths*0.2)).." SPEED / SEC"
 if grade>=2 then B.C.WorldBuilder.Part(base.Progress,"TreadmillConsole",Vector3.new(6,grade,1),origin*CFrame.new(0,4,-0.5),Color3.fromRGB(115,227,221),grade>=4 and Enum.Material.Neon or nil,nil,false) end
 local defs={{"TreadUpgrade","Treadmill",p.TreadmillLevel,E.TreadCosts},{"Luck","Luck",p.LuckLevel,E.LuckCosts},{"BaseUpgrade","Base",p.BaseLevel,E.BaseCosts}}
 for _,d in ipairs(defs) do local part=base[d[1]] local price=d[4][d[3]+1] part.ProximityPrompt.ObjectText=d[2].." LV "..d[3].." • "..(price and "$"..E.Format(price) or "MAX") part.ProximityPrompt.ActionText=price and "Upgrade" or "MAX" end
 base.Luck.Label.Text.Text="🍀 LUCK • LV "..p.LuckLevel base.BaseUpgrade.Label.Text.Text="BASE LV "..p.BaseLevel.." • "..slots.." SLOTS"
 B.C.PlayerStateService.Sync(s) B.Sign(s)
end
function B.Protect(s,pad)
 if type(pad)~="number" or pad~=math.floor(pad) or pad<1 or pad>E.BaseSlots[s.Profile.BaseLevel] then return false end
 local k=tostring(pad) local target=s.Base.Pads:FindFirstChild(string.format("Pad%02d",pad))
 if not B.C.PlayerStateService.Near(s,target) or not s.Profile.CritterPads[k] or s.Transit[k] then return false end
 s.Profile.ProtectedPad=pad B.Refresh(s) B.C.PlayerStateService.Full(s) B.C.PlayerStateService.Emit(s,"Notice",{Text="Protected! This critter cannot be stolen or replaced."}) return true
end
function B.Release(s) if not s.Base then return end B.Owners[s.BaseId]=nil s.Base:SetAttribute("OwnerId",nil) s.Base.Critters:ClearAllChildren() s.Base.Progress:ClearAllChildren() s.Base.OwnerSign.Label.Text.Text="AVAILABLE BASE"
 for _,w in s.Base.Shield:GetChildren() do w.Transparency=1 end end
return B

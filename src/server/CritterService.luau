local S=game.ReplicatedStorage.CritterHeistShared local C=require(S.GameConfig) local E=require(S.EconomyConfig) local R=require(S.CritterRegistry) local Models=require(S.CritterModels)
local CS={}
function CS.Init(ctx) CS.C=ctx end
function CS.Render(s,pad,item)
 local m=Models.Build(item.SpeciesId,item.Mutation) m.Name="Pad"..pad:GetAttribute("PadIndex") m.Parent=s.Base.Critters
 local box,size=m:GetBoundingBox() local lift=m:GetPivot().Position.Y-(box.Position.Y-size.Y/2)
 local position=pad.Position+Vector3.new(0,pad.Size.X/2+lift+0.1,0)
 local forward=s.Base:GetAttribute("Origin").LookVector m:PivotTo(CFrame.lookAt(position,position+forward))
 game:GetService("CollectionService"):AddTag(m,"CHCritter")
 local species=R.ById[item.SpeciesId]
 CS.C.WorldBuilder.Label(m.PrimaryPart,(item.Mutation=="Normal" and "" or item.Mutation.."
")..species.Name.."
"..C.Rarities[species.Rarity].." • +$"..E.Format(E.Intrinsic(item)).."/s",170,36)
 return m
end
function CS.Grant(s,item,source)
 local before=E.Count(s.Profile) local outcome,sale=E.Place(s.Profile,item,s.Transit)
 if not s.Profile.ProtectedPad then for k in pairs(s.Profile.CritterPads) do s.Profile.ProtectedPad=tonumber(k) break end end
 CS.C.BaseService.Refresh(s) CS.C.PlayerStateService.Full(s)
 CS.C.PlayerStateService.Emit(s,"CritterObtained",{Item=item,Outcome=outcome,Sale=sale,Source=source,Income=E.Intrinsic(item)})
 local spec=R.ById[item.SpeciesId] CS.C.TelemetryService.Event(s.Player,"CritterObtained",E.Intrinsic(item),{spec.Zone,C.Rarities[spec.Rarity],item.Mutation})
 if item.Mutation=="Celestial" or spec.Rarity==6 and (item.Mutation=="Rainbow" or item.Mutation=="Glitched") then CS.C.TelemetryService.Event(s.Player,"ExceptionalPull",E.Intrinsic(item),{spec.Zone,C.Rarities[spec.Rarity],item.Mutation}) end
 if sale>0 then CS.C.TelemetryService.Economy(s.Player,true,sale,s.Profile.Cash,"CritterAutoSale") end
 local after=E.Count(s.Profile) for _,milestone in ipairs({10,25,50,75,100,150,200,216}) do if before<milestone and after>=milestone then CS.C.TelemetryService.Event(s.Player,"CritterdexMilestone",milestone) end end
 return outcome,sale
end
function CS.Carry(s,item,mystery)
 local root=CS.C.PlayerStateService.Alive(s) if not root then return end local m
 if mystery then
 m=Instance.new("Model") m.Name="WildCage"
 local body=CS.C.WorldBuilder.Part(m,"Mystery",Vector3.new(2.5,2.5,2.5),CFrame.new(),Color3.fromRGB(246,204,116),Enum.Material.Metal,nil,false) m.PrimaryPart=body
 CS.C.WorldBuilder.Label(body,"?",70,50)
 else m=Models.Build(item.SpeciesId,item.Mutation) m:ScaleTo(0.6) end
 m.Parent=CS.C.Runtime.CarriedCritters m:PivotTo(root.CFrame*CFrame.new(0,1.8,2.2))
 for _,p in m:GetDescendants() do if p:IsA("BasePart") then p.Anchored=false p.Massless=true p.CanCollide=false p.CanTouch=false p.CanQuery=false local weld=Instance.new("WeldConstraint") weld.Part0=root weld.Part1=p weld.Parent=p end end
 return m
end
return CS

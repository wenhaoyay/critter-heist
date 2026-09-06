local C=require(script.Parent.GameConfig)
local Z=require(script.Parent.ZoneRegistry)
local R=require(script.Parent.CritterRegistry)
local E={
 BaseSlots={4,6,8,10,12,14},BaseCosts={0,2000,20000,200000,2000000,20000000},
 TreadRates={5,8,13,20,32,50,80,125},TreadCosts={0,250,2000,15000,100000,750000,5000000,30000000},
 LuckExtra={0,0.1,0.2,0.35,0.5,0.75},LuckMutation={1,1.1,1.25,1.5,1.8,2.2},LuckCosts={0,5000,50000,500000,5000000,50000000}
}
function E.Finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
function E.Number(n,d,low,high) if not E.Finite(n) then return d end return math.clamp(n,low,high) end
function E.WalkSpeed(power) return 16+math.min(24,7.5*math.log10(1+math.max(0,power)/100)) end
function E.Highest(power) local n=1 for i,z in ipairs(Z) do if power>=z.Speed then n=i end end return n end
function E.Count(p) local n=0 for _,v in pairs(p.Discoveries) do if v==true then n+=1 end end return n end
function E.Collection(p) return 1+math.min(10,math.floor(E.Count(p)/10))*0.02 end
function E.Intrinsic(c) local s=c and R.ById[c.SpeciesId] local m=c and table.find(C.Mutations,c.Mutation) return s and m and s.BaseIncome*C.MutationIncome[m] or 0 end
function E.Income(p,transit) local n=0 for k,c in pairs(p.CritterPads) do if not transit or not transit[k] then n+=E.Intrinsic(c) end end return n*(1+p.Rebirths*0.5)*E.Collection(p) end
function E.Offline(p,now) if not E.Finite(p.LastLogout) or p.LastLogout<=0 or p.LastLogout>now then return 0 end return E.Income(p)*math.clamp(now-p.LastLogout,0,C.OfflineCap)*C.OfflineRate end
function E.Format(n) local a=math.abs(n) for _,pair in ipairs({{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}) do if a>=pair[1] then return string.format(a/pair[1]<10 and "%.2f%s" or "%.1f%s",n/pair[1],pair[2]):gsub("%.00",""):gsub("(%..-)0(%a)","%1%2") end end return tostring(math.floor(n)) end
function E.New() return {DataVersion=1,Cash=0,SpeedPower=0,TreadmillLevel=1,BaseLevel=1,LuckLevel=1,Rebirths=0,CritterPads={},Discoveries={},TutorialComplete=false,TutorialRewardClaimed=false,LastDailyReward=0,LastLogout=0,Settings={Music=true,SFX=true,ReducedMotion=false}} end
function E.Normalize(raw)
 if type(raw)~="table" then raw={} end
 if E.Finite(raw.DataVersion) and raw.DataVersion>C.DataVersion then return nil,"Future profile version" end
 local p=E.New()
 for _,k in ipairs({"Cash","SpeedPower","Rebirths","LastDailyReward","LastLogout"}) do p[k]=E.Number(raw[k],0,0,k=="Cash" and C.MaxCash or k=="SpeedPower" and C.MaxSpeed or k=="Rebirths" and 100000 or 1e12) end
 for k,max in pairs({TreadmillLevel=8,BaseLevel=6,LuckLevel=6}) do p[k]=math.floor(E.Number(raw[k],1,1,max)) end
 for _,k in ipairs({"TutorialComplete","TutorialRewardClaimed"}) do p[k]=raw[k]==true end
 if type(raw.Settings)=="table" then for k in pairs(p.Settings) do if type(raw.Settings[k])=="boolean" then p.Settings[k]=raw.Settings[k] end end end
 if type(raw.CritterPads)=="table" then for k,c in pairs(raw.CritterPads) do local i=tonumber(k)
 if i and i==math.floor(i) and i>=1 and i<=E.BaseSlots[p.BaseLevel] and type(c)=="table" and R.ById[c.SpeciesId] and table.find(C.Mutations,c.Mutation) then
 p.CritterPads[tostring(i)]={SpeciesId=c.SpeciesId,Mutation=c.Mutation}
 end end end
 if E.Finite(raw.ProtectedPad) and raw.ProtectedPad==math.floor(raw.ProtectedPad) and p.CritterPads[tostring(raw.ProtectedPad)] then p.ProtectedPad=raw.ProtectedPad end
 if type(raw.Discoveries)=="table" then for _,s in ipairs(R.List) do for _,m in ipairs(C.Mutations) do local key=s.Id.."|"..m if raw.Discoveries[key]==true then p.Discoveries[key]=true end end end end
 for _,c in pairs(p.CritterPads) do p.Discoveries[c.SpeciesId.."|"..c.Mutation]=true end
 return p
end
function E.Pick(weights,rng) local sum=0 for _,w in ipairs(weights) do sum+=w end local x=rng:NextNumber()*sum for i,w in ipairs(weights) do x-=w if x<0 then return i end end return #weights end
function E.Roll(zone,tier,luck,golden,rng)
 rng=rng or Random.new() local rolls=C.Tiers[tier].Rolls+(golden and 1 or 0)
 if rng:NextNumber()<E.LuckExtra[luck] then rolls+=1 end
 local best=1 for _=1,rolls do best=math.max(best,E.Pick(C.RarityWeights,rng)) end
 local weights={} local special=0 local multiplier=E.LuckMutation[luck]*(golden and 2 or 1)
 for i=2,6 do weights[i]=C.MutationWeights[i]*multiplier special+=weights[i] end
 if special>=100 then for i=2,6 do weights[i]*=99.9/special end special=99.9 end weights[1]=100-special
 return {SpeciesId=R.ByZone[zone][best].Id,Mutation=C.Mutations[E.Pick(weights,rng)]},rolls,best
end
function E.Place(p,item,reserved)
 local slots=E.BaseSlots[p.BaseLevel] local free,weak,weakValue
 for i=1,slots do local k=tostring(i) if not (reserved and reserved[k]) then local c=p.CritterPads[k]
 if not c then free=free or k elseif i~=p.ProtectedPad and (not weakValue or E.Intrinsic(c)<weakValue) then weak=k weakValue=E.Intrinsic(c) end end end
 p.Discoveries[item.SpeciesId.."|"..item.Mutation]=true
 if free then p.CritterPads[free]=item return "Placed",0,free end
 if weak and E.Intrinsic(item)>weakValue then local sale=weakValue*10 p.CritterPads[weak]=item p.Cash=math.min(C.MaxCash,p.Cash+sale) return "Replaced",sale,weak end
 local sale=E.Intrinsic(item)*10 p.Cash=math.min(C.MaxCash,p.Cash+sale) return "AutoSold",sale,nil
end
return E

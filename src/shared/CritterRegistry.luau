local C=require(script.Parent.GameConfig)
local names={{"Hamster","Bunny","Puppy","Raccoon","Fox","Capybara"},{"Chicken","Piglet","Goat","Cow","Alpaca","Highland Cow"},{"Frog","Parrot","Monkey","Crocodile","Tiger","Panda"},{"Penguin","Seal","Snow Hare","Arctic Fox","Polar Cub","Snow Leopard"},{"Lava Crab","Fire Gecko","Ember Boar","Magma Turtle","Phoenix","Baby Dragon"},{"Moon Mouse","Astro Cat","UFO Cow","Nebula Slime","Cosmic Axolotl","Star Dragon"}}
local forms={{"round","rabbit","dog","raccoon","fox","capybara"},{"bird","pig","horn","cow","longneck","shaggy"},{"frog","bird","monkey","long","tiger","panda"},{"penguin","seal","rabbit","fox","bear","leopard"},{"crab","long","boar","turtle","wings","dragon"},{"mouse","cat","ufo","slime","axolotl","dragon"}}
local colors={{{211,159,104},{243,223,213},{196,138,91},{125,137,159},{246,153,70},{169,135,93}},{{249,228,183},{245,161,177},{205,188,159},{239,231,213},{234,210,171},{180,102,57}},{{82,222,143},{80,197,226},{174,112,70},{73,170,124},{242,174,63},{232,233,225}},{{47,64,88},{158,191,209},{236,240,250},{207,224,246},{240,229,214},{193,209,220}},{{233,105,68},{247,153,52},{161,95,87},{154,103,91},{255,187,69},{235,115,83}},{{185,196,232},{156,133,227},{164,222,207},{160,136,255},{239,151,223},{144,202,255}}}
local R={ById={},List={},ByZone={}}
for z,row in ipairs(names) do R.ByZone[z]={} for rank,name in ipairs(row) do
 local rgb=colors[z][rank] local id=name:gsub(" ","")
 local s={Id=id,Name=name,Zone=z,Rarity=rank,BaseIncome=2*5^(z-1)*({1,2,4,8,20,50})[rank],Form=forms[z][rank],Color=Color3.fromRGB(unpack(rgb)),Accent=C.RarityColors[rank]}
 R.ById[id]=s table.insert(R.List,s) R.ByZone[z][rank]=s
end end
return R

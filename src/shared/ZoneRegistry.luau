local function col(r,g,b) return Color3.fromRGB(r,g,b) end
return {
 {Id="Backyard",Name="Backyard",Icon="🌿",Speed=0,Color=col(100,213,131),Floor=col(141,208,135),Guardian="Angry Dog",Landmark="DOGHOUSE"},
 {Id="Farm",Name="Farm",Icon="🌾",Speed=100,Color=col(255,189,87),Floor=col(214,202,120),Guardian="Giant Bull",Landmark="RED BARN"},
 {Id="Jungle",Name="Jungle",Icon="🌴",Speed=2000,Color=col(53,207,168),Floor=col(72,148,123),Guardian="Gorilla",Landmark="ANCIENT TEMPLE"},
 {Id="Arctic",Name="Arctic",Icon="❄",Speed=10000,Color=col(119,217,255),Floor=col(216,235,247),Guardian="Polar Bear",Landmark="FROZEN CAVE"},
 {Id="Volcano",Name="Volcano",Icon="🌋",Speed=40000,Color=col(255,131,83),Floor=col(108,101,123),Guardian="Lava Beast",Landmark="VOLCANIC CORE"},
 {Id="SpaceLab",Name="Space Lab",Icon="🪐",Speed=150000,Color=col(174,146,255),Floor=col(79,91,137),Guardian="Alien Experiment",Landmark="CONTAINMENT REACTOR"},
}

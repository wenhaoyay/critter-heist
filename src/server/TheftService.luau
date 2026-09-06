local S = game.ReplicatedStorage.CritterHeistShared
local C = require(S.GameConfig)
local E = require(S.EconomyConfig)
local R = require(S.CritterRegistry)

local T = {}

function T.Init(ctx)
	T.C = ctx
end

function T.Log(s, tx, result)
	local spec = R.ById[tx.Item.SpeciesId]
	T.C.TelemetryService.Event(s.Player, "TheftResult", os.clock() - tx.Started, {
		result,
		C.Rarities[spec.Rarity],
		tx.Item.Mutation,
	})
end

function T.Cleanup(s, tx)
	if tx.Carry then
		tx.Carry:Destroy()
	end
	if tx.Highlight then
		tx.Highlight:Destroy()
	end
	if tx.Tag then
		tx.Tag:Destroy()
	end
	s.Theft = nil
	T.C.PlayerStateService.Sync(s)
end

function T.Cancel(s, reason)
	local tx = s.Theft
	if not tx or tx.Committing then
		return
	end

	local victim = tx.Victim
	victim.Transit[tx.Pad] = nil
	T.Cleanup(s, tx)

	if victim.Base then
		T.C.BaseService.Refresh(victim)
		T.C.PlayerStateService.Full(victim)
	end

	T.C.PlayerStateService.Emit(s, "TheftBusted", {
		Text = reason == "Busted" and "BUSTED!" or "Theft cancelled",
	})
	T.C.PlayerStateService.Emit(victim, "Notice", {
		Text = reason == "Busted" and "CRITTER SAVED!" or "Your critter returned safely.",
	})
	T.Log(s, tx, reason or "CancelledInvalid")
end

function T.Start(s, baseId, pad, part)
	local victim = T.C.BaseService.Owners[baseId]
	local key = tostring(pad)
	if not victim
		or victim == s
		or not T.C.PlayerStateService.Valid(s)
		or not T.C.PlayerStateService.Valid(victim)
		or s.Heist
		or s.Theft
		or victim.Closing
		or s.RewardBusy
		or victim.RewardBusy
		or s.Zone ~= 0
	then
		return false
	end

	if not T.C.PlayerStateService.Near(s, part)
		or not T.C.PlayerStateService.Rate(s, "Theft", 1)
		or os.clock() < s.TheftReady
		or os.clock() < victim.ShieldUntil
		or victim.Profile.ProtectedPad == pad
		or victim.Transit[key]
	then
		return false
	end

	local item = victim.Profile.CritterPads[key]
	if not item then
		return false
	end

	victim.Transit[key] = s
	local tx = { Victim = victim, Pad = key, Item = item, Started = os.clock() }
	s.Theft = tx
	tx.Carry = T.C.CritterService.Carry(s, item, false)

	local char = s.Player.Character
	tx.Highlight = Instance.new("Highlight")
	tx.Highlight.Name = "ThiefHighlight"
	tx.Highlight.FillColor = Color3.fromRGB(255, 90, 104)
	tx.Highlight.FillTransparency = 0.65
	tx.Highlight.OutlineColor = Color3.fromRGB(255, 92, 97)
	tx.Highlight.Parent = char

	local root = T.C.PlayerStateService.Alive(s)
	local label = T.C.WorldBuilder.Label(root, "THIEF!", 150, 100)
	tx.Tag = label.Parent

	T.C.BaseService.Refresh(victim)
	T.C.PlayerStateService.Sync(s)
	T.C.PlayerStateService.Emit(s, "TheftStarted", {
		Text = "GET TO YOUR BASE! • OWNER CAN BUST YOU",
		ThiefId = s.Player.UserId,
	})
	T.C.PlayerStateService.Emit(victim, "TheftAlert", {
		Text = s.Player.DisplayName .. " is stealing your " .. R.ById[item.SpeciesId].Name .. "! TOUCH THEM!",
		ThiefId = s.Player.UserId,
	})
	return true
end

function T.Success(s)
	local tx = s.Theft
	if not tx or tx.Committing then
		return
	end

	local victim = tx.Victim
	tx.Committing = true
	s.RewardBusy = true
	victim.RewardBusy = true

	task.spawn(function()
		local success, reason = T.C.DataService.Transfer(victim.Player, s.Player, tx.Pad, tx.Item, function()
			victim.Transit[tx.Pad] = nil
			T.C.CritterService.Grant(s, tx.Item, "Theft")
		end)

		victim.Transit[tx.Pad] = nil
		if success then
			victim.ShieldUntil = os.clock() + C.VictimShield
			s.TheftReady = os.clock() + C.ThiefCooldown
			T.C.PlayerStateService.Emit(s, "TheftSuccessful", {
				Text = "HEIST COMPLETE! Critter secured.",
			})
			T.C.PlayerStateService.Emit(victim, "Notice", {
				Text = "Critter stolen. Your base is shielded for 90 seconds.",
			})
			T.Log(s, tx, "Success")
		else
			T.C.PlayerStateService.Emit(s, "Notice", {
				Text = "Transfer paused to protect saved data.",
			})
			T.Log(s, tx, "CancelledInvalid")
		end

		T.Cleanup(s, tx)
		T.C.BaseService.Refresh(victim)
		T.C.PlayerStateService.Full(victim)
		s.RewardBusy = false
		victim.RewardBusy = false
	end)
end

function T.Tick(s)
	local tx = s.Theft
	if not tx or tx.Committing then
		return
	end

	local root = T.C.PlayerStateService.Valid(s)
	local victim = tx.Victim
	if not root
		or not victim.Player.Parent
		or victim.Closing
		or not victim.Base
		or os.clock() - tx.Started > C.TheftTimeout
	then
		T.Cancel(s, "CancelledInvalid")
		return
	end

	local ownerRoot = T.C.PlayerStateService.Alive(victim)
	if ownerRoot and (root.Position - ownerRoot.Position).Magnitude <= C.BustDistance and os.clock() - tx.Started > 0.4 then
		T.Cancel(s, "Busted")
		return
	end

	if os.clock() - tx.Started > 1 and T.C.BaseService.Inside(s, root.Position) then
		T.Success(s)
	end
end

function T.Leaving(s)
	if s.Theft then
		T.Cancel(s, "CancelledThiefLeft")
	end
	for _, other in pairs(T.C.PlayerStateService.States) do
		if other.Theft and other.Theft.Victim == s then
			T.Cancel(other, "CancelledVictimLeft")
		end
	end
end

return T

local DSS = game:GetService("DataStoreService")
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")

local S = game.ReplicatedStorage.CritterHeistShared
local C = require(S.GameConfig)
local E = require(S.EconomyConfig)

local D = {
	Records = {},
	SessionOnly = Run:IsStudio() and game.PlaceId == 0,
}

local store
local ok, result = pcall(function()
	return DSS:GetDataStore(C.StoreName)
end)

if ok then
	store = result
elseif not Run:IsStudio() then
	error(result)
else
	D.SessionOnly = true
end

local function copy(t)
	if type(t) ~= "table" then
		return t
	end

	local r = {}
	for k, v in pairs(t) do
		r[k] = copy(v)
	end
	return r
end

D.Copy = copy

function D.Init(ctx)
	D.Context = ctx
end

function D.Migrate(raw)
	local p, err = E.Normalize(raw)
	if not p then
		return nil, err
	end

	p._Outgoing = type(raw) == "table" and type(raw._Outgoing) == "table" and copy(raw._Outgoing) or {}
	p._Receipts = type(raw) == "table" and type(raw._Receipts) == "table" and copy(raw._Receipts) or {}
	return p
end

local function update(key, fn)
	local last
	for attempt = 1, 3 do
		local success, value = pcall(function()
			return store:UpdateAsync(key, fn)
		end)
		if success then
			return true, value
		end

		last = value
		if attempt < 3 then
			task.wait(0.4 * 2 ^ (attempt - 1))
		end
	end
	return false, last
end

function D.Load(player)
	local token = Http:GenerateGUID(false)
	local key = "Player_" .. player.UserId
	local offline = 0
	local p

	if D.SessionOnly then
		p = E.New()
	else
		local denied
		local success, value = update(key, function(raw)
			denied = nil
			if type(raw) == "table"
				and raw._Session
				and raw._Session ~= token
				and E.Finite(raw._Expires)
				and raw._Expires > os.time()
			then
				denied = "Profile is still active in another server. Please rejoin shortly."
				return nil
			end

			local migrated, err = D.Migrate(raw)
			if not migrated then
				denied = err
				return nil
			end

			if type(raw) == "table" and raw._Session == token then
				offline = raw._OfflineAward or 0
			else
				offline = E.Offline(migrated, os.time())
				migrated.Cash = math.min(C.MaxCash, migrated.Cash + offline)
			end

			migrated.LastLogout = 0
			migrated._Session = token
			migrated._Expires = os.time() + C.LeaseSeconds
			migrated._OfflineAward = offline
			return migrated
		end)

		if not success then
			if Run:IsStudio() then
				D.SessionOnly = true
				p = E.New()
				warn("DataStore unavailable; using Studio session profile")
			else
				return nil, "Could not load your data safely. Please rejoin."
			end
		elseif not value then
			return nil, denied or "Profile unavailable. Please rejoin."
		else
			p = D.Migrate(value)
		end
	end

	if D.SessionOnly and not D.Warned then
		D.Warned = true
		warn("DataStore unavailable; using Studio session profile")
	end

	p._Outgoing = p._Outgoing or {}
	p._Receipts = p._Receipts or {}
	D.Records[player] = {
		Token = token,
		Key = key,
		Profile = p,
		Busy = false,
		Closing = false,
		Offline = offline,
		LastSave = os.clock(),
	}
	return p, offline
end

function D.Save(player, release)
	local r = D.Records[player]
	if not r then
		return false
	end

	while r.Busy do
		task.wait(0.05)
	end
	if r.Closed then
		return true
	end

	r.Busy = true
	local snapshot = copy(r.Profile)
	snapshot.LastLogout = release and os.time() or 0
	snapshot._Session = release and nil or r.Token
	snapshot._Expires = release and nil or os.time() + C.LeaseSeconds
	snapshot._OfflineAward = nil

	local success = true
	if not D.SessionOnly then
		local accepted = false
		success = update(r.Key, function(raw)
			if type(raw) ~= "table" or raw._Session ~= r.Token then
				-- An ambiguous release may already have committed.
				if release and type(raw) == "table" and raw._ReleasedBy == r.Token then
					accepted = true
					return nil
				end
				return nil
			end

			accepted = true
			snapshot._ReleasedBy = release and r.Token or nil
			return snapshot
		end)
		success = success and accepted
	end

	r.Busy = false
	if success then
		r.LastSave = os.clock()
		if release then
			r.Closed = true
		end
	else
		warn("Critter Heist: profile save failed; progression locked for " .. player.UserId)
		r.Unsafe = true
	end
	return success
end

-- Persistent outbox: donor removal is durable BEFORE recipient placement.
-- Recipient receipts make recovery idempotent after an interrupted transfer.
function D.Transfer(donor, receiver, pad, item, apply)
	local a = D.Records[donor]
	local b = D.Records[receiver]
	if not a or not b or a.Unsafe or b.Unsafe or a.Closing or b.Closing then
		return false
	end

	local id = Http:GenerateGUID(false)
	a.Profile._Outgoing[id] = { To = receiver.UserId, Item = copy(item) }
	a.Profile.CritterPads[pad] = nil

	if not D.Save(donor, false) then
		return false, "PendingSave"
	end

	apply()
	b.Profile._Receipts[id] = true
	if not D.Save(receiver, false) then
		return true, "PendingDelivery"
	end

	a.Profile._Outgoing[id] = nil
	task.spawn(function()
		if D.Save(donor, false) then
			b.Profile._Receipts[id] = nil
		end
	end)
	return true
end

function D.Recover(player)
	local r = D.Records[player]
	if not r or D.SessionOnly or next(r.Profile._Outgoing) == nil then
		return
	end

	for id, tx in pairs(r.Profile._Outgoing) do
		if type(tx) == "table" and E.Finite(tx.To) and type(tx.Item) == "table" and E.Intrinsic(tx.Item) > 0 then
			local online = game.Players:GetPlayerByUserId(tx.To)
			if not online then
				local applied = false
				local success = update("Player_" .. tx.To, function(raw)
					if type(raw) == "table" and raw._Session and E.Finite(raw._Expires) and raw._Expires > os.time() then
						return nil
					end

					local p = D.Migrate(raw)
					if not p then
						return nil
					end
					if not p._Receipts[id] then
						E.Place(p, copy(tx.Item))
						p._Receipts[id] = true
					end
					applied = true
					return p
				end)
				if success and applied then
					r.Profile._Outgoing[id] = nil
				end
			elseif D.Records[online] then
				local target = D.Records[online]
				local state = D.Context.PlayerStateService.Get(online)
				if state and not state.Closing and not state.RewardBusy and not target.Unsafe then
					state.RewardBusy = true
					if not target.Profile._Receipts[id] then
						D.Context.CritterService.Grant(state, copy(tx.Item), "RecoveredTheft")
						target.Profile._Receipts[id] = true
					end
					if D.Save(online, false) then
						r.Profile._Outgoing[id] = nil
					end
					state.RewardBusy = false
				end
			end
		end
	end
	D.Save(player, false)
end

return D

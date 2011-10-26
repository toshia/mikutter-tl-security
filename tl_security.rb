# -*- coding: utf-8 -*-

# ＼爽快セキュリティ！／
# サクサクサクサクサクサクサクサク…
Plugin.create(:tl_security) do

  muted_users = Hash.new        # user_id => mute limit Time
  update_count = Hash.new{ |h, k| h[k] = 0 } # user_id => count

  filter_show_filter do |messages|
    if muted_users
      [messages.select{ |m| not muted_users.has_key?(m.id) }]
    else
      [messages] end end

  onappear do |messages|
    now = Time.new.freeze
    messages.each { |message|
      limit = message[:created] + UserConfig[:tl_security_update_section]
      if limit > now
        count = atomic{ update_count[message.user.id] += 1 }
        notice "@#{message.user.idname} #{count} #{limit}"
        Reserver.new(limit){
          count = atomic{ update_count[message.user.id] -= 1 }
          notice "@#{message.user.idname} #{count}" }
        if count >= UserConfig[:tl_security_update_limit]
          Plugin.call :tl_security_temporary_mute, message.user, limit end end } end

  on_tl_security_temporary_mute do |user, mute_limit|
    Plugin.call(:update, nil, [Message.new(:message => "@#{user.idname} を #{mute_limit} までミュートします",
                                           :system => true)])
    notice "temporary mute @#{user.idname} to #{mute_limit}"
    muted_users[user.id] = mute_limit
    Reserver.new(mute_limit){
      Plugin.call :tl_security_temporary_unmute, user } end

  on_tl_security_temporary_unmute do |user|
    notice "unmute @#{user.idname}"
    muted_users.delete(user.id) end

  # この秒数の間にtl_security_update_limit回ツイートがあれば一定時間ミュート
  UserConfig[:tl_security_update_section] ||= 1

  # この回数だけtl_security_update_section秒間の間にツイートがあれば一定時間ミュート
  UserConfig[:tl_security_update_limit] ||= 5

  # 一時ミュートする時間(秒)
  UserConfig[:tl_security_mute_seconds] ||= 1800 # 30分

end

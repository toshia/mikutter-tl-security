# -*- coding: utf-8 -*-

# ＼爽快セキュリティ！／
# サクサクサクサクサクサクサクサク…

require 'set'

Plugin.create(:tl_security) do

  @muted_users = Set.new        # user_id
  @update_count = Hash.new{ |h, k| h[k] = 0 } # user_id => count

  settings("ファイアウォール") do
    settings("連投非表示機能") do
      adjustment("連投と判断する投稿の間隔（秒数）", :tl_security_update_section, 1, 10000).
        tooltip "この秒数の間に、下で設定された回数ツイートしたユーザを、一定時間ミュートします"
      adjustment("連投と判断する投稿の回数", :tl_security_update_limit, 1, 10000).
        tooltip "この回数ツイートしたユーザを一定時間ミュートします"
      adjustment("ミュートする秒数", :tl_security_mute_seconds, 1, 10000).
        tooltip "上記の条件に当てはまったユーザを、この秒数だけミュートします。mikutterを再起動すると設定にかかわらずミュートは解除されます"
    end
  end

  filter_show_filter do |messages|
    [messages.select{ |m| !@muted_users.include?(m.user.id) }]
  end

  onupdate do |service, messages|
    messages.each &method(:regist)
  end

  class << self
    def regist(message)
      return if @muted_users.include?(message.user.id) or message.user.idname == 'mikutter_bot' or message.user.is_me?
      now = Time.new.freeze
      limit = message[:created] + UserConfig[:tl_security_update_section]
      # limit = now + UserConfig[:tl_security_update_section]
      if limit > now
        count = atomic{ @update_count[message.user.id] += 1 }
        Reserver.new(limit){
          count = atomic{ @update_count[message.user.id] -= 1 } }
        if count >= UserConfig[:tl_security_update_limit]
          temporary_mute message.user, now + UserConfig[:tl_security_mute_seconds] end end end

    def temporary_mute(user, mute_limit)
      notice "temporary mute @#{user.idname} to #{mute_limit}"
      Plugin.call(:update, nil, [Message.new(:message => "@#{user.idname} を #{mute_limit} までミュートします",
                                             :system => true)])
      Plugin.call :tl_security_temporary_mute, user, mute_limit
      @muted_users << user.id
      Reserver.new(mute_limit){
        temporary_unmute(user) } end

    def temporary_unmute(user)
      notice "unmute @#{user.idname}"
      Plugin.call(:update, nil, [Message.new(:message => "@#{user.idname} のミュートを解除します",
                                             :system => true)])
      Plugin.call :tl_security_temporary_unmute, user
      @muted_users.delete(user.id) end

  end

  # この秒数の間にtl_security_update_limit回ツイートがあれば一定時間ミュート
  UserConfig[:tl_security_update_section] ||= 1

  # この回数だけtl_security_update_section秒間の間にツイートがあれば一定時間ミュート
  UserConfig[:tl_security_update_limit] ||= 5

  # 一時ミュートする時間(秒)
  UserConfig[:tl_security_mute_seconds] ||= 1800 # 30分

end

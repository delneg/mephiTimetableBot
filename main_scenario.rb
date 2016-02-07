require 'telegram/bot'
require 'open-uri'
require 'mysql'
require 'unicode_utils'
require_relative 'messages'
require_relative 'data_fetcher'
require_relative 'db_controller'
require_relative 'config'
#TODO: set timeout for request - 5 sec
#TODO: keyboards
class MainScenario



  #emoji list http://apps.timwhitlock.info/emoji/tables/unicode
  @@unreg_commands = ["\xF0\x9F\x86\x93Свободные аудитории","\xF0\x9F\x9A\xB6Карта","\xF0\x9F\x94\xA2Список функций",
                    "\xF0\x9F\x93\xB0Новости","\xF0\x9F\x98\x82Шутки","\xE2\x9D\x93Обратная связь","\xF0\x9F\x93\x9DРегистрация"]
  @@reg_commands   = ["\xF0\x9F\x93\x85Расписание","\xE2\x9C\x8FНастройки"]
  @@menu_button = "\xF0\x9F\x94\x99Меню"
  def main_keyboard
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:@@unreg_commands[0..-2].each_slice(2).to_a+@@reg_commands, one_time_keyboard: false)
  end



  def handle_message(message,id)
    found = ""
    df=DataFetcher.new
    dbc=DBController.new
    for command in @@unreg_commands+@@reg_commands
      if UnicodeUtils.downcase(message).include? UnicodeUtils.downcase(command[1..-1])
        found = command
        break
      end
    end
    puts found
    #if found == ""
      #return Messages.not_recognized_message
    #end
    case found
      when @@unreg_commands[0]#free auditories
        buildings=df.free_auditories('foobar',true)
        if buildings == Messages.server_timeout
          return buildings
        end
        dbc.update_user_context(id,'free_auditories')
        keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:buildings.each_slice(3).to_a+@@menu_button, one_time_keyboard: false)
        invite = "В течение часа будут свободны аудитории в \xF0\x9F\x8F\xA2корпусах:\n#{buildings.join(',')}\nВыберите один корпус, или все корпуса написав \"Все корпуса\""
        return invite,keyboard
        #return invite for buildings or all,keyboard, update context
      when @@unreg_commands[2]#function list
        return Messages.function_list,main_keyboard
      when @@unreg_commands[3]#news
        return df.news,main_keyboard
      when @@unreg_commands[4]#jokes
        invite = "Случайные шутки или шутки определенного преподавателя?\xF0\x9F\x8E\x93"
        keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:["Случайные","Преподаватель"], one_time_keyboard: false)
        dbc.update_user_context(id,'jokes')
        return invite,keyboard
      when @@unreg_commands[5]#feedback
        return Messages.start_message,main_keyboard
      when @@unreg_commands[6]#registration
      when @@reg_commands[0]#timetable
      when @@reg_commands[1]#settings
      else
        return context_check(message,id)
    end

  end
  def context_check(message,id)
    dbc=DBController.new
    df=DataFetcher.new
    #user_info = dbc.get_user(id)
    user_info=nil
    if user_info != nil
      if user_info[:context]=="free_auditories"

        auds = df.free_auditories(message)
        if auds == Messages.building_not_free
          dbc.update_user_context(id,'main')
          return auds
        else
          return auds,main_keyboard
        end

      elsif user_info[:context]=="timetable"
      elsif user_info[:context]=="jokes"
        if message =="Случайные"
          return df.joke,main_keyboard
        elsif message=="Преподаватель"
          invite = "Введите фамилию преподавателя\xF0\x9F\x8E\xAB"
          keyboard = Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard:true)
          dbc.update_user_context(id,'jokes_tutor')
          return invite,keyboard
        else
          return "Простите, я не понимаю. Попробуйте еще раз!\xF0\x9F\x98\xA5"
        end
      elsif user_info[:context]=="jokes_tutor"
        tutors = Messages.teachers

      elsif user_info[:context]=="registration"
      elsif user_info[:context]=="settings"
      elsif user_info[:context]=="main"
      end
    else
      return Messages.not_recognized_message
    end
  end
end



class Telegram_handler
  def mainloop
    token=Config.token
    filename = "mephiBot log #{Time.now.strftime('%d.%m.%Y %H:%M:%S')}.txt"
    admin_id=Config.admin_id
    #time options yesterday,today,tomorrow,the day after tomorrow,date
    msc=MainScenario.new
    Telegram::Bot::Client.run(token) do |bot|
      bot.listen do |message|
        begin

          if message.chat.id != admin_id
            bot.api.sendMessage(chat_id: admin_id, text: "Message from:#{message.from.username},id:#{message.chat.id}
                                               \nFirst,last name:#{message.from.first_name} #{message.from.last_name}\nText:#{message.text}")
          if message.chat.id == admin_id
            if message.text[0..8] =='broadcast'
            elsif message.text[0..8] == 'usercount'


            end
          end

          if message.text == '/start'
            bot.api.sendMessage(chat_id:message.chat.id,text:Messages.start_message, reply_markup:msc.main_keyboard)
          elsif message.text == "\xF0\x9F\x9A\xB6Карта"
            bot.api.send_photo(chat_id: message.chat.id, photo: File.new('/root/mephitimetablebot/mephimap.jpg'))
          else
            message_handling = msc.handle_message(message.text,message.chat.id)
            bot.api.sendMessage(chat_id:message.chat.id,text:message_handling[0], reply_markup:message_handling[1])
          end

        end
      end
    end
  end
  end
end

#th=Telegram_handler.new
#th.mainloop
msc = MainScenario.new
puts msc.handle_message('/регистрация',11)

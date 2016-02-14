require 'telegram/bot'
require 'open-uri'
require 'mysql'
require 'unicode_utils'
require_relative 'messages'
require_relative 'data_fetcher'
require_relative 'db_controller'
require_relative 'config'
require_relative 'timetable_fetcher'
#TODO: keyboards
#TODO: html markup
#TODO: auto-increment groups in DB
#TODO: обр. связь и св. ауитории в функциях измениь
#TODO: избранное
#TODO: teacher names(?)
class MainScenario


  #emoji list http://apps.timwhitlock.info/emoji/tables/unicode

  @@unreg_commands = ["\xF0\x9F\x86\x93Св. аудитории","\xF0\x9F\x9A\xB6Карта","\xF0\x9F\x94\xA2Функции",
                    "\xF0\x9F\x93\xB0Новости","\xF0\x9F\x98\x82Шутки","\xE2\x9D\x93Обр. связь","\xF0\x9F\x93\x85Расписание","\xF0\x9F\x93\x9DРегистрация"]
  @@reg_commands   = ["\xF0\x9F\x91\x89Моё расписaние","\xE2\x9C\x8FНастройки"]#hack used - second A in расписание is english, not rus
  @@menu_button = ["\xF0\x9F\x94\x99Меню"]

  def main_keyboard
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:(@@unreg_commands[0..-2]+@@reg_commands).each_slice(2).to_a, one_time_keyboard: false)
  end

  def handle_message(message,id)
    found = ""
    df=DataFetcher.new
    dbc=DBController.new
    for command in @@unreg_commands+@@reg_commands+@@menu_button
      if UnicodeUtils.downcase(message).include? UnicodeUtils.downcase(command[1..-1])
        found = command
        break
      end
    end
    case found
      when @@unreg_commands[0]#free auditories

        buildings=df.free_auditories('foobar',true)
        if buildings == Messages.server_timeout
          return buildings
        end
        dbc.update_user_context(id,'free_auditories')
        keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:["Все корпуса"]+buildings.each_slice(3).to_a+@@menu_button, one_time_keyboard: false)
        invite = "В течение часа будут свободны аудитории в \xF0\x9F\x8F\xA2корпусах:\n#{buildings.join(',')}\nВыберите один корпус, или все корпуса написав \"Все корпуса\""
        return invite,keyboard
        #return invite for buildings or all,keyboard, update context

      when @@unreg_commands[2]#function list

        return Messages.function_list,main_keyboard

      when @@unreg_commands[3]#news

        return df.news,main_keyboard

      when @@unreg_commands[4]#jokes

        dbc.update_user_context(id,'jokes')
        invite = "Случайные шутки или шутки определенного преподавателя?\xF0\x9F\x8E\x93"
        keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:["Случайные","Преподаватель"]+@@menu_button, one_time_keyboard: false)
        return invite,keyboard

      when @@unreg_commands[5]#feedback

        return Config.feedback,main_keyboard

      when @@unreg_commands[7]#registration

        dbc.update_user_context(id,'registration')
        invite = "Давайте вас зарегистрируем.В дальнейшем вы сможете изменить все данные в настройках.\nВы преподаватель или студент?"
        keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:["Студент","Преподаватель"]+@@menu_button, one_time_keyboard: false)
        return invite,keyboard

      when @@unreg_commands[6]#other timetable
        dbc.update_user_context(id,'timetable')
        variants = [['Группа','Преподаватель'],['Аудитория',@@menu_button[0]]]
        invite = 'Выберите, пожалуйста, тип показа расписания:'
        keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:variants, one_time_keyboard: false)
        return invite,keyboard

      when @@reg_commands[0]#my timetable
        user_info = dbc.get_user(id)
        if user_info[:data]==''
          dbc.update_user_context(id,'main')
          return Messages.please_register,main_keyboard
        end
        dbc.update_user_context(id,'timetable_other')
        variants = [["Вчера","Сегодня","Завтра"],["Послезавтра","Дата","Неделя"]]
        invite = "Вы можете получить своё расписание на вчера, сегодня, завтра, послезавтра, на неделю или на конкретную дату"
        keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:variants+@@menu_button, one_time_keyboard: false)
        return invite,keyboard


      when @@reg_commands[1]#settings

        user_info = dbc.get_user(id)
        if user_info==nil
          return Messages.please_register,main_keyboard
        elsif user_info[:data]==''
          return Messages.please_register,main_keyboard
        else
          type="#{if user_info[:type]=='1';"преподаватель" else "студент" end}"
          data_t="#{if user_info[:type]=='1';"ФИО" else "группой" end}"
          dbc.update_user_context(id,'settings')
          invite = "В данный момент вы зарегистрированы как #{type.force_encoding('UTF-8')} c #{data_t.force_encoding('UTF-8')} #{user_info[:data].force_encoding('UTF-8')}\nХотите сменить тип студент<->преподаватель или изменить свои данные(ФИО или группу)?"
          keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:["Изменить тип","Изменить данные"]+@@menu_button, one_time_keyboard: false)
          return invite,keyboard
        end

      when @@menu_button[0]#menu

        dbc.update_user_context(id,'main')
        return Messages.menu_message,main_keyboard

      else

        return context_check(message,id)

    end
  end
  def timetable_context_check(message,id,dbc,tf)
    user_info = dbc.get_user(id)

    if user_info[:context]=="timetable"
      case message
        when 'Группа'
          dbc.update_user_context(id,'timetable_group')
          variants = [["Вчера","Сегодня","Завтра"],["Послезавтра","Дата","Неделя"]]
          invite = "Вы можете получить расписание для группы на вчера, сегодня, завтра, послезавтра, на неделю или на конкретную дату"
          keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:variants+@@menu_button, one_time_keyboard: false)
          return invite,keyboard
        when 'Преподаватель'
          dbc.update_user_context(id,'timetable_tutor')
          variants = [["Вчера","Сегодня","Завтра"],["Послезавтра","Дата","Неделя"]]
          invite = "Вы можете получить расписание для преподавателя на вчера, сегодня, завтра, послезавтра, на неделю или на конкретную дату"
          keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:variants+@@menu_button, one_time_keyboard: false)
          return invite,keyboard
        when 'Аудитория'
          dbc.update_user_context(id,'timetable_auditory')
          variants = [["Вчера","Сегодня","Завтра"],["Послезавтра","Дата","Неделя"]]
          invite = "Вы можете получить расписание для аудитории на вчера, сегодня, завтра, послезавтра, на неделю или на конкретную дату"
          keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:variants+@@menu_button, one_time_keyboard: false)
          return invite,keyboard
        else
          return "Простите, я не понимаю. Попробуйте еще раз!\xF0\x9F\x98\xA5 или напишите /меню , чтобы вернуться в меню"
      end

    elsif user_info[:context]=="timetable_group" or user_info[:context]=="timetable_tutor" or user_info[:context]=="timetable_auditory"

      if user_info[:context]=="timetable_group"
        invite = "Хорошо, введите, пожалуйста, группу в формате К01-121"
      elsif user_info[:context]=="timetable_tutor"
        invite = "Введите фамилию преподавателя\xF0\x9F\x8E\xAB:"
      elsif user_info[:context]=="timetable_auditory"
        invite = "Введите аудиторию (Пример:303 или К-417,Б-100)"
      end
      variants = {"Вчера"=>"yesterday","Сегодня"=>"today","Завтра"=>"tomorrow","Послезавтра"=>"day_after_tomorrow","Дата"=>"date","Неделя"=>"week"}
      if variants[message]!=nil
        dbc.update_user_context(id,user_info[:context]+"_"+variants[message])
        if variants[message]=="date"
          invite+=",а также дату в формате дд.мм.гггг (10.02.2016) через пробел"
        end
      else
        return "Простите, я не понимаю. Попробуйте еще раз!\xF0\x9F\x98\xA5 или напишите /меню , чтобы вернуться в меню"
      end
      keyboard =Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard:true)
      return invite,keyboard
    elsif user_info[:context].include? "timetable_group_"
      check = ""
      if user_info[:context]=="timetable_group_date"
        begin
          check = message[0..message.index(' ')-1]
        rescue NoMethodError
          return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе группы - попробуйте еще раз (Пример:Ф05-120)\nЕсли проблема повторяется, напишите @TheDelneg"
        end
      else
        check = message
      end
      if dbc.groupcheck(check)
        dbc.update_user_context(id,"main")
        if user_info[:context]=="timetable_group_today"
          time=tf.time_array_form(:today)
          return tf.get_timetable(:group,message.force_encoding('UTF-8'),time),main_keyboard
        elsif user_info[:context]=="timetable_group_yesterday"
          time=tf.time_array_form(:yesterday)
          return tf.get_timetable(:group,message.force_encoding('UTF-8'),time),main_keyboard
        elsif user_info[:context]=="timetable_group_tomorrow"
          time=tf.time_array_form(:tomorrow)
          return tf.get_timetable(:group,message.force_encoding('UTF-8'),time),main_keyboard
        elsif user_info[:context]=="timetable_group_day_after_tomorrow"
          time=tf.time_array_form(:day_after_tomorrow)
          return tf.get_timetable(:group,message.force_encoding('UTF-8'),time),main_keyboard
        end
        if user_info[:context]=="timetable_group_week"
          return tf.get_week_timetable(:group,message.force_encoding('UTF-8')),main_keyboard
        elsif user_info[:context]=="timetable_group_date"
          grp = message[0..message.index(' ')-1]
          begin
            time=tf.time_for_date(message[message.index(' ')+1..-1])
          rescue ArgumentError
            return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе даты - попробуйте еще раз (Пример:23.02.2016)\nЕсли проблема повторяется, напишите @TheDelneg"
          end
          return tf.get_timetable(:group,grp.force_encoding('UTF-8'),time),main_keyboard
        end
      else
        return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе группы - попробуйте еще раз (Пример:Ф05-120)\nЕсли проблема повторяется, напишите @TheDelneg"
      end


    elsif user_info[:context].include? "timetable_auditory_"
      check = ""
      if user_info[:context]=="timetable_auditory_date"
        begin
          check = message[0..message.index(' ')-1]
        rescue NoMethodError
          return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе аудитории - попробуйте еще раз (Пример:303 или К-417,Б-100)\nЕсли проблема повторяется, напишите @TheDelneg"
        end
      else
        check = message
      end

      if Messages.auditories.include? check
        dbc.update_user_context(id,"main")
        if user_info[:context]=="timetable_auditory_today"
          time=tf.time_array_form(:today)
          return tf.get_timetable(:auditory,message.force_encoding('UTF-8'),time),main_keyboard
        elsif user_info[:context]=="timetable_auditory_yesterday"
          time=tf.time_array_form(:yesterday)
          return tf.get_timetable(:auditory,message.force_encoding('UTF-8'),time),main_keyboard
        elsif user_info[:context]=="timetable_auditory_tomorrow"
          time=tf.time_array_form(:tomorrow)
          return tf.get_timetable(:auditory,message.force_encoding('UTF-8'),time),main_keyboard
        elsif user_info[:context]=="timetable_auditory_day_after_tomorrow"
          time=tf.time_array_form(:day_after_tomorrow)
          return tf.get_timetable(:auditory,message.force_encoding('UTF-8'),time),main_keyboard
        end
        if user_info[:context]=="timetable_auditory_week"
          return tf.get_week_timetable(:auditory,message.force_encoding('UTF-8')),main_keyboard
        elsif user_info[:context]=="timetable_auditory_date"
          aud = message[0..message.index(' ')-1]
          begin
            time=tf.time_for_date(message[message.index(' ')+1..-1])
          rescue ArgumentError
            return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе даты - попробуйте еще раз (Пример:23.02.2016)\nЕсли проблема повторяется, напишите @TheDelneg"
          end
          return tf.get_timetable(:auditory,aud.force_encoding('UTF-8'),time),main_keyboard
        end
      else
        return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе аудитории - попробуйте еще раз (Пример:303 или К-417,Б-100)\nЕсли проблема повторяется, напишите @TheDelneg"
      end

    elsif user_info[:context].include? "timetable_tutor_"
      check = ""
      if user_info[:context]=="timetable_tutor_date"
        begin
          check = message[0..message.index(' ')-1]
        rescue NoMethodError
          return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе фамилии - попробуйте еще раз (Пример:Сандаков)\nЕсли проблема повторяется, напишите @TheDelneg"
        end
      else
        check = message
      end

      tutors = Messages.teachers_trunc
      found = []
      for t in tutors
        if UnicodeUtils.downcase(t[0..t.index(' ')-1])==UnicodeUtils.downcase(check) or UnicodeUtils.downcase(t)==UnicodeUtils.downcase(check)
          found.push(t)
        end
      end

      if found.count==1
        dbc.update_user_context(id,"main")
        if user_info[:context]=="timetable_tutor_today"
          time=tf.time_array_form(:today)
          return tf.get_timetable(:tutor,found[0].force_encoding('UTF-8'),time),main_keyboard
        elsif user_info[:context]=="timetable_tutor_yesterday"
          time=tf.time_array_form(:yesterday)
          return tf.get_timetable(:tutor,found[0].force_encoding('UTF-8'),time),main_keyboard
        elsif user_info[:context]=="timetable_tutor_tomorrow"
          time=tf.time_array_form(:tomorrow)
          return tf.get_timetable(:tutor,found[0].force_encoding('UTF-8'),time),main_keyboard
        elsif user_info[:context]=="timetable_tutor_day_after_tomorrow"
          time=tf.time_array_form(:day_after_tomorrow)
          return tf.get_timetable(:tutor,found[0].force_encoding('UTF-8'),time),main_keyboard
        end
        if user_info[:context]=="timetable_tutor_week"
          return tf.get_week_timetable(:tutor,found[0].force_encoding('UTF-8')),main_keyboard
        elsif user_info[:context]=="timetable_tutor_date"
          begin
            time=tf.time_for_date(message[message.index(' ')+1..-1])
          rescue ArgumentError
            return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе даты - попробуйте еще раз (Пример:23.02.2016)\nЕсли проблема повторяется, напишите @TheDelneg"
          end
          return tf.get_timetable(:tutor,found[0].force_encoding('UTF-8'),time),main_keyboard
        end
      elsif found.count>1
        dbc.update_user_context(id,'timetable_multiple_tutor_'+user_info[:context][user_info[:context].index("tutor_")+6..-1])
        if user_info[:context]=="timetable_tutor_date"
          invite = "Найдено несколько преподавателей с такой фамилией. Введите ФИО одного из них и дату через пробел (Пример:Тронин Иван Владимирович 23.02.2016):\n#{found.join(',')}"
          keyboard =Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard:true)
        else
          invite = "Найдено несколько преподавателей с такой фамилией. Выберите одного из них:\n#{found.join(',')}"
          keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:found.each_slice(2).to_a+@@menu_button, one_time_keyboard: false)
        end
        return invite,keyboard
      else
        return Messages.teacher_not_found
      end


    elsif user_info[:context].include? "timetable_multiple_tutor_"
      check = ""
      if user_info[:context]=="timetable_multiple_tutor_date"
        begin
          check = message[0..message.rindex(' ')-1]
        rescue NoMethodError
          return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку фамилии - попробуйте еще раз (Пример:Тронин Иван Владимирович 23.02.2016)\nЕсли проблема повторяется, напишите @TheDelneg"
        end
      else
        check = message
      end
      tutors = Messages.teachers_trunc
      tutors.each do |t|
        if UnicodeUtils.downcase(t)==UnicodeUtils.downcase(check)
          dbc.update_user_context(id,'main')

          if user_info[:context]=="timetable_multiple_tutor_today"
            time=tf.time_array_form(:today)
            return tf.get_timetable(:tutor,message.force_encoding('UTF-8'),time),main_keyboard
          elsif user_info[:context]=="timetable_multiple_tutor_yesterday"
            time=tf.time_array_form(:yesterday)
            return tf.get_timetable(:tutor,message.force_encoding('UTF-8'),time),main_keyboard
          elsif user_info[:context]=="timetable_multiple_tutor_tomorrow"
            time=tf.time_array_form(:tomorrow)
            return tf.get_timetable(:tutor,message.force_encoding('UTF-8'),time),main_keyboard
          elsif user_info[:context]=="timetable_multiple_tutor_day_after_tomorrow"
            time=tf.time_array_form(:day_after_tomorrow)
            return tf.get_timetable(:tutor,message.force_encoding('UTF-8'),time),main_keyboard
          end
          if user_info[:context]=="timetable_multiple_tutor_week"
            return tf.get_week_timetable(:tutor,message.force_encoding('UTF-8')),main_keyboard
          elsif user_info[:context]=="timetable_multiple_tutor_date"
            tut = message[0..message.rindex(' ')-1]
            begin
              time=tf.time_for_date(message[message.rindex(' ')+1..-1])
            rescue ArgumentError
              return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе даты - попробуйте еще раз (Пример:23.02.2016)\nЕсли проблема повторяется, напишите @TheDelneg"
            end
            return tf.get_timetable(:tutor,tut.force_encoding('UTF-8'),time),main_keyboard
          end
        end
      end
      return "Простите, я не понимаю. Попробуйте еще раз!\xF0\x9F\x98\xA5 или напишите /меню , чтобы вернуться в меню"

    elsif user_info[:context]=="timetable_other" #send after time
      case message
        when "Вчера"
          dbc.update_user_context(id,'main')
          time = tf.time_array_form(:yesterday)
          user=dbc.get_user(id)
          if user[:type]=='1'
            return tf.get_timetable(:tutor,user[:data].force_encoding('UTF-8'),time),main_keyboard
          else
            return tf.get_timetable(:group,user[:data].force_encoding('UTF-8'),time),main_keyboard
          end
        when "Сегодня"
          dbc.update_user_context(id,'main')
          time = tf.time_array_form(:today)
          user=dbc.get_user(id)
          if user[:type]=='1'
            return tf.get_timetable(:tutor,user[:data].force_encoding('UTF-8'),time),main_keyboard
          else
            return tf.get_timetable(:group,user[:data].force_encoding('UTF-8'),time),main_keyboard
          end
        when "Завтра"
          dbc.update_user_context(id,'main')
          time = tf.time_array_form(:tomorrow)
          user=dbc.get_user(id)
          if user[:type]=='1'
            return tf.get_timetable(:tutor,user[:data].force_encoding('UTF-8'),time),main_keyboard
          else
            return tf.get_timetable(:group,user[:data].force_encoding('UTF-8'),time),main_keyboard
          end
        when "Послезавтра"
          dbc.update_user_context(id,'main')
          time = tf.time_array_form(:day_after_tomorrow)
          user=dbc.get_user(id)
          if user[:type]=='1'
            return tf.get_timetable(:tutor,user[:data].force_encoding('UTF-8'),time),main_keyboard
          else
            return tf.get_timetable(:group,user[:data].force_encoding('UTF-8'),time),main_keyboard
          end
        when "Дата"
          dbc.update_user_context(id,'timetable_other_date')
          invite = "Введите дату в формате дд.мм.гггг (10.02.2016)"
          keyboard = Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard:true)
          return invite,keyboard
        when "Неделя"
          dbc.update_user_context(id,'main')
          user=dbc.get_user(id)
          if user[:type]=='1'
            return tf.get_week_timetable(:tutor,user[:data].force_encoding('UTF-8')),main_keyboard
          else
            return tf.get_week_timetable(:group,user[:data].force_encoding('UTF-8')),main_keyboard
          end
        else
          return "Простите, я не понимаю. Попробуйте еще раз!\xF0\x9F\x98\xA5 или напишите /меню , чтобы вернуться в меню"
      end
    elsif user_info[:context]=="timetable_other_date"
      begin
        time=tf.time_for_date(message)
        dbc.update_user_context(id,'main')
        user=dbc.get_user(id)
        if user[:type]=='1'
          return tf.get_timetable(:tutor,user[:data].force_encoding('UTF-8'),time),main_keyboard
        else
          return tf.get_timetable(:group,user[:data].force_encoding('UTF-8'),time),main_keyboard
        end
      rescue ArgumentError
        return "Простите, я не понимаю.Пример:10.02.2016\nПопробуйте еще раз!\xF0\x9F\x98\xA5 или напишите /меню , чтобы вернуться в меню"
      end
    end
  end
  def context_check(message,id)
    dbc=DBController.new
    df=DataFetcher.new
    tf=TimetableFetcher.new
    user_info = dbc.get_user(id)
    if user_info != nil
      if user_info[:context]=="free_auditories"

        auds = df.free_auditories(message)
        dbc.update_user_context(id,'main')
        if auds == Messages.building_not_free
          return auds
        else
          return auds,main_keyboard
        end

      elsif user_info[:context].index("timetable")!=nil

        return timetable_context_check(message,id,dbc,tf)
      elsif user_info[:context]=="jokes"
        if message =="Случайные"
          dbc.update_user_context(id,'main')
          return df.joke,main_keyboard
        elsif message=="Преподаватель"
          dbc.update_user_context(id,'jokes_tutor')
          invite = "Введите фамилию преподавателя\xF0\x9F\x8E\xAB"
          keyboard = Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard:true)
          return invite,keyboard
        else
          return "Простите, я не понимаю. Попробуйте еще раз!\xF0\x9F\x98\xA5 или напишите /меню , чтобы вернуться в меню"
        end

      elsif user_info[:context]=="jokes_tutor"

        tutors = Messages.teachers
        found = []
        for t in tutors
          if UnicodeUtils.downcase(t[0..t.index(' ')-1])==UnicodeUtils.downcase(message)
            found.push(t)
          end
        end
        if found.count==1
          dbc.update_user_context(id,'main')
          return df.joke(false,10,found[0]),main_keyboard
        elsif found.count>1
          dbc.update_user_context(id,'jokes_tutor_multiple')
          invite = "Найдено несколько преподавателей с такой фамилией. Выберите одного из них:\n#{found.join(',')}"
          keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:found.each_slice(2).to_a+@@menu_button, one_time_keyboard: false)
          return invite,keyboard
        else
          return Messages.teacher_not_found
        end

      elsif user_info[:context]=="jokes_tutor_multiple"

        tutors = Messages.teachers
        for t in tutors
          if UnicodeUtils.downcase(t)==UnicodeUtils.downcase(message)
            dbc.update_user_context(id,'main')
            return df.joke(false,10,t),main_keyboard
          end
        end
        return "Простите, я не понимаю. Попробуйте еще раз!\xF0\x9F\x98\xA5 или напишите /меню , чтобы вернуться в меню"

      elsif user_info[:context]=="registration"

        if message=="Студент"
          dbc.update_user_context(id,'registration_student')
          invite = "Хорошо, введите, пожалуйста, свою группу в формате К01-121"
          keyboard = Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard:true)
          return invite,keyboard
        elsif message=="Преподаватель"
          dbc.update_user_context(id,'registration_tutor')
          invite = "Хорошо, введите, пожалуйста, свои ФИО в формате Фамилия И.О.(Пример:Теляковский Д.С.)"
          keyboard = Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard:true)
          return invite,keyboard
        else
          return "Простите, я не понимаю. Попробуйте еще раз!\xF0\x9F\x98\xA5"
        end
      elsif user_info[:context]=="registration_student"

        if dbc.groupcheck(message)
          dbc.update_user_all(id,"main",false,message)
          invite = "Поздравляю, вы зарегистрированы! Посмотрите \xF0\x9F\x94\xA2 /Функции"
          return invite,main_keyboard
        else
          return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе группы - попробуйте еще раз (Пример:Ф05-120)\nЕсли проблема повторяется, напишите @TheDelneg"
        end

      elsif user_info[:context]=="registration_tutor"

        if dbc.familynamecheck(message)
          dbc.update_user_all(id,"main",true,message)
          invite = "Поздравляю, вы зарегистрированы! Посмотрите \xF0\x9F\x94\xA2 /Функции"
          return invite,main_keyboard
        else
          return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе ФИО - попробуйте еще раз (Пример:Сандаков Е.Б.)\nЕсли проблема повторяется, напишите @TheDelneg"
        end

      elsif user_info[:context]=="settings"

        if message=="Изменить тип"
          dbc.update_user_type(id)
          now = dbc.get_user(id)
          if now[:type]=='1'
            invite = "Тип успешно изменен\xE2\x9C\x85\nТеперь вы преподаватель\nВведите, пожалуйста, свои ФИО в формате Фамилия И.О.(Пример:Теляковский Д.С.)"
          else
            invite = "Тип успешно изменен\xE2\x9C\x85Теперь вы студент\nВведите, пожалуйста, свою группу в формате К01-121"
          end
          dbc.update_user_context(id,'settings_data')
          keyboard = Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard:true)
          return invite,keyboard

        elsif message=="Изменить данные"
          dbc.update_user_context(id,'settings_data')
          user = dbc.get_user(id)
          if user[:type]=='1'
            invite = "Хорошо, введите, пожалуйста, свои ФИО в формате Фамилия И.О.(Пример:Теляковский Д.С.)"
          else
            invite = "Хорошо, введите, пожалуйста, свою группу в формате К01-121"
          end
          keyboard = Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard:true)
          return invite,keyboard
        else
          return "Простите, я не понимаю. Попробуйте еще раз!\xF0\x9F\x98\xA5 или напишите /меню , чтобы вернуться в меню"
        end

      elsif user_info[:context]=="settings_data"

        user = dbc.get_user(id)
        if user[:type]=='1'
          check = dbc.familynamecheck(message)
        else
          check =dbc.groupcheck(message)
        end
        if check
          dbc.update_user_data(id,message)
          dbc.update_user_context(id,'main')
          invite = "Данные успешно изменены на "+message
          return invite,main_keyboard
        else
          return "\xF0\x9F\x98\xA5Похоже,вы допустили ошибку при вводе данных - попробуйте еще раз \nЕсли проблема повторяется, напишите @TheDelneg"
        end

      elsif user_info[:context]=="main"
        return Messages.not_recognized_message,main_keyboard
      end

    else
      return Messages.not_recognized_message
    end
  end
end



class Telegram_handler
  def mainloop
    token=Config.token

    admin_id=Config.admin_id
    #time options yesterday,today,tomorrow,the day after tomorrow,date
    msc=MainScenario.new
    dbc=DBController.new
    file = "mephiBot log.txt"
    Telegram::Bot::Client.run(token,logger: Logger.new(file)) do |bot|

      bot.listen do |message|
        begin
          bot.logger.info("Message from username:#{message.from.username},id:#{message.chat.id} First,last name:#{message.from.first_name} #{message.from.last_name} Text:#{message.text}")
          if message.chat.id == admin_id
            bot.logger.info("Detected admin message")
              if message.text[0..8] =='broadcast'

                broadcast_text = message.text[10..-1]
                users = dbc.get_all_users
                bot.logger.info("Sending broadcast message to #{users.count} users")
                users.each do |u|
                  bot.api.send_message(chat_id:u[:id],text:broadcast_text, reply_markup:msc.main_keyboard)
                end
              elsif message.text[0..8] == 'usercount'
                users = dbc.usercount
                bot.logger.info("Sending usercount")
                bot.api.send_message(chat_id: admin_id, text: users)
              elsif message.text[0..4]== 'query'
                query = message.text[6..-1]
                bot.logger.info("Doing query #{query}")
                bot.api.send_message(chat_id: admin_id, text: dbc.do_db_query(query))
              elsif message.text[0..3]=='logs'
                bot.api.send_document(chat_id: admin_id, document:File.new(file))
              elsif message.text[0..8] == 'functions'
                bot.logger.info("Sending functions")
                bot.api.send_message(chat_id: admin_id, text: "broadcast messagetext,usercount,query querytext,logs,functions")
              end
          end

          if message.text == '/start'
            bot.logger.info("Sending start message reply")
              bot.api.send_message(chat_id:message.chat.id,text:Messages.start_message, reply_markup:msc.main_keyboard,disable_web_page_preview:true)
              bot.api.send_message(chat_id:message.chat.id,text:Messages.in_development, reply_markup:msc.main_keyboard,disable_web_page_preview:true)
          elsif UnicodeUtils.downcase(message.text[0..4])==UnicodeUtils.downcase("опрос")
            bot.logger.info("Survey answer detected")
            bot.api.send_message(chat_id:message.chat.id,text:Messages.survey, reply_markup:msc.main_keyboard,disable_web_page_preview:true)
            bot.api.send_message(chat_id: admin_id, text: "Survey answer from username:#{message.from.username},id:#{message.chat.id} First,last name:#{message.from.first_name} #{message.from.last_name}\nText:#{message.text}")
          elsif UnicodeUtils.downcase(message.text).include? UnicodeUtils.downcase("Карта")
            #path = '/Users/Delneg/Downloads/mephimap.jpg'
            path = '/root/mephitimetablebot/mephimap.jpg'
            bot.logger.info("Sending map from the path #{path}")
              bot.api.send_photo(chat_id: message.chat.id, photo: File.new(path))
          else
              bot.logger.info("Sending message to message handling")
              message_handling = msc.handle_message(message.text,message.chat.id)

              if message_handling.is_a?([].class)
                register_success="Поздравляю, вы зарегистрированы! Посмотрите \xF0\x9F\x94\xA2 /Функции"
                if message_handling[0]==register_success
                  bot.api.send_message(chat_id: admin_id, text: "New user - username:#{message.from.username},id:#{message.chat.id} First,last name:#{message.from.first_name} #{message.from.last_name} Data:#{message.text}")
                end
                bot.api.send_message(chat_id:message.chat.id,text:message_handling[0], reply_markup:message_handling[1],disable_web_page_preview:true)
              else
                bot.api.send_message(chat_id:message.chat.id,text:message_handling,disable_web_page_preview:true)
              end

              bot.logger.info("Sent message handling result")
          end

        rescue Exception => e
          bot.logger.warn("Exception #{e},backtrace:\n#{e.backtrace.join("\n")}")
        end
    end
  end
  end
end
#OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
th=Telegram_handler.new
th.mainloop


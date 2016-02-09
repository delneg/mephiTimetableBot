class TimetableEvent
  def start_time
    @start_time
  end
  def end_time
    @end_time
  end
  def id
    @id
  end
  def title
    @title
  end
  def type
    @type
  end
  def groups
    @groups
  end
  def teachers
    @teachers
  end
  def auditories
    @auditories
  end
  def note
    @note
  end
  def initialize(json)
    @start_time = Integer(json['start'])
    @end_time = Integer(json['end'])
    @id = Integer(json['id'])
    @title = json['title']
    @type = json['type']
    @groups = json['groups'].split(':')
    @teachers = json['teachers']
    @auditories = json['auditories']
    @note = json['note']
  end
  def to_s
    "#{(Time.at(@start_time)-3*60*60).strftime("%H:%M")}-#{(Time.at(@end_time)-3*60*60).strftime("%H:%M")} #{@title}, #{type} ведет #{@teachers}  в #{@auditories.gsub(":",",")}   Примечание:#{note}"
  end
  def allinfo
    "#{(Time.at(@start_time)-3*60*60).strftime("%H:%M")}-#{(Time.at(@end_time)-3*60*60).strftime("%H:%M")}  #{@title} - это  #{@type}\nПроходит в #{@auditories.join(',')} у групп #{@groups},занятие ведет(ут) #{@teachers} \nПримечание - #{@note} \n"
  end
end
class TimetableFetcher
  #variants = ['Мое сегодня','Группа','Преподаватель','Аудитория','Другие']
  def group_string_to_group_with_year(group_string)
    number = group_string[1..2].to_i
    faculty = group_string[0]
    else_left = group_string[3..-1]
    current_year = Integer(Date.today.strftime("%Y"))
    current_month = Integer(Date.today.strftime("%m")[1])
    if current_month < 9
      start_year=current_year-(number/2)
    else
      start_year=current_year-((number-1)/2)
    end
    "#{faculty}#{else_left}/#{String(start_year)}"
  end
  def time_for_date(date_string)
    date = Date.strptime(date_string,format="%d.%m.%Y")
    start_time = date.to_time.to_i
    end_time = (date + 1).to_time.to_i
    [start_time,end_time]
  end
  def get_timetable(type,data,time_arr)
    start_time = time_arr[0]
    end_time = time_arr[1]
    case type
      when :auditory
        url = "http://timetable.mephist.ru/getEvents.php?rType=json&start=#{start_time}&end=#{end_time}&auditoryName=#{data}"
      when :tutor
        url = "http://timetable.mephist.ru/getEvents.php?rType=json&start=#{start_time}&end=#{end_time}&teacherName=#{data}"
      when :group
        url = "http://timetable.mephist.ru/getEvents.php?rType=json&start=#{start_time}&end=#{end_time}&groupName=#{group_string_to_group_with_year(data)}"
      else
        url=""
    end
    encoded_url = URI.encode(url)
    begin
      events = JSON.parse(open(encoded_url,:read_timeout=>7).read)
    rescue Exception => e
      puts e
      return Messages.server_timeout
    end
    events_array = []
    for thing in events
      events_array.push(TimetableEvent.new(thing).to_s)
    end
    return_string =events_array.join("\n")
    if return_string==''
      return_string=Messages.no_classes
    end
    return_string
  end
  def get_week_timetable(type,data)
    now = Date.today
    monday = now - (now.wday - 1) % 7
    events_hash={}
    for i in 0..6
      start_time,end_time = time_for_date((monday+i).strftime("%d.%m.%Y"))
      case type
        when :auditory
          url = "http://timetable.mephist.ru/getEvents.php?rType=json&start=#{start_time}&end=#{end_time}&auditoryName=#{data}"
        when :tutor
          url = "http://timetable.mephist.ru/getEvents.php?rType=json&start=#{start_time}&end=#{end_time}&teacherName=#{data}"
        when :group
          url = "http://timetable.mephist.ru/getEvents.php?rType=json&start=#{start_time}&end=#{end_time}&groupName=#{group_string_to_group_with_year(data)}"
        else
          url=""
      end
      encoded_url = URI.encode(url)
      begin
        events = JSON.parse(open(encoded_url,:read_timeout=>7).read)
      rescue Exception => e
        puts e
        return Messages.server_timeout
      end
      events_array = []
      events.each do |evnt|
        events_array.push(TimetableEvent.new(evnt).allinfo)
      end
      days = ["Понедельник","Вторник","Среда","Четверг","Пятница","Суббота","Воскресенье"]
      events_hash["#{days[i]}"]=events_array
    end
    if events_hash.values==[[],[],[],[],[],[],[]]
      return Messages.no_classes
    end
    return_string=""
    events_hash.each do |key, value|

      return_string+= "#{"="*key.length}\n#{key}\n#{"="*key.length}\n#{value.join("\n")}\n"
    end
    return_string
  end
  def time_array_form(type)
    start_time = 0
    end_time= 0
    case type
      when :today
        start_time = Date.today.to_time.to_i
        end_time = (Date.today + 1).to_time.to_i
      when :tomorrow
        start_time = (Date.today + 1).to_time.to_i
        end_time = (Date.today + 2).to_time.to_i
      when :yesterday
        start_time = (Date.today - 1).to_time.to_i
        end_time = Date.today.to_time.to_i
      when :day_after_tomorrow
        start_time = (Date.today + 2).to_time.to_i
        end_time = (Date.today + 3).to_time.to_i
      when :week
        now = Date.today
        sunday = now - now.wday+8
        monday = now - (now.wday - 1) % 7
        start_time = monday.to_time.to_i
        end_time = sunday.to_time.to_i
      else
        ''
    end
    [start_time,end_time]
  end
end
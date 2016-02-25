require 'multi_xml/parsers/nokogiri'
require 'open-uri'
require 'time'
require 'msgpack'
require 'parallel'
require 'eventmachine'
class MephiHomeParser
  def weekday_number_to_rus(number)
    case number
      when '1'
        return "Понедельник"
      when '2'
        return "Вторник"
      when '3'
        return "Среда"
      when '4'
        return "Четверг"
      when '5'
        return "Пятница"
      when '6'
        return "Суббота"
      when '7'
        return "Воскресенье"
      else
        return nil
    end
  end
  def weekday_rus_to_number(weekday)
    case weekday
      when "Понедельник"
        return 1
      when "Вторник"
        return 2
      when "Среда"
        return 3
      when "Четверг"
        return 4
      when "Пятница"
        return 5
      when "Суббота"
        return 6
      when "Воскресенье"
        return 7
      else
        return nil
    end
  end
  def pretty_print_timetable(event)
    #always  - time,oddness,lesson_name,type
    #sometimes - tutor,place,dates,special
    #if five_days; (five_days.to_f/all.count)*100 else 0 end
    returned_string="#{event['time']} #{event['name']}\n#{event['type']}, проходит:#{event['oddness']}"
    if event['tutor']
      returned_string+=",ведёт #{event['tutor']['name']}"
    end
    if event['place']
      returned_string+=",в #{event['place']['name']}"
    end
    if event['dates']
      returned_string+=", в даты #{event['dates']}"
    end
    if event['special']
      returned_string+="\nДополнительно:#{event['special']}"
    end
    returned_string+="\n"
  end
  def parse_faculties
    url='https://home.mephi.ru/study_groups'
    page = Nokogiri::HTML(open(url))
    items =  page.css('ul').select{|link| link['class'] == "nav nav-tabs"}
    objects = []
    fcs=items[0].css('li')
    fcs.each do |f|
      a=f.css('a')[0]
      objects.push(:url=>a['href'],:name=>a.text)
    end
    objects
  end
  def parse_groups(url)
    base_url="https://home.mephi.ru"
    page = Nokogiri::HTML(open(base_url+url))
    divs = page.css('div').select{|link| link['class'] == "col-sm-2"}
    groups=[]
    divs.each do |d|
      group_div = d.css('div').select{|link| link['class'] == "list-group"}
      if group_div.count != 0
        group_a_s=group_div[0].css('a')
        group_a_s.each do |a|
          groups.push(:url=>a['href'],:name=>a.text)
        end
      end
    end
    groups
  end
  def parse_all_groups
    groups=[]
    parse_faculties.each do |faculty|
      groups.push(parse_groups(faculty[:url]))
    end
    groups
  end
  def store_all_groups_timetable(logger)
    groups_timetable=[]
    logger.info("Parsing groups began at #{Time.now.to_s}")
    beginning_time = Time.now
    faculty_groups = parse_all_groups
    end_time = Time.now
    logger.info("Parsing groups finished #{(end_time - beginning_time)*1000} milliseconds")
    all_begin_time=Time.now
    faculty_groups.each do |groups|
      Parallel.each(groups, :in_threads => 10) do |gr|
        #puts "Parsing timetable for group #{gr},\t\t#{Time.now.to_s}"
        beginning_time = Time.now
        groups_timetable.push(:name=>gr[:name],:url=>gr[:url],:timetable=>parse_timetable(gr[:url]))
        end_time = Time.now
        #puts "Finished parsing group #{gr[:name]} in #{(end_time - beginning_time)*1000} milliseconds"
      end
    end
    all_end_time=Time.now
    filename='groups_timetable.msgpack'
    check_for_old(filename)
    File.write(filename, groups_timetable.to_msgpack)
    logger.info("Finished all groups in #{(all_end_time - all_begin_time)*1000} milliseconds")
    filename
  end
  def store_all_tutors_timetable(logger)
    tutors_timetable=[]
    logger.info("Parsing tutors began at #{Time.now.to_s}")
    beginning_time = Time.now
    tutors = parse_all_tutors
    end_time = Time.now
    logger.info("Parsing tutors finished #{(end_time - beginning_time)*1000} milliseconds")
    all_begin_time=Time.now
    Parallel.each(tutors, :in_threads => 10) do |tutor|
      #puts "Parsing timetable for group #{gr},\t\t#{Time.now.to_s}"
      beginning_time = Time.now
      tutors_timetable.push(:name=>tutor[:name],:url=>tutor[:url],:timetable=>parse_timetable(tutor[:url]))
      end_time = Time.now
     # puts "Finished parsing tutor #{tutor[:name]} in #{(end_time - beginning_time)*1000} milliseconds"
    end
    all_end_time=Time.now
    filename='tutors_timetable.msgpack'
    check_for_old(filename)
    File.write(filename, tutors_timetable.to_msgpack)
    logger.info("Finished all tutors in #{(all_end_time - all_begin_time)*1000} milliseconds")
    filename
  end
  def check_for_old(filename)
    if File.exist?(filename)
      new=File.basename(filename,".*")+"_old"+File.extname(filename)
      if File.exist?(new)
        File.delete(new)
      end
      File.rename(filename, new)
    end
  end
  def parse_all_tutors
    tutors=[]
    parse_tutors_letters.each do |letter|
      Parallel.each(parse_tutor_letter_pages(letter[:url]), :in_threads => 10) do |page|
        beginning_time = Time.now
        tutors.push(*parse_tutors_from_page(page))
        end_time = Time.now
        puts "Parsed tutors for page #{page} in  #{(end_time - beginning_time)*1000} milliseconds"
      end
    end
    tutors
  end

  def parse_tutors_letters
    url='https://home.mephi.ru/tutors'
    page = Nokogiri::HTML(open(url))
    nav =  page.css('nav').select{|link| link['class'] == "text-center"}[0]
    ul =  nav.css('ul').select{|link| link['class'] == "pagination"}[0]

    objects = []
    letters=ul.css('li')
    letters.each do |f|
      a=f.css('a')[0]
      objects.push(:url=>a['href'],:name=>a.text)
    end
    objects
  end
  def parse_tutor_letter_pages(url)
    base_url="https://home.mephi.ru"
    page = Nokogiri::HTML(open(base_url+url))
    ul = page.css('ul').select{|link| link['class'] == "pagination"}[1]
    if ul
      last = ul.css('li').select{|link| link['class'] == "last"}[0].css('a')[0]
      pages=[]
      for i in 1..Integer(last['href'][last['href'].index('page=')+5])
        url_now=last['href']
        url_now[last['href'].index('page=')+5]=String(i)
        pages.push(url_now)
      end
      return pages
    else
      return [url]
    end
  end
  def parse_tutors_from_page(url)
    base_url="https://home.mephi.ru"
    page = Nokogiri::HTML(open(base_url+url))
    list= page.css('div').select{|link| link['class'] == "list-group"}[0]
    tutors=[]
    list.css('a').each do |tutor|
      tutors.push(:url=>tutor['href'],:name=>tutor.text)
    end
    tutors
  end


  def parse_timetable(url)
    #свойства - тип(лекция, лаба, практика), время, четные/нечетные/все,
    base_url="https://home.mephi.ru"
    all_lessons={}
    page = Nokogiri::HTML(open(base_url+url))
    h3s = page.css('h3').select{|link| link['class'] == "lesson-wday"}
    divs = page.css('div').select{|link| link['class'] == "list-group"}
    h3s.each_with_index do |day_name,i|
      day_lessons=[]
      day_classes=divs[i].css('div').select{|link| link['class'] == "list-group-item"}
      day_classes.each do |lesson|
        lesson_object={}
        time=lesson.css('div').select{|link| link['class'] == "lesson-time"}[0].text
        lesson_main=lesson.css('div').select{|link| link['class'] == "lesson-lessons"}[0]
        lesson_with_type=lesson_main.css('div').select{|link| link['class'] == "lesson lesson-lecture" or link['class'] == "lesson lesson-practice" \
        or link['class'] == "lesson lesson-lab" or link['class'] == "lesson lesson-default"or link['class'] == "lesson"}[0]

        place_a=lesson_with_type.css('a').select{|link| link['class'] == "text-nowrap"}[0]
        if place_a
          place={:url=>place_a['href'],:name=>place_a.text}
          lesson_object[:place]=place
        end
        oddness=lesson_with_type.css('span').select{|link| link['data-toggle'] == "tooltip"}[0]['title']


        #if place[:name]=="Б-215"
        #end

        lesson_name=""
        lesson_with_type.children.each do |c|
          if c.class == Nokogiri::XML::Text and c.text != "\n"
            lesson_name=c.text.gsub("\n","")
            break
          end
        end
        lesson_object[:name]=lesson_name

        tutor_a=lesson_with_type.css('a').select{|link| link['class'] == "text-nowrap"}[1]
        if tutor_a
          tutor={:url=>tutor_a['href'],:name=>tutor_a.text}
          lesson_object[:tutor]=tutor
        end
        lesson_object[:time]=time
        lesson_object[:oddness]=oddness
        div_special = lesson_with_type.css('div').select{|link| link['class'] == "label label-gray" or link['class']=="label label-pink"}[0]
        if div_special
          lesson_object[:special]=div_special['title']
        end
        lesson_dates = lesson_with_type.css('span').select{|link| link['class'] == "lesson-dates"}[0]
        if lesson_dates
          lesson_object[:dates]=lesson_dates.text.gsub("\n","")
        end


        if lesson_with_type['class']=="lesson lesson-lab"
          lesson_object[:type]="Лабораторная"
        elsif lesson_with_type['class']=="lesson lesson-lecture"
          lesson_object[:type]="Лекция"
        elsif lesson_with_type['class']=="lesson lesson-practice"
          lesson_object[:type]="Практика"
        elsif lesson_with_type['class']=="lesson lesson-default"
          lesson_object[:type]="Обычное"
        elsif lesson_with_type['class']=="lesson"
          lesson_object[:type]="Резерв"
        end
        day_lessons.push(lesson_object)
      end
      all_lessons[day_name.text.gsub("\n","")]=day_lessons
    end
    all_lessons
  end
  def get_timetable(type,data,time,date=nil)
    # return codes
    # string - all ok
    # -1 - file not found
    # -2 - no data matching
    # -3 - no classes for the time
    # -4 - wrong time
    # -5 - wrong type
    # -6 - wrong date
    case type
      when :auditory
        filename='auditories_timetable.msgpack'
      when :tutor
        filename='tutors_timetable.msgpack'
      when :group
        filename='groups_timetable.msgpack'
      else
        return -5
    end
    begin
      tmt=MessagePack.unpack(File.read(filename))
    rescue Exception
      return -1
    end
    if time==:yesterday or time==:today or time==:tomorrow or time==:day_after_tomorrow or time==:date
      case time
        when :yesterday
          day = (Date.today-1).strftime("%u")
        when :today
          day = Date.today.strftime("%u")
        when :tomorrow
          day = (Date.today+1).strftime("%u")
        when :day_after_tomorrow
          day = (Date.today+2).strftime("%u")
        when :date
          begin
            day = Date.strptime(date,format="%d.%m.%Y")
            day=day.strftime("%u")
          rescue Exception
            return -6
          end
        else
          day = -1
      end
      day_timetable = tmt.select{|s| UnicodeUtils.downcase(s['name'])==UnicodeUtils.downcase(data)}
      if day_timetable==[]
        similar = tmt.select{|s| UnicodeUtils.downcase(s['name']).include? UnicodeUtils.downcase(data)}
        if similar==[]
          return -2
        else
          day_timetable=similar
        end
      end
      if day_timetable!=[]
        needed_day_timetable=day_timetable[0]['timetable'][weekday_number_to_rus(day)]
        if needed_day_timetable
          returned_string=""
          returned_string+= "#{'='*weekday_number_to_rus(day).length}\n#{weekday_number_to_rus(day)}\n#{'='*weekday_number_to_rus(day).length}\n"
          needed_day_timetable.each do |ev|
            returned_string+= pretty_print_timetable(ev)
          end
          return returned_string
        else
          return -3
        end
      end
    elsif time==:week
      day_timetable = tmt.select{|s| UnicodeUtils.downcase(s['name'])==UnicodeUtils.downcase(data)}
      if day_timetable==[]
        similar = tmt.select{|s| UnicodeUtils.downcase(s['name']).include? UnicodeUtils.downcase(data)}
        if similar==[]
          return -2
        else
          day_timetable=similar
        end
      end
        returned_string=""
        day_timetable[0]['timetable'].each do |day,tm|
          returned_string+= "#{'='*day.length}\n#{day}\n#{'='*day.length}\n"
          tm.each do |ev|
            returned_string+= pretty_print_timetable(ev)
          end
        end
        return returned_string
    else
      return -4
    end
  end
end

#m=MephiHomeParser.new
#m.check_for_old("groups_timetable.msgpack")
#puts m.get_timetable(:group,"У06-712",:date,"23.02.2016")
# n = 0
# EventMachine.run {
# timer = EventMachine::PeriodicTimer.new(5) do
#   puts "the time is #{Time.now}"
#   Thread.new do
#     m.store_all_tutors_timetable
#     m.store_all_groups_timetable
#   end
#   timer.cancel
# end
# }
#puts m.store_all_groups_timetable
#puts m.parse_all_groups
#puts m.parse_timetable('/tutors/313').flatten
#puts m.parse_timetable('/study_groups/1018/schedule').flatten
#groups = m.parse_all_groups
  #faculty_groups.each do |gr|
    #m.parse_timetable(gr[:url])
  #end




#puts "#{ (seven_days.to_f/all.count)*100}% groups have 7 days lessons\n#{ (six_days.to_f/all.count)*100}% groups have 6 days lessons\n#{if five_days; (five_days.to_f/all.count)*100 else 0 end }% groups have 5 days lessons\n#{if four_days; (four_days.to_f/all.count)*100 else 0 end }% groups have 4 days lessons\n#{if three_days; (three_days.to_f/all.count)*100 else 0 end }% groups have 3 days lessons\n#{if two_days; (two_days.to_f/all.count)*100 else 0 end }% groups have 2 days lessons\n#{if one_day; (one_day.to_f/all.count)*100 else 0 end }% groups have 1 day lessons\n"
#end
#m.store_all_groups_timetable
# Thread.new do
#   m.store_all_tutors_timetable
# end
# Thread.new do
#   m.store_all_groups_timetable
# end
#
# i=0
# while true
#   puts "I'm alive, time passed = #{i*5}\n"
#   i+=1
#   sleep(5)
# end

#puts m.parse_tutors_from_page(m.parse_tutor_letter_pages(m.parse_tutors_letters[0][:url])[0])
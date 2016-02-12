require_relative 'messages'
require 'vkontakte_api'
require 'googl'
require 'uri'
class Joke
  def id
    @id
  end
  def unid
    @unid
  end
  def teacher
    @teacher
  end
  def rating
    @rating
  end
  def date
    @date
  end
  def text
    @text
  end
  def remove_html_tags(str)
    return str.gsub("\\\\","\\").gsub("&quot;",'"').gsub("<br><br/>","\n").gsub("\\\"","\"").gsub("<br/>","\n").gsub("&lt;","<").gsub("&gt;",">")
  end
  def initialize(json)
    @id = Integer(json['id'])
    @unid = json['unid']
    @teacher=json['teacher']
    @rating=Float(json['rating'])
    @date=json['date']
    @text=remove_html_tags(json['text'])
  end
  def to_s
    star = "\xE2\xAD\x90"
    return "#{@teacher} (#{@date}|#{star}#{@rating}):\n#{@text}"
  end
end
class DataFetcher
  def joke(random=true,count=10,teacher="Теляковский")
    #order может быть:
    #rand,date,rating
    if random
      url = "http://bash.mephist.ru/api/&order=rand&count=#{String(count)}"
    else
      url = "http://bash.mephist.ru/api/&order=rating&count=#{String(count)}&teacher=#{teacher}"
    end

      encoded_url = URI.encode(url)
      begin
        data = open(encoded_url,:read_timeout=>7).read
      rescue Exception => e
        puts e
        return Messages.server_timeout
      end
      data= JSON.parse(data.gsub("\n\n","").gsub("\t",""))
      returned_string=""
      data.each do |perl|
        j=Joke.new(perl)
        returned_string+=j.to_s
        returned_string+="\n\n"
      end
      return returned_string
  end
  def news
    @vk = VkontakteApi::Client.new
    got_news = @vk.wall.get(owner_id:-12742657,filter:'owner',count:3,version:5.44)
    returned_string = ""
    for n in got_news[1..-1]
      link = "https://vk.com/vmephi?w=wall-12742657_#{n.id}"
      time = Time.at(n.date).strftime('%d.%m.%Y %H:%M')
      text = n.text.gsub("<br>","\n")
      begin
      text_links = URI.extract(text)
      replacements = []
      for l in text_links[0..-1]
        url = Googl.shorten(l,nil,Config.google_api_key).short_url
        replacements.push([l,url])
      end
      replacements.each {|replacement| text.gsub!(replacement[0], replacement[1])}
      rescue Exception => e
        puts e.to_s
      ensure
        returned_string+="#{'-'*5}Новость от #{time}\nСсылка: #{link}\n#{text}\n"
      end
    end
    returned_string
  end
  def free_auditories(building,only_buildings=false)
    start_time = Time.now.to_i
    end_time = (Time.now+60*60).to_i
    url = "http://timetable.mephist.ru/getEvents.php?rType=json&get=freeAuditories&start=#{start_time}&end=#{end_time}"
    encoded_url = URI.encode(url)
    begin
      data = JSON.parse(open(encoded_url,:read_timeout=>7).read)
    rescue Exception => e
      puts e
      return Messages.server_timeout
    end
    proper_auditories=["316", "323", "325", "402", "403", "404", "405", "406", "407", "408", "А-100", "А-105", "А-112", "А-119", "А-119а", "А-204", "А-205", "А-207", "А-209", "А-210", "А-212", "А-215", "А-218", "А-220", "А-223", "А-226", "А-301а", "А-304", "А-306", "А-308", "А-312", "А-316", "А-320", "А-403", "А-408", "А-412", "Б-036", "Б-039", "Б-100", "Б-103", "Б-105", "Б-106А", "Б-108", "Б-109", "Б-110", "Б-118", "Б-120", "Б-124/126", "Б-201", "Б-202", "Б-204", "Б-205", "Б-207", "Б-208", "Б-210", "Б-211", "Б-212", "Б-212ст", "Б-213", "Б-214", "Б-215", "Б-216", "Б-217", "Б-218", "Б-219", "Б-221", "Б-301", "Б-303", "Б-304", "Б-314а", "Б-315", "Б-316", "Б-317", "Б-318", "Б-319", "Б-401", "Б-403", "В-103", "В-106", "В-109", "В-114", "В-115", "В-116", "В-117", "В-118", "В-119", "В-201", "В-204б", "В-204в", "В-205", "В-205А", "В-210а", "В-210б", "В-215", "В-306", "В-315", "В-403", "В-404", "В-407", "В-408", "В-409", "В-411", "В-413", "В-416", "В-417", "В-418", "Д-002", "Д-004", "Д-101", "Д-116", "Д-302", "Д-303", "Д-304", "Д-305", "Д-310", "Д-311", "Д-312", "Д-314", "Д-405", "Д-407", "Д-408", "Д-410", "Д-418", "И-105", "И-108", "И-110", "И-114", "И-201", "И-205", "И-206а", "И-207", "И-209", "И-210", "И-211", "И-212", "И-308", "И-309", "К-1006", "К-1009", "К-1015", "К-1017", "К-1018", "К-102", "К-109", "К-110", "К-1102", "К-1109", "К-111", "К-1117", "К-1119", "К-112", "К-1206", "К-1218", "К-1219", "К-1220", "К-202", "К-205", "К-206", "К-207", "К-208", "К-210", "К-211", "К-212", "К-213", "К-302", "К-305", "К-306", "К-307", "К-308", "К-310", "К-315", "К-402", "К-407", "К-409", "К-411", "К-414", "К-415", "К-417", "К-418", "К-710", "К-714а", "К-715", "К-805", "К-806", "К-807", "К-807а", "К-815", "К-819", "К-822", "К-823", "К-911", "К-914", "К-923", "К-924", "Т-100а", "Т-100б", "Т-101", "Т-102", "Т-107", "Т-108", "Т-201", "Т-204", "Т-204В", "Т-205", "Т-208", "Т-209", "Т-211", "Т-213", "Т-214", "Т-215", "Т-301", "Т-306", "Т-308", "Т-314", "Э-003", "Э-103", "Э-112", "Э-204", "Э-207", "Э-212", "Э-213", "Э-214", "Э-220", "Э-307", "Э-318", "Э-402", "Э-403", "Э-406", "Э-409", "Э-409А", "Э-411", "Э-430"]
    free_auditories=[]
    data.each do |auditory|
      if proper_auditories.include? auditory["name"]
        free_auditories.push(auditory["name"])
      end
    end

    buildings = []
    for i in 0..free_auditories.count-1
      this = free_auditories[i]
      if !(this.include? "-") and i==0
        buildings.push("Главный")
      end
      if this.include? "-"
        if this[0] != free_auditories[i-1][0]
          buildings.push(this[0])
        end
      end
    end
    if only_buildings
      return buildings
    end
    if building == "Все корпуса"

      returned_string=""
      for i in 0..free_auditories.count-1
        this = free_auditories[i]
        if !(this.include? "-") and i==0
          returned_string+="Главный корпус\n"
        end

        if this.include? "-"
          if this[0] != free_auditories[i-1][0]
            returned_string+="\nКорпус #{this[0]}\n"
          end
        end
        returned_string+="#{this}\t"
      end

    else

      if not buildings.include? building
        return Messages.building_not_free
      else
        returned_string="\xF0\x9F\x8F\xA2"+building+"\n"
        for i in 0..free_auditories.count-1
          this = free_auditories[i]
          if building == "Главный"
            if !(this.include? "-")
              returned_string+="#{this}\t"
            end
          else
            if this.include? "-" and this[0]==building
              returned_string+="#{this}\t"
            end
          end
        end
      end
    end
    return returned_string
  end
end


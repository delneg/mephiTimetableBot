require_relative 'config'
class DBController
  @@user = Config.user
  @@host = Config.host
  @@password = Config.password
  @@dbname = Config.dbname
  def get_user(id)
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      rs = con.query("SELECT * FROM TELEGRAMUSERS WHERE ChatId='#{id}';")
      row= rs.fetch_row
      if row==nil
        return nil
      end
      return {:id=>row[0],:context=>row[1],:type=>row[2],:data=>row[3]}
    rescue Mysql::Error => e
      return [e.errno,e.error]
    ensure
      con.close if con
    end
  end
  def update_user_context(id,context)
      if get_user(id)==nil
        res = add_user(id,context)
      end
      begin
        con = Mysql.new @@host, @@user, @@password, @@dbname
        con.autocommit false
        pst = con.prepare "UPDATE TELEGRAMUSERS SET context = ? WHERE ChatId = ?"
        pst.execute "#{context}", "#{id}"
        con.commit
        return true
      rescue Mysql::Error => e
        con.rollback
        return [e.errno,e.error]
      ensure
        con.close if con
      end
  end
  def update_user_all(id,context="main",type=nil,data=nil)
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      con.autocommit false
      pst = con.prepare "UPDATE TELEGRAMUSERS SET CONTEXT = ?, TYPE = ?, DATA = ? WHERE CHATID = ?"
      pst.execute "#{context}","#{type}","#{data}", "#{id}"
      con.commit
      return true
    rescue Mysql::Error => e
      con.rollback
      return [e.errno,e.error]
    ensure
      con.close if con
    end
  end
  def increment_groups
    get_all_users.each do |user|
      #({:id=>row[0],:context=>row[1],:type=>row[2],:data=>row[3]})
      if user[:type]!='1'
        d=user[:data].force_encoding('UTF-8')
        old=Integer(d[1..d.index('-')-1])
        old+=1
        if old<10;old="0#{String(old)}" else old="#{String(old)}"  end
        new="#{d[0]}#{old}#{user[:data][user[:data].index('-')..-1]}"
        update_user_all(user[:id],user[:context],user[:type],new)
      end
    end

  end
  def update_user_type(id)
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      con.autocommit false
      pst = con.prepare "UPDATE TELEGRAMUSERS SET TYPE = NOT TYPE WHERE CHATID = ?"
      pst.execute "#{id}"
      con.commit
      return true
    rescue Mysql::Error => e
      con.rollback
      return [e.errno,e.error]
    ensure
      con.close if con
    end
  end
  def update_user_data(id,data)
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      con.autocommit false
      pst = con.prepare "UPDATE TELEGRAMUSERS SET  DATA = ? WHERE CHATID = ?"
      pst.execute "#{data}","#{id}"
      con.commit
      return true
    rescue Mysql::Error => e
      con.rollback
      return [e.errno,e.error]
    ensure
      con.close if con
    end
  end
  def add_user(id,context="main",type=nil,data=nil)
    #TODO: work on mysql errors
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      #con.query("CREATE TABLE IF NOT EXISTS TELEGRAMUSERS (CHATID INTEGER NOT NULL, CONTEXT VARCHAR(40), TYPE BOOLEAN, DATA VARCHAR(100), PRIMARY KEY (CHATID))")
      q="INSERT INTO TELEGRAMUSERS (ChatId,context,type,data) VALUES('#{id}','#{context}','#{type}','#{data}')"
      con.query(q)
      return true
    rescue Mysql::Error => e
      return [e.errno,e.error]
    ensure
      con.close if con
    end
  end
  def do_db_query(query)
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      rs = con.query(query)
      returned_string = ""
      rs.each do |q_result|
        returned_string += q_result.to_s.force_encoding('UTF-8')
      end
      return returned_string
    rescue Mysql::Error => e
      return [e.errno,e.error]
    rescue Exception => ee
        return ee.to_s
    ensure
      con.close if con
    end
  end
  def get_all_users
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      rs = con.query("SELECT * FROM TELEGRAMUSERS;")
      users = []
      rs.each do |row|
        users.push({:id=>row[0],:context=>row[1],:type=>row[2],:data=>row[3]})
      end
      return users
    rescue Mysql::Error => e
      return [e.errno,e.error]
    ensure
      con.close if con
    end
  end
  def usercount
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      rs = con.query("SELECT * FROM TELEGRAMUSERS;")
      users = []
      rs.each do |row|
        users.push({:id=>row[0],:context=>row[1],:type=>row[2],:data=>row[3]})
      end
      returned_string =''
      users.each do |user|
        returned_string+="ID:#{user[:id]},context:#{user[:context]},type:#{if user[:type]=='1';"Преподаватель" else "Студент" end},data:#{user[:data].force_encoding('UTF-8')}\n"
      end
      returned_string+="\n#{'-'*10}\nTotal:#{users.count} users"
      return returned_string
    rescue Mysql::Error => e
      return [e.errno,e.error]
    ensure
      con.close if con
    end
  end
  def groupcheck(group)
    regex = /(А|Б|В|Е|К|М|Р|С|Т|У|Ф|а|б|в|е|к|м|р|с|т|у|ф)(?!00)(?!1[3-9])((0|1)[0-9])[-][а-яА-Я0-9]{2,4}/
    if regex.match(group)
      true
    else
      false
    end
  end
  def familynamecheck(familyname)
    regex= /([А-я]+-[А-я]+ [А-я]\.[А-я]\.|[А-я,ё]+ [А-я]\.[А-я]\.)/
    if regex.match(familyname)
      true
    else
      false
    end
  end
end
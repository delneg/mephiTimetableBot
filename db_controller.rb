require_relative 'config'
class DBController
  @@user = Config.user
  @@host = Config.host
  @@password = Config.password
  @@dbname = Config.dbname
  #TODO: create table if not present, add user if not added
  def get_user(id)
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      rs = con.query("SELECT * FROM telegramusers WHERE ChatId='#{id}';")
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
        res = add_user(id)
      end
      begin
        con = Mysql.new @@host, @@user, @@password, @@dbname
            con.autocommit false
            pst = con.prepare "UPDATE telegramusers SET context = ? WHERE ChatId = ?"
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
  def add_user(id,context="main",type=nil,data=nil)
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      #con.query("CREATE TABLE IF NOT EXISTS TELEGRAMUSERS (CHATID INTEGER NOT NULL, CONTEXT VARCHAR(40), TYPE BOOLEAN, DATA VARCHAR(100), PRIMARY KEY (CHATID))")
      con.query("INSERT INTO telegramusers(ChatId,context,type,data) VALUES(#{id},'#{context}',#{type},'#{data}')")
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
      return returnedStr
    rescue Mysql::Error => e
      return [e.errno,e.error]
    ensure
      con.close if con
    end
  end
  def get_all_users
    begin
      con = Mysql.new @@host, @@user, @@password, @@dbname
      rs = con.query("SELECT chatid FROM telegramusers;")
      users = []
      rs.each do |row|
        users.push(row)
      end
      return users
    rescue Mysql::Error => e
      return [e.errno,e.error]
    ensure
      con.close if con
    end
  end
end
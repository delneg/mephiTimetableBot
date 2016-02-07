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
      return {:id=>row[0],:last_message=>row[1],:context=>row[2],:type=>row[3],:data=>row[4]}
    rescue Mysql::Error => e
      return [e.errno,e.error]
    ensure
      con.close if con
    end
  end
  def update_user_context(id,context)
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

end
# mephiTimetableBot
This is a repository for the telegram bot, which purpose is to serve timetable to human beings. https://telegram.me/mephiTimetableBot
In order to set it up, in addition to the files listed you'll need a file config.rb, containing a Ruby class or module "Config",with these methods:
"user" - MySQL database user
"host"- MySQL database host
"password" - MySQL database user password
"dbname" - MySQL database name
"token" - bot token from @BotFather
"admin_id" - admin telegram chat id
"s_message" - start message, usually stating main functions,feedback contacts and some description.
"feedback" - feedback message
"google_api_key" - create your api key at https://console.developers.google.com/apis/credentials 

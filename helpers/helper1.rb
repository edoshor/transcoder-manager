def clear; '<div class="clear"><!-- --></div>' end


# return string of kerberos user or false
def authenticate
  if ENV['RACK_ENV'] == 'development' or ENV['RACK_ENV'] == 'qa'
    return settings.user
  end

  user = request.env["HTTP_AUTHORIZATION"]

  if user
    user = Base64.decode64(user[6,user.length-6])[/\w+/]
    return user
  end

  false
end




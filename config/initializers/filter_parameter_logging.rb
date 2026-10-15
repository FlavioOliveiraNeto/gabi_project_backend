Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc, :content, :reason,
  :name, :phone, :google_meet_link, :audio
]

require_relative '../application_config'
class ::String
  def email_to_sha1
    Digest::SHA1.hexdigest("#{jsc_email_sha1_salt}#{downcase}")
  end
end
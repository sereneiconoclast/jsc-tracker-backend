require 'net/http'
require 'json'
require 'timeout'

class AuthenticationFailedError < StandardError; end

class String
  # {
  #   sub: "115...140",
  #   name: "Gregory Meyers",
  #   given_name: "Gregory",
  #   family_name: "Meyers",
  #   picture: "https://lh3.googleusercontent.com/a/...", # URL of profile picture
  #   email: "greg.meyers.1138@gmail.com",
  #   email_verified: true
  # }
  def parse_google_access_token
    uri = URI('https://www.googleapis.com/oauth2/v3/userinfo')
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{self}"

    begin
      response = Timeout.timeout(10) do
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end
      end

      case response
      when Net::HTTPSuccess
        Hash[
          JSON.parse(response.body).map do |k, v|
            [k.to_sym, v]
          end
        ]
      when Net::HTTPUnauthorized
        raise AuthenticationFailedError, 'Invalid Google access token'
      else
        raise AuthenticationFailedError, "Google authentication failed: #{response.code} #{response.message}"
      end
    rescue Timeout::Error
      raise AuthenticationFailedError, 'Google authentication request timed out'
    rescue JSON::ParserError
      raise AuthenticationFailedError, 'Failed to parse Google authentication response'
    rescue StandardError => e
      raise AuthenticationFailedError, "Google authentication failed: #{e.message}"
    end
  end
end

module Om
  class CloudClient
    USER_ID = "3174298634"
    TOKEN   = "MGFmNWJjZGMt.GM4Yy00NmViLTkyYjMtN2ZhM2ViZjM2ODc5:"
    URL     = "https://api.newrocktech.com/v1"

    def initialize
      @params = { user_id: USER_ID }
      authorization
    end

    def get_p2p device_mac
      url = URL + '/services/p2p'
      params = @params.merge({ device_mac: device_mac })
      JSON.parse(RestClient.get url + '?' + params.to_query, @authorization)
    end

    def get_device_info device_mac
      url = URL + '/devices'
      params = @params.merge({ device_mac: device_mac })
      JSON.parse(RestClient.get url + '?' + params.to_query, @authorization)
    end

    private
    def authorization
      encode_token = 'Basic ' + Base64.urlsafe_encode64(TOKEN)
      @authorization = {:Authorization => encode_token}
    end
  end
end

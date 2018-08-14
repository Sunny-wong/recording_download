class OmDownloadHttp < OmDownload
  PROXY_URL = 'http://om.263onet.com/api/v1/devices/cloud_proxy_address'

  def proxy_url
    @proxy_url ||= cloud_proxy_address
  end

  def query
    result = parse_page
    {
      total_count: result.count,
      total_size:  result.map { |d| d[:file_size] }.sum,
      data: result.map {|d| { file_name: d[:file_name], file_size: d[:file_size] }}
    }
  end

  def dir_download
    t1 = Time.now
    files = query[:data]
    files.each do |file|
      file_download(file[:file_name])
    end

    local_dir_info.merge({duration: Time.now - t1})
  end

  def file_download(file_name)
    t1 = Time.now
    local_path = local_dir + file_name
    download_url = proxy_url + file_name

    FileUtils.mkdir_p(local_dir) unless Dir.exist?(local_dir)
    unless File.exist?(local_path)
      File.open(local_path, 'wb') {|f|
        block = proc { |response|
          response.read_body do |chunk|
            f.write chunk
          end
        }
        RestClient::Request.new(method: :get, url: URI.escape(download_url), user: 'user', password: 'user',  verify_ssl: false, block_response: block).execute
      }

      logger.info("[HTTP] #{file_name} 开始下载时间: #{t1} - 结束时间: #{Time.now}")
    end
    local_dir_info(file_name)
  end

  private

  def parse_page
    raise "[HTTP] 未找到代理地址" unless proxy_url
    begin
      resp = RestClient::Resource.new(proxy_url, user: 'user', password: 'user', verify_ssl: false).get

      Nokogiri::HTML(resp.body).xpath('//tr').map do |row|
        file_name = row.at('td[1]').text.strip rescue ""
        next if file_name.blank? || ["Directories", "Parent Directory", "Files"].include?(file_name)

        file_size = (row.at('td[3]').text.strip rescue "").to_i
        { file_name: file_name, file_size: file_size }
      end.compact
    rescue RestClient::NotFound
      raise "[HTTP] 未找到对应录音文件目录"
    rescue OpenSSL::SSL::SSLError
      raise "[HTTP] 设备离线"
    end
  end

  def cloud_proxy_address
    resp = JSON.parse(RestClient.get(PROXY_URL, params: {mac: @mac}).body)
    resp['code'] == 0 ? "https://#{resp['proxy_ip']}:#{resp['proxy_port']}/usb/builtin/Recorder/#{@date.strftime('%Y%m%d')}/" : nil
  end
end
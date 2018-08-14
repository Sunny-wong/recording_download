# fsp使用详见https://github.com/omapi/fspClientLib

class OmDownloadFsp < OmDownload
  FSP_CMD = Settings.external_cmd.fsp

  def om_dir
    "Recorder/#{@date.strftime('%Y%m%d')}/"
  end

  def cid
    # 判断设备状态
    resp = Om::CloudClient.new.get_device_info(@mac)

    raise '获取设备信息失败。' unless connection_status = resp && resp['devices'] && resp['devices'][0] && resp['devices'][0]['connection_status']

    raise '设备离线。' if  connection_status == 'offline'

    # 获取cid
    resp = Om::CloudClient.new.get_p2p(mac)
    raise '获取cid失败。' unless cid = resp && resp['p2p'] && resp['p2p'][0] && resp['p2p'][0]['cid']

    cid
  end

  def query
    result = exec_cmd(query_cmd)
    # 根据标识位去除提示打印字段
    result = result[(result.index("[start]\n").to_i + 1)...result.index("[end]\n").to_i]

    raise '查询服务器上的文件数量为空' unless result.is_a?(Array)
    result.collect! { |r| r.chomp.split(' ') }

    {
      total_count: result.count,
      total_size:  result.map {|r| r[1].to_i}.sum,
      data: result.map {|r| {file_name: r[4], file_size: r[1].to_i}}
    }
  end

  def dir_download
    t1 = Time.now
    exec_cmd(dir_download_cmd)

    local_dir_info.merge({duration: Time.now - t1})
  end

  def file_download(file_name)
    exec_cmd file_download_cmd(file_name)

    local_dir_info(file_name)
  end

  # 一次通话录音下载处理
  def record_download(recording_file)
    # 解析录音文件名
    recording_name = recording_file.recording_path.split('/')[1]
    if recording_file.rec_codec == 'G729'
      file_ary = %w(_send.dat _recv.dat).map{ |ext| recording_name.gsub(/.wav$/, ext) }
    else
      file_ary = [recording_name]
    end

    # 下载
    file_ary.each do |file|
      exec_cmd file_download_cmd(file)
    end

    # 转换wav
    if recording_file.rec_codec == 'G729'
      local_dat_files = file_ary.map{ |file| local_dir + file }
      exec_cmd dat2wav_cmd(local_dat_files, 1)
    end

    # 转换mp3
    local_wav_file = local_dir + recording_name
    exec_cmd wav2mp3_cmd(local_wav_file)
  end


  def dir_dat2wav
    t1 = Time.now
    datfiles = local_dir_info('*.dat')

    group_datfiles = datfiles[:files].group_by { |i| i[0...-9] }.values
    group_datfiles.each do |file_ary|
      cmd = dat2wav_cmd(file_ary)
      exec_cmd(cmd)
    end

    { duration: Time.now - t1 }
  end

  def dir_wav2mp3
    t1 = Time.now
    wavfiles = local_dir_info('*.wav')

    wavfiles[:files].each do |file|
      cmd = wav2mp3_cmd(file)
      result = exec_cmd(cmd)
      raise result if result.present?

      # 转换后删除原始wav文件
      File.delete(file)
    end

    mp3files = local_dir_info('*.mp3')

    {
      total_count: mp3files[:total_count],
      total_size:  mp3files[:total_size],
      duration:    Time.now - t1
    }
  end

  private
  def query_cmd
    "#{FSP_CMD} -id #{cid} -ic newrocktech -p newrocktech -ls #{om_dir}"
  end

  # 文件夹下载 文件夹必须以'/'结尾
  def dir_download_cmd
    "#{FSP_CMD} -id #{cid} -ic newrocktech -p newrocktech -g #{om_dir} -s #{local_dir}"
  end

  # 单文件下载
  def file_download_cmd(file)
    "#{FSP_CMD} -id #{cid} -ic newrocktech -p newrocktech -g #{om_dir + file} -s #{local_dir}"
  end
end

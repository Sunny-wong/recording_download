# fsp使用详见https://github.com/omapi/fspClientLib

class OmDownload
  TCONV_CMD = Settings.external_cmd.tconv

  attr_reader :mac, :date, :base_dir
  def initialize(args={})
    @mac = args[:mac]
    @date = args[:date]
    @base_dir = args[:base_dir]
  end

  def local_dir
    base_dir || "#{Rails.root}/public/recording/#{mac}/#{date.strftime('%Y%m%d')}/"
  end

  # 获取本地目录信息
  def local_dir_info(extname = '*.*')
    total_size, total_count, files = 0, 0, []

    pattern = local_dir + extname
    localfiles  = Dir.glob(pattern)

    localfiles.each do |file|
      next if file == '.' || file == '..' || %w(.log .bak).include?(File.extname(file))

      files << file
      total_size  += File.size(file)
      total_count += 1
    end

    { total_size: total_size, total_count: total_count, files: files }
  end

  def dat2wav(file_ary, flag=0)
    exec_cmd dat2wav_cmd(file_ary, flag)
  end

  def wav2mp3(file, flag=0)
    exec_cmd wav2mp3_cmd(file, flag)
  end

  def logger
    @@logger ||= Logger.new 'log/recording.log'
  end

  private
  def exec_cmd(cmd)
    f = IO.popen(cmd)
    logger.info cmd
    results = f.readlines
    f.close

    results.each do |result|
      logger.warn result if result =~ /Warning/
      if result =~ /Failed/
        logger.error result
        raise result
      end
    end

    results
  end

  # @params [Array] file    文件需带路径 e.g. [file_path1[, file_path2]]
  # @params [Integer] flag  转换后是否删除原始文件 e.g.  0/删除 1/保留
  #   新版tconv不提供删除源文件参数，所以flag不起作用 https://github.com/omapi/rtpconv
  def dat2wav_cmd(file_ary, flag=0)
    "#{TCONV_CMD} #{file_ary[0].to_s} #{file_ary[1].to_s}"
  end

  # @params [String] file    文件需带路径
  # @params [Integer] flag  转换后是否删除原始文件 e.g.  0/删除 1/保留
  def wav2mp3_cmd(file, flag=0)
    convert_file = file.gsub(/.wav$/, '.mp3')
    cmd = "ffmpeg -loglevel 16 -i #{file} -f mp3 -acodec libmp3lame  -metadata:s:t mimetype=audio/mpeg -y #{convert_file} "
    cmd += " && rm #{file}" if flag == 0

    cmd
  end

  def logger
    @@logger ||= Logger.new 'log/recording.log'
  end
end

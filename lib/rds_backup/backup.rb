require 'fog'
require 'open3'
require 'yaml'
require_relative '../yell_adapters/ses_adapter'
require_relative '../yell_adapters/hipchat_adapter'

module RdsBackup
  class Backup
    def initialize(config_file = 'config.yml')
      config = YAML.load(File.open(config_file))
      config_google(config)
      config_mysql(config)
      config_logger(config)

      @backups_to_keep = config['backups_to_keep'] || 3
      current_utc_time = Time.now.getutc.strftime('%Y%m%d%H%M%S')
      @file_name = "#{mysql_database}-#{current_utc_time}.sql.gz"
    end

    def backup
      logger.info 'Starting...'
      dump_database
      upload_backup
      prune_old_backups
      remove_local_dump
    ensure
      logger.info 'Exiting...'
      logger.close
    end

    private

    attr_accessor :mysql_database, :mysql_host, :mysql_user, :mysql_password,
                  :mysql_ssl, :rds_cert_path, :fog_directory, :file_name,
                  :backups_to_keep, :logger

    def config_mysql(config)
      @mysql_database = config['mysql']['database']
      @mysql_host = config['mysql']['host']
      @mysql_user = config['mysql']['user']
      @mysql_password = config['mysql']['password']
      @mysql_ssl = config['mysql']['ssl']
      @rds_cert_path = config['mysql']['rds_cert_path'] if @mysql_ssl
    end

    def config_google(config)
      google_access = config['cloud_storage']['access_key_id']
      google_secret = config['cloud_storage']['secret_access_key']
      connection = Fog::Storage.new(
        provider: 'Google',
        google_storage_access_key_id: google_access,
        google_storage_secret_access_key: google_secret
      )
      @fog_directory = connection.directories.get('idxp-rds-backup')
    end

    def config_logger(config)
      @logger = Yell.new do |yell_logger|
        config['loggers'].each do |logger|
          send("config_#{logger}_adapter", yell_logger, config)
        end
      end
    end

    def config_ses_adapter(logger, config)
      logger.adapter :ses_adapter,
                     format: Yell::BasicFormat,
                     aws_access_key_id: config['aws']['access_key_id'],
                     aws_secret_access_key: config['aws']['secret_access_key'],
                     email_config: config['email']
    end

    def config_hipchat_adapter(logger, config)
      logger.adapter :hipchat_adapter,
                     format: Yell::BasicFormat,
                     hipchat_token: config['hipchat']['token'],
                     hipchat_rooms: config['hipchat']['rooms']
    end

    def dump_database
      _out, err, _status = Open3.capture3 mysqldump_cmd

      if err.empty?
        logger.info 'Database dump successfully created'
      else
        logger.error "Error when dumping the database: #{err.strip}"
        remove_local_dump
        fail RuntimeError
      end
    end

    def mysqldump_cmd
      cmd = "mysqldump -u#{mysql_user} "
      cmd += "-p#{mysql_password} " if mysql_password
      cmd += "--ssl_ca=#{rds_cert_path} " if mysql_ssl
      cmd += '--single-transaction --routines --triggers '\
             "-h #{mysql_host} #{mysql_database} "\
             "| gzip -c > #{file_name}"
      cmd
    end

    def upload_backup
      fog_directory.files.create(key: file_name, body: File.open(file_name))
      logger.info 'Backup uploaded to Google'
    rescue
      logger.error 'Error while uploading dump to Google'
    end

    def prune_old_backups
      sorted_files = fog_directory.files.reload.sort do |x, y|
        x.last_modified <=> y.last_modified
      end
      sorted_files[0 .. -backups_to_keep - 1].each { |f| f.destroy }
      logger.info 'Old backups pruned'
    rescue
      logger.error 'Error while pruning old backups'
    end

    def remove_local_dump
      Open3.capture3 "rm -rf #{file_name}"
    end
  end
end

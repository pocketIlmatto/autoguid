class Migrator < ActiveRecord::Migration

    attr_accessor :config

    def up
      puts 'Found config' + config.to_s
      whitelist = Migrator.all_models if @config[:all] or @config[:blacklist]
      if ( @config[:whitelist] )
        puts "Got into Whitelist"
        whitelist = Array.new
        Migrator.all_models.each do |m|
          puts "Checking for model " + m.name + " in whitelist "
          whitelist.push(m) if @config[:whitelist].include?(m.name)
        end
      elsif ( @config[:blacklist] )
        puts "Processing by blacklist"
        whitelist.each do |m|
          puts "Checking for model " + m.name + " in blacklist "
          whitelist.delete(m) if @config[:blacklist].include?(m.name)
        end
      end
      puts "whitelist"
      whitelist.each do |model|
        puts "Processing " + model.name
        model.reset_column_information
        add_column(model, :guid, :string, :unique => true) unless column_exists?(model, :guid)
        add_index(model, :guid) if @config[:indices] && !index_exists?(model, :guid)
      end
    end

    def down
      Migrator.all_models.each do |model|
        model.reset_column_information
        remove_index(model, :guid) if index_exists?(model, :guid)
        remove_column(model, :guid) if column_exists?(model, :guid)
      end
    end

    def self.all_models
      Rails.application.eager_load!
      mods = Array.new
      Module.constants.select do |constant_name|
        constant = eval( constant_name.to_s )
        if not constant.nil? and constant.is_a? Class and constant.superclass == ActiveRecord::Base
          mods.push(constant)
        end
      end
      return mods
    end

end
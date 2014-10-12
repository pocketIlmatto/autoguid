class Migrator < ActiveRecord::Migration

    attr_accessor :config

    def up
      begin
        whitelist = build_whitelist
        puts "whitelist"
        whitelist.each do |model|
          puts "Processing " + model.name
          puts "Are you sure you want to add/update guid column on " + model.name + "? (y/n)"
          input = STDIN.gets.strip
          if input == 'y'
            model.reset_column_information
            add_column(model, :guid, :string, :unique => true) unless column_exists?(model, :guid)
            add_index(model, :guid) if @config[:indices] && !index_exists?(model, :guid)
          else
            puts model.name + " skipped."
          end
        end
        #TODO run synch_check once it is ready
      rescue Exception => e
        puts e.message
      end
    end

    def down
      Migrator.all_models.each do |model|
        model.reset_column_information
        remove_index(model, :guid) if index_exists?(model, :guid)
        remove_column(model, :guid) if column_exists?(model, :guid)
      end
    end

    # Checks that any models that end up in the whitelist
    # have the following:
    # * guid column on database table
    # * TODO include Autoguid in their model definition
    # * reminder to backfill if either of these is missing
    def synch_check
      puts "Running synchronization check"
      whitelist = build_whitelist(debug: true)
      backfill_reminder = false
      whitelist.each do |model|
        backfill_reminder = false
        backfill_reminder = true and puts "guid is missing from #{model.name} \n Run rake autoguid:migrate:up" unless column_exists?(model, :guid)
        backfill_reminder = true and puts "#{model.name} definition doesn't include Autoguid." unless model.respond_to?('backfill')
        puts "Run rake autoguid:migrate:backfill after completing synchronization steps" if backfill_reminder
      end
    end

    # Builds the whitelist of models
    def build_whitelist(options = {})
      begin
        puts 'Found config' + @config.to_s if options[:debug]
        raise "Autoguid configuration is incomplete" unless @config[:all] || (@config[:whitelist].nil? ^ @config[:blacklist].nil?)
        raise "Specifying both whitelist & blacklist is not supported." if @config[:whitelist] && @config[:blacklist]
        whitelist = Migrator.all_models if @config[:all] or @config[:blacklist]
        if ( @config[:whitelist] )
          puts "Got into Whitelist" if options[:debug]
          whitelist = Array.new
          Migrator.all_models.each do |m|
            puts "Checking for model " + m.name + " in whitelist " if options[:debug]
            whitelist.push(m) if @config[:whitelist].include?(m.name)
          end
        elsif ( @config[:blacklist] )
          puts "Processing by blacklist" if options[:debug]
          whitelist.delete_if {|m| @config[:blacklist].include?(m.name)}
        end
      rescue Exception => e
        puts e.message
      end
      whitelist
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
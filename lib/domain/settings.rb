module VolgaCTF
  module Final
    module Domain
      def self.settings(&block)
        settings_dsl = SettingsDSL.new
        settings_dsl.instance_eval &block
        @_settings = settings_dsl.settings
      end

      def self.get_settings
        @_settings
      end

      class Settings
        attr_accessor :flag_lifetime, :round_timespan,
                      :poll_timespan, :poll_delay

        def initialize
          @flag_lifetime = nil
          @round_timespan = nil
          @poll_timespan = nil
          @poll_delay = nil
        end
      end

      class SettingsDSL
        attr_reader :settings

        def initialize
          @settings = Settings.new
        end

        def flag_lifetime(flag_lifetime)
          @settings.flag_lifetime = flag_lifetime
        end

        def round_timespan(round_timespan)
          @settings.round_timespan = round_timespan
        end

        def poll_timespan(poll_timespan)
          @settings.poll_timespan = poll_timespan
        end

        def poll_delay(poll_delay)
          @settings.poll_delay = poll_delay
        end
      end

      protected
      @_settings = nil
    end
  end
end

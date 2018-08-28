module Themis
  module Finals
    module Configuration
      def self.deprecated_settings(&block)
        deprecated_settings_dsl = DeprecatedSettingsDSL.new
        deprecated_settings_dsl.instance_eval &block
        @_deprecated_settings = deprecated_settings_dsl.deprecated_settings
      end

      def self.get_deprecated_settings
        @_deprecated_settings
      end

      class DeprecatedSettings
        attr_accessor :attack_limit_attempts, :attack_limit_period

        def initialize
          @attack_limit_attempts = nil
          @attack_limit_period = nil
        end
      end

      class DeprecatedSettingsDSL
        attr_reader :deprecated_settings

        def initialize
          @deprecated_settings = DeprecatedSettings.new
        end

        def attack_limits(attempts, period)
          @deprecated_settings.attack_limit_attempts = attempts
          @deprecated_settings.attack_limit_period = period
        end
      end

      protected
      @_deprecated_settings = nil
    end
  end
end

require 'date'
require './lib/domain/network'
require './lib/domain/settings'

module Themis
  module Finals
    module Controllers
      class Domain
        def initialize
          @data = nil
          @network = nil
          @settings = nil
        end

        def init
          ::Themis::Finals::Models::DB.transaction do
            network = ::Themis::Finals::Domain.get_network
            settings = ::Themis::Finals::Domain.get_settings
            data = {
              network: {
                internal: network.internal.map { |x| x.to_s }
              },
              settings: {
                flag_lifetime: settings.flag_lifetime,
                round_timespan: settings.round_timespan,
                poll_timespan: settings.poll_timespan,
                poll_delay: settings.poll_delay
              }
            }

            configuration = ::Themis::Finals::Models::Configuration.create(
              data: data,
              created: ::DateTime.now
            )

            require './lib/controllers/team'
            team_ctrl = ::Themis::Finals::Controllers::Team.new
            team_ctrl.init_teams(::Themis::Finals::Domain.get_teams)

            require './lib/controllers/service'
            service_ctrl = ::Themis::Finals::Controllers::Service.new
            service_ctrl.init_services(::Themis::Finals::Domain.get_services)
          end
        end

        def update
          require './lib/controllers/service'
          service_ctrl = ::Themis::Finals::Controllers::Service.new

          ::Themis::Finals::Models::DB.transaction do
            service_ctrl.init_services(::Themis::Finals::Domain.get_services)
          end
        end

        def available?
          return true unless @data.nil?

          configuration = ::Themis::Finals::Models::Configuration.first
          unless configuration.nil?
            @data = configuration.data
          end

          !@data.nil?
        end

        def network
          raise "Configuration unavailable!" if @data.nil?

          if @network.nil?
            dsl = ::Themis::Finals::Domain::NetworkDSL.new
            dsl.internal(*@data['network']['internal'])
            @network = dsl.network
          end

          @network
        end

        def settings
          raise "Configuration unavailable!" if @data.nil?

          if @settings.nil?
            dsl = ::Themis::Finals::Domain::SettingsDSL.new
            dsl.flag_lifetime(@data['settings']['flag_lifetime'])
            dsl.round_timespan(@data['settings']['round_timespan'])
            dsl.poll_timespan(@data['settings']['poll_timespan'])
            dsl.poll_delay(@data['settings']['poll_delay'])
            @settings = dsl.settings
          end

          @settings
        end
      end
    end
  end
end

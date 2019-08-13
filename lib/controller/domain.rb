require 'date'
require './lib/domain/network'
require './lib/domain/settings'

module VolgaCTF
  module Final
    module Controller
      class Domain
        def initialize
          @data = nil
          @network = nil
          @settings = nil
        end

        def init
          ::VolgaCTF::Final::Model::DB.transaction do
            network = ::VolgaCTF::Final::Domain.get_network
            settings = ::VolgaCTF::Final::Domain.get_settings
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

            configuration = ::VolgaCTF::Final::Model::Configuration.create(
              data: data,
              created: ::DateTime.now
            )

            require './lib/controller/team'
            team_ctrl = ::VolgaCTF::Final::Controller::Team.new
            team_ctrl.init_teams(::VolgaCTF::Final::Domain.get_teams)

            require './lib/controller/service'
            service_ctrl = ::VolgaCTF::Final::Controller::Service.new
            service_ctrl.init_services(::VolgaCTF::Final::Domain.get_services)
          end
        end

        def update
          require './lib/controller/service'
          service_ctrl = ::VolgaCTF::Final::Controller::Service.new

          ::VolgaCTF::Final::Model::DB.transaction do
            service_ctrl.init_services(::VolgaCTF::Final::Domain.get_services)
          end
        end

        def available?
          return true unless @data.nil?

          configuration = ::VolgaCTF::Final::Model::Configuration.first
          unless configuration.nil?
            @data = configuration.data
          end

          !@data.nil?
        end

        def network
          raise "Configuration unavailable!" if @data.nil?

          if @network.nil?
            dsl = ::VolgaCTF::Final::Domain::NetworkDSL.new
            dsl.internal(*@data['network']['internal'])
            @network = dsl.network
          end

          @network
        end

        def settings
          raise "Configuration unavailable!" if @data.nil?

          if @settings.nil?
            dsl = ::VolgaCTF::Final::Domain::SettingsDSL.new
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

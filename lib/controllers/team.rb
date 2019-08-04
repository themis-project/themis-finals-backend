module VolgaCTF
  module Final
    module Controllers
      class Team
        def initialize
          @logger = ::VolgaCTF::Final::Utils::Logger.get
        end

        def all_teams(shuffle = false)
          res = ::VolgaCTF::Final::Models::Team.all
          shuffle ? res.shuffle : res
        end

        def init_teams(entries)
          ::VolgaCTF::Final::Models::DB.transaction do
            entries.each { |p| create_team(p) }
          end
        end

        private
        def create_team(opts)
          ::VolgaCTF::Final::Models::Team.create(
            name: opts.name,
            alias: opts.alias,
            network: opts.network,
            guest: opts.guest,
            logo_hash: nil
          )
        end
      end
    end
  end
end

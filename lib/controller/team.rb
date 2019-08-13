module VolgaCTF
  module Final
    module Controller
      class Team
        def initialize
          @logger = ::VolgaCTF::Final::Util::Logger.get
        end

        def all_teams(shuffle = false)
          res = ::VolgaCTF::Final::Model::Team.all
          shuffle ? res.shuffle : res
        end

        def init_teams(entries)
          ::VolgaCTF::Final::Model::DB.transaction do
            entries.each { |p| create_team(p) }
          end
        end

        private
        def create_team(opts)
          ::VolgaCTF::Final::Model::Team.create(
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

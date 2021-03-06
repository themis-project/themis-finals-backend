require 'sequel'

module VolgaCTF
  module Final
    module Model
      class Flag < ::Sequel::Model
        many_to_one :service
        many_to_one :team
        many_to_one :round

        one_to_many :attacks
        one_to_many :flag_polls

        dataset_module do
          def living(cutoff)
            exclude(expired_at: nil)
            .where { expired_at > cutoff }
          end

          def failed(round)
            where(round_id: round.id)
            .where(expired_at: nil)
          end

          def relevant(round)
            where(round_id: round.id)
            .exclude(expired_at: nil)
          end

          def relevant_expired(round, cutoff)
            where(round_id: round.id)
            .exclude(expired_at: nil)
            .where { expired_at < cutoff }
          end

          def first_match(s)
            exclude(pushed_at: nil).first(flag: s)
          end
        end
      end
    end
  end
end

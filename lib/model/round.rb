require 'sequel'

module VolgaCTF
  module Final
    module Model
      class Round < ::Sequel::Model
        one_to_many :polls

        dataset_module do
          def current
            where(finished_at: nil).order(:id)
          end

          def latest_ready
            exclude(finished_at: nil).order(::Sequel.desc(:finished_at)).first
          end
        end
      end
    end
  end
end

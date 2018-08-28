require 'sequel'

module Themis
  module Finals
    module Models
      class Round < ::Sequel::Model
        one_to_many :polls

        dataset_module do
          def current
            where(finished_at: nil).order(:id)
          end
        end
      end
    end
  end
end

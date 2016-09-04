require 'bigdecimal'
require './lib/constants/flag_poll_state'

module Themis
  module Finals
    module Controllers
      module Score
        def self.get_score(round, team)
          score = ::Themis::Finals::Models::Score.first(
            round_id: round.id,
            team_id: team.id
          )

          if score.nil?
            score = ::Themis::Finals::Models::Score.create(
              defence_points: ::BigDecimal.new('0'),
              attack_points: ::BigDecimal.new('0'),
              team_id: team.id,
              round_id: round.id
            )
          end

          score
        end

        def self.charge_defence(flag)
          ::Themis::Finals::Models::DB.transaction do
            score = get_score flag.round, flag.team
            score.defence_points += ::BigDecimal.new('1')
            score.save
          end
        end

        def self.charge_availability(flag, polls)
          ::Themis::Finals::Models::DB.transaction do
            success_count = polls.count do |poll|
              poll.state == ::Themis::Finals::Constants::FlagPollState::SUCCESS
            end

            return if success_count == 0

            pts = Float(success_count) / Float(polls.count)

            team = flag.team
            score = get_score flag.round, team
            precision = ENV.fetch('THEMIS_FINALS_SCORE_PRECISION', '4').to_i
            score.defence_points += ::BigDecimal.new(pts.round(precision).to_s)
            score.save
          end
        end

        def self.charge_attack(flag, attack)
          ::Themis::Finals::Models::DB.transaction do
            score = get_score flag.round, attack.team
            score.attack_points += ::BigDecimal.new('1')
            score.save
          end
        end
      end
    end
  end
end

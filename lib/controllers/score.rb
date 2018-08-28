require './lib/constants/flag_poll_state'

module Themis
  module Finals
    module Controllers
      class Score
        def charge_defence(flag)
          ::Themis::Finals::Models::DB.transaction do
            score = get_score(flag.round, flag.team)
            score.defence_points += 1.0
            score.save
          end
        end

        def charge_availability(flag, polls)
          ::Themis::Finals::Models::DB.transaction do
            success_count = polls.count do |poll|
              poll.state == ::Themis::Finals::Constants::FlagPollState::SUCCESS
            end

            return if success_count == 0

            pts = Float(success_count) / Float(polls.count)

            team = flag.team
            score = get_score(flag.round, team)
            score.availability_points += pts
            score.save
          end
        end

        def charge_attack(flag, attack)
          ::Themis::Finals::Models::DB.transaction do
            score = get_score(flag.round, attack.team)
            score.attack_points += 1.0
            score.save
          end
        end

        private
        def get_score(round, team)
          ::Themis::Finals::Models::Score.first(
            round_id: round.id,
            team_id: team.id
          )
        end
      end
    end
  end
end

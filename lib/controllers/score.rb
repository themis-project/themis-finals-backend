require 'sequel'

require './lib/constants/flag_poll_state'
require './lib/utils/logger'
require './lib/controllers/attack'

module Themis
  module Finals
    module Controllers
      class Score
        def initialize
          @logger = ::Themis::Finals::Utils::Logger.get
        end

        def update_score(flag)
          ::Themis::Finals::Models::DB.transaction(
          ) do
            polls = ::Themis::Finals::Models::FlagPoll.relevant(flag).all
            charge_availability(flag, polls)

            attacks = flag.attacks
            if attacks.count == 0
              error_count = polls.count { |p| p.error? }
              success_count = polls.count { |p| p.success? }

              if error_count == 0 && success_count > 0
                charge_defence(flag)
              end
            else
              attacks.each do |attack|
                begin
                  charge_attack(flag, attack)
                  attack.processed = true
                  attack.save
                rescue => e
                  @logger.error(e.to_s)
                end
              end
            end
          end
        end

        def update_total_scores
          ::Themis::Finals::Models::Team.all.each do |team|
            begin
              update_total_score(team)
            rescue => e
              @logger.error(e.to_s)
            end
          end
        end

        private
        def score_table_name
          ::Themis::Finals::Models::Score.table_name
        end

        def charge_availability(flag, polls)
          ::Themis::Finals::Models::DB.transaction do
            success_count = polls.count { |p| p.success? }
            return if success_count == 0
            pts = Float(success_count) / Float(polls.count)

            ::Themis::Finals::Models::Score.dataset.returning.insert_conflict(
              constraint: :score_team_round_uniq,
              update: {
                availability_points: ::Sequel.expr(pts) + ::Sequel[score_table_name][:availability_points]
              }
            ).insert(
              attack_points: 0.0,
              availability_points: pts,
              defence_points: 0.0,
              team_id: flag.team.id,
              round_id: flag.round.id
            )
          end
        end

        def charge_defence(flag)
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Models::Score.dataset.returning.insert_conflict(
              constraint: :score_team_round_uniq,
              update: {
                defence_points: ::Sequel.expr(1.0) + ::Sequel[score_table_name][:defence_points]
              }
            ).insert(
              attack_points: 0.0,
              availability_points: 0.0,
              defence_points: 1.0,
              team_id: flag.team.id,
              round_id: flag.round.id
            )
          end
        end

        def charge_attack(flag, attack)
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Models::Score.dataset.returning.insert_conflict(
              constraint: :score_team_round_uniq,
              update: {
                attack_points: ::Sequel.expr(1.0) + ::Sequel[score_table_name][:attack_points]
              }
            ).insert(
              attack_points: 1.0,
              availability_points: 0.0,
              defence_points: 0.0,
              team_id: attack.team.id,
              round_id: flag.round.id
            )
          end
        end

        def update_total_score(team)
          ::Themis::Finals::Models::DB.transaction do
            attack_pts = 0.0
            availability_pts = 0.0
            defence_pts = 0.0

            ::Themis::Finals::Models::Score.where(team_id: team.id).each do |score|
              attack_pts += score.attack_points
              availability_pts += score.availability_points
              defence_pts += score.defence_points
            end

            ::Themis::Finals::Models::TotalScore.dataset.returning.insert_conflict(
              target: :team_id,
              update: {
                attack_points: attack_pts,
                availability_points: availability_pts,
                defence_points: defence_pts
              }
            ).insert(
              attack_points: attack_pts,
              availability_points: availability_pts,
              defence_points: defence_pts,
              team_id: team.id
            )

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info(
                "Total score of team `#{team.name}` has been recalculated: "\
                "attack - #{attack_pts} pts, "\
                "availability - #{availability_pts}, "\
                "defence - #{defence_pts} pts"\
              )
            end
          end
        end
      end
    end
  end
end

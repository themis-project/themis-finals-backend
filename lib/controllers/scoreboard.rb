require 'json'
require 'bigdecimal'
require './lib/utils/event_emitter'
require './lib/utils/logger'

module Themis
  module Finals
    module Controllers
      module Scoreboard
        @logger = ::Themis::Finals::Utils::Logger.get

        def self.format_team_positions(positions)
          positions.map { |position|
            {
              team_id: position[:team_id],
              total_points: position[:total_points],
              attack_points: position[:attack_points],
              availability_points: position[:availability_points],
              defence_points: position[:defence_points],
              last_attack: \
                if position[:last_attack].nil?
                  nil
                else
                  position[:last_attack].iso8601
                end
            }
          }
        end

        def self.sort_rows(a, b, precision)
          zero_edge = (10 ** -(precision + 1)).to_f

          a_total_points = a[:total_points]
          b_total_points = b[:total_points]

          if (a_total_points - b_total_points).abs < zero_edge
            a_last_attack = a[:last_attack]
            b_last_attack = b[:last_attack]
            if a_last_attack.nil? && b_last_attack.nil?
              return 0
            elsif a_last_attack.nil? && !b_last_attack.nil?
              return -1
            elsif !a_last_attack.nil? && b_last_attack.nil?
              return 1
            else
              if a_last_attack < b_last_attack
                return -1
              elsif a_last_attack > b_last_attack
                return 1
              else
                return 0
              end
            end
          end

          if a_total_points < b_total_points
            return 1
          else
            return -1
          end
        end

        def self.get_team_positions
          positions = ::Themis::Finals::Models::Team.all.map do |team|
            last_attack = ::Themis::Finals::Models::Attack.last(
              team_id: team.id,
              considered: true
            )

            last_score = ::Themis::Finals::Models::TotalScore.first(
              team_id: team.id
            )

            attack_pts = last_score.nil? ? 0.0 : last_score.attack_points
            availability_pts = last_score.nil? ? 0.0 : last_score.availability_points
            defence_pts = last_score.nil? ? 0.0 : last_score.defence_points
            total_pts = attack_pts + availability_pts + defence_pts

            {
              team_id: team.id,
              attack_points: attack_pts,
              availability_points: availability_pts,
              defence_points: defence_pts,
              total_points: total_pts,
              last_attack: last_attack.nil? ? nil : last_attack.occured_at
            }
          end

          precision = ENV.fetch('THEMIS_FINALS_SCORE_PRECISION', '4').to_i
          positions.sort! { |a, b| sort_rows(a, b, precision) }
        end
      end
    end
  end
end

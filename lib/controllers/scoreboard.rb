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
              total_relative: position[:total_relative],
              defence_relative: position[:defence_relative],
              defence_points: position[:defence_points],
              attack_relative: position[:attack_relative],
              attack_points: position[:attack_points],
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

          a_total_relative = a[:total_relative]
          b_total_relative = b[:total_relative]

          if (a_total_relative - b_total_relative).abs < zero_edge
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
                return 1
              elsif a_last_attack > b_last_attack
                return -1
              else
                return 0
              end
            end
          end

          if a_total_relative < b_total_relative
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

            {
              team_id: team.id,
              defence_points: \
                if last_score.nil?
                  0.0
                else
                  last_score.defence_points
                end,
              attack_points: \
                if last_score.nil?
                  0.0
                else
                  last_score.attack_points
                end,
              last_attack: last_attack.nil? ? nil : last_attack.occured_at
            }
          end

          leader_defence = positions.max_by { |x| x[:defence_points] }
          max_defence = leader_defence[:defence_points]

          leader_attack = positions.max_by { |x| x[:attack_points] }
          max_attack = leader_attack[:attack_points]

          precision = ENV.fetch('THEMIS_FINALS_SCORE_PRECISION', '4').to_i
          zero_edge = (10 ** -(precision + 1)).to_f

          positions.map! do |position|
            position[:attack_relative] = \
              if max_attack < zero_edge
                0.0
              else
                position[:attack_points] / max_attack
              end
            position[:defence_relative] = \
              if max_defence < zero_edge
                0.0
              else
                position[:defence_points] / max_defence
              end

            position[:total_relative] = \
              (0.5 *
               (position[:attack_relative] + position[:defence_relative])
              )

            position
          end

          positions.sort! { |a, b| sort_rows(a, b, precision) }
        end
      end
    end
  end
end

require 'date'
require 'json'
require 'bigdecimal'

require './lib/utils/event_emitter'
require './lib/utils/logger'
require './lib/constants/position_trend'

module Themis
  module Finals
    module Controllers
      class Scoreboard
        def initialize
          @logger = ::Themis::Finals::Utils::Logger.get
        end

        def broadcast?
          scoreboard_state = ::Themis::Finals::Models::ScoreboardState.last
          return scoreboard_state.nil? ? true : scoreboard_state.enabled
        end

        def update
          cutoff = ::DateTime.now
          positions = format_team_positions(get_team_positions)

          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Models::ScoreboardPosition.create(
              created_at: cutoff,
              data: positions
            )

            event_data = {
              muted: false,
              positions: positions
            }

            if broadcast?
              ::Themis::Finals::Utils::EventEmitter.broadcast(
                'scoreboard',
                event_data
              )
            else
              ::Themis::Finals::Utils::EventEmitter.emit(
                'scoreboard',
                event_data,
                nil,
                nil
              )
            end
          end
        end

        def enable_broadcast
          cutoff = ::DateTime.now
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Models::ScoreboardState.create(
              enabled: true,
              created_at: cutoff
            )

            positions = format_team_positions(get_team_positions)

            ::Themis::Finals::Models::ScoreboardPosition.create(
              created_at: cutoff,
              data: positions
            )

            ::Themis::Finals::Utils::EventEmitter.broadcast(
              'scoreboard',
              {
                muted: false,
                positions: positions
              }
            )
          end
        end

        def disable_broadcast
          cutoff = ::DateTime.now
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Models::ScoreboardState.create(
              enabled: false,
              created_at: cutoff
            )

            positions = format_team_positions(get_team_positions)

            ::Themis::Finals::Models::ScoreboardHistoryPosition.create(
              created_at: cutoff,
              data: positions
            )

            ::Themis::Finals::Models::ScoreboardPosition.create(
              created_at: cutoff,
              data: positions
            )

            internal_data = {
              muted: false,
              positions: positions
            }

            other_data = {
              muted: true,
              positions: positions
            }

            ::Themis::Finals::Utils::EventEmitter.emit(
              'scoreboard',
              internal_data,
              other_data,
              other_data
            )
          end
        end

        private
        def format_team_positions(positions)
          positions.map { |pos|
            {
              team_id: pos[:team_id],
              total_points: pos[:total_points],
              attack_points: pos[:attack_points],
              availability_points: pos[:availability_points],
              defence_points: pos[:defence_points],
              last_attack: pos[:last_attack].nil? ? nil : pos[:last_attack].iso8601,
              trend: pos[:trend].nil? ? ::Themis::Finals::Constants::PositionTrend::FLAT : pos[:trend]
            }
          }
        end

        def get_team_positions
          positions = ::Themis::Finals::Models::Team.all.map do |team|
            last_attack = ::Themis::Finals::Models::Attack.last(
              team_id: team.id,
              processed: true
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
              last_attack: last_attack.nil? ? nil : last_attack.occured_at,
              trend: nil
            }
          end

          precision = ::ENV.fetch('THEMIS_FINALS_SCORE_PRECISION', '4').to_i
          positions.sort! { |a, b| sort_rows(a, b, precision) }

          estimate_trends(positions)
        end

        def estimate_trends(positions)
          latest_round = ::Themis::Finals::Models::Round.latest_ready
          if latest_round.nil?
            return positions
          end

          trend_depth = ::ENV.fetch('THEMIS_FINALS_TREND_DEPTH', '5').to_i
          start_num = latest_round.id - trend_depth + 1
          end_num = latest_round.id
          scores = ::Themis::Finals::Models::Score.filter_by_round_range(start_num, end_num).all

          positions.each_with_index.map do |pos, ndx|
            cur_team_scores = scores.select { |s| s.team_id == pos[:team_id] }
            cur_team_total = cur_team_scores.sum { |s| s.attack_points + s.availability_points + s.defence_points }

            prev_team_total = nil
            if ndx > 0
              prev_team_scores = scores.select { |s| s.team_id == positions[ndx - 1][:team_id] }
              prev_team_total = prev_team_scores.sum { |s| s.attack_points + s.availability_points + s.defence_points }
            end

            next_team_total = nil
            if ndx < positions.size - 1
              next_team_scores = scores.select { |s| s.team_id == positions[ndx + 1][:team_id] }
              next_team_total = next_team_scores.sum { |s| s.attack_points + s.availability_points + s.defence_points }
            end

            pos[:trend] = estimate_trend(prev_team_total, cur_team_total, next_team_total)
            pos
          end
        end

        def estimate_trend(prev_total, cur_total, next_total)
          if prev_total.nil? && next_total.nil?  # only one team (?)
            return ::Themis::Finals::Constants::PositionTrend::FLAT
          elsif prev_total.nil?  # the first team
            if cur_total >= next_total
              return ::Themis::Finals::Constants::PositionTrend::FLAT
            else
              return ::Themis::Finals::Constants::PositionTrend::DOWN
            end
          elsif next_total.nil?  # the last team
            if cur_total <= prev_total
              return ::Themis::Finals::Constants::PositionTrend::FLAT
            else
              return ::Themis::Finals::Constants::PositionTrend::UP
            end
          else  # a team in between
            if cur_total > prev_total && cur_total >= next_total
              return ::Themis::Finals::Constants::PositionTrend::UP
            elsif cur_total < prev_total && cur_total < next_total
              return ::Themis::Finals::Constants::PositionTrend::DOWN
            else
              return ::Themis::Finals::Constants::PositionTrend::FLAT
            end
          end
        end

        def sort_rows(a, b, precision)
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
      end
    end
  end
end

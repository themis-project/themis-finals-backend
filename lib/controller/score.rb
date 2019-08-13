require 'sequel'

require './lib/const/flag_poll_state'
require './lib/util/logger'
require './lib/controller/attack'
require './lib/controller/service'
require './lib/util/event_emitter'

module VolgaCTF
  module Final
    module Controller
      class Score
        def initialize
          @logger = ::VolgaCTF::Final::Util::Logger.get
          @service_ctrl = ::VolgaCTF::Final::Controller::Service.new
        end

        def init_scores(round)
          ::VolgaCTF::Final::Model::Team.all.each do |team|
            begin
              init_score(team, round)
            rescue => e
              @logger.error(e.to_s)
            end
          end
        end

        def update_score(flag)
          ::VolgaCTF::Final::Model::DB.transaction(
          ) do
            polls = ::VolgaCTF::Final::Model::FlagPoll.relevant(flag).all
            charge_availability(flag, polls)

            attacks = flag.attacks
            if attacks.count == 0
              error_count = polls.count { |p| p.error? }
              success_count = polls.count { |p| p.success? }

              if error_count == 0 && success_count > 0 && @service_ctrl.can_award_defence?(flag.service, flag.round)
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
          ::VolgaCTF::Final::Model::Team.all.each do |team|
            begin
              update_total_score(team)
            rescue => e
              @logger.error(e.to_s)
            end
          end
        end

        def notify_team_scores(round)
          ::VolgaCTF::Final::Model::DB.transaction do
            ::VolgaCTF::Final::Model::Score.where(round_id: round.id).each do |score|
              data = score.serialize
              team_data = {}
              team_data[score.team_id] = data
              ::VolgaCTF::Final::Util::EventEmitter.emit(
                'team/score',
                data,
                nil,
                nil,
                team_data
              )
            end
          end
        end

        def get_team_scores(team)
          round = ::VolgaCTF::Final::Model::Round.latest_ready
          if round.nil?
            return []
          end

          ::VolgaCTF::Final::Model::Score.filter_by_team_round(team, round)
        end

        private
        def score_table_name
          ::VolgaCTF::Final::Model::Score.table_name
        end

        def init_score(team, round)
          ::VolgaCTF::Final::Model::DB.transaction do
            ::VolgaCTF::Final::Model::Score.create(
              attack_points: 0.0,
              availability_points: 0.0,
              defence_points: 0.0,
              team_id: team.id,
              round_id: round.id
            )
          end
        end

        def charge_availability(flag, polls)
          ::VolgaCTF::Final::Model::DB.transaction do
            success_count = polls.count { |p| p.success? }
            return if success_count == 0
            pts = Float(success_count) / Float(polls.count)

            ::VolgaCTF::Final::Model::Score.dataset.returning.insert_conflict(
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
          ::VolgaCTF::Final::Model::DB.transaction do
            ::VolgaCTF::Final::Model::Score.dataset.returning.insert_conflict(
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
          ::VolgaCTF::Final::Model::DB.transaction do
            ::VolgaCTF::Final::Model::Score.dataset.returning.insert_conflict(
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
          ::VolgaCTF::Final::Model::DB.transaction do
            attack_pts = 0.0
            availability_pts = 0.0
            defence_pts = 0.0

            ::VolgaCTF::Final::Model::Score.where(team_id: team.id).each do |score|
              attack_pts += score.attack_points
              availability_pts += score.availability_points
              defence_pts += score.defence_points
            end

            ::VolgaCTF::Final::Model::TotalScore.dataset.returning.insert_conflict(
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

            ::VolgaCTF::Final::Model::DB.after_commit do
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

task :reset_db do
    require './config'
    require './lib/models/init'

    Themis::Models::init
    DataMapper.auto_migrate!
end


task :init_contest do
    require './config'
    require './lib/models/init'

    Themis::Models::init

    Themis::Configuration.get_teams.each do |team_opts|
        team = Themis::Models::Team.create(
            name: team_opts.name,
            network: team_opts.network,
            host: team_opts.host)
        team.save
    end

    Themis::Configuration.get_services.each do |service_opts|
        service = Themis::Models::Service.create(
            name: service_opts.name,
            alias: service_opts.alias)
        service.save
    end

    contest_state = Themis::Models::ContestState.create(
        state: :preparation,
        created_at: DateTime.now)
    contest_state.save

    scoreboard_state = Themis::Models::ScoreboardState.create(
        state: :enabled,
        created_at: DateTime.now,
        calculated_scores: nil,
        last_attacks: nil)
    scoreboard_state.save
end


# task :test_generate_flag do
#     require './config'
#     require './lib/utils/flag_generator'

#     puts Themis::Utils::FlagGenerator::get_flag
# end

# task :test_publisher do
#     require './config'
#     require './lib/utils/publisher'

#     p = Themis::Utils::Publisher.new
#     p.publish 'test', 'HELLO!'
#     p.publish 'test', 'WORLD!'
# end
require './lib/configuration/init'


module Themis
    module Configuration
        network do
            internal '172.20.0.0/24'  # internal network (for contest organizers)
            other '172.20.100.0/24'  # other network (for visualization system)
        end

        contest_flow do
            flag_lifetime 300  # flag lives for 300 seconds
            push_period 120  # push new flags every 120 seconds
            poll_period 60  # poll submitted flags every 60 seconds
            poll_count 2  # poll 2 flags at once
            update_period 60  # update scores every 60 seconds
            attack_limits 200, 60  # max 200 attack attempts for the last 60 seconds
            generator_secret 'Yj9W6vWzGS2pgifUeLz60+gKokzw9wzchUq7/70f664yIkv47YQpeUO0TZV6F57yMAvrkc7KBJ4CJul/tnO1IA=='  # an IV for flag generator
        end

        team 'team_1' do  # this is an internal alias
            name 'Team #1'  # team displayed name
            network '172.20.1.0/24'  # team network
            host '172.20.1.2'  # game box address
        end

        team 'team_2' do
            name 'Team #2'
            network '172.20.2.0/24'
            host '172.20.2.2'
        end

        team 'team_3' do
            name 'Team #3'
            network '172.20.3.0/24'
            host '172.20.3.2'
        end
        # and so on for teams

        service 'service_1' do  # this is an internal alias
            name 'Service #1'  # service displayed name
        end

        service 'service_2' do
            name 'Service #2'
        end
        # and so on for services
    end
end
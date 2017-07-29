require './lib/configuration/init'

module Themis
  module Finals
    module Configuration
      network do
        internal '172.20.0.0/24'  # internal network (for contest organizers)
      end

      contest_flow do
        flag_lifetime 300  # flag lives for 300 seconds
        push_period 120  # push new flags every 120 seconds
        poll_period 60  # poll submitted flags every 60 seconds
        poll_count 2  # poll 2 flags at once
        update_period 60  # update scores every 60 seconds
        attack_limits 200, 60  # max 200 attack attempts for the last 60 seconds
      end

      team 'team1' do  # this is an internal alias
        name 'Team #1'  # team displayed name
        network '172.20.1.0/24'  # team network
      end

      team 'team2' do
        name 'Team #2'
        network '172.20.2.0/24'
      end

      team 'team3' do
        name 'Team #3'
        network '172.20.3.0/24'
      end
      # and so on for teams

      service 'service1' do  # this is an internal alias
        base_url = 'http://service1.checker.finals.themis-project.com'

        name 'Service #1'  # service displayed name
        protocol 2
        hostmask '0.0.0.3'
        metadata push_url: "#{base_url}/push", pull_url: "#{base_url}/pull"
      end

      service 'service2' do
        base_url = 'http://service2.checker.finals.themis-project.com'

        name 'Service #2'  # service displayed name
        protocol 2
        hostmask '0.0.0.3'
        metadata push_url: "#{base_url}/push", pull_url: "#{base_url}/pull"
      end

      service 'service3' do
        base_url = 'http://service3.checker.finals.themis-project.com'

        name 'Service #3'  # service displayed name
        protocol 2
        hostmask '0.0.0.3'
        metadata push_url: "#{base_url}/push", pull_url: "#{base_url}/pull"
      end
      # and so on for services
    end
  end
end

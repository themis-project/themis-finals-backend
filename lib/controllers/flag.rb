require './lib/utils/flag_generator'
require './lib/utils/logger'

require 'jwt'
require 'openssl'

module Themis
  module Finals
    module Controllers
      module Flag
        @logger = ::Themis::Finals::Utils::Logger.get

        def self.issue(team, service, round)
          flag_model = nil

          ::Themis::Finals::Models::DB.transaction do
              flag, label = ::Themis::Finals::Utils::FlagGenerator.generate_flag
              created = ::DateTime.now
              flag_model = ::Themis::Finals::Models::Flag.create(
                flag: flag,
                created_at: created,
                pushed_at: nil,
                expired_at: nil,
                considered_at: nil,
                label: label,
                capsule: encode(flag, created)
                service_id: service.id,
                team_id: team.id,
                round_id: round.id
              )
          end

          flag_model
        end

        def self.encode(flag, created)
          key = ::OpenSSL::PKey.read(::ENV['THEMIS_FINALS_FLAG_SIGN_KEY_PRIVATE'].gsub('\n', "\n"))
          payload = {
            'flag' => flag,
            'created' => created.iso8601
          }
          alg = 'none'
          if key.class == ::OpenSSL::PKey::RSA
            alg = 'RS256'
          elsif key.class == ::OpenSSL::PKey::EC
            alg = 'ES256'
          end

          "#{::ENV['THEMIS_FINALS_FLAG_WRAP_PREFIX']}"\
          "#{::JWT.encode(payload, key, alg)}"\
          "#{::ENV['THEMIS_FINALS_FLAG_WRAP_SUFFIX']}"
        end
      end
    end
  end
end

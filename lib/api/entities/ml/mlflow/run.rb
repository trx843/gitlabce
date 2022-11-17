# frozen_string_literal: true

module API
  module Entities
    module Ml
      module Mlflow
        class Run < Grape::Entity
          expose :run do
            expose :itself, using: RunInfo, as: :info
            expose :data do
              expose :metrics, using: Metric
              expose :params, using: RunParam
            end
          end
        end
      end
    end
  end
end

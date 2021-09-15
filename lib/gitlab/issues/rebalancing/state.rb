# frozen_string_literal: true

module Gitlab
  module Issues
    module Rebalancing
      class State
        REDIS_EXPIRY_TIME = 10.days
        MAX_NUMBER_OF_CONCURRENT_REBALANCES = 5
        NAMESPACE = 1
        PROJECT = 2

        def initialize(root_namespace, projects)
          @root_namespace = root_namespace
          @projects = projects
          @rebalanced_container_type = @root_namespace.is_a?(Group) ? NAMESPACE : PROJECT
          @rebalanced_container_id = @rebalanced_container_type == NAMESPACE ? @root_namespace.id : projects.take.id # rubocop:disable CodeReuse/ActiveRecord
        end

        def track_new_running_rebalance
          with_redis do |redis|
            redis.multi do |multi|
              # we trigger re-balance for namespaces(groups) or specific user project
              value = "#{rebalanced_container_type}/#{rebalanced_container_id}"
              multi.sadd(concurrent_running_rebalances_key, value)
              multi.expire(concurrent_running_rebalances_key, REDIS_EXPIRY_TIME)
            end
          end
        end

        def concurrent_running_rebalances_count
          with_redis { |redis| redis.scard(concurrent_running_rebalances_key).to_i }
        end

        def rebalance_in_progress?
          all_rebalanced_containers = with_redis { |redis| redis.smembers(concurrent_running_rebalances_key) }

          is_running = case rebalanced_container_type
                       when NAMESPACE
                         namespace_ids = all_rebalanced_containers.map {|string| string.split("#{NAMESPACE}/").second.to_i }.compact
                         namespace_ids.include?(root_namespace.id)
                       when PROJECT
                         project_ids = all_rebalanced_containers.map {|string| string.split("#{PROJECT}/").second.to_i }.compact
                         project_ids.include?(projects.take.id) # rubocop:disable CodeReuse/ActiveRecord
                       else
                         false
                       end

          refresh_keys_expiration if is_running

          is_running
        end

        def can_start_rebalance?
          rebalance_in_progress? || too_many_rebalances_running?
        end

        def cache_issue_ids(issue_ids)
          with_redis do |redis|
            values = issue_ids.map { |issue| [issue.relative_position, issue.id] }

            redis.multi do |multi|
              multi.zadd(issue_ids_key, values) unless values.blank?
              multi.expire(issue_ids_key, REDIS_EXPIRY_TIME)
            end
          end
        end

        def get_cached_issue_ids(index, limit)
          with_redis do |redis|
            redis.zrange(issue_ids_key, index, index + limit - 1)
          end
        end

        def cache_current_index(index)
          with_redis { |redis| redis.set(current_index_key, index, ex: REDIS_EXPIRY_TIME) }
        end

        def get_current_index
          with_redis { |redis| redis.get(current_index_key).to_i }
        end

        def cache_current_project_id(project_id)
          with_redis { |redis| redis.set(current_project_key, project_id, ex: REDIS_EXPIRY_TIME) }
        end

        def get_current_project_id
          with_redis { |redis| redis.get(current_project_key) }
        end

        def issue_count
          @issue_count ||= with_redis { |redis| redis.zcard(issue_ids_key)}
        end

        def remove_current_project_id_cache
          with_redis { |redis| redis.del(current_project_key)}
        end

        def refresh_keys_expiration
          with_redis do |redis|
            redis.multi do |multi|
              multi.expire(issue_ids_key, REDIS_EXPIRY_TIME)
              multi.expire(current_index_key, REDIS_EXPIRY_TIME)
              multi.expire(current_project_key, REDIS_EXPIRY_TIME)
              multi.expire(concurrent_running_rebalances_key, REDIS_EXPIRY_TIME)
            end
          end
        end

        def cleanup_cache
          with_redis do |redis|
            redis.multi do |multi|
              multi.del(issue_ids_key)
              multi.del(current_index_key)
              multi.del(current_project_key)
              multi.srem(concurrent_running_rebalances_key, "#{rebalanced_container_type}/#{rebalanced_container_id}")
            end
          end
        end

        private

        attr_accessor :root_namespace, :projects, :rebalanced_container_type, :rebalanced_container_id

        def too_many_rebalances_running?
          concurrent_running_rebalances_count <= MAX_NUMBER_OF_CONCURRENT_REBALANCES
        end

        def redis_key_prefix
          "gitlab:issues-position-rebalances"
        end

        def issue_ids_key
          "#{redis_key_prefix}:#{root_namespace.id}"
        end

        def current_index_key
          "#{issue_ids_key}:current_index"
        end

        def current_project_key
          "#{issue_ids_key}:current_project_id"
        end

        def concurrent_running_rebalances_key
          "#{redis_key_prefix}:running_rebalances"
        end

        def with_redis(&blk)
          Gitlab::Redis::SharedState.with(&blk) # rubocop: disable CodeReuse/ActiveRecord
        end
      end
    end
  end
end
#
# Author:: Tim Hinderliter (<tim@opscode.com>)
# Copyright:: Copyright (c) 2010 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Wrapper class for interacting with JSON.

begin
  require 'yajl'

  class Chef
    class JSON
      class <<self
        def constantize(s)
          r = Object
          s.split('::').each { |p| r = r.const_get(p) }
          r
        end

        def rework_object(obj)
          case obj
          when Array then obj.map { |e| rework_object(e) }
          when Hash
            new_obj = Hash.new
            obj.each_pair do |k, v|
              new_obj[k] = rework_object(v)
            end
            if new_obj.include?('json_class')
              klass = constantize(new_obj['json_class'])
              unless klass.respond_to?(:json_create)
                klass.new(new_obj)
              else
                klass.json_create(new_obj)
              end
            else
              new_obj
            end
          else obj
          end
        end

        # Yajl classes do not limit nesting anyway 
        def from_json(source, opts = {})
          rework_object(Yajl::Parser.parse(source, opts || {}))
        end

        def to_json(obj, opts = nil)
          Yajl::Encoder.encode(obj, opts || {})
        end

        def to_json_pretty(obj, opts = nil)
          Yajl::Encoder.encode(obj, { :pretty => true }.merge(opts || {}))
        end
      end
    end
  end

rescue LoadError
  # fallback to json
  require 'json'

  class Chef
    class JSON
      JSON_MAX_NESTING = 1000

      class <<self
        # See CHEF-1292/PL-538. Increase the max nesting for JSON, which defaults
        # to 19, and isn't enough for some (for example, a Node within a Node)
        # structures.
        def opts_add_max_nesting(opts)
          if opts.nil? || !opts.has_key?(:max_nesting)
            opts = opts.nil? ? Hash.new : opts.clone
            opts[:max_nesting] = JSON_MAX_NESTING
          end
          opts
        end

        # Just call the JSON gem's parse method with a modified :max_nesting field
        def from_json(source, opts = {})
          ::JSON.parse(source, opts_add_max_nesting(opts))
        end

        def to_json(obj, opts = nil)
          obj.to_json(opts_add_max_nesting(opts))
        end

        def to_json_pretty(obj, opts = nil)
          ::JSON.pretty_generate(obj, opts_add_max_nesting(opts))
        end

        private :opts_add_max_nesting
      end
    end
  end

end

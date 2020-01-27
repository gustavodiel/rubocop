# frozen_string_literal: true

module RuboCop
  module Cop
    module Lint
      # This cop checks for uses of the deprecated class method usages.
      #
      # @example
      #
      #   # bad
      #
      #   File.exists?(some_path)
      #   Dir.exists?(some_path)
      #   iterator?
      #
      # @example
      #
      #   # good
      #
      #   File.exist?(some_path)
      #   Dir.exist?(some_path)
      #   block_given?
      class DeprecatedClassMethods < Cop
        # Inner class to DeprecatedClassMethods.
        # This class exists to add abstraction and clean naming to the
        # objects that are going to be operated on.
        class DeprecatedClassMethod
          include RuboCop::AST::Sexp

          attr_reader :class_constant, :deprecated_method, :replacement_method, :argument_name

          def initialize(deprecated:, replacement:, class_constant: nil, argument_name: nil)
            @deprecated_method = deprecated
            @replacement_method = replacement
            @class_constant = class_constant
            @argument_name = argument_name
          end

          def class_nodes
            @class_nodes ||=
              [
                s(:const, nil, class_constant),
                s(:const, s(:cbase), class_constant)
              ]
          end

          def argument_node
            @argument_node ||= s(:sym, argument_name.to_sym)
          end

          def fail?(node)
            first_argument = node.first_argument

            if match_rules?(node)
              if match_arguments?
                return valid_node_arguments?(first_argument)
              end

              return true
            end

            false
          end

          def deprecated_method_formatted
            return "#{class_constant}.#{deprecated_method}(#{argument_name}:)" if argument_name

            return "#{class_constant}.#{deprecated_method}" if class_constant

            return deprecated_method
          end

          private

          def valid_node_arguments?(argument)
            argument.is_a?(AST::HashNode) &&
              argument.keys.size == 1 &&
              argument.keys.include?(argument_node)
          end

          def match_rules?(node)
            class_nodes.include?(node.receiver) && node.method?(deprecated_method)
          end

          def match_arguments?
            argument_name != nil
          end
        end

        MSG = '`%<current>s` is deprecated in favor of `%<prefer>s`.'
        DEPRECATED_METHODS_OBJECT = [
          DeprecatedClassMethod.new(deprecated: :exists?,
                                    replacement: 'File.exist?',
                                    class_constant: :File),
          DeprecatedClassMethod.new(deprecated: :exists?,
                                    replacement: 'Dir.exist?',
                                    class_constant: :Dir),
          DeprecatedClassMethod.new(deprecated: :iterator?,
                                    replacement: :block_given?)
        ].freeze

        def on_send(node)
          setup_rules(cop_config['Rules'] || [])

          check(node) do |match|
            message = format(MSG, current: match.deprecated_method_formatted,
                                  prefer: match.replacement_method)

            add_offense(node, location: :selector, message: message)
          end
        end

        def autocorrect(node)
          lambda do |corrector|
            check(node) do |data|
              binding.pry
              corrector.replace(node.loc.expression,
                                data.replacement_method.to_s)
            end
          end
        end

        private

        attr_accessor :rules

        def setup_rules(new_rules)
          @rules = DEPRECATED_METHODS_OBJECT

          new_rules.each do |rule|
            rules << DeprecatedClassMethod.new(
              class_constant: rule['Constant'],
              deprecated: rule['Method'],
              replacement: rule['Replacement'],
              argument_name: rule['ArgumentName']
            )
          end
        end

        def check(node)
          rules.each do |rule|
            yield rule if rule.fail?(node)
          end
        end
      end
    end
  end
end

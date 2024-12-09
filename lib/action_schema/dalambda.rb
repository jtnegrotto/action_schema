module ActionSchema
  # Dalambda is a stupid name for a stupid class.
  # Forces your lambdas to ignore extra arguments and blocks.
  # Works with instance_exec, etc.
  class Dalambda
    def self.[](lambda_or_proc, &block)
      new(lambda_or_proc || block)
    end

    def initialize(lambda_or_proc, &block)
      @lambda = lambda_or_proc || block
      raise ArgumentError, "You must provide a lambda, proc, or block" unless @lambda.is_a?(Proc)
    end

    def to_proc
      da_actual_lambda = @lambda
      arity = @lambda.arity
      proc do |*args, &block|
        if da_actual_lambda.parameters.any? { |type, _| type == :block }
          instance_exec(*args.take(arity), block, &da_actual_lambda)
        else
          instance_exec(*args.take(arity), &da_actual_lambda)
        end
      end
    end
  end
end

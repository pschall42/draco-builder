# frozen_string_literal: true

module Physics
  module Colliders
    class Base
      # This method should only be used to route to the corresponding Physics method and is only provided for convenience (we need to accomodate for all possible collisions anyway, and spreading the logic between multiple files and classes will just make debugging more difficult)
      def intersect?(other_collider)
        raise NoMethodError.new("#{self.class.name}##{__method__} is missing its implementation but was called")
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'base'
# require_relative '../transform'

module Physics
  module Colliders
    class Circle < Base
      attr_accessor :center, :radius
      def initialize(center, radius)
        @center = Transform::Position.from(center)
        @radius = radius
      end
      def intersect?(other_collider)
        ::Physics.circle_intersecting?(self, other_collider)
      end
      def x
        self.center[0]
      end
      def y
        self.center[1]
      end

      def area
        Math::PI * (self.radius ** 2.0)
      end

      def axis_aligned_bounding_box
        @aabb ||= {
          x: self.center[0] - self.radius,
          y: self.center[1] - self.radius,
          w: 2 * self.radius,
          h: 2 * self.radius
        }
      end
      alias_method :aabb, :axis_aligned_bounding_box
    end
  end
end

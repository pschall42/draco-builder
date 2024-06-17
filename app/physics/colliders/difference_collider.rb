# frozen_string_literal: true

require_relative 'algebraic_collider'

module Physics
  module Colliders
    class DifferenceCollider < AlgebraicCollider
      def intersect?(other_collider)
        ::Physics.difference_collider_intersecting?(self, other_collider)
      end
    end
  end
end
